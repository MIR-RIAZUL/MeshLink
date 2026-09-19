package com.example.meshlink

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
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
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.SecureRandom

class MainActivity : FlutterActivity() {
    companion object {
        private const val METHOD_CHANNEL = "meshlink/device_discovery"
        private const val EVENT_CHANNEL = "meshlink/device_discovery_events"
        private const val REQUEST_NEARBY_PERMISSIONS = 42
        private const val SCAN_DURATION_MS = 20_000L
        private val MESH_LINK_SERVICE = ParcelUuid.fromString("6f4b6d65-7368-4c69-6e6b-000000000002")
    }

    private val handler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null
    private var pendingStartResult: MethodChannel.Result? = null
    private var scanner: BluetoothLeScanner? = null
    private var advertiser: BluetoothLeAdvertiser? = null
    private var scanning = false
    private var advertising = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler(::onMethodCall)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "checkAvailability" -> result.success(checkAvailability())
            "startDiscovery" -> requestPermissionsThenStart(result)
            "stopDiscovery" -> {
                stopDiscovery()
                result.success(null)
            }
            else -> result.notImplemented()
        }
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
            "message" to if (permanentlyDenied)
                "Nearby-device permission was permanently denied. Enable it in Android Settings to discover MeshLink devices."
            else
                "Nearby-device permission is needed to find and advertise MeshLink devices."
        ))
    }

    @SuppressLint("MissingPermission")
    private fun beginDiscovery(result: MethodChannel.Result) {
        val adapter = bluetoothAdapter()!!
        scanner = adapter.bluetoothLeScanner
        advertiser = adapter.bluetoothLeAdvertiser
        if (scanner == null || advertiser == null) {
            result.success(mapOf("started" to false, "message" to "Bluetooth LE discovery is unavailable on this device."))
            return
        }
        stopDiscovery()
        val filter = ScanFilter.Builder().setServiceUuid(MESH_LINK_SERVICE).build()
        val settings = ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY).build()
        scanner!!.startScan(listOf(filter), settings, scanCallback)
        scanning = true
        startAdvertising()
        handler.postDelayed(scanTimeout, SCAN_DURATION_MS)
        result.success(mapOf("started" to true))
    }

    @SuppressLint("MissingPermission")
    private fun startAdvertising() {
        val data = AdvertiseData.Builder()
            .addServiceUuid(MESH_LINK_SERVICE)
            .addServiceData(MESH_LINK_SERVICE, meshLinkIdentity())
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
        handler.removeCallbacks(scanTimeout)
        if (scanning) scanner?.stopScan(scanCallback)
        if (advertising) advertiser?.stopAdvertising(advertiseCallback)
        scanning = false
        advertising = false
    }

    private val scanTimeout = Runnable {
        if (scanning) {
            stopDiscovery()
            eventSink?.success(mapOf("type" to "completed"))
        }
    }

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            val serviceData = result.scanRecord?.getServiceData(MESH_LINK_SERVICE) ?: return
            // Service data is the app-specific, rotating-ready identity; no hardware address is exposed to Flutter.
            val id = Base64.encodeToString(serviceData, Base64.NO_WRAP)
            eventSink?.success(mapOf(
                "type" to "device",
                "id" to id,
                "name" to "MeshLink device",
                "isConnectable" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && result.isConnectable)
            ))
        }

        override fun onScanFailed(errorCode: Int) {
            stopDiscovery()
            eventSink?.success(mapOf("type" to "error", "message" to "Bluetooth scan failed (code $errorCode)."))
        }
    }

    private val advertiseCallback = object : AdvertiseCallback() {
        override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {
            advertising = true
        }

        override fun onStartFailure(errorCode: Int) {
            stopDiscovery()
            eventSink?.success(mapOf("type" to "error", "message" to "MeshLink advertising could not start (code $errorCode)."))
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

    private fun meshLinkIdentity(): ByteArray {
        val preferences = getSharedPreferences("meshlink", Context.MODE_PRIVATE)
        preferences.getString("ble_identity", null)?.let { return Base64.decode(it, Base64.NO_WRAP) }
        val identity = ByteArray(8).also { SecureRandom().nextBytes(it) }
        preferences.edit().putString("ble_identity", Base64.encodeToString(identity, Base64.NO_WRAP)).apply()
        return identity
    }

    private inline fun <T> Array<out T>.anyIndexed(predicate: (Int, T) -> Boolean): Boolean {
        forEachIndexed { index, item -> if (predicate(index, item)) return true }
        return false
    }

    override fun onDestroy() {
        stopDiscovery()
        super.onDestroy()
    }
}
