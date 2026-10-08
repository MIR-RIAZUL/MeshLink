# MeshLink

> **Decentralized, Off-Grid Peer-to-Peer Communication & File Transfer System for Android**

MeshLink is an open-source Flutter application engineered for **100% offline, zero-infrastructure peer-to-peer communication**. It enables nearby smartphones to autonomously discover each other, establish cryptographically verified direct connections, route multi-hop messages through a decentralized mesh, and exchange encrypted text messages and files directly over **Bluetooth Low Energy (BLE)** — without requiring cellular data, internet connectivity, Wi-Fi routers, or central servers.

---

## Table of Contents

- [Key Capabilities](#key-capabilities)
- [System Architecture](#system-architecture)
- [Phased Engineering Milestones](#phased-engineering-milestones)
  - [Phase 1: Modern UI & Design System](#phase-1--modern-ui--design-system)
  - [Phase 2: Autonomous BLE Device Discovery](#phase-2--autonomous-ble-device-discovery)
  - [Phase 3: Direct Peer-to-Peer Connection Handshake](#phase-3--direct-peer-to-peer-connection-handshake)
  - [Phase 4: Offline Text Messaging & Delivery Acknowledgements](#phase-4--offline-text-messaging--delivery-acknowledgements)
  - [Phase 5: Multi-Hop Mesh Routing & Store-and-Forward Relay](#phase-5--multi-hop-mesh-routing--store-and-forward-relay)
  - [Phase 6: Local SQLite & Drift Persistence Engine](#phase-6--local-sqlite--drift-persistence-engine)
  - [Phase 7: End-to-End Cryptographic Security Architecture](#phase-7--end-to-end-cryptographic-security-architecture)
  - [Phase 8: Offline Peer-to-Peer File Transfer System](#phase-8--offline-peer-to-peer-file-transfer-system)
- [Cryptographic & Protocol Specifications](#cryptographic--protocol-specifications)
- [Project Directory Structure](#project-directory-structure)
- [Getting Started](#getting-started)
- [Automated Testing & Quality Assurance](#automated-testing--quality-assurance)
- [Testing on Physical Devices](#testing-on-physical-devices)
- [Roadmap](#roadmap)
- [License](#license)

---

## Key Capabilities

* **100% Off-Grid & Autonomous**: Operates entirely without cellular towers, Wi-Fi access points, DNS, or backend cloud servers.
* **Military-Grade End-to-End Encryption (E2EE)**: Powered by ChaCha20-Poly1305 AEAD, X25519 ECDH ephemeral key exchange, Ed25519 digital signatures, and HKDF-SHA256 key derivation.
* **Perfect Forward Secrecy (PFS) & Session Rekeying**: Ephemeral Curve25519 session keys ensure that future compromises of long-term identity keys cannot retroactively decrypt past sessions.
* **Persistent Replay Protection**: Combined sliding-window validation and SQLite-backed sequence tracking eliminate packet duplication and replay attacks.
* **Multi-Hop Mesh Routing**: Decentralized store-and-forward routing (`MeshRouter`) with loop prevention, hop-count decrementing (TTL), and dynamic reverse route learning.
* **Reactive Local Database Persistence**: Type-safe Drift & SQLite database (`AppDatabase`) stores encrypted message threads, contacts, delivery receipts, and file transfer chunk states.
* **High-Performance Chunked File Transfers**: Bounded-memory streaming reader (`FileStreamReader`) and receiver-side random-access writer (`FileDiskWriter`) capable of transferring large files out-of-order without whole-file memory buffering.
* **Safe Filesystem Sandbox**: Dedicated staging directories with strict containment checks and traversal defense (`FilePathService`).

---

## System Architecture

MeshLink is built with a strictly decoupled, layered architecture:

```text
┌────────────────────────────────────────────────────────────────────────┐
│                        Flutter UI Presentation                         │
│   Material 3 • Dark Slate/Emerald Glassmorphism • Riverpod Controllers  │
└───────────────────────────────────▲────────────────────────────────────┘
                                    │
┌───────────────────────────────────▼────────────────────────────────────┐
│                       Domain & Service Layer                           │
│   FileTransferStateMachine • MeshRouter • Delivery Lifecycle Controller │
└───────────────────────▲───────────────────────▲────────────────────────┘
                        │                       │
┌───────────────────────▼───────────┐   ┌───────▼────────────────────────┐
│     Cryptographic Security        │   │    Data Persistence & I/O      │
│   ChaCha20-Poly1305 (IETF RFC 8439)│   │  Drift / SQLite3 (AppDatabase) │
│   X25519 ECDH Ephemeral Sessions  │   │  FilePathService Sandbox       │
│   Ed25519 Device Identity & Sigs  │   │  FileStreamReader (Bounded IO) │
│   HKDF-SHA256 Directional Keys    │   │  FileDiskWriter (Random-Access)│
│   Persistent Replay Protection    │   │  BLAKE2s / SHA-256 Verification│
└───────────────────────▲───────────┘   └───────▲────────────────────────┘
                        │                       │
┌───────────────────────▼───────────────────────▼────────────────────────┐
│                   Platform Channels (Method & Event)                   │
└───────────────────────────────────▲────────────────────────────────────┘
                                    │
┌───────────────────────────────────▼────────────────────────────────────┐
│                    Native Android Kotlin Layer                         │
│   MainActivity.kt: BLE Scanner • BLE Advertiser • GATT Client & Server │
└────────────────────────────────────────────────────────────────────────┘
```

---

## Phased Engineering Milestones

### Phase 1 — Modern UI & Design System
* **Curated Dark Mode**: Sleek emerald accents, dark slate surfaces, and glassmorphism styling.
* **Fluid Navigation**: Seamless bottom navigation bar across **Home**, **Devices**, **Messages**, and **Settings**.
* **Live System Telemetry**: Real-time visualization of Bluetooth radio state, active discovery status, and connected peer metrics.

### Phase 2 — Autonomous BLE Device Discovery
* **Continuous Background Advertising & Scanning**: Discovers nearby MeshLink nodes automatically upon app launch without manual user interaction.
* **Service UUID Filtering**: Scans specifically for MeshLink's unique 128-bit service UUID (`0000FE20-0000-1000-8000-00805F9B34FB`), ignoring irrelevant Bluetooth clutter.
* **Deduplication & Self-Exclusion**: Suppresses echo broadcasts, excludes the user's own device identifier, and smooths RSSI signal strength metrics.
* **Modern Android Permissions**: Full support for Android 12+ runtime permissions (`BLUETOOTH_SCAN`, `BLUETOOTH_ADVERTISE`, `BLUETOOTH_CONNECT` with `neverForLocation`) with backwards compatibility for legacy location APIs.

### Phase 3 — Direct Peer-to-Peer Connection Handshake
* **Bidirectional GATT Session Handshake**: Coordinates connection requests, interactive peer accept/reject prompts, and dedicated GATT client/server sessions.
* **Deterministic Connection States**: Explicit finite state lifecycle: `disconnected` → `connecting` → `connected` → `disconnecting` → `disconnected`.
* **Session Lifecycle Recovery**: Cancels watchdog timers upon connection completion and cleanly resets GATT handles when disconnecting or if Bluetooth is toggled OFF.

### Phase 4 — Offline Text Messaging & Delivery Acknowledgements
* **Zero Internet Required**: Direct GATT frame transmission between paired peer devices.
* **End-to-End Delivery Receipts (ACK)**: Dynamic status progression (`pending` → `sending` → `delivered` / `failed`) verified by cryptographic remote acknowledgement.
* **Conversation Management**: Message grouping by peer ID, duplicate suppression via UUIDs, and chronological sorting.

### Phase 5 — Multi-Hop Mesh Routing & Store-and-Forward Relay
* **Decentralized `MeshRouter`**: Dynamic routing table management for multi-hop packet routing across intermediary peer nodes.
* **Loop Prevention & Flood Control**: Time-To-Live (TTL) hop limits combined with an in-memory packet cache to discard duplicate broadcasts and prevent routing loops.
* **Reverse Route Learning**: Dynamically establishes return paths for unicast delivery receipts without central coordinators.
* **Store-and-Forward Queuing**: Automatically queues messages for offline or unreachable peers, attempting transmission when a route becomes available.

### Phase 6 — Local SQLite & Drift Persistence Engine
* **Type-Safe Drift Schema (`AppDatabase`)**: Local SQLite database storing conversation histories, peer contacts, and file transfer progress across app restarts.
* **Relational Schema**:
  * `MessagesTable`: Unique message UUIDs, peer IDs, content payloads, delivery statuses, and timestamps.
  * `ContactsTable`: Discovered peers, trust levels, Ed25519 identity fingerprints, and last-seen timestamps.
  * `FileTransfersTable`: Transfer IDs, file names, file sizes, mime types, staging paths, directions (`inbound`/`outbound`), and progress.
  * `FileChunksTable`: Per-chunk offsets, sequence indices, byte lengths, chunk hashes, and acknowledgement flags.
* **Reactive Drift Streams**: Direct integration with Riverpod providers for instantaneous UI updates upon database mutation.

### Phase 7 — End-to-End Cryptographic Security Architecture
MeshLink implements a complete, zero-compromise cryptographic pipeline across 9 verification steps:
1. **Security Primitives**:
   * Authenticated Encryption: **ChaCha20-Poly1305** (IETF RFC 8439) with 256-bit keys and 128-bit MAC tags.
   * Key Derivation: **HKDF-SHA256** (RFC 5869) with cryptographically separated salt and context labels.
   * Constant-Time Equality: Timing-resistant byte array comparison to protect against side-channel timing attacks.
   * Cryptographically secure pseudo-random number generator (CSPRNG).
2. **Ed25519 Long-Term Device Identity**:
   * Asymmetric Ed25519 keypair per device (`MeshIdentityService`).
   * Persistent key storage and public key identity fingerprints for trust verification.
3. **Mutual Authenticated Signed Handshake**:
   * Cryptographically signed `HandshakeInit` and `HandshakeResponse` packets.
   * Random anti-replay challenges and timestamp verification to eliminate man-in-the-middle (MITM) and impersonation attacks.
4. **Ephemeral X25519 Session Derivation**:
   * Elliptic-curve Diffie-Hellman (ECDH) key exchange over Curve25519.
   * Provides **Perfect Forward Secrecy (PFS)**.
5. **Directional Session Encryption**:
   * Independent transmit (`tx_key`) and receive (`rx_key`) session keys derived from shared ECDH secret via HKDF.
   * Monotonically incrementing 64-bit directional nonce counters to eliminate keystream reuse and reflection attacks.
6. **Persistent Replay Protection**:
   * 64-bit sliding window replay detection combined with SQLite sequence tracking (`ReplayProtectionService`).
7. **Zero-Plaintext Wire Protocol Enforcement**:
   * Wire protocol strictly forbids unencrypted payloads; unauthenticated frames are immediately dropped.
8. **Session Rekeying & Ratcheting**:
   * Automatic session rekeying triggered by message count limits or session duration thresholds (`SessionRekeyingService`).
9. **Protocol Hardening**:
   * Full tamper detection, payload padding to mitigate traffic analysis, and strict boundary validation.

### Phase 8 — Offline Peer-to-Peer File Transfer System
A robust, bounded-memory file streaming and assembly pipeline:
1. **Cryptographic Chunk Integrity**: Per-chunk BLAKE2s / SHA-256 hashing verifies that corrupted or modified chunks are detected and discarded prior to disk commitment.
2. **Relational Chunk Tracking**: Drift database integration records received chunks, enabling resumption of interrupted transfers.
3. **Domain Models**: Immutable representations (`FileMetadata`, `FileChunk`, `FileTransfer`, `FileTransferProgress`, `FileTransferStatus`, `FileTransferDirection`).
4. **Safe Filesystem Sandbox (`FilePathService`)**:
   * Isolated sandbox directory structure: `staging/`, `downloads/`, and `cache/`.
   * Traversal defenses against `..`, null bytes, and path escape attacks.
5. **Deterministic State Machine (`FileTransferStateMachine`)**:
   * Strict lifecycle: `idle` → `initiated` → `offered` → `accepted` → `transferring` → `verifying` → `completed` (with `paused`, `failed`, `cancelled` recovery states).
6. **Bounded-Memory Stream Reader (`FileStreamReader`)**:
   * Streams files in fixed-size chunks (e.g. 16 KB) with zero whole-file memory accumulation.
   * Seekable chunk slicing for resume support.
7. **Receiver-Side Disk Writer (`FileDiskWriter`)**:
   * True random-access file assembly (`RandomAccessFile`) enabling out-of-order chunk writes.
   * Pre-allocated staging files with non-destructive preservation of already received chunks.
   * Synchronized FIFO write serialization queue guaranteeing safe asynchronous disk writes without race conditions.

---

## Cryptographic & Protocol Specifications

### BLE GATT Service & Characteristics

| Identifier | UUID | Description |
| :--- | :--- | :--- |
| **Service** | `0000FE20-0000-1000-8000-00805F9B34FB` | Primary MeshLink GATT Service |
| **Request Char** | `0000FE21-0000-1000-8000-00805F9B34FB` | Client connection request initiation |
| **Response Char** | `0000FE22-0000-1000-8000-00805F9B34FB` | Server notification response (`0x01` Accept, `0x02` Reject) |
| **Message Char** | `0000FE23-0000-1000-8000-00805F9B34FB` | Bidirectional encrypted payload frames & ACKs |

### Cryptographic Primitives

| Purpose | Algorithm | Key / Tag Size | Specification |
| :--- | :--- | :--- | :--- |
| **Authenticated Encryption** | ChaCha20-Poly1305 | 256-bit key, 128-bit MAC | RFC 8439 |
| **Key Derivation** | HKDF-SHA256 | 256-bit PRK/OKM | RFC 5869 |
| **Key Exchange (PFS)** | X25519 (Curve25519 ECDH) | 256-bit public/private | RFC 7748 |
| **Digital Signatures** | Ed25519 | 256-bit keys, 512-bit sig | RFC 8032 |
| **Chunk Integrity Hashing** | BLAKE2s / SHA-256 | 256-bit digest | RFC 7693 / FIPS 180-4 |
| **Replay Protection** | 64-bit Sliding Window | Sequence Numbers + DB | RFC 6479 |

---

## Project Directory Structure

```text
lib/
├── app/
│   └── theme/                  # Design tokens, typography, dark palette
├── core/
│   ├── constants/              # UUIDs, channel names, protocol strings
│   └── widgets/                # Reusable glassmorphic UI widgets
├── features/
│   ├── devices/
│   │   ├── data/               # Native BLE platform channel bindings
│   │   ├── domain/             # MeshDevice models & connection state enums
│   │   ├── presentation/       # Discovery radar & peer list screens
│   │   └── providers/          # Device discovery Riverpod controllers
│   ├── home/
│   │   └── presentation/       # Dashboard overview & active status cards
│   ├── messages/
│   │   ├── data/
│   │   │   ├── database/       # Drift SQLite database (AppDatabase) & DAOs
│   │   │   ├── models/         # Session keys, encrypted payloads, packets
│   │   │   ├── repositories/   # Message repository implementation
│   │   │   └── services/       # Security, routing, and file transfer services
│   │   │       ├── directional_session_encryption_service.dart
│   │   │       ├── ephemeral_session_service.dart
│   │   │       ├── file_disk_writer.dart
│   │   │       ├── file_path_service.dart
│   │   │       ├── file_stream_reader.dart
│   │   │       ├── handshake_service.dart
│   │   │       ├── mesh_crypto_service.dart
│   │   │       ├── mesh_identity_service.dart
│   │   │       ├── mesh_messaging_service.dart
│   │   │       ├── mesh_router.dart
│   │   │       ├── message_storage_service.dart
│   │   │       └── replay_protection_service.dart
│   │   ├── domain/
│   │   │   ├── models/         # FileTransfer, FileChunk, FileMetadata models
│   │   │   └── services/       # FileTransferStateMachine
│   │   ├── presentation/       # Conversation views & chat bubbles
│   │   └── providers/          # Messaging and file transfer controllers
│   └── settings/
│       └── presentation/       # Device identity & fingerprint display
└── main.dart                   # Application entrypoint & dependency setup
```

---

## Getting Started

### Prerequisites

* **Flutter SDK**: `^3.13.3` (Flutter 3.22+ or Flutter 3.47+)
* **Dart SDK**: `^3.13.3`
* **Android SDK**: Min API Level 26 (Android 8.0 Oreo), Target API Level 34 (Android 14)
* **Physical Hardware**: At least two Android devices equipped with Bluetooth 4.2+ (BLE peripheral & central support is required; emulators cannot emulate BLE advertising).

### Installation & Run

1. **Clone the repository**:
   ```bash
   git clone https://github.com/MIR-RIAZUL/MeshLink.git
   cd MeshLink
   ```

2. **Fetch dependencies**:
   ```bash
   flutter pub get
   ```

3. **Verify static analysis**:
   ```bash
   flutter analyze
   ```

4. **Execute automated test suite**:
   ```bash
   flutter test
   ```

5. **Deploy to a connected Android phone**:
   ```bash
   flutter run -d <device-id>
   ```

---

## Automated Testing & Quality Assurance

MeshLink maintains a rigorous test-driven standard with **372+ automated tests** across **20 dedicated test suites**:

```bash
flutter test
```

### Test Suite Matrix

| Suite | Description | Key Verifications |
| :--- | :--- | :--- |
| `step1_security_primitives_test.dart` | Cryptographic primitives | ChaCha20-Poly1305, HKDF, constant-time compare |
| `step2_ed25519_identity_test.dart` | Device identity | Ed25519 key generation, signatures, fingerprinting |
| `step2_file_database_test.dart` | Drift database storage | File transfers & chunks table CRUD, transactions |
| `step3_file_transfer_models_test.dart` | File transfer models | Serialization, immutability, progress calculations |
| `step3_signed_handshake_test.dart` | Handshake security | Mutual auth, anti-replay challenges, signature verification |
| `step4_ephemeral_session_test.dart` | X25519 ECDH sessions | Forward secrecy, session state transitions |
| `step4_file_path_service_test.dart` | Safe filesystem paths | Traversal attacks, sandbox containment, sanitization |
| `step5_directional_encryption_test.dart` | Directional encryption | Inbound/outbound nonces, reflection attack defenses |
| `step5_file_transfer_state_machine_test.dart` | File transfer lifecycle | Deterministic state transitions, pause, resume, cancel |
| `step6_file_stream_reader_test.dart` | Bounded-memory streaming | Chunk slicing, seekable reads, memory boundaries |
| `step6_persistent_replay_test.dart` | Persistent replay defenses | Sliding window, sequence number replay rejection |
| `step7_file_disk_writer_test.dart` | Random-access disk writes | Out-of-order chunk assembly, concurrent writes, preallocation |
| `step8_session_rekeying_test.dart` | Session ratcheting & rekeying | Message limits, elapsed-time rekey triggers |
| `step9_protocol_hardening_test.dart` | Security hardening | Tamper detection, frame corruption, MITM resistance |
| `mesh_router_test.dart` | Multi-hop mesh routing | Store-and-forward, loop prevention, TTL, route discovery |
| `messaging_test.dart` | Messaging pipeline | End-to-end delivery ACK, deduplication, conversation threads |
| `device_discovery_controller_test.dart` | BLE discovery & state | State management, discovery start/stop, device list updates |
| `widget_test.dart` | UI Component rendering | ConversationScreen rendering, message input interaction |

---

## Testing on Physical Devices

To verify MeshLink on two physical Android phones:

1. Install and launch MeshLink on **Phone A** and **Phone B**.
2. Enable **Bluetooth** on both phones and grant the requested **Nearby Devices** permissions.
3. Both devices will automatically begin advertising and scanning:
   * **Phone A** appears in **Phone B's** *Nearby Devices* list.
   * **Phone B** appears in **Phone A's** *Nearby Devices* list.
4. Tap **Connect** on Phone A next to Phone B:
   * Phone B presents an interactive incoming connection dialog.
   * Tap **Accept** on Phone B.
5. The devices will complete the mutual Ed25519 signed handshake and establish directional ChaCha20-Poly1305 session keys.
6. **Test Offline Texting**:
   * Turn OFF Mobile Data and Wi-Fi on both devices.
   * Send messages across the conversation screen.
   * Verify the checkmark transitions from `pending` / `sending` to `delivered` upon remote ACK receipt.
7. **Test File Sharing**:
   * Tap the attachment icon to select an image or document.
   * Confirm the transfer offer on the receiving device.
   * Observe progressive chunk transfer and automated SHA-256 integrity verification upon completion.

---

## Roadmap

- [x] **Phase 1**: Modern dark-themed Flutter UI, design tokens, and navigation.
- [x] **Phase 2**: Autonomous BLE discovery, service UUID filtering, and permission management.
- [x] **Phase 3**: Direct peer-to-peer GATT connection handshake and session lifecycle control.
- [x] **Phase 4**: Offline peer-to-peer text messaging with delivery receipts (ACK).
- [x] **Phase 5**: Multi-hop mesh routing, store-and-forward relaying, and loop prevention.
- [x] **Phase 6**: Local SQLite/Drift encrypted persistence for messages, contacts, and transfers.
- [x] **Phase 7**: End-to-end cryptographic security architecture (Ed25519, X25519 ECDH, ChaCha20-Poly1305, HKDF, replay protection, rekeying).
- [x] **Phase 8 (Steps 1–7)**: Bounded-memory file stream reader, receiver-side random-access disk writer, path sandbox, and transfer state machine.
- [ ] **Phase 8 (Step 8+)**: File transfer wire protocol framing, chunk negotiation over BLE GATT, and transfer progress UI integration.
- [ ] **Phase 9**: BLE MTU dynamic negotiation, PHY 2M optimization, and transfer bandwidth acceleration.

---

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
