# How to start the NyayaAI app

Everything needed to get from a cold machine to a signed-in police console, in order.

The app is a **client**. It shows a splash and a sign-in form with no server, and nothing past that — so the
backend comes first, every time.

```
MongoDB  →  Flask (:5000)  →  device link  →  Flutter app
```

---

## 0. What you need once

| | Check it with | If it's missing |
|---|---|---|
| Flutter ≥ 3.27 | `flutter --version` | https://flutter.dev/setup |
| Android SDK + `adb` | `adb version` | comes with Android Studio |
| MongoDB running | `systemctl is-active mongod` | `sudo systemctl start mongod` |
| The website's venv | `ls website/venv/bin/python` | see step 1 |

Paths below are relative to the repo root (the folder holding `website/` and `Application/`).

---

## 1. Start MongoDB

```bash
sudo systemctl start mongod        # or: mongod --dbpath /var/lib/mongodb
systemctl is-active mongod         # expect: active
```

The app reads and writes `NyayaAI_DB` — the **same** database the website uses. Nothing here creates a
separate store.

---

## 2. Start the Flask server

```bash
cd website
./venv/bin/python app.py           # serves on 0.0.0.0:5000
```

First run only, if the venv does not exist:

```bash
cd website
python3 -m venv venv
./venv/bin/pip install -r requirements.txt
```

Leave it running in its own terminal. Check it from another:

```bash
curl -s http://127.0.0.1:5000/api/acts
# ["IPC","CRPC","NIA","IEA","HMA","CPC","IDA","MVA"]
```

If that returns nothing, the app will show *"Cannot reach the NyayaAI server"* and nothing else is worth
trying yet.

---

## 3. Point the app at the server

Pick the row that matches where you are running it. This is the step that goes wrong most often.

| Target | `API_BASE_URL` | Extra step |
|---|---|---|
| **Physical Android phone (USB)** | `http://127.0.0.1:5000` | `adb reverse tcp:5000 tcp:5000` |
| **Android emulator** | *(leave unset)* | none — `10.0.2.2` is the built-in default |
| **Linux desktop / Chrome** | `http://127.0.0.1:5000` | none |

### Why a physical phone needs `adb reverse`

`127.0.0.1` on the phone is the *phone*. `adb reverse tcp:5000 tcp:5000` forwards the phone's own loopback
back down the USB cable to your machine's port 5000, so the phone can reach a server that is not on any
shared network.

```bash
adb devices                        # confirm the phone is listed as "device", not "unauthorized"
adb reverse tcp:5000 tcp:5000
adb reverse --list                 # expect: <transport> tcp:5000 tcp:5000
```

**The forward does not survive unplugging the cable.** Re-run `adb reverse` after every reconnect; the app
does not need rebuilding for it.

> **Do not use your machine's LAN address** (`http://192.168.x.x:5000`). It will fail, and on purpose:
> `android/app/src/main/res/xml/network_security_config.xml` permits cleartext HTTP **only** to `127.0.0.1`,
> `localhost` and `10.0.2.2`. Plaintext to a routable address would put the session cookie of a police, judge
> or lawyer account on the wire. Use the `adb reverse` tunnel, or put TLS in front of Flask.

---

## 4. Run it

```bash
cd Application/NayayaAi_APP/flutter_app
flutter pub get
```

**Physical phone:**

```bash
flutter run -d <device-id> --dart-define=API_BASE_URL=http://127.0.0.1:5000
```

`<device-id>` is the middle column of `flutter devices`.

**Emulator** — start it first, then the default base URL is already right:

```bash
flutter emulators --launch Medium_Phone_API_36.1
flutter run
```

**Install a build without keeping a `flutter run` session attached:**

```bash
flutter build apk --debug --dart-define=API_BASE_URL=http://127.0.0.1:5000
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell am start -n com.nayaya.nayaya_app/.MainActivity
```

Note the `--dart-define` is baked in **at build time**. Changing the base URL means rebuilding.

---

## 5. Sign in

Use any account already in `NyayaAI_DB.users`, or register a new one on the app's own sign-up screen.

To see the police console you need a **police** account. Registering one requires a unique ID starting with
`POL` (the server enforces this; `LAW` and `JUD` for the other professional roles, and citizens get a
generated `CIT###`).

Create one from the command line if you would rather not type on a phone:

