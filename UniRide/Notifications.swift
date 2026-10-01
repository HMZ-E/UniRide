import Foundation
import UserNotifications

final class NotificationCoordinator: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()
    override init() { super.init(); center.delegate = self }
    func enable() async throws -> Bool { try await center.requestAuthorization(options: [.alert, .sound, .badge]) }
    func clear() { center.removeAllPendingNotificationRequests(); center.removeAllDeliveredNotifications() }
    func deliver(_ note: RideNotification, title: String, body: String) {
        let content = UNMutableNotificationContent(); content.title = title; content.body = body; content.sound = .default
        content.userInfo = ["rideId": note.rideId]
        center.add(UNNotificationRequest(identifier: note.id, content: content, trigger: nil))
    }
    func syncReminders(_ snapshot: AppSnapshot, title: String) {
        let active = snapshot.rides.filter { ride in
            ride.status == .scheduled && (ride.driverId == snapshot.currentUser.id || snapshot.bookings.contains { $0.rideId == ride.id && $0.passengerId == snapshot.currentUser.id && $0.status == .confirmed })
        }
        center.getPendingNotificationRequests { requests in
            let old = requests.filter { $0.identifier.hasPrefix("departure.") }.map(\.identifier)
            self.center.removePendingNotificationRequests(withIdentifiers: old)
            for ride in active {
                let seconds = ride.departureTime.timeIntervalSinceNow - 600
                guard seconds > 1 else { continue }
                let content = UNMutableNotificationContent(); content.title = title; content.body = ride.route; content.sound = .default
                content.userInfo = ["rideId": ride.id]
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
                self.center.add(UNNotificationRequest(identifier: "departure." + ride.id, content: content, trigger: trigger))
            }
        }
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if let rideId = response.notification.request.content.userInfo["rideId"] as? String {
            DispatchQueue.main.async { NotificationCenter.default.post(name: .uniRideOpenTrip, object: rideId) }
        }
        completionHandler()
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) { completionHandler([.banner, .sound]) }
}
