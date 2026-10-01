import SwiftUI

struct User: Identifiable, Codable {
    let id: String
    var name: String
    var email: String?
    var university: String
    var carModel: String
    var carColor: String
    var plate: String
    var bio: String
    var emailVerified: Bool
    var studentEmailVerified: Bool
    var rating: Double
    var reviewCount: Int
    var totalRides: Int
    var initials: String { name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined() }
}

struct Location: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    let isUniversityLocation: Bool
    static let sampleLocations = [
        Location(id: "ista2", name: "ISTA 2", address: "Quartier Administratif, Settat", latitude: 33.014, longitude: -7.611, isUniversityLocation: true),
        Location(id: "encg", name: "ENCG Settat", address: "Campus universitaire, Settat", latitude: 33.004, longitude: -7.621, isUniversityLocation: true),
        Location(id: "station", name: "Gare de Settat", address: "Gare ferroviaire, Settat", latitude: 32.990, longitude: -7.622, isUniversityLocation: false),
        Location(id: "bus", name: "Gare Routière Settat", address: "Gare routière, Settat", latitude: 33.007, longitude: -7.619, isUniversityLocation: false),
        Location(id: "science", name: "Faculté des Sciences", address: "Campus universitaire, Settat", latitude: 33.001, longitude: -7.619, isUniversityLocation: true),
        Location(id: "health", name: "Institut de Santé", address: "Settat", latitude: 33.008, longitude: -7.609, isUniversityLocation: true)
    ]
}

struct Ride: Identifiable, Codable {
    let id: String
    let driverId: String
    let fromLocation: Location
    let toLocation: Location
    var departureTime: Date
    let price: Double
    var availableSeats: Int
    let totalSeats: Int
    var status: Status
    var pickupNote: String
    let repeatWeekdays: [Int]
    let seriesId: String?
    let createdAt: Date
    var route: String { "\(fromLocation.name) → \(toLocation.name)" }
    enum Status: String, Codable {
        case scheduled, inProgress, completed, cancelled
        var label: String {
            switch self { case .scheduled: return "Scheduled"; case .inProgress: return "En route"; case .completed: return "Completed"; case .cancelled: return "Cancelled" }
        }
    }
}
struct Booking: Identifiable, Codable {
    let id: String
    let rideId: String
    let passengerId: String
    let seats: Int
    var status: Status
    let createdAt: Date
    enum Status: String, Codable {
        case requested, confirmed, declined, cancelled
        var label: String {
            switch self { case .requested: return "Awaiting driver"; case .confirmed: return "Confirmed"; case .declined: return "Declined"; case .cancelled: return "Cancelled" }
        }
    }
}
struct ChatMessage: Identifiable, Codable {
    let id: String
    let bookingId: String
    let senderId: String
    let text: String
    let createdAt: Date
}
struct RideReview: Identifiable, Codable {
    let id: String
    let rideId: String
    let authorId: String
    let subjectId: String
    let stars: Int
    let comment: String
    let createdAt: Date
}
struct RideNotification: Identifiable, Codable {
    let id: String
    let kind: String
    let rideId: String
    let bookingId: String?
    let createdAt: Date
    var read: Bool
    var title: String {
        switch kind {
        case "request": return "New seat request"
        case "confirmed": return "Your seat is confirmed"
        case "declined": return "Seat request declined"
        case "changed": return "Departure updated"
        case "cancelled", "passengerCancelled": return "Ride cancelled"
        case "started": return "Your ride has started"
        case "completed": return "Trip completed"
        case "message": return "New message"
        default: return "Ride update"
        }
    }
}
struct SavedCommute: Identifiable, Codable {
    let id: String
    let name: String
    let fromId: String
    let toId: String
}
struct Preferences: Codable {
    var favoriteLocationIDs: [String] = []
    var homeLocationId: String?
    var savedCommutes: [SavedCommute] = []
}
struct AppSnapshot: Codable {
    var currentUser: User
    var users: [User]
    var rides: [Ride]
    var bookings: [Booking]
    var messages: [ChatMessage]
    var notifications: [RideNotification]
    var reviews: [RideReview]
    var preferences: Preferences
}
struct SessionResponse: Codable { let token: String; let snapshot: AppSnapshot }

extension AppSnapshot {
    static var preview: AppSnapshot {
        let student = User(id: "preview", name: "UniRide Student", email: "student@example.com", university: "Université Hassan I", carModel: "", carColor: "", plate: "", bio: "", emailVerified: false, studentEmailVerified: false, rating: 0, reviewCount: 0, totalRides: 0)
        let omar = User(id: "driver1", name: "Omar Mahir", university: "Université Hassan I", carModel: "Dacia Sandero", carColor: "White", plate: "DEMO 01", bio: "Campus commute · Preview profile", emailVerified: false, studentEmailVerified: false, rating: 0, reviewCount: 0, totalRides: 0)
        let said = User(id: "driver2", name: "Said Hatim", university: "Université Hassan I", carModel: "Renault Clio", carColor: "Grey", plate: "DEMO 02", bio: "Preview profile", emailVerified: false, studentEmailVerified: false, rating: 0, reviewCount: 0, totalRides: 0)
        let places = Location.sampleLocations
        let rides = [
            Ride(id: "preview-1", driverId: omar.id, fromLocation: places[2], toLocation: places[0], departureTime: Date().addingTimeInterval(3600), price: 6, availableSeats: 2, totalSeats: 2, status: .scheduled, pickupNote: "Meet outside the station entrance. Look for the white Dacia.", repeatWeekdays: [], seriesId: nil, createdAt: Date()),
            Ride(id: "preview-2", driverId: said.id, fromLocation: places[3], toLocation: places[1], departureTime: Date().addingTimeInterval(7200), price: 11, availableSeats: 3, totalSeats: 3, status: .scheduled, pickupNote: "Meet at the main bus station entrance.", repeatWeekdays: [], seriesId: nil, createdAt: Date())
        ]
        return AppSnapshot(currentUser: student, users: [student, omar, said], rides: rides, bookings: [], messages: [], notifications: [], reviews: [], preferences: Preferences(favoriteLocationIDs: ["ista2", "encg", "station"]))
    }
}
