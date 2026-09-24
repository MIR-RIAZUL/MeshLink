package com.example.meshlink

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothGattServer
import android.bluetooth.BluetoothGattServerCallback
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.bluetooth.le.BluetoothLeScanner
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import android.provider.Settings
import android.util.Base64
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.nio.charset.StandardCharsets
import java.security.SecureRandom

class MainActivity : FlutterActivity() {
    companion object {
        private const val METHOD_CHANNEL = "meshlink/device_discovery"
        private const val SECURITY_CHANNEL = "meshlink/security"
        private const val EVENT_CHANNEL = "meshlink/device_discovery_events"
        private const val REQUEST_NEARBY_PERMISSIONS = 42
        private const val REQUEST_ENABLE_BT = 43
        private val MESH_LINK_SERVICE = ParcelUuid.fromString("6f4b6d65-7368-4c69-6e6b-000000000002")
        private val REQUEST_CHARACTERISTIC = java.util.UUID.fromString("6f4b6d65-7368-4c69-6e6b-000000000003")
        private val RESPONSE_CHARACTERISTIC = java.util.UUID.fromString("6f4b6d65-7368-4c69-6e6b-000000000004")
        private val MESSAGE_CHARACTERISTIC = java.util.UUID.fromString("6f4b6d65-7368-4c69-6e6b-000000000005")
        private val CLIENT_CONFIG = java.util.UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
    }

    private val handler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null
    private var pendingStartResult: MethodChannel.Result? = null
    private var pendingEnableResult: MethodChannel.Result? = null
    private var scanner: BluetoothLeScanner? = null
    private var advertiser: BluetoothLeAdvertiser? = null
    private var scanning = false
    private var advertising = false
    private val devicesByIdentity = mutableMapOf<String, BluetoothDevice>()
    private val deviceNamesByIdentity = mutableMapOf<String, String>()
    private val pendingIncoming = mutableMapOf<String, BluetoothDevice>()
    private var connectedServerDevice: BluetoothDevice? = null
    private var connectedServerId: String? = null
    private var gattServer: BluetoothGattServer? = null
    private var clientGatt: BluetoothGatt? = null
    private var clientTargetId: String? = null
    private var isReceiverRegistered = false
    private var connectionTimeoutRunnable: Runnable? = null

    private fun sendEvent(event: Map<String, Any?>) {
        handler.post {
            eventSink?.success(event)
        }
    }