```bash
curl -s -X POST http://127.0.0.1:5000/signup \
  -H 'Content-Type: application/json' \
  -d '{"fullname":"Test Officer","email":"officer@test.local",
       "password":"Test@12345","role":"police","unique_id":"POL777"}'
```

Passwords are bcrypt-hashed server-side, so an existing account's password cannot be recovered — make a new
one rather than guessing.

Where each role lands:

| Role | Lands on |
|---|---|
| police / admin | the tabbed console — **FIR**, **Complaints**, **Evidence**, **Law** |
| citizen / lawyer / judge | the role home list (their features are not built yet) |

---

## 6. The evidence locker's PIN

```
secure@123
```

Checked **by the server**, via `POST /verify-locker-access` — so the handset and the website's console open
the locker with the same string. The app used to compare `INDIA@123` in Dart, which meant the two clients
disagreed; see `docs/features/03-evidence-locker.md`, "The PIN".

It is not real authentication either way: `/upload-evidence`, `/api/evidence`, `/get-all-evidence` and
`/evidence-file/...` have no session check at all, so the gate protects an unattended handset, not the
evidence.

The locker relocks on sign-out and on every cold start. It is never written to storage.

---

## 7. A quick end-to-end pass

1. Sign in as police → the console opens on the **FIR** tab.
2. **File an FIR** → four steps (only six entries are required: FIR number, district, station, FIR date,
   complainant name, and the narrative) → **Review** → *File this FIR* → the receipt shows the FIR number.
   On step 4, *Suggest acts and sections* reads the narrative and proposes sections with a reason each.
3. **Evidence** tab → enter `secure@123` → the locker lists what the station holds, grouped by FIR.
4. **Add evidence** → type the FIR number you just filed → *Attach a file* → upload.
   The file appears under that FIR without a manual refresh.
5. Tap it → the detail page, with its type and upload time.

Uploading against an FIR that does not exist is refused by the server, in its own words — that is expected,
not a bug. The FIR has to be registered first.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| *"Cannot reach the NyayaAI server"* | Flask not running, or the base URL is wrong | step 2, then step 3 |
| Sign-in works, then everything fails after a reconnect | the `adb reverse` forward was dropped | `adb reverse tcp:5000 tcp:5000` |
| Works in `flutter run`, fails in the installed APK | cleartext blocked, or the base URL is a LAN address | step 3's warning |
| Signed out on every launch | the session cookie is not persisting | `PersistCookieJar` needs `ignoreExpires: true` — see `dio_client.dart` |
| *"Take a photo"* does nothing | missing `<queries>` for `IMAGE_CAPTURE` | already in `AndroidManifest.xml`; check it survived a merge |
| `assembleDebug` fails: *"compile against version 36 or later"* | `file_picker` downgraded below 10.x | keep `file_picker: ^10.0.0` in `pubspec.yaml` |
| Device shows `unauthorized` in `adb devices` | USB debugging not confirmed on the phone | accept the prompt on the phone's screen |
| Nothing on the FIR pickers, "Retry" beside them | the lookup endpoints failed | the field falls back to typed entry — filing still works |

---

## Checks (no device needed)

```bash
cd Application/NayayaAi_APP/flutter_app
flutter analyze                              # must be clean
flutter test                                 # 453 unit + widget + golden
flutter test --tags golden --update-goldens  # after an intentional design change
```

The `live` suites hit a real server and are excluded from a default run. They **write to the database and to
disk**, under a `ZZFLUTTER<timestamp>` prefix, and nothing has a delete route:

```bash
# with Flask and MongoDB up:
flutter test test_live/ --dart-define=API_BASE_URL=http://127.0.0.1:5000

# cleanup, from the repo root:
website/venv/bin/python -c "from pymongo import MongoClient; \
  db = MongoClient('mongodb://127.0.0.1:27017/')['NyayaAI_DB']; \
  print(db['fir_records'].delete_many({'fir_no': {'\$regex': '^ZZFLUTTER'}}).deleted_count, \
        db['evidence_files'].delete_many({'fir_no': {'\$regex': '^ZZFLUTTER'}}).deleted_count)"
rm -rf website/static/uploads/evidence/ZZFLUTTER*
rm -f  website/generated_firs/FIR_ZZFLUTTER*.pdf
```

---

## Shutting down

```bash
# stop Flask with Ctrl-C in its terminal, then:
adb reverse --remove tcp:5000
```

MongoDB can be left running; it holds the data both clients share.
