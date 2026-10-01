# UniRide

SwiftUI campus ride sharing for Settat, with the restored black/lime identity, icon and moving banknote login animation. The writable project is `UniRide.xcodeproj` in this folder. The older checkout on `/Volumes/New Volume 2` is read-only.

## What works

- Campus searches by departure, destination, time and seat count; interactive Apple map and public pickup landmarks.
- Saved locations, a public Home meeting point, and named saved commutes.
- Account registration/sign-in with server-side password hashing and Keychain bearer sessions.
- Driver profiles/car details, ride offers, weekday repeats over two weeks, and independent seats for every departure.
- Seat requests, driver accept/decline, passenger cancellation, driver cancellation, departure edits, start and completion.
- Private booking conversations, notification inbox, local departure reminders, trip sharing and post-trip driver reviews.
- English, French and Arabic, including right-to-left layout; haptics and Reduce Motion support.
- An explicitly separate, persistent on-device preview. Switch Passenger/Driver in Profile to try both sides of a booking. Preview users have no fabricated verification or ratings.

## Run the backend

Python 3.11 or later is sufficient; no third-party Python packages are required.

```sh
python3 backend/server.py --host 0.0.0.0 --port 8787
```

For the simulator, the Debug app defaults to `http://127.0.0.1:8787`. On this iPhone build it defaults to the Mac's current LAN address, `http://192.168.1.107:8787`. Both devices must be on the same Wi-Fi and the Mac must remain running. Change the address through the server button on sign-in, or Profile → Server settings, if the Mac's address changes.

Real accounts and rides start empty. Create two accounts to exercise the real flow: one publishes a ride, the other requests a seat, and the driver accepts it. Sample data lives only in Preview mode. The SQLite database is in `backend/data/` and is ignored by Git.

## Email verification and hosted notifications

Email verification is implemented but needs an SMTP service configured on the backend. See `backend/environment.example`. The university badge additionally requires the email domain to be in the server's explicitly configured `UNIRIDE_STUDENT_DOMAINS` allowlist. Self-entering a university never creates a verified badge. Without SMTP the app reports that delivery is not configured.

Departure reminders work locally after notification permission is granted. Booking, departure-change, cancellation and message updates appear in the inbox while the app is open. APNs registration, trip routing, a transactional notification outbox and a provider worker are implemented for background delivery. Activation requires an Apple push signing key and a push-enabled provisioning profile; remote registration is disabled in the current build so the existing iPhone signing profile continues to work. See the backend guide for activation.

The server is running locally, not published on the internet. HTTPS hosting, email delivery credentials and Apple push credentials are external configuration steps. Release builds accept HTTPS servers only. Configure `UNIRIDE_API_URL` when building a hosted version, or enter its HTTPS address on sign-in.

Map coordinates are suggested landmarks, not surveyed entrances. Drivers provide the actual meeting note; verify campus entrances before a wider pilot.

## Verification

```sh
python3 -m unittest discover -s backend/tests -v
python3 Tests/run_ui_tests.py --simulator SIMULATOR_UUID
```

The backend suite covers concurrent last-seat decisions, cancellation/rebooking, privacy, authorization, repeated departures, real review eligibility and verification attempts. UI tests exercise publication, requests, chat, driver acceptance/completion, review submission and French/Arabic. UI testing uses a separate temporary server/database and does not populate the real database.

Xcode 16.2 builds the app with a minimum deployment target of iOS 16.0. Both simulator and device builds can be made using the UniRide scheme.
