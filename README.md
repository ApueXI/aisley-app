# Aisley Courier

Aisley Courier is the external Flutter/Dart application for Aisley Couriers. It is a Courier client, not a Customer, Seller, Admin, or Logistics dashboard.

The current app provides:

- approval-aware Courier sign-in and session restoration;
- secure Sanctum token storage and logout;
- explicit pending, rejected, suspended, invalid-affiliation, storage, and network-failure states; and
- an honest authenticated dashboard scaffold that does not fabricate delivery jobs or operational counts.

Shipment, pickup, scanning, routing, proof-of-delivery, chat, earnings, and offline synchronization remain backend-contract work. See [docs/README.md](docs/README.md) and [docs/PROGRESS.md](docs/PROGRESS.md) for the current boundary.

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
  libsecret-1-dev libjsoncpp-dev
```

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

Browser support is a development/testing target, not a separate Courier web dashboard. The current checkout does not include a `web/` runner directory. If you need to generate it locally, run this once from the project root:

```bash
flutter create --platforms=web .
```

Install Google Chrome or Microsoft Edge, enable web support, and verify the device:

```bash
flutter config --enable-web
flutter devices
```

Run in Chrome:

```bash
flutter run -d chrome
```

Build the web bundle:

```bash
flutter build web
```

Browser requests are subject to CORS. The API must allow the local Flutter web origin. The secure-storage package uses an experimental WebCrypto implementation on the web, so browser use should remain limited to approved development/testing scenarios until web security requirements are finalized.

The current API client also contains a native `dart:io` import. This README does not change runtime code, so if the browser build reports that `dart:io` is unavailable, web support needs a separate platform-compatibility change.

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
