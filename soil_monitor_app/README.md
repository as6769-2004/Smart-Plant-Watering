# soil_monitor_app

A Flutter-based mobile application for remotely monitoring and controlling the **Soil Moisture & Pump Control System**.

## Getting Started

This Flutter app is designed to communicate with an Arduino-based automated plant watering system over a local network.

### 📱 App Installation

- Download the APK: [Download the App](/soil_monitor_app/Soil%20Monitoring.apk)
- Ensure your phone is connected to the same network as the Arduino system.
- On app launch, **set the IP address** of your Arduino server (shown in the top-right corner of the app).
- Upon successful connection, control buttons (Manual ON/OFF, Auto Mode) will be enabled.

## Tech Stack

- **Flutter** – Cross-platform app development
- **Dart** – Programming language used with Flutter
- **HTTP** – For communicating with the Arduino server

## Modify App Code

🔧 The app can be modified using the Flutter source code provided in this repository under `/soil_monitor_app`.

### 🔍 Debugging and Customization Guide

To customize or debug the app:

1. **Clone the Repository**
   ```bash
   git clone https://github.com/as6769-2004/Smart-Plant-Watering/tree/main/soil_monitor_app.git
   cd soil_monitor_app
   ```

2. **Open in an IDE**
   - Recommended: [Android Studio](https://developer.android.com/studio) or [VS Code](https://code.visualstudio.com/)
   - Ensure Flutter and Dart extensions are installed

3. **Run the App**
   - Use `flutter run` to run the app on a connected device/emulator

4. **Edit UI or Logic**
   - UI code is primarily located in `/lib/screens`
   - Networking logic is found in `/lib/services` or similar

5. **Test Changes**
   - Use hot reload (`r` in terminal or UI button in IDE) to see changes instantly

6. **Build APK**
   ```bash
   flutter build apk --release
   ```
   - The APK will be located at `build/app/outputs/flutter-apk/app-release.apk`

7. **Deploy APK to Device**
   - Manually install via file transfer or use `flutter install`


## License

This project is open-source. Contributions and modifications are welcome! 🚀

