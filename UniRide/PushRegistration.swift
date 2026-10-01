import UIKit

final class UniRideAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(token, forKey: "pushToken")
        NotificationCenter.default.post(name: .uniRidePushRegistered, object: token)
    }
}
extension Notification.Name {
    static let uniRidePushRegistered = Notification.Name("UniRidePushRegistered")
    static let uniRideOpenTrip = Notification.Name("UniRideOpenTrip")
}
struct TripRoute: Identifiable { let id: String }
