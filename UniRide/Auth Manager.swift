import SwiftUI
import Combine
import UIKit
import OSLog

@MainActor
final class AppStore: ObservableObject {
    @Published var snapshot: AppSnapshot?
    @Published var isPreview = false
    @Published var isBusy = false
    @Published var restoring = false
    @Published var error: String?
    @Published var notice: String?
    @Published var connected = false
    @Published var language: String = UserDefaults.standard.string(forKey: "language") ?? "en" {
        didSet { UserDefaults.standard.set(language, forKey: "language") }
    }
    @Published var endpoint: String = UserDefaults.standard.string(forKey: "server") ?? {
        #if DEBUG
        #if targetEnvironment(simulator)
        return "http://127.0.0.1:8787"
        #else
        return "http://192.168.1.107:8787"
        #endif
        #else
        return Bundle.main.object(forInfoDictionaryKey: "UniRideAPIURL") as? String ?? ""
        #endif
    }()
    private let logger = Logger(subsystem: "HMZ.UniRide", category: "Session")
    private var token: String?
    private var revision = 0
    private var seenNotifications: Set<String> = []
    let notifications = NotificationCoordinator()
    private var registeredPushToken: String?
    var remotePushEnabled: Bool { Bundle.main.object(forInfoDictionaryKey: "UniRideRemotePushEnabled") as? Bool ?? false }
    func registerPushToken(_ value: String) async {
        guard remotePushEnabled, !isPreview, token != nil, value != registeredPushToken else { return }
        if await perform("/devices", body: ["token": value]) { registeredPushToken = value }
    }
    var user: User? { snapshot?.currentUser }
    var isAuthenticated: Bool { snapshot != nil }
    var rides: [Ride] { snapshot?.rides ?? [] }
    var bookings: [Booking] { snapshot?.bookings ?? [] }
    var messages: [ChatMessage] { snapshot?.messages ?? [] }
    var preferences: Preferences { snapshot?.preferences ?? Preferences() }
    var unreadCount: Int { snapshot?.notifications.filter { !$0.read }.count ?? 0 }
    var api: APIClient { APIClient(endpoint: endpoint, token: token) }
    func profile(_ id: String) -> User? { snapshot?.users.first { $0.id == id } }
    func ride(_ id: String) -> Ride? { rides.first { $0.id == id } }
    func booking(for ride: Ride) -> Booking? {
        bookings.filter { $0.rideId == ride.id && $0.passengerId == user?.id }.sorted { $0.createdAt > $1.createdAt }.first
    }
    func text(_ key: String) -> String {
        guard let path = Bundle.main.path(forResource: language, ofType: "lproj"), let bundle = Bundle(path: path) else { return key }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }
    func flash(_ message: String) { notice = message; Task { try? await Task.sleep(nanoseconds: 4_000_000_000); if notice == message { notice = nil } } }

