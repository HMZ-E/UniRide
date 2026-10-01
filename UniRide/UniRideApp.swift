import SwiftUI

@main
struct UniDriveApp: App {
    @UIApplicationDelegateAdaptor(UniRideAppDelegate.self) private var appDelegate
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
