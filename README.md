# ReachOut

**Offline Messaging Through Bluetooth Mesh Networking**

ReachOut is a Flutter-based mobile application designed to help people communicate when traditional communication infrastructure, such as cellular networks and internet connectivity, is unavailable or unreliable.

Using Bluetooth Low Energy (BLE) and Delay-Tolerant Networking (DTN), ReachOut enables nearby smartphones to exchange messages and relay them through intermediate devices until they reach their intended recipients. This approach is particularly relevant during emergencies, natural disasters, power outages, and situations where communication infrastructure is disrupted.

## Features

- **Offline Messaging:** Exchange messages between nearby devices without relying on internet connectivity or cellular networks.
- **DTN Store-Carry-Forward:** Store messages locally and forward them when suitable relay devices become available.
- **PRoPHET Routing:** Use delivery predictability to help determine which devices are suitable message relays.
- **Priority-Based Messaging:** Support message priorities, including high-priority emergency messages.
- **SOS Messaging:** Provide an emergency messaging feature for situations requiring urgent communication.
- **Bluetooth Communication:** Discover nearby devices and establish Bluetooth Low Energy connections for message exchange.
- **Multi-Hop Relaying:** Allow intermediate devices to carry and forward messages toward their destinations.
- **Relay History:** View information about message relay activity.
- **Nearby Devices:** Discover devices available for local communication.
- **Location Map:** Display map information to support location-aware functionality.
- **Light and Dark Themes:** Switch between available application themes.
- **Local Storage:** Store messages and relevant application data on the device.

## How It Works

ReachOut combines three main components:

1. **Communication Layer — Bluetooth Low Energy (BLE)**  
   Enables nearby smartphones to discover each other and exchange data without requiring an internet connection.

2. **Routing Layer — DTN and PRoPHET**  
   Messages are stored locally when the recipient is unreachable. When devices encounter one another, the routing logic evaluates delivery predictability and forwards eligible messages. High-priority messages can use the PRoPHET Broadcast Router extension to improve their dissemination opportunities.

3. **Application Layer — Flutter**  
   Provides the messaging interface, nearby-device discovery, emergency messaging, relay history, location map, and theme settings.

### Store-Carry-Forward Example

Suppose Device A needs to send a message to Device C, but they cannot connect directly.

- Device A stores the message and transfers it to Device B when an appropriate connection becomes available.
- Device B carries the message until it encounters another suitable device or Device C.
- The message is forwarded through available relay opportunities until it reaches its destination, subject to connectivity, routing decisions, message lifetime, and device availability.

Messages may therefore take time to arrive. Delivery is not guaranteed, particularly when devices never encounter a suitable relay.

## Technology Stack

| Component | Technology |
|---|---|
| Mobile application | Flutter |
| Programming language | Dart |
| Device communication | Bluetooth Low Energy (BLE) |
| Networking model | Delay-Tolerant Networking (DTN) |
| Routing protocol | PRoPHET |
| High-priority routing | PRoPHET Broadcast Router extension |
| Local data storage | Hive |
| Mapping | MapLibre with locally stored map data |

## Project Structure

The project is organized around the mobile interface, device communication, routing, and local data management.

Key application components include:

- `main.dart` — Application entry point and initialization.
- `ThemeProvider` — Manages application theme settings.
- `ChatProvider` — Manages chat-related application state.
- `DTNProvider` — Connects the user interface with DTN functionality.
- `DtnManager` — Coordinates DTN operations and peer connections.
- `ProphetRoutingService` — Handles PRoPHET routing logic.
- `DtnStorageService` — Manages locally stored DTN messages and related data.
- `TransferService` — Supports message transfer between connected devices.
- `BatteryService` — Supports battery-aware networking decisions.
- `screens/` — Contains the application screens, including conversations, chat, nearby devices, relay history, and SOS map functionality.

*Note: File locations and names may vary as the project evolves.*

## Getting Started

### Prerequisites

Install the following tools before running the application:

- Flutter SDK
- Dart SDK compatible with the project's Flutter version
- Android Studio or Visual Studio Code
- Android SDK and the required Android build tools
- A physical Android device with Bluetooth Low Energy support for device-to-device testing

### Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/naghamducks/delay_messaging.git
   ```

2. Navigate to the project directory:

   ```bash
   cd delay_messaging
   ```

3. Install the dependencies:

   ```bash
   flutter pub get
   ```

4. Check your Flutter environment:

   ```bash
   flutter doctor
   ```

5. Connect an Android device or start an emulator, then run:

   ```bash
   flutter run
   ```

For realistic Bluetooth communication and relay testing, use multiple compatible physical devices.

## Permissions

ReachOut may require the following Android permissions, depending on the Android version and implemented features:

- Bluetooth scanning
- Bluetooth connection
- Bluetooth advertising
- Location access where required by the Android version or location-related features

Grant the requested permissions for the corresponding functionality to work correctly.

## Testing

ReachOut can be evaluated using multiple physical devices and different connectivity scenarios.

Suggested test scenarios include:

- **Device discovery:** Verify that nearby devices can be discovered over BLE.
- **Direct messaging:** Test message exchange between two connected devices.
- **Multi-hop relaying:** Verify that a message can travel through an intermediate device.
- **Distance testing:** Evaluate communication behavior at different distances.
- **Obstacle testing:** Examine BLE communication when walls or other physical obstacles separate devices.
- **Multiple connections:** Test device communication when several devices are available simultaneously.
- **Store-and-forward behavior:** Verify that messages remain stored when the destination is unavailable and can be forwarded when an appropriate connection becomes available.
- **Priority handling:** Verify that high-priority messages are handled according to the configured routing rules.
- **Connectivity interruptions:** Evaluate message handling when Bluetooth connections are interrupted and later restored.
- **Battery and storage behavior:** Examine operation under different battery conditions and local storage loads.

Actual results depend on device hardware, operating-system restrictions, Bluetooth conditions, routing configuration, and relay availability.

## Limitations

- Bluetooth communication is limited by device range and environmental conditions.
- Successful delivery depends on encounters with suitable relay devices.
- Messages may experience delays because communication is opportunistic.
- Android background-execution and Bluetooth restrictions may affect discovery and forwarding.
- The application does not replace cellular emergency services or guarantee emergency-message delivery.

## Intended Use

ReachOut is designed as a prototype for resilient mobile communication in environments where conventional communication infrastructure is disrupted. Potential use cases include disaster response, emergency coordination, and communication in areas with limited connectivity.

## Contributing

Contributions, testing, and suggestions are welcome. Before submitting changes, ensure the application builds successfully and test any modifications that affect Bluetooth communication, routing, message storage, or delivery behavior.

## License

The application uses third-party software libraries and OpenStreetMap data under their respective licenses. The application code license is to be determined. OpenStreetMap attribution and ODbL requirements apply to the map data.
---

**ReachOut — Keeping messages moving when networks go down.**
