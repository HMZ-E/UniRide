# UniRide API

The service uses SQLite WAL and transactional seat decisions. A seat request does not reserve inventory; confirmation by the driver does. Accepting a request checks the remaining capacity inside `BEGIN IMMEDIATE`, so simultaneous accepts cannot oversell a ride. Cancellation frees confirmed inventory. Starting a ride declines outstanding requests. Reviews require a confirmed passenger on a completed trip.

Passwords use salted PBKDF2-SHA256 (600,000 rounds). Bearer tokens expire after 30 days; only token hashes are stored in the database. Other users' email addresses are omitted from public profiles. Messages and bookings are returned only to their participants. The database is private to the server and requests containing credentials or message content are not logged.

## Routes

All authenticated mutations return a fresh snapshot for the acting user.

| Method | Route | Purpose |
|---|---|---|
| GET | `/health`, `/places` | Health and campus landmarks |
| POST | `/signup`, `/login` | Session token and initial snapshot |
| GET | `/snapshot` | Own profile, public profiles, eligible rides, own bookings/messages/notifications/reviews/preferences |
| POST | `/logout` | Revoke the session |
| PATCH | `/profile` | Name, university, bio and car details |
| PUT | `/preferences` | Favorite locations, Home landmark, saved commutes |
| POST | `/rides` | Publish one departure or two weeks of selected weekdays |
| PATCH | `/rides/{id}` | Change that departure's time/meeting note and notify passengers |
| POST | `/rides/{id}/request` | Request seats |
| POST | `/rides/{id}/start`, `/complete`, `/cancel` | Driver trip lifecycle |
| POST | `/bookings/{id}/accept`, `/decline` | Driver decision |
| POST | `/bookings/{id}/cancel` | Passenger cancellation |
| POST | `/bookings/{id}/message` | Private conversation |
| POST | `/reviews` | One real review per joined, completed trip |
| POST | `/notifications/read` | Mark the acting user's notifications as read |
| POST | `/verification/request`, `/confirm` | SMTP code delivery/confirmation; university-domain eligibility |
| POST | `/devices` | Register an APNs token for the acting user |

Dates are Unix epoch seconds. Seats are integers from 1 to 6. Prices are Dhs per seat from 1 to 200. Repeat weekdays are ISO weekdays: Monday = 1, Sunday = 7. Dates are expanded using Africa/Casablanca, preserving the local departure time over the two-week window. Credentials use `Authorization: Bearer TOKEN`.

## Hosting

For local development, run `python3 backend/server.py`. For an iPhone on the same Wi-Fi, bind `--host 0.0.0.0`. A Dockerfile is supplied for hosting; mount a persistent volume at `/data` and place an HTTPS reverse proxy in front of port 8787. Release iOS builds reject plain HTTP. Configure a DNS name and HTTPS server address in the app. SQLite suits a small, single-server campus pilot; multiple API replicas must use a shared transactional database rather than separate SQLite files.

## SMTP

Set the environment values in `environment.example` using your mail service's settings. SMTP uses STARTTLS. Codes expire after 10 minutes, allow at most five guesses, and can be resent once a minute. The university-domain allowlist starts empty; populate it with domains confirmed for the participating schools. Without mail configuration, verification returns an explicit error and does not award a badge.

## APNs

1. Enable Push Notifications for `HMZ.UniRide` in your Apple developer account/Xcode target and regenerate the provisioning profile.
2. Configure an `aps-environment` entitlement for the build (development or production), and set `UniRideRemotePushEnabled` to true in the iOS Info.plist.
3. Put the Apple `.p8` key outside this repository and set the APNs environment variables. `curl` must support HTTP/2 and `openssl` must be installed on the server; the container supplies both.
4. Build/install the push-enabled app and grant notifications. Its token is registered to the signed-in account. The backend worker sends committed updates through APNs and retries provider outages.

Provider signing and transport follow [Apple's token-based connection guidance](https://developer.apple.com/documentation/usernotifications/establishing-a-token-based-connection-to-apns) and [APNs request guidance](https://developer.apple.com/documentation/usernotifications/sending-notification-requests-to-apns). Push signing keys and SMTP credentials are server-only. The current iPhone build retains local reminders and foreground updates until these services are configured.
