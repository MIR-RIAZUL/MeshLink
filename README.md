# MeshLink

> **Decentralized, Off-Grid Peer-to-Peer Communication App for Android**

MeshLink is a Flutter application designed for **100% offline, direct peer-to-peer communication**. It enables nearby smartphones to discover each other, establish secure local connections, and exchange text messages directly via **Bluetooth Low Energy (BLE)** without requiring internet access, cellular networks, Wi-Fi routers, or central servers.

---

## Key Features

### Phase 1 — Modern UI & Design System
* **Premium Dark Mode**: Built with custom emerald accents, slate surfaces, and glassmorphism styling.
* **Intuitive Navigation**: Seamless navigation bar for quick access across Home, Devices, Messages, and Settings.
* **Live System Status**: Real-time visualization of Bluetooth state, active discovery status, and connected peer metrics.

### Phase 2 — Real Nearby Device Discovery
* **Autonomous BLE Advertising & Scanning**: Discovers nearby MeshLink devices automatically upon launch without requiring manual user scanning.
* **Protocol-Specific Filtering**: Filters discovered devices by MeshLink's unique service UUID (`0000FE20-0000-1000-8000-00805F9B34FB`), preventing unwanted Bluetooth clutter.
* **Deduplication & Self-Exclusion**: Automatically excludes the user's own broadcast identity and aggregates RSSI signal updates cleanly.
* **Permission Management**: Supports modern Android 12+ runtime permissions (`BLUETOOTH_SCAN`, `BLUETOOTH_ADVERTISE`, `BLUETOOTH_CONNECT` with `neverForLocation`) and legacy location permissions for older Android versions.

### Phase 3 — Direct Peer-to-Peer Connection Handshake
* **Bidirectional Handshake**: Initiates connection requests, displays interactive accept/reject dialogs with peer names, and establishes dedicated GATT client/server sessions.
* **Deterministic Connection States**: Explicit lifecycle management (`disconnected` → `connecting` → `connected` → `disconnecting` → `disconnected`).
* **Session Lifecycle Recovery**: Cancels watchdog timers upon connection completion and cleanly resets GATT handles when disconnecting or if Bluetooth is toggled OFF.

### Phase 4 — Real Offline Text Messaging
* **Zero Internet Required**: Transmits text messages directly over peer-to-peer BLE GATT characteristics.
* **End-to-End Delivery Acknowledgements (ACK)**: Dynamic delivery receipts that update message status from `sending` to `delivered` upon verified remote acknowledgement.
* **In-Memory Message Store**: Organizes conversation threads, prevents message duplication by unique UUIDs, and preserves chronological order.

---

## Architecture

MeshLink follows a strict layered architecture:

```text
┌────────────────────────────────────────────────────────┐
│                   Flutter UI Layer                     │
│  (Screens, Widgets, Dialogs, Theme, Navigation)        │
└───────────────────────────▲────────────────────────────┘
                            │
┌───────────────────────────▼────────────────────────────┐
│              Riverpod State Controllers                │
│  (DeviceDiscoveryController, MessagingController)      │
└───────────────────────────▲────────────────────────────┘
                            │
┌───────────────────────────▼────────────────────────────┐
│               Data Services & Models                   │
│  (DeviceDiscoveryService, InMemoryMessageStorage)      │
└───────────────────────────▲────────────────────────────┘
                            │ Platform Channels (Method & Event)
┌───────────────────────────▼────────────────────────────┐
│              Native Android Kotlin Layer               │
│  (MainActivity.kt: BLE Scanner, Advertiser, GATT)      │
└────────────────────────────────────────────────────────┘
```

### Protocol Specifications

* **Service UUID**: `0000FE20-0000-1000-8000-00805F9B34FB`
* **Characteristics**:
  * **Request Characteristic** (`0000FE21-...`): Client write requests (initiates connection with 64-bit device ID).
  * **Response Characteristic** (`0000FE22-...`): Server notify response (`0x01` = Accepted, `0x02` = Rejected).
  * **Message Characteristic** (`0000FE23-...`): Bidirectional write & notify for wire-protocol JSON message frames and ACKs.
* **Manufacturer Identifier**: `0xFFFF` with 8-byte device identity payload.

---

## Project Structure

```text
lib/
├── app/
│   └── theme/               # Color palettes, typography, and theme definitions
├── core/
│   ├── constants/           # Global string constants, UUIDs, and keys
│   └── widgets/             # Reusable UI widgets (cards, badges, buttons)
├── features/
│   ├── devices/
│   │   ├── data/            # Discovery service & platform channel bindings
│   │   ├── domain/          # MeshDevice model and connection state enums
│   │   ├── presentation/    # Devices discovery screen & peer list
│   │   └── providers/       # Riverpod controller for discovery & connection
│   ├── home/
│   │   └── presentation/    # Dashboard overview & active status cards
│   ├── messages/
│   │   ├── data/            # Messaging service, storage, and models
│   │   ├── domain/          # MeshMessage and DeliveryStatus models
│   │   ├── presentation/    # Messages list & active Conversation screen
│   │   └── providers/       # Riverpod messaging controller
│   └── settings/
│       └── presentation/    # Settings & device identity management
└── main.dart                # App entrypoint and root provider initialization
```

---

## Getting Started

### Prerequisites
* **Flutter SDK**: 3.22.0 or higher
* **Android SDK**: API level 26 (Android 8.0) minimum, API level 34 (Android 14) target
* **Hardware**: Two physical Android devices with Bluetooth 4.2+ support (BLE testing cannot be performed on virtual emulators alone).

### Installation & Run

1. **Clone the repository**:
   ```bash
   git clone https://github.com/MIR-RIAZUL/MeshLink.git
   cd MeshLink
   ```

2. **Install Flutter dependencies**:
   ```bash
   flutter pub get
   ```

3. **Verify code quality**:
   ```bash
   flutter analyze
   ```

4. **Run automated test suite**:
   ```bash
   flutter test
   ```

5. **Deploy to a connected Android device**:
   ```bash
   flutter run -d <device-id>
   ```

---

## How to Test Two Physical Phones

1. Install and launch MeshLink on both **Phone A** and **Phone B**.
2. Ensure **Bluetooth is turned ON** and accept the requested Nearby Device / Bluetooth permissions.
3. Both phones will automatically start advertising and scanning:
   - **Phone A** will display **Phone B** in its **Nearby Devices** list.
   - **Phone B** will display **Phone A** in its **Nearby Devices** list.
4. Tap **Connect** on Phone A next to Phone B:
   - Phone B will display an incoming connection dialog with Phone A's name.
   - Tap **Accept** on Phone B.
5. Both devices will transition to the **Connected** state.
6. Open the conversation from the **Messages** screen:
   - Disable Mobile Data and Wi-Fi on both devices.
   - Send text messages directly between Phone A and Phone B.
   - Observe message delivery indicators transition to **Delivered** upon remote ACK receipt.

---

## Roadmap & Next Phases

- [x] **Phase 1**: Modern dark-themed Flutter UI and responsive navigation.
- [x] **Phase 2**: Real nearby BLE device discovery and auto-start management.
- [x] **Phase 3**: Direct peer-to-peer connection handshake and lifecycle control.
- [x] **Phase 4**: Real offline text messaging with delivery acknowledgements.
- [ ] **Phase 5**: Message fragmentation & reassembly for long text and payload transfers.
- [ ] **Phase 6**: Local SQLite/Drift database encryption for persistent offline message history.
- [ ] **Phase 7**: Multi-hop mesh routing and store-and-forward relay mechanism.

---

## License

This project is licensed under the MIT License — see the LICENSE file for details.
