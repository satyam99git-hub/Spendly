# NayayaAI — Setup Requirements

What needs installing to run this project on this machine.

## Summary

**Flutter SDK is not installed.** That's the only real blocker. Everything else is ready.

## Already set up ✅

| Component | Status |
|---|---|
| Java | OpenJDK 21.0.11 (Gradle 9.1 / AGP 9.0.1 need 17+ — fine) |
| Android SDK | `~/Android/Sdk` — platforms 34/35/36, build-tools 36.1.0, NDK 28.2.13676358, adb 36.0.2 |
| Emulator + AVD | `Medium_Phone_API_36.1` already created |
| MongoDB | `mongod` running, `NyayaAI_DB` exists |
| Python backend | `Website/venv` fully provisioned — Flask 3.1.3, pymongo, bcrypt, groq, langchain, faiss, sentence-transformers, torch, reportlab, thefuzz, opencv |
| Secrets | `Website/.env` present (GROQ, OpenRouter, Google, GitHub keys) |

## 1. Install Flutter

The project's `android/local.properties` already points at `/home/user/flutter`, so install it there or the
Gradle build won't find it.

```bash
cd ~
curl -O https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.44.9-stable.tar.xz
tar xf flutter_linux_3.44.9-stable.tar.xz
echo 'export PATH="$HOME/flutter/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

Version 3.44.9 because `.dart_tool/version` shows that's what the project was last built with. Any stable
release >= 3.27 satisfies `pubspec.yaml`.

## 2. Install Android cmdline-tools

`~/Android/Sdk/cmdline-tools` does not exist, so `flutter doctor` will complain and licenses can't be
accepted. Easiest fix: Android Studio → SDK Manager → SDK Tools → "Android SDK Command-line Tools".

Then:

```bash
flutter doctor --android-licenses
flutter doctor          # Android toolchain should be green
```

## 3. Get the Dart packages

```bash
cd "/home/user/Documents/NayayaAi_1-main(2)/Application/NayayaAi_APP/flutter_app"
flutter pub get
```

## Running it

The Flutter app has **no backend of its own** — `Application/NayayaAi_APP/backend/` is an empty scaffold
(all `.gitkeep`, zero `.py` files). The app talks to the Flask site in `../../Website`.

```bash
# Terminal 1 — backend (deps already installed, Mongo already running)
cd "/home/user/Documents/NayayaAi_1-main(2)/Website"
venv/bin/python app.py        # :5000

# Terminal 2 — app
cd "/home/user/Documents/NayayaAi_1-main(2)/Application/NayayaAi_APP/flutter_app"
flutter emulators --launch Medium_Phone_API_36.1
flutter run                   # defaults to 10.0.2.2:5000, the emulator's host alias
```

On a physical phone the emulator alias won't resolve — pass the host's LAN IP instead:

```bash
flutter run --dart-define=API_BASE_URL=http://<your-lan-ip>:5000
```

## Note

The first `flutter run` is a fresh Gradle 9.1 build: it downloads the Gradle distribution and the full
Android dependency tree. Expect several minutes and a few hundred MB — first build only.