    func restore() async {
        guard !isAuthenticated else { return }
        token = SessionKeychain.read(endpoint)
        guard token != nil else { return }
        restoring = true
        defer { restoring = false }
        await refresh()
    }
    func authenticate(name: String?, email: String, password: String, university: String) async -> Bool {
        guard !isBusy else { return false }
        logger.info("Authentication started")
        isBusy = true; revision += 1; let generation = revision; let authServer = endpoint
        defer { isBusy = false }
        do {
            var body: [String: Any] = ["email": email.trimmingCharacters(in: .whitespaces), "password": password]
            if let name { body["name"] = name; body["university"] = university }
            let response: SessionResponse = try await APIClient(endpoint: authServer, token: nil).request(name == nil ? "/login" : "/signup", method: "POST", body: body)
            guard generation == revision, endpoint == authServer else { return false }
            logger.info("Authentication succeeded")
            token = response.token; SessionKeychain.save(token, server: endpoint)
            isPreview = false; snapshot = response.snapshot; connected = true
            if remotePushEnabled { UIApplication.shared.registerForRemoteNotifications() }
            seenNotifications = Set(response.snapshot.notifications.map(\.id))
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            return true
        } catch { guard generation == revision else { return false }; logger.error("Authentication failed: \(error.localizedDescription, privacy: .public)"); self.error = error.localizedDescription; connected = false; return false }
    }
    func setServer(_ value: String) {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard normalized != endpoint else { return }
        SessionKeychain.save(nil, server: endpoint); token = nil; snapshot = nil; isPreview = false
        endpoint = normalized; UserDefaults.standard.set(normalized, forKey: "server")
        revision += 1; notifications.clear()
    }
    func signOut() async {
        logger.info("Signing out")
        let oldAPI = api; let revokeSession = !isPreview && token != nil
        let deviceToken = UserDefaults.standard.string(forKey: "pushToken")
        SessionKeychain.save(nil, server: endpoint); token = nil; snapshot = nil; isPreview = false; connected = false
        revision += 1; notifications.clear(); seenNotifications = []; registeredPushToken = nil
        if revokeSession { let _: [String: Bool]? = try? await oldAPI.request("/logout", method: "POST", body: deviceToken.map { ["deviceToken": $0] }) }
    }
    func refresh() async {
        guard !isPreview, token != nil else { return }
        let generation = revision
        do {
            let result: AppSnapshot = try await api.request("/snapshot")
            guard generation == revision else { return }
            apply(result); connected = true
        } catch {
            guard generation == revision else { return }
            connected = false
            if (error as? APIError)?.status == 401 {
                logger.info("Session expired")
                SessionKeychain.save(nil, server: endpoint); token = nil; snapshot = nil; notifications.clear()
                self.error = "Please sign in again."
            }
        }
    }
    private func apply(_ state: AppSnapshot) {
        let fresh = state.notifications.filter { !seenNotifications.contains($0.id) && !$0.read }
        snapshot = state
        seenNotifications.formUnion(state.notifications.map(\.id))
        for note in fresh { notifications.deliver(note, title: text(note.title), body: ride(note.rideId)?.route ?? "UniRide") }
        notifications.syncReminders(state, title: text("Your ride leaves soon"))
    }
    @discardableResult func perform(_ path: String, method: String = "POST", body: [String: Any] = [:], success: String? = nil) async -> Bool {
        guard !isBusy else { return false }
        isBusy = true; revision += 1; let generation = revision
        defer { isBusy = false }
        do {
            let result = isPreview ? try previewMutation(path, body: body) : try await api.request(path, method: method, body: body) as AppSnapshot
            guard generation == revision else { return false }
            apply(result); connected = !isPreview
            if let success { flash(success) }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return true
        } catch { guard generation == revision else { return false }; self.error = error.localizedDescription; return false }
    }
    func savePreferences(_ prefs: Preferences) async {
        guard let data = try? APIClient.encoder.encode(prefs), let body = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return }
        await perform("/preferences", method: "PUT", body: body)
    }
    func toggleFavorite(_ id: String) async {
        var prefs = preferences
        if prefs.favoriteLocationIDs.contains(id) { prefs.favoriteLocationIDs.removeAll { $0 == id } } else { prefs.favoriteLocationIDs.append(id) }
        await savePreferences(prefs)
    }
    func previewApp() {
        revision += 1; notifications.clear()
        isPreview = true; connected = false; token = nil
        if let data = try? Data(contentsOf: previewURL), let saved = try? APIClient.decoder.decode(AppSnapshot.self, from: data) { snapshot = saved }
        else { snapshot = .preview }
        seenNotifications = Set(snapshot?.notifications.map(\.id) ?? [])
    }
    func resetPreview() { snapshot = .preview; try? FileManager.default.removeItem(at: previewURL) }
    func switchPreviewRole(driver: Bool) {
        guard isPreview, let user = snapshot?.users.first(where: { $0.id == (driver ? "driver1" : "preview") }) else { return }
        snapshot?.currentUser = user
    }
    private var previewURL: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("preview.json") }

    private func previewMutation(_ path: String, body: [String: Any]) throws -> AppSnapshot {
        guard var state = snapshot else { throw APIError(message: "Please sign in again.") }
        let parts = path.split(separator: "/").map(String.init)
        let actor = state.currentUser.id
        func fail(_ message: String) throws -> Never { throw APIError(message: message) }
        if parts == ["profile"] {
            for index in state.users.indices where state.users[index].id == actor {
                state.users[index].name = body["name"] as? String ?? state.users[index].name
                state.users[index].university = body["university"] as? String ?? state.users[index].university
                state.users[index].carModel = body["carModel"] as? String ?? state.users[index].carModel
                state.users[index].carColor = body["carColor"] as? String ?? state.users[index].carColor
                state.users[index].plate = body["plate"] as? String ?? state.users[index].plate
                state.users[index].bio = body["bio"] as? String ?? state.users[index].bio
                state.currentUser = state.users[index]
            }
        } else if parts == ["preferences"] {
            state.preferences = try APIClient.decoder.decode(Preferences.self, from: JSONSerialization.data(withJSONObject: body))
        } else if parts == ["rides"] {
            guard let source = Location.sampleLocations.first(where: { $0.id == body["fromId"] as? String }), let target = Location.sampleLocations.first(where: { $0.id == body["toId"] as? String }), source.id != target.id,
                  let departure = body["departureTime"] as? Double, departure > Date().timeIntervalSince1970,
                  let price = body["price"] as? Double, (1...200).contains(price), let seats = body["totalSeats"] as? Int, (1...6).contains(seats),
                  let note = body["pickupNote"] as? String, !note.trimmingCharacters(in: .whitespaces).isEmpty else { try fail("Please check the required fields.") }
            guard !state.currentUser.carModel.isEmpty && !state.currentUser.carColor.isEmpty && !state.currentUser.plate.isEmpty else { try fail("Add your car details in Profile before offering a ride.") }
            let days = body["repeatWeekdays"] as? [Int] ?? []
            var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "Africa/Casablanca")!
            let start = Date(timeIntervalSince1970: departure)
            let dates = days.isEmpty ? [start] : (0..<14).compactMap { offset -> Date? in
                guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
                let isoDay = (calendar.component(.weekday, from: date) + 5) % 7 + 1
                return days.contains(isoDay) ? date : nil
            }
            let series = days.isEmpty ? nil : UUID().uuidString
            for date in dates { state.rides.append(Ride(id: UUID().uuidString, driverId: actor, fromLocation: source, toLocation: target, departureTime: date, price: price, availableSeats: seats, totalSeats: seats, status: .scheduled, pickupNote: note, repeatWeekdays: days, seriesId: series, createdAt: Date())) }
        } else if parts.first == "rides", parts.count >= 2, let index = state.rides.firstIndex(where: { $0.id == parts[1] }) {
            let ride = state.rides[index]
            if parts.last == "request" {
                guard ride.driverId != actor, ride.status == .scheduled, ride.departureTime > Date(), let seats = body["seats"] as? Int, seats >= 1, seats <= ride.availableSeats else { try fail("This ride is no longer available.") }
                guard !state.bookings.contains(where: { $0.rideId == ride.id && $0.passengerId == actor && [.requested, .confirmed].contains($0.status) }) else { try fail("You already have a request for this ride.") }
                state.bookings.append(Booking(id: UUID().uuidString, rideId: ride.id, passengerId: actor, seats: seats, status: .requested, createdAt: Date()))
            } else {
                guard ride.driverId == actor else { try fail("Only the driver can change this ride.") }
                if parts.count == 2 {
                    guard ride.status == .scheduled else { try fail("Only scheduled rides can be edited.") }
                    if let date = body["departureTime"] as? Double { state.rides[index].departureTime = Date(timeIntervalSince1970: date) }
                    if let note = body["pickupNote"] as? String { state.rides[index].pickupNote = note }
                } else if parts.last == "start", ride.status == .scheduled {
                    state.rides[index].status = .inProgress
                    for i in state.bookings.indices where state.bookings[i].rideId == ride.id && state.bookings[i].status == .requested { state.bookings[i].status = .declined }
                }
                else if parts.last == "complete", ride.status == .inProgress { state.rides[index].status = .completed }
                else if parts.last == "cancel", [.scheduled,.inProgress].contains(ride.status) {
                    state.rides[index].status = .cancelled
                    for i in state.bookings.indices where state.bookings[i].rideId == ride.id && [.requested,.confirmed].contains(state.bookings[i].status) { state.bookings[i].status = .cancelled }
                } else { try fail("This transition is not available.") }
            }
        } else if parts.first == "bookings", parts.count == 3, let index = state.bookings.firstIndex(where: { $0.id == parts[1] }), let rideIndex = state.rides.firstIndex(where: { $0.id == state.bookings[index].rideId }) {
            let booking = state.bookings[index]; let ride = state.rides[rideIndex]
            switch parts[2] {
            case "accept", "decline":
                guard ride.driverId == actor, booking.status == .requested, ride.status == .scheduled, ride.departureTime > Date() else { try fail("This request is no longer available.") }
                if parts[2] == "accept" {
                    guard ride.availableSeats >= booking.seats else { try fail("There are not enough seats.") }
                    state.bookings[index].status = .confirmed
                } else { state.bookings[index].status = .declined }
            case "cancel":
                guard booking.passengerId == actor, [.requested,.confirmed].contains(booking.status), [.scheduled,.inProgress].contains(ride.status) else { try fail("This request cannot be cancelled.") }
                state.bookings[index].status = .cancelled
            case "message":
                guard [booking.passengerId,ride.driverId].contains(actor), [.requested,.confirmed].contains(booking.status), let text = body["text"] as? String, !text.trimmingCharacters(in: .whitespaces).isEmpty else { try fail("This conversation is closed.") }
                state.messages.append(ChatMessage(id: UUID().uuidString, bookingId: booking.id, senderId: actor, text: text, createdAt: Date()))
            default: try fail("Unable to complete the request.")
            }
        } else if parts == ["reviews"] {
            guard let ride = state.rides.first(where: { $0.id == body["rideId"] as? String }), ride.status == .completed,
                  state.bookings.contains(where: { $0.rideId == ride.id && $0.passengerId == actor && $0.status == .confirmed }),
                  let stars = body["stars"] as? Int, (1...5).contains(stars) else { try fail("Review a completed trip you joined.") }
            guard !state.reviews.contains(where: { $0.rideId == ride.id && $0.authorId == actor }) else { try fail("You already reviewed this trip.") }
            state.reviews.append(RideReview(id: UUID().uuidString, rideId: ride.id, authorId: actor, subjectId: ride.driverId, stars: stars, comment: body["comment"] as? String ?? "", createdAt: Date()))
        } else if parts == ["notifications", "read"] {
            for i in state.notifications.indices { state.notifications[i].read = true }
        } else if parts.first == "verification" { try fail("Verification requires a connected server with email delivery.") }
        else { try fail("Unable to complete the request.") }
        for i in state.rides.indices {
            let used = state.bookings.filter { $0.rideId == state.rides[i].id && $0.status == .confirmed }.reduce(0) { $0 + $1.seats }
            state.rides[i].availableSeats = state.rides[i].totalSeats - used
        }
        for i in state.users.indices {
            let reviews = state.reviews.filter { $0.subjectId == state.users[i].id }
            state.users[i].reviewCount = reviews.count
            state.users[i].rating = reviews.isEmpty ? 0 : Double(reviews.reduce(0) { $0 + $1.stars }) / Double(reviews.count)
            state.users[i].totalRides = state.rides.filter { $0.driverId == state.users[i].id && $0.status == .completed }.count
        }
        state.currentUser = state.users.first { $0.id == actor } ?? state.currentUser
        let data = try APIClient.encoder.encode(state)
        try data.write(to: previewURL, options: [.atomic, .completeFileProtection])
        return state
    }
}
