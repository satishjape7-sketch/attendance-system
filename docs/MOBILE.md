# Native Flutter setup

On Windows, run scripts/bootstrap-mobile.ps1 from the repository root (or ../scripts/bootstrap-mobile.ps1 from mobile). It generates native runners, adds Android INTERNET permission and disables Android backups for secure storage. On other platforms, generate the runners manually and apply the manifest settings below:
```sh
flutter create --platforms=android,ios --project-name attendance_app .
flutter pub get
```

Android: add the following directly inside the manifest element in android/app/src/main/AndroidManifest.xml (outside application):
```xml
<uses-permission android:name="android.permission.INTERNET" />
```

For local HTTP development only, set android:usesCleartextTraffic="true" on an application element in android/app/src/debug/AndroidManifest.xml. Keep release builds on HTTPS. Android emulator API address: http://10.0.2.2:3000/api/v1. iOS simulator may use http://localhost:3000/api/v1; HTTP requires a development-only App Transport Security exception. Prefer HTTPS.

Follow the installed flutter_secure_storage package's native setup for minimum SDK, Android backup exclusions, and iOS Keychain entitlements. Do not back up the secure storage preferences without their associated encryption keys. Run native builds to validate plugin setup.

The access token is stored through flutter_secure_storage; user passwords are not persisted. Session expiry redirects to sign-in after a protected request returns 401. No refresh token is stored. A connection failure while restoring a session offers retry instead of discarding the token.

Use a real HTTPS API_BASE_URL for release. CORS applies to browsers; native mobile authentication still requires bearer tokens. Web and desktop runners have not been configured or tested.

Attendance dates follow the backend's business timezone. Displayed check-in/out times follow the device timezone and the UI states this distinction.
