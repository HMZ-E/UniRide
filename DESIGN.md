# UniRide design and restoration

The supplied [Canva presentation](https://uniride101.my.canva.site/smart-fin-app), videos and simulator screenshot guide the black background, lime highlights, rounded cards, Dhs prices and Map / Rides / Messages / Profile navigation.

The supplied `UniRide.png` is the app icon, normalized to an opaque 1024×1024 image with white behind its transparent corners. The recovered shield logo is retained on sign-in. `UniRide.mp4` guides a native SwiftUI Canvas animation of floating banknotes and connected points. It pauses while inactive and respects Reduce Motion.

`RideCancel_Mockup.mp4` is a rotating promotional phone with ongoing and scheduled ride cards. Its visual language informs the ride cards and transitions. Cancellation now changes actual bookings on the backend; passenger cancellation releases confirmed seats, and drivers can cancel their rides.

Home adds campus departure/destination choices, departure time and seat filters, saved commutes, available offers, and an interactive dark MapKit map. The original simulator screenshot remains a reference asset. The live map uses approximate public Settat landmarks; each driver supplies the exact meeting note.

Real accounts, bookings, private conversations, notification history and completed-trip reviews are stored by the accompanying backend. Real data starts empty. Preview is clearly labelled, persists separately on the device, and supports switching passenger/driver roles. Sample profiles have no fabricated ratings or verification badges.

English, French and Arabic share the same interface; Arabic uses right-to-left layout. Local departure reminders work after permission is granted. SMTP verification and background APNs delivery require the configuration described in the backend guide.
