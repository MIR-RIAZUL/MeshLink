# MeshLink — READ-ONLY Audit Report
**Audit Basis:** Direct code inspection only. No code was run, modified, or tested on device.
**Inspection Date:** 2026-10-02

---

## Phase Status Summary

| Phase | Name | Status | Confidence |
|-------|------|--------|------------|
| 1 | UI / Foundation | ✅ COMPLETE | High |
| 2 | Real Nearby Device Discovery | ✅ COMPLETE | High |
| 3 | Real Direct Device Connection | ✅ COMPLETE | High |
| 4 | Offline Text Messaging | ✅ COMPLETE | High |
| 5 | Local Storage + Offline Queue + ACK/Retry | ✅ COMPLETE | High |
| 6 | Multi-Hop Mesh Routing | ✅ COMPLETE | High |
| 7 | Security + End-to-End Encryption | ✅ COMPLETE | High |
| 8 | Offline File Transfer | 🟡 PARTIAL | High |

> **Legend:**
> ✅ COMPLETE — Logic fully implemented, wired end-to-end, test coverage exists.
> 🟡 PARTIAL — Core logic present but one or more critical pieces are missing or not wired up.
> 🔴 NOT STARTED — No meaningful implementation found.
> ⚠️ UNVERIFIABLE — Cannot confirm without physical device testing.

---

## Phase 1 — UI / Foundation

**Status: ✅ COMPLETE**

