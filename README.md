# Aisley Courier

Aisley Courier is the external Flutter/Dart application for Aisley Couriers. It is a Courier client, not a Customer, Seller, Admin, or Logistics dashboard.

The current app provides Courier authentication, account and vehicle management, policy consent, notifications, first-mile pickup, task-bound final-mile hub handoff, photo upload/COD completion intent, delivery history, and Logistics/Seller task chat. The dashboard has separate read-only task previews while its backend aggregate remains a scaffold; Buyer chat is read-only and normal final-mile batch acceptance is not yet adopted. Camera barcode scanning is implemented for the Android release APK and local Flutter web-server testing; Linux remains manual-input only for barcodes. Live Logistics validation and device/browser acceptance remain unverified. See [docs/README.md](docs/README.md) and [docs/PROGRESS.md](docs/PROGRESS.md) for the current boundary.

Frontend work follows the shared [Courier design guide](docs/design-courier.md): familiar Material interactions, consistent labels and navigation, and focused decisions based on Jakob's Law and Hick's Law. [AGENTS.md](AGENTS.md) requires review of changed screens against those rules; feature specs continue to define the authorized workflow.

## Requirements

- Flutter SDK compatible with the lockfile (Flutter >= 3.38.4, Dart >= 3.13.2).
- Git.
- A reachable Laravel API implementing the versioned `/api/v1` Courier contract.
- A platform toolchain for the target you want to run.

Check the local installation before setup:

```bash
flutter --version
flutter doctor -v
```

Official setup references:

- [Install Flutter](https://docs.flutter.dev/get-started/install)
- [Linux desktop setup](https://docs.flutter.dev/platform-integration/linux/setup)
- [Web setup](https://docs.flutter.dev/platform-integration/web/setup)
- [Windows desktop setup](https://docs.flutter.dev/platform-integration/windows/setup)

## Clone and configure

From the cloned repository root:

```bash
git clone <repository-url>
cd aisley_app
cp .env.example .env
flutter pub get
flutter doctor -v
flutter analyze
flutter test
```

Edit `.env` and set the API origin only. The app appends `/api/v1` itself, so do not include that suffix:

```dotenv
API_BASE_URL=http://127.0.0.1:8000
```

Use an HTTPS API URL outside local development. Do not put passwords, bearer tokens, signing keys, or other secrets in `.env`; the file is ignored by Git and is bundled as a client asset when the app runs.

If the Laravel API is running on another machine, use a development-machine address reachable from the target platform and configure the API's CORS policy for browser runs. The app shows a recoverable network state when the API is unavailable.

## Run on Linux desktop

Linux is the currently committed desktop runner and the normal local development target.

On Ubuntu/Debian, install the Flutter Linux and secure-storage prerequisites:

```bash
sudo apt-get update
sudo apt-get install -y \
  clang cmake ninja-build pkg-config libgtk-3-dev libstdc++-12-dev \
  libsecret-1-0 libsecret-1-dev gnome-keyring libjsoncpp-dev
```

### Linux secure storage and keyring

The app uses `flutter_secure_storage` for its bearer token. Linux needs both
the `libsecret` runtime/development packages and a running Secret Service
provider such as GNOME Keyring. Installing only the development package may
allow compilation but still cause secure-storage errors when the app starts.

After installing the packages, log out and back in so the desktop session can
start and unlock the keyring before running the app. On a non-GNOME session or
window manager, make sure its session startup provides a D-Bus user session and
starts a Secret Service provider. If the app reports that secure storage is
unavailable, check the session keyring before troubleshooting the API:

```bash
gnome-keyring-daemon --start --components=secrets
flutter run -d linux
```

Do not replace secure storage with plaintext files, ordinary preferences, or
hard-coded tokens. See the [`flutter_secure_storage_linux` requirements](https://pub.dev/documentation/flutter_secure_storage_linux/latest/)
for platform-specific alternatives and package details.

Enable and verify Linux desktop support:

```bash
flutter config --enable-linux-desktop
flutter devices
```

Run the app:

```bash
flutter run -d linux
```

Create a release build:

```bash
flutter build linux --release
```

## Run in a browser

The existing `web/` runner serves the **same Flutter Courier app** for local development and camera testing. It is not a separate Courier web dashboard. Use a fixed local origin so API CORS and camera permissions can be tested consistently:

```bash
flutter run -d web-server --web-hostname localhost --web-port 8765
```

Open `http://localhost:8765` in your browser. Browser webcam access requires permission and a secure context such as localhost; a non-local browser test needs HTTPS. Allow the exact Flutter origin in the Laravel API's CORS configuration. See the [Flutter web-server guide](https://docs.flutter.dev/platform-integration/web/setup) and [browser camera requirements](https://developer.mozilla.org/en-US/docs/Web/API/MediaDevices/getUserMedia).

Camera scanning uses the shared Flutter scanner for QR and Code 128 tracking-ID candidates. It fills pickup or proof input and never submits an action automatically. If permission or browser camera support is unavailable, use manual input; do not use a plaintext token workaround. The API must allow the exact localhost origin for authenticated web testing.

Browser file uploads are not yet verified: the current shared multipart sender uses a native file-path API. See the [cross-platform upload guide](docs/flutter-file-uploads.md) before testing registration evidence, profile-photo, or vehicle-document uploads in `web-server`. The intended change keeps Android's working upload route and adds a browser-safe selected-file transport; the API must allow this exact origin and the required upload/private-read preflights. A successful `flutter build web` or APK build alone does not verify either upload path.

## Run on Android and build an APK

Android uses the existing `android/` runner. To build an installable release APK:

```bash
flutter build apk --release
```

The output is `build/app/outputs/flutter-apk/app-release.apk`. The release APK includes the camera permission and shared QR/Code 128 scanner. Verify camera permission and successful scans on an installed release APK; manual entry remains available when permission is denied. A successful build alone does not prove the physical camera flow works.

## Run on Windows desktop

Windows desktop builds must be run on Windows. Install Flutter and Visual Studio with the **Desktop development with C++** workload; Visual Studio Code alone is not the Windows C++ toolchain.

This checkout does not include a `windows/` runner directory. Generate it once from the project root when working on Windows:

```powershell
flutter create --platforms=windows .
```

Enable and verify Windows desktop support:

```powershell
flutter config --enable-windows-desktop
flutter doctor -v
flutter devices
```

Run the app:

```powershell
flutter run -d windows
```

Create a release build:

```powershell
flutter build windows --release
```

## Useful development commands

```bash
flutter analyze
flutter test
flutter devices
```

Keep API calls in the client/repository layers, keep bearer tokens in secure storage, and follow the rules in [AGENTS.md](AGENTS.md) before changing Courier behavior.