    private val bluetoothStateReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == BluetoothAdapter.ACTION_STATE_CHANGED) {
                val state = intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, BluetoothAdapter.ERROR)
                when (state) {
                    BluetoothAdapter.STATE_OFF -> {
                        stopDiscovery()
                        disconnect(clientTargetId ?: connectedServerId)
                        sendEvent(mapOf("type" to "bluetoothStateChanged", "state" to "disabled"))
                    }
                    BluetoothAdapter.STATE_ON -> {
                        sendEvent(mapOf("type" to "bluetoothStateChanged", "state" to "enabled"))
                    }
                    BluetoothAdapter.STATE_TURNING_OFF -> {
                        stopDiscovery()
                    }
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler(::onMethodCall)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SECURITY_CHANNEL)
            .setMethodCallHandler(::onSecurityMethodCall)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })

        if (!isReceiverRegistered) {
            val filter = IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED)
            registerReceiver(bluetoothStateReceiver, filter)
            isReceiverRegistered = true
        }
    }

    private fun onSecurityMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            val preferences = EncryptedSharedPreferences.create(
                this,
                "meshlink_crypto_identity",
                MasterKey.Builder(this).setKeyScheme(MasterKey.KeyScheme.AES256_GCM).build(),
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
            )
            when (call.method) {
                "readIdentity" -> result.success(preferences.getString("x25519_identity", null))
                "writeIdentity" -> {
                    val value = call.argument<String>("value")
                    if (value == null) result.error("invalid_argument", "Missing identity", null)
                    else {
                        preferences.edit().putString("x25519_identity", value).commit()
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        } catch (_: Exception) {
            result.error("secure_storage_failure", "Secure identity storage unavailable", null)
        }
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getBluetoothState" -> result.success(getBluetoothStateMap())
            "checkAvailability" -> result.success(checkAvailability())
            "requestEnableBluetooth" -> requestEnableBluetooth(result)
            "openAppSettings" -> {
                openAppSettings()
                result.success(true)
            }
            "getLocalIdentity" -> result.success(getLocalIdentityMap())
            "setDisplayName" -> {
                val name = call.argument<String>("name") ?: ""
                setDisplayName(name)
                result.success(true)
            }
            "startDiscovery" -> requestPermissionsThenStart(result)
            "stopDiscovery" -> {
                stopDiscovery()
                result.success(null)
            }
            "connect" -> connect(call.argument<String>("deviceId"), result)
            "acceptConnection" -> acceptConnection(call.argument<String>("deviceId"), result)
            "rejectConnection" -> rejectConnection(call.argument<String>("deviceId"), result)
            "sendMessage" -> {
                val deviceId = call.argument<String>("deviceId")
                val payload = call.argument<String>("payload")
                sendMessage(deviceId, payload, result)
            }
            "disconnect" -> {
                disconnect(call.argument<String>("deviceId"))
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun getBluetoothStateMap(): Map<String, Any> {
        val adapter = bluetoothAdapter()
        if (adapter == null) {
            return mapOf(
                "state" to "unavailable",
                "message" to "Bluetooth is not supported on this device."
            )
        }
        if (!hasNearbyPermissions()) {
            return mapOf(
                "state" to "permissionRequired",
                "message" to "Bluetooth permissions are required for MeshLink discovery."
            )
        }
        if (!adapter.isEnabled) {
            return mapOf(
                "state" to "disabled",
                "message" to "Bluetooth is disabled. Please turn Bluetooth ON."
            )
        }
        return mapOf(
            "state" to "enabled",
            "message" to "Bluetooth is ready."
        )
    }

    private fun checkAvailability(): Map<String, Any> {
        val adapter = bluetoothAdapter()
            ?: return mapOf("available" to false, "message" to "Bluetooth is not supported on this device.")
        if (!adapter.isEnabled) {
            return mapOf("available" to false, "message" to "Bluetooth is disabled. Please enable it to discover nearby devices.")
        }
        if (!adapter.isMultipleAdvertisementSupported) {
            return mapOf("available" to false, "message" to "This device does not support Bluetooth LE advertising required by MeshLink discovery.")
        }
        return mapOf("available" to true)
    }

    private fun requestEnableBluetooth(result: MethodChannel.Result) {
        val adapter = bluetoothAdapter()
        if (adapter == null) {
            result.success(false)
            return
        }
        if (adapter.isEnabled) {
            result.success(true)
            return
        }
        pendingEnableResult = result
        try {
            val enableBtIntent = Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE)
            startActivityForResult(enableBtIntent, REQUEST_ENABLE_BT)
        } catch (e: Exception) {
            try {
                val intent = Intent(Settings.ACTION_BLUETOOTH_SETTINGS)
                startActivity(intent)
                result.success(true)
            } catch (e2: Exception) {
                result.success(false)
            }
        }
    }

    private fun openAppSettings() {
        try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.fromParts("package", packageName, null)
            }
            startActivity(intent)
        } catch (e: Exception) {
            val intent = Intent(Settings.ACTION_SETTINGS)
            startActivity(intent)
        }
    }

    private fun getLocalIdentityMap(): Map<String, String> {
        return mapOf(
            "id" to meshLinkId(),
            "name" to getDisplayName()
        )
    }

    private fun getDisplayName(): String {
        val preferences = getSharedPreferences("meshlink", Context.MODE_PRIVATE)
        return preferences.getString("display_name", "MeshLink User") ?: "MeshLink User"
    }

    private fun setDisplayName(name: String) {
        val trimmed = name.trim()
        val finalName = if (trimmed.isEmpty()) "MeshLink User" else trimmed
        val preferences = getSharedPreferences("meshlink", Context.MODE_PRIVATE)
        preferences.edit().putString("display_name", finalName).apply()
        if (advertising) {
            startAdvertising()
        }
    }

    private fun meshLinkId(): String {
        val preferences = getSharedPreferences("meshlink", Context.MODE_PRIVATE)
        preferences.getString("mesh_id", null)?.let { return it }
        val randomBytes = ByteArray(3).also { SecureRandom().nextBytes(it) }
        val hex = randomBytes.joinToString("") { "%02X".format(it) }
        val id = "ML-$hex"
        preferences.edit().putString("mesh_id", id).apply()
        return id
    }

    private fun meshLinkIdentityPayload(): ByteArray {
        val id = meshLinkId()
        val name = getDisplayName()
        val idBytes = id.toByteArray(StandardCharsets.US_ASCII)
        val nameBytes = name.toByteArray(StandardCharsets.UTF_8)
        val maxNameLen = (20 - idBytes.size).coerceAtLeast(0)
        val trimmedNameBytes = if (nameBytes.size > maxNameLen) nameBytes.copyOf(maxNameLen) else nameBytes
        
        val payload = ByteArray(idBytes.size + trimmedNameBytes.size)
        System.arraycopy(idBytes, 0, payload, 0, idBytes.size)
        if (trimmedNameBytes.isNotEmpty()) {
            System.arraycopy(trimmedNameBytes, 0, payload, idBytes.size, trimmedNameBytes.size)
        }
        return payload
    }

    private fun requestPermissionsThenStart(result: MethodChannel.Result) {
        val availability = checkAvailability()
        if (availability["available"] != true) {
            result.success(mapOf("started" to false, "message" to availability["message"]!!))
            return
        }
        if (hasNearbyPermissions()) {
            beginDiscovery(result)
            return
        }
        pendingStartResult = result
        requestPermissions(requiredPermissions(), REQUEST_NEARBY_PERMISSIONS)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_NEARBY_PERMISSIONS) return
        val result = pendingStartResult ?: return
        pendingStartResult = null
        if (hasNearbyPermissions()) {
            beginDiscovery(result)
            return
        }
        val permanentlyDenied = permissions.anyIndexed { index, permission ->
            grantResults.getOrNull(index) != PackageManager.PERMISSION_GRANTED &&
                !shouldShowRequestPermissionRationale(permission)
        }
        result.success(mapOf(
            "started" to false,
            "permanentlyDenied" to permanentlyDenied,
            "message" to if (permanentlyDenied)
                "Nearby-device permission was permanently denied. Enable it in Android Settings to discover MeshLink devices."
            else
                "Nearby-device permission is needed to find and advertise MeshLink devices."
        ))
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_ENABLE_BT) {
            val result = pendingEnableResult
            pendingEnableResult = null
            val isEnabled = bluetoothAdapter()?.isEnabled == true
            result?.success(isEnabled)
            if (isEnabled) {
                eventSink?.success(mapOf("type" to "bluetoothStateChanged", "state" to "enabled"))
            }
        }
    }

    @SuppressLint("MissingPermission")
    private fun beginDiscovery(result: MethodChannel.Result) {
        val adapter = bluetoothAdapter()
        if (adapter == null || !adapter.isEnabled) {
            result.success(mapOf("started" to false, "message" to "Bluetooth is not enabled."))
            return
        }
        scanner = adapter.bluetoothLeScanner
        advertiser = adapter.bluetoothLeAdvertiser
        if (scanner == null || advertiser == null) {
            result.success(mapOf("started" to false, "message" to "Bluetooth LE discovery is unavailable on this device."))
            return
        }
        stopDiscovery()
        ensureGattServer()
        val filter = ScanFilter.Builder().setServiceUuid(MESH_LINK_SERVICE).build()
        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()
        scanner!!.startScan(listOf(filter), settings, scanCallback)
        scanning = true
        startAdvertising()
        result.success(mapOf("started" to true))
    }

    @SuppressLint("MissingPermission")
    private fun startAdvertising() {
        if (advertiser == null) {
            advertiser = bluetoothAdapter()?.bluetoothLeAdvertiser
        }
        if (advertiser == null) return
        if (advertising) {
            try { advertiser?.stopAdvertising(advertiseCallback) } catch (_: Exception) {}
            advertising = false
        }
        val data = AdvertiseData.Builder()
            .addServiceUuid(MESH_LINK_SERVICE)
            .addServiceData(MESH_LINK_SERVICE, meshLinkIdentityPayload())
            .setIncludeDeviceName(false)
            .build()
        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM)
            .setConnectable(true)
            .build()
        advertiser?.startAdvertising(settings, data, advertiseCallback)
    }

    @SuppressLint("MissingPermission")
    private fun stopDiscovery() {
        if (scanning) {
            try { scanner?.stopScan(scanCallback) } catch (_: Exception) {}
        }
        if (advertising) {
            try { advertiser?.stopAdvertising(advertiseCallback) } catch (_: Exception) {}
        }
        scanning = false
        advertising = false
    }

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            val serviceData = result.scanRecord?.getServiceData(MESH_LINK_SERVICE) ?: return
            if (serviceData.size < 9) return

            val idString = String(serviceData.copyOfRange(0, 9), StandardCharsets.US_ASCII)
            val myId = meshLinkId()
            if (idString.equals(myId, ignoreCase = true)) {
                return
            }

            var displayName = "MeshLink User"
            if (serviceData.size > 9) {
                val nameBytes = serviceData.copyOfRange(9, serviceData.size)
                val parsedName = String(nameBytes, StandardCharsets.UTF_8).trim()
                if (parsedName.isNotEmpty()) {
                    displayName = parsedName
                }
            }

            devicesByIdentity[idString] = result.device
            deviceNamesByIdentity[idString] = displayName
            sendEvent(mapOf(
                "type" to "device",
                "id" to idString,
                "name" to displayName,
                "rssi" to result.rssi,
                "isConnectable" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && result.isConnectable)
            ))
        }

        override fun onScanFailed(errorCode: Int) {
            stopDiscovery()
            sendEvent(mapOf("type" to "error", "message" to "Bluetooth scan failed (code $errorCode)."))
        }
    }

    private val advertiseCallback = object : AdvertiseCallback() {
        override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {
            advertising = true
        }

        override fun onStartFailure(errorCode: Int) {
            advertising = false
            sendEvent(mapOf("type" to "error", "message" to "MeshLink advertising could not start (code $errorCode)."))
        }
    }

    private fun bluetoothAdapter(): BluetoothAdapter? =
        (getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager).adapter

    private fun requiredPermissions(): Array<String> = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        arrayOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_ADVERTISE, Manifest.permission.BLUETOOTH_CONNECT)
    } else {
        arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
    }

    private fun hasNearbyPermissions() = Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
        requiredPermissions().all { checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED }

    @SuppressLint("MissingPermission")
    private fun ensureGattServer() {
        if (gattServer != null) return
        val manager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        gattServer = manager.openGattServer(this, serverCallback)?.also { server ->
            val service = BluetoothGattService(MESH_LINK_SERVICE.uuid, BluetoothGattService.SERVICE_TYPE_PRIMARY)
            val request = BluetoothGattCharacteristic(REQUEST_CHARACTERISTIC,
                BluetoothGattCharacteristic.PROPERTY_WRITE,
                BluetoothGattCharacteristic.PERMISSION_WRITE)
            val response = BluetoothGattCharacteristic(RESPONSE_CHARACTERISTIC,
                BluetoothGattCharacteristic.PROPERTY_INDICATE or BluetoothGattCharacteristic.PROPERTY_NOTIFY,
                BluetoothGattCharacteristic.PERMISSION_READ)
            response.addDescriptor(BluetoothGattDescriptor(CLIENT_CONFIG,
                BluetoothGattDescriptor.PERMISSION_READ or BluetoothGattDescriptor.PERMISSION_WRITE))
            
            val message = BluetoothGattCharacteristic(MESSAGE_CHARACTERISTIC,
                BluetoothGattCharacteristic.PROPERTY_WRITE or BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE or BluetoothGattCharacteristic.PROPERTY_INDICATE or BluetoothGattCharacteristic.PROPERTY_NOTIFY,
                BluetoothGattCharacteristic.PERMISSION_WRITE or BluetoothGattCharacteristic.PERMISSION_READ)
            message.addDescriptor(BluetoothGattDescriptor(CLIENT_CONFIG,
                BluetoothGattDescriptor.PERMISSION_READ or BluetoothGattDescriptor.PERMISSION_WRITE))

            service.addCharacteristic(request)
            service.addCharacteristic(response)
            service.addCharacteristic(message)
            server.addService(service)
        }
    }

    @SuppressLint("MissingPermission")
    private fun connect(deviceId: String?, result: MethodChannel.Result) {
        val device = deviceId?.let { devicesByIdentity[it] }
        if (device == null) {
            result.success(mapOf("started" to false, "message" to "This device is no longer available. Discover it again."))
            return
        }
        if (clientGatt != null) {
            result.success(mapOf("started" to false, "message" to "A connection is already in progress."))
            return
        }
        clientTargetId = deviceId
        clientGatt = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            device.connectGatt(this, false, clientCallback, BluetoothDevice.TRANSPORT_LE)
        } else {
            device.connectGatt(this, false, clientCallback)
        }

        // 15-second connection timeout guard
        connectionTimeoutRunnable?.let { handler.removeCallbacks(it) }
        connectionTimeoutRunnable = Runnable {
            if (clientGatt != null && clientTargetId == deviceId) {
                sendEvent(mapOf(
                    "type" to "connectionFailed",
                    "deviceId" to deviceId,
                    "message" to "Unable to connect to this device. Please make sure it is nearby and available."
                ))
                disconnect(deviceId)
            }
        }.also { handler.postDelayed(it, 15_000) }

        result.success(mapOf("started" to true))
    }

    @SuppressLint("MissingPermission")
    private fun acceptConnection(deviceId: String?, result: MethodChannel.Result) {
        val device = deviceId?.let { pendingIncoming.remove(it) }
        if (device == null) { result.success(false); return }
        connectedServerDevice = device
        connectedServerId = deviceId
        notifyResponse(device, 1)
        sendEvent(mapOf("type" to "connected", "deviceId" to deviceId))
        result.success(true)
    }

    @SuppressLint("MissingPermission")
    private fun rejectConnection(deviceId: String?, result: MethodChannel.Result) {
        val device = deviceId?.let { pendingIncoming.remove(it) }
        if (device != null) { notifyResponse(device, 0); gattServer?.cancelConnection(device) }
        result.success(device != null)
    }

    @SuppressLint("MissingPermission")
    private fun notifyResponse(device: BluetoothDevice, value: Int) {
        val characteristic = gattServer?.getService(MESH_LINK_SERVICE.uuid)?.getCharacteristic(RESPONSE_CHARACTERISTIC) ?: return
        characteristic.value = byteArrayOf(value.toByte())
        gattServer?.notifyCharacteristicChanged(device, characteristic, true)
    }

    @SuppressLint("MissingPermission")
    private fun sendMessage(deviceId: String?, payload: String?, result: MethodChannel.Result) {
        if (payload == null || deviceId == null) {
            result.success(mapOf("sent" to false, "message" to "Invalid message payload"))
            return
        }
        val bytes = payload.toByteArray(StandardCharsets.UTF_8)
        
        // If we are client connected to remote server
        if (clientGatt != null && clientTargetId == deviceId) {
            val char = clientGatt?.getService(MESH_LINK_SERVICE.uuid)?.getCharacteristic(MESSAGE_CHARACTERISTIC)
            if (char == null) {
                result.success(mapOf("sent" to false, "message" to "Message characteristic unavailable."))
                return
            }
            char.value = bytes
            char.writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
            val success = clientGatt?.writeCharacteristic(char) == true
            result.success(mapOf("sent" to success))
            return
        }

        // If we are server connected to remote client
        if (connectedServerDevice != null && connectedServerId == deviceId) {
            val char = gattServer?.getService(MESH_LINK_SERVICE.uuid)?.getCharacteristic(MESSAGE_CHARACTERISTIC)
            if (char == null) {
                result.success(mapOf("sent" to false, "message" to "Server message characteristic unavailable."))
                return
            }
            char.value = bytes
            val success = gattServer?.notifyCharacteristicChanged(connectedServerDevice, char, true) == true
            result.success(mapOf("sent" to success))
            return
        }

        result.success(mapOf("sent" to false, "message" to "Device is not currently connected."))
    }

    @SuppressLint("MissingPermission")
    private fun disconnect(deviceId: String?) {
        connectionTimeoutRunnable?.let { handler.removeCallbacks(it) }
        connectionTimeoutRunnable = null
        clientGatt?.disconnect()
        clientGatt?.close()
        clientGatt = null
        clientTargetId = null
        if (connectedServerDevice != null && (deviceId == null || connectedServerId == deviceId)) {
            connectedServerDevice?.let { gattServer?.cancelConnection(it) }
            connectedServerDevice = null
            connectedServerId = null
        }
        if (deviceId != null) {
            pendingIncoming.remove(deviceId)?.let { gattServer?.cancelConnection(it) }
            sendEvent(mapOf("type" to "disconnected", "deviceId" to deviceId))
        }
    }

    private val serverCallback = object : BluetoothGattServerCallback() {
        @SuppressLint("MissingPermission")
        override fun onDescriptorWriteRequest(device: BluetoothDevice, requestId: Int, descriptor: BluetoothGattDescriptor,
            preparedWrite: Boolean, responseNeeded: Boolean, offset: Int, value: ByteArray?) {
            descriptor.value = value
            if (responseNeeded) gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null)
        }

        @SuppressLint("MissingPermission")
        override fun onCharacteristicWriteRequest(device: BluetoothDevice, requestId: Int, characteristic: BluetoothGattCharacteristic,
            preparedWrite: Boolean, responseNeeded: Boolean, offset: Int, value: ByteArray?) {
            if (characteristic.uuid == REQUEST_CHARACTERISTIC && value != null) {
                val id = String(value, StandardCharsets.US_ASCII)
                pendingIncoming[id] = device
                val name = deviceNamesByIdentity[id] ?: "MeshLink device"
                sendEvent(mapOf("type" to "incomingRequest", "deviceId" to id, "name" to name))
            } else if (characteristic.uuid == MESSAGE_CHARACTERISTIC && value != null) {
                val payload = String(value, StandardCharsets.UTF_8)
                sendEvent(mapOf("type" to "messageReceived", "payload" to payload))
            }
            if (responseNeeded) gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null)
        }

        override fun onConnectionStateChange(device: BluetoothDevice, status: Int, newState: Int) {
            if (newState == BluetoothGatt.STATE_DISCONNECTED) {
                val id = if (connectedServerDevice?.address == device.address) connectedServerId
                         else pendingIncoming.entries.firstOrNull { it.value.address == device.address }?.key
                if (id != null) {
                    if (connectedServerDevice?.address == device.address) {
                        connectedServerDevice = null
                        connectedServerId = null
                    }
                    sendEvent(mapOf("type" to "disconnected", "deviceId" to id))
                }
            }
        }
    }

    private val clientCallback = object : BluetoothGattCallback() {
        @SuppressLint("MissingPermission")
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            if (newState == BluetoothGatt.STATE_CONNECTED && status == BluetoothGatt.GATT_SUCCESS) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    gatt.requestMtu(512)
                } else {
                    gatt.discoverServices()
                }
            } else if (newState == BluetoothGatt.STATE_DISCONNECTED) {
                connectionTimeoutRunnable?.let { handler.removeCallbacks(it) }
                connectionTimeoutRunnable = null
                clientTargetId?.let { sendEvent(mapOf("type" to "disconnected", "deviceId" to it)) }
                gatt.close()
                if (clientGatt == gatt) clientGatt = null
            }
        }

        @SuppressLint("MissingPermission")
        override fun onMtuChanged(gatt: BluetoothGatt, mtu: Int, status: Int) {
            gatt.discoverServices()
        }

        @SuppressLint("MissingPermission")
        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            val service = gatt.getService(MESH_LINK_SERVICE.uuid)
            val response = service?.getCharacteristic(RESPONSE_CHARACTERISTIC)
            if (status != BluetoothGatt.GATT_SUCCESS || response == null) {
                clientTargetId?.let { disconnect(it) }
                return
            }
            // Step 1: Enable notifications on RESPONSE_CHARACTERISTIC
            gatt.setCharacteristicNotification(response, true)
            val responseDesc = response.getDescriptor(CLIENT_CONFIG)
            if (responseDesc != null) {
                responseDesc.value = BluetoothGattDescriptor.ENABLE_INDICATION_VALUE
                gatt.writeDescriptor(responseDesc)
            } else {
                // If descriptor is missing, proceed to step 2
                enableMessageNotification(gatt)
            }
        }

        @SuppressLint("MissingPermission")
        private fun enableMessageNotification(gatt: BluetoothGatt) {
            val message = gatt.getService(MESH_LINK_SERVICE.uuid)?.getCharacteristic(MESSAGE_CHARACTERISTIC)
            if (message != null) {
                gatt.setCharacteristicNotification(message, true)
                val msgDesc = message.getDescriptor(CLIENT_CONFIG)
                if (msgDesc != null) {
                    msgDesc.value = BluetoothGattDescriptor.ENABLE_INDICATION_VALUE
                    gatt.writeDescriptor(msgDesc)
                    return
                }
            }
            sendConnectionRequest(gatt)
        }

        @SuppressLint("MissingPermission")
        private fun sendConnectionRequest(gatt: BluetoothGatt) {
            val request = gatt.getService(MESH_LINK_SERVICE.uuid)?.getCharacteristic(REQUEST_CHARACTERISTIC) ?: return
            request.value = meshLinkId().toByteArray(StandardCharsets.US_ASCII)
            gatt.writeCharacteristic(request)
            clientTargetId?.let { sendEvent(mapOf("type" to "waitingForAcceptance", "deviceId" to it)) }
        }

        @SuppressLint("MissingPermission")
        override fun onDescriptorWrite(gatt: BluetoothGatt, descriptor: BluetoothGattDescriptor, status: Int) {
            if (descriptor.characteristic?.uuid == RESPONSE_CHARACTERISTIC) {
                // Step 2: Now that RESPONSE descriptor is written, write MESSAGE descriptor sequentially
                enableMessageNotification(gatt)
            } else if (descriptor.characteristic?.uuid == MESSAGE_CHARACTERISTIC) {
                // Step 3: Now that both descriptors are written, transmit connection request
                sendConnectionRequest(gatt)
            }
        }

        private fun handleCharacteristicChanged(uuid: java.util.UUID, value: ByteArray?) {
            val id = clientTargetId ?: return
            if (uuid == RESPONSE_CHARACTERISTIC && value?.firstOrNull()?.toInt() == 1) {
                // Cancel timeout immediately upon connection
                connectionTimeoutRunnable?.let { handler.removeCallbacks(it) }
                connectionTimeoutRunnable = null
                sendEvent(mapOf("type" to "connected", "deviceId" to id))
            } else if (uuid == MESSAGE_CHARACTERISTIC && value != null) {
                val payload = String(value, StandardCharsets.UTF_8)
                sendEvent(mapOf("type" to "messageReceived", "payload" to payload))
            } else if (uuid == RESPONSE_CHARACTERISTIC) {
                connectionTimeoutRunnable?.let { handler.removeCallbacks(it) }
                connectionTimeoutRunnable = null
                sendEvent(mapOf("type" to "connectionFailed", "deviceId" to id, "message" to "Connection request was rejected."))
                clientGatt?.disconnect()
            }
        }

        @Deprecated("Deprecated in Java")
        override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
            handleCharacteristicChanged(characteristic.uuid, characteristic.value)
        }

        // Android 13+ (API 33) overload
        override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, value: ByteArray) {
            handleCharacteristicChanged(characteristic.uuid, value)
        }
    }

    private inline fun <T> Array<out T>.anyIndexed(predicate: (Int, T) -> Boolean): Boolean {
        forEachIndexed { index, item -> if (predicate(index, item)) return true }
        return false
    }

    override fun onDestroy() {
        if (isReceiverRegistered) {
            try { unregisterReceiver(bluetoothStateReceiver) } catch (_: Exception) {}
            isReceiverRegistered = false
        }
        stopDiscovery()
        clientGatt?.close()
        gattServer?.close()
        super.onDestroy()
    }
}