### Evidence
- [`main.dart`](file:///d:/antigravity_project/MeshLink/lib/main.dart): Full service initialization, wires `AndroidBleDiscoveryService`, `DriftMessageRepository`, `MeshCryptoService`, `BleMeshMessagingService`, and `MeshRouter` together.
- [`devices_screen.dart`](file:///d:/antigravity_project/MeshLink/lib/features/devices/presentation/devices_screen.dart): Renders device list, Bluetooth enable/disable state, RSSI indicators, connectable badge, connection request accept/reject dialogs.
- [`messages_screen.dart`](file:///d:/antigravity_project/MeshLink/lib/features/messages/presentation/messages_screen.dart): Conversation list with last message preview, online indicator, empty state.
- [`conversation_screen.dart`](file:///d:/antigravity_project/MeshLink/lib/features/messages/presentation/conversation_screen.dart): Full chat UI with message bubbles, send button, status icons (pending/sent/delivered/failed), retry, file attachment button, and file progress display.
- Bottom navigation with Devices and Messages tabs confirmed.

### Missing / Gaps
- No Settings screen or profile/display name editor in the UI (display name is set at the native layer via `setDisplayName`). Minor UX gap, not a functional gap.

---

## Phase 2 — Real Nearby Device Discovery

**Status: ✅ COMPLETE**

### Evidence (Dart side)
- [`android_ble_discovery_service.dart`](file:///d:/antigravity_project/MeshLink/lib/features/devices/data/services/android_ble_discovery_service.dart): Bridges to Kotlin over `meshlink/device_discovery` MethodChannel and `meshlink/device_discovery_events` EventChannel. Maps all hardware events to typed `DeviceDiscoveryEvent` objects.
- `DeviceDiscoveryController` filters own device ID from discovered list.

### Evidence (Kotlin native)
- [`MainActivity.kt`](file:///d:/antigravity_project/MeshLink/android/app/src/main/kotlin/com/example/meshlink/MainActivity.kt) (lines 366–461):
  - BLE scanning with `BluetoothLeScanner.startScan()` filtered by `MESH_LINK_SERVICE` UUID (`6f4b6d65-7368-4c69-6e6b-000000000002`).
  - BLE advertising with `BluetoothLeAdvertiser.startAdvertising()`, including `meshLinkIdentityPayload()` (device ID + display name) in service data.
  - SCAN_MODE_LOW_LATENCY with service UUID filter — avoids scanning all devices.
  - Custom ML-XXXXXX mesh ID generated and persisted in SharedPreferences.
  - Display name broadcast in advertisement payload.

### AndroidManifest
- Correct permissions declared: `BLUETOOTH_SCAN` (with `neverForLocation`), `BLUETOOTH_ADVERTISE`, `BLUETOOTH_CONNECT` for API 31+; `ACCESS_FINE_LOCATION` + `BLUETOOTH` + `BLUETOOTH_ADMIN` for API ≤ 30.
- Runtime permission request flow implemented in `onRequestPermissionsResult`.

### Missing / Gaps
- No Wi-Fi Direct / Wi-Fi Aware transport. The app is BLE-only.
- Single active connection constraint in Kotlin (one `clientGatt`, one `connectedServerDevice`). Discovery works for multiple devices but connections are one-at-a-time.

---

## Phase 3 — Real Direct Device Connection

**Status: ✅ COMPLETE**

### Evidence (Kotlin native — `MainActivity.kt`)
- **GATT Server** (lines 487–512): Opens a GATT server with three characteristics:
  - `REQUEST_CHARACTERISTIC` (write-only): receives connection initiation from client.
  - `RESPONSE_CHARACTERISTIC` (indicate/notify): sends accept/reject result to client.
  - `MESSAGE_CHARACTERISTIC` (write + indicate/notify): bidirectional message transport.
- **GATT Client** (lines 514–546, 668–771):
  - `connectGatt()` → MTU negotiation (512 bytes) → `discoverServices()` → enable notifications on both `RESPONSE_CHARACTERISTIC` and `MESSAGE_CHARACTERISTIC` sequentially → write `REQUEST_CHARACTERISTIC` with local ID.
  - 15-second connection timeout with auto-disconnect on expiry.
- **Accept/Reject flow**: Server writes response byte (1 = accept, 0 = reject) via notification; client reads it in `handleCharacteristicChanged`.
- **Event channel** delivers: `device`, `incomingRequest`, `waitingForAcceptance`, `connected`, `connectionFailed`, `disconnected`, `messageReceived`, `bluetoothStateChanged`, `error`.

### Evidence (Dart side)
- `DeviceConnectionController` tracks state machine (`connecting`, `waitingForAcceptance`, `connected`, `disconnected`).
- `DevicesScreen` shows accept/reject dialog on `incomingRequest`.
- `MessagingController` auto-flushes pending messages when a connection event fires.

### Missing / Gaps
- Only one simultaneous BLE connection supported (Kotlin uses single `clientGatt` + single `connectedServerDevice`). Multi-peer connection would require significant native refactoring.
- No background service; connections are lost when the app is backgrounded on strict Android battery optimization.

---

## Phase 4 — Offline Text Messaging

**Status: ✅ COMPLETE**

### Evidence
- [`mesh_messaging_service.dart`](file:///d:/antigravity_project/MeshLink/lib/features/messages/data/services/mesh_messaging_service.dart): `sendMessage()` method:
  - If peer is connected: encrypts via `MeshCryptoService.encrypt()`, sends encrypted payload over BLE, sets status `sent`.
  - If peer is offline: saves message with status `pending`; queued for retry on reconnect.
- `_handleIncomingPayload()`: parses and routes via `MeshRouter.handleIncomingPayload()`, then decrypts locally-destined messages via `MeshCryptoService.decrypt()`.
- `_flushPending()`: called on connection event; drains all pending messages for the peer.
- Incoming duplicate detection via `MessageStorageService.hasMessage()`.
- ACK generated and sent back to sender on successful receipt.
- ACK received → updates originator's message status to `delivered`.

### Tests
- `messaging_test.dart`: Tests sending while connected → `sent`; sending while disconnected → `pending`; reconnect flushes pending; ACK receipt → `delivered`; duplicate rejection; retry preserves original ID.

---

## Phase 5 — Local Storage + Offline Queue + ACK/Retry

**Status: ✅ COMPLETE**

### Evidence — SQLite Persistence
- [`app_database.dart`](file:///d:/antigravity_project/MeshLink/lib/features/messages/data/database/app_database.dart): Drift/SQLite schema with `messages` table containing: `id`, `conversation_id`, `sender_id`, `receiver_id`, `origin_id`, `destination_id`, `text`, `timestamp`, `status`, `retry_count`, `ttl`, `hop_count`.
- [`DriftMessageRepository`](file:///d:/antigravity_project/MeshLink/lib/features/messages/data/repositories/message_repository.dart): Full CRUD: `saveMessage`, `updateMessageStatus`, `incrementRetryCount`, `getPendingMessages`, `getAllPendingMessages`, `hasMessage`, `getActivePeerIds`, `getLastMessage`.
- DB is wired in `main.dart` as the primary storage for the app (not just tests).

### Evidence — Offline Queue
- `MessagingController.sendMessage()` → saves as `pending` when disconnected.
- `_flushPending()` in `BleMeshMessagingService` drains pending queue on reconnect.
- `retryMessage()` in `MessagingController` re-sends with original message ID preserved.
- `maxRetryCount = 5` enforced in `MessagingController`; sets status to `failed` after 5 retries.

### Evidence — ACK
- `MeshMessage.createAckPayload()` produces a typed JSON frame (`type: ack`).
- ACK frames are routed through `MeshRouter` (multi-hop aware).
- Receipt of ACK updates originator's message from `sent` → `delivered`.

### Tests
- `messaging_test.dart`: DB save/retrieve, status updates, retry count increment, pending message query, multi-conversation separation — all verified via in-memory Drift DB.

---

## Phase 6 — Multi-Hop Mesh Routing

**Status: ✅ COMPLETE**

### Evidence
- [`mesh_router.dart`](file:///d:/antigravity_project/MeshLink/lib/features/messages/data/services/mesh_router.dart): Full flood-relay router:
  - `handleIncomingPayload()` dispatches on `type` field: `message`, `encrypted_message`, `ack`, `key_exchange`.
  - `routeEncryptedPayload()`: routes encrypted frame to direct peer or floods to all connected peers (excluding sender/origin), decrementing TTL and incrementing `hopCount`.
  - `routeMessage()` throws `UnsupportedError` — plaintext relay explicitly forbidden.
  - TTL enforcement: drops if `ttl <= 1`.
  - Duplicate detection: in-memory `_seenMessageIds` Set (capped at 500 entries, oldest evicted).
  - Loop prevention: skips `fromPeerId` and `originId` when forwarding.
  - Returns typed result: `LocalMessageDelivery`, `RelayedMessage`, `DroppedPayload`, `KeyExchangeDelivery`, `AckDelivery`.
- `MeshMessage` fields: `originId`, `destinationId`, `ttl` (default 5), `hopCount` — all fields wired through DB schema.

### Tests (`mesh_router_test.dart`)
- Plaintext route disabled ✅
- Direct link forwarding (destination connected) ✅
- Multi-hop relay (destination not connected) ✅
- TTL decrement + hopCount increment verified in wire payload ✅
- TTL expiry drops message ✅
- Duplicate protection ✅
- Loop prevention (skips sender/origin) ✅
- Local delivery detection ✅
- Full 3-node simulation (A ↔ B ↔ C): forward path, reverse path, end-to-end ACK relay, store-and-forward on reconnect ✅

### Missing / Gaps
- Routing is flood/broadcast — no topology-aware routing or route discovery (no RREQ/RREP). For a small mesh this is acceptable; at scale, network congestion is likely.
- `_seenMessageIds` is in-memory only; not persisted across app restarts (duplicate protection resets on restart).

---

## Phase 7 — Security + End-to-End Encryption

**Status: ✅ COMPLETE**

### Evidence (Dart — `mesh_crypto_service.dart`)
- **Key Generation**: X25519 key pair generated using `cryptography` package. Local private key lazily generated and cached.
- **Key Storage**: Private key bytes serialized to Base64 and stored via `AndroidKeyMaterialStore` (MethodChannel `meshlink/security` → `readIdentity`/`writeIdentity`).
- **Native Key Store** (Kotlin — `MainActivity.kt` lines 131–155): Uses `EncryptedSharedPreferences` with `MasterKey.KeyScheme.AES256_GCM` (backed by Android Keystore). Preference file: `meshlink_crypto_identity`, key: `x25519_identity`.
- **Key Exchange**: `MeshCryptoService.performKeyExchange()` sends local public key as a `key_exchange` typed JSON frame; `MeshRouter` delivers it to `handleKeyExchange()`.
- **AEAD Encryption**: ChaCha20-Poly1305 via `cryptography` package. AAD constructed from `messageId + originId + destinationId` (binds ciphertext to routing context).
- **Decryption**: `decrypt()` verifies MAC before returning plaintext; throws `MeshCryptoException` on failure.
- **Plaintext prohibition**: `MeshMessage.toWireProtocol()` throws `UnsupportedError`; `MeshRouter.routeMessage()` (plaintext) throws `UnsupportedError`.

### Evidence (Tests — `mesh_crypto_service_test.dart`)
- Encrypt + decrypt round-trip ✅
- Wrong recipient key rejected (MeshCryptoException) ✅
- Tampered ciphertext rejected ✅
- Unique nonces per encryption ✅

### Missing / Gaps / Security Concerns
- **No key authentication / identity verification**: Public keys are exchanged in plaintext `key_exchange` frames relayed through BLE. There is no certificate, trust-on-first-use (TOFU) confirmation, or fingerprint comparison step. A relay node (acting as MITM) could substitute its own public key during the exchange.
- **Key exchange timing**: The first message sent triggers key exchange. If a key exchange frame is lost (BLE is lossy), subsequent messages will fail to decrypt with no automatic retry of the key exchange itself.
- **Session key not refreshed**: There is no key rotation / forward secrecy beyond the initial X25519 exchange. The same shared secret is used for the lifetime of the relationship.
- **`_seenMessageIds` not persisted**: An attacker who replays a message after an app restart will bypass duplicate detection.

---

## Phase 8 — Offline File Transfer

**Status: 🟡 PARTIAL**

### What IS implemented
- **UI**: `ConversationScreen` has a file attachment button (📎), file progress display (`_FileProgressBubble`), and file message bubbles.
- **`MeshMessage` file fields**: `fileId`, `fileName`, `fileSize`, `fileMimeType`, `fileData` (Base64), `fileChunkIndex`, `fileChunkCount` are all present in the model.
- **DB Schema**: All file fields exist in the `messages` table (Drift schema).
- **`BleMeshMessagingService.sendFile()`**: Method exists. It reads file bytes, Base64-encodes them, and builds a `file_transfer_start` JSON frame with all file metadata.
- **`MeshMessagingService` abstract interface**: `sendFile()` is declared.
- **`MeshRouter`**: Has a `file_transfer` type handler stub.

### What is MISSING or INCOMPLETE

1. **Chunking not implemented**: `sendFile()` sends the entire file in a single BLE write. BLE MTU is negotiated to 512 bytes in the Kotlin layer. Sending more than ~500 bytes in a single write will silently fail or be truncated. There is no chunking loop, no chunk reassembly, and no `fileChunkIndex`/`fileChunkCount` tracking in the sending path.

2. **File receipt reassembly not implemented**: `_handleIncomingPayload()` in `BleMeshMessagingService` has a `file_transfer_start` case that saves the incoming "message," but there is no reassembly buffer, no chunk accumulation, and no mechanism to reconstruct a multi-chunk file.

3. **File encryption not implemented**: `sendFile()` calls `_sendEncryptedPayload()` but passes the raw Base64 file bytes as the `text` field of a `MeshMessage`. There is no call to `MeshCryptoService.encrypt()` on the file payload. File data would travel in Base64-encoded plaintext inside the BLE frame.

4. **No multi-hop file relay**: `MeshRouter` routes `file_transfer` type payloads but the handler is a stub. The actual relay logic (chunk-by-chunk forwarding, TTL/hop enforcement for file chunks) is not present.

5. **No file write to disk on receiving side**: Received file data remains in-memory as a `MeshMessage` with `fileData`. There is no `dart:io` write to the device's file system, no platform-specific path resolution, and no share/open action.

6. **No progress tracking**: The `_FileProgressBubble` widget exists in the UI but there is no backend mechanism emitting chunk-level progress events.

---

## Tests: What Was Verified by Tests vs. What Was Not

| Component | Test Coverage | Notes |
|-----------|--------------|-------|
| `MeshMessage` model | ✅ | `toWireProtocol` throws, ACK payload creation, ID uniqueness, length validation |
| `DriftMessageRepository` (SQLite) | ✅ | Save, retrieve, status update, retry count, pending query, multi-conversation separation |
| `MeshCryptoService` | ✅ | Encrypt/decrypt, wrong key rejection, tamper detection, nonce uniqueness |
| `MessagingController` + `BleMeshMessagingService` | ✅ | Send while connected, send offline → pending, reconnect flush, ACK delivery, duplicate rejection, retry ID preservation |
| `DeviceDiscoveryController` | ✅ | Init with BT disabled/enabled, permission flow, own-device filter, BT state change event |
| `MeshRouter` (unit + topology) | ✅ | All routing rules + 3-node simulation |
| Widget tests | ✅ | Home screen, Messages tab empty state, ConversationScreen render, send message interaction |
| File transfer | ❌ | No tests for `sendFile`, chunking, reassembly, or file encryption |
| BLE transport (physical) | ⚠️ UNVERIFIABLE | All BLE code in Kotlin; only testable on physical Android hardware |

---

## Physical Testing Status
**None confirmed.** The codebase has never been run against a real Android device based on code evidence alone. All tests use in-memory mocks (`MockDiscoveryService`, `InMemoryMessageStorageService`, `InMemoryKeyMaterialStore`). The Kotlin BLE implementation is structurally correct and uses standard Android APIs, but real-world BLE behavior (scan results, GATT connection stability, MTU negotiation, concurrent operations) can only be validated on hardware.

---

## Security Concerns (Priority Order)

1. **🔴 HIGH — No MITM protection on key exchange**: `key_exchange` frames are unauthenticated and relay-able. A BLE man-in-the-middle could substitute its own X25519 public key during the initial handshake. Mitigation requires TOFU fingerprint verification or a shared-secret / PIN channel for key confirmation.
2. **🟡 MEDIUM — File transfer data not encrypted** (Phase 8 gap): File bytes are Base64-encoded but not ChaCha20 encrypted before transmission.
3. **🟡 MEDIUM — No replay attack protection across restarts**: `_seenMessageIds` is in-memory only. Persisting this set to SQLite (with TTL-based expiry) would close the window.
4. **🟡 MEDIUM — No key rotation / forward secrecy**: The X25519 shared secret is used indefinitely. Compromising one device's private key exposes all past messages encrypted with that keypair.
5. **🟢 LOW — Duplicate `_seenMessageIds` cap**: The router evicts oldest seen IDs at 500 entries. Under very heavy multi-hop traffic, this could allow duplicate delivery of very old packets.

---

## Next Recommended Development Step

**Complete Phase 8 — File Transfer (Chunking + Encryption)**

This is the only incomplete phase. Specifically:

1. Implement chunked splitting in `BleMeshMessagingService.sendFile()` (≤ 400-byte chunks after Base64 to leave room for JSON overhead within the 512-byte MTU).
2. Implement chunk reassembly buffer keyed on `fileId` in `_handleIncomingPayload()`.
3. Call `MeshCryptoService.encrypt()` on each chunk's data before transmission.
4. Wire up progress events so `_FileProgressBubble` can display real progress.
5. On final chunk received: write assembled bytes to `getApplicationDocumentsDirectory()` / `getExternalStorageDirectory()`.
6. Add `file_transfer` relay logic in `MeshRouter` (TTL decrement + flood to non-sender peers).

After that, **physical BLE device testing** on two real Android phones should be the next milestone before any further feature work.
