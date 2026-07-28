import SwiftUI

// MARK: - User Model
struct User: Identifiable, Codable {
    let id: String
    let name: String
    let email: String
    let studentId: String
    let university: String
    let phone: String
    let isDriver: Bool
    let isVerified: Bool
    let rating: Double
    let totalRides: Int
    
    var initials: String {
        let components = name.components(separatedBy: " ")
        return components.compactMap { $0.first }.map(String.init).joined()
    }
}

// MARK: - Location Model
struct Location: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    let isUniversityLocation: Bool
}

// MARK: - Ride Model
struct Ride: Identifiable, Codable {
    let id: String
    let driverId: String
    let fromLocation: Location
    let toLocation: Location
    let departureTime: Date
    let price: Double
    let availableSeats: Int
    let totalSeats: Int
    let status: RideStatus
    let driver: User
    let createdAt: Date
    
    enum RideStatus: String, Codable, CaseIterable {
        case pending = "pending"
        case accepted = "accepted"
        case inProgress = "in-progress"
        case completed = "completed"
        case cancelled = "cancelled"
        
        var color: Color {
            switch self {
            case .pending: return .yellow
            case .accepted: return .green
            case .inProgress: return .blue
            case .completed: return .gray
            case .cancelled: return .red
            }
        }
        
        var displayText: String {
            switch self {
            case .pending: return "Pending"
            case .accepted: return "Accepted"
            case .inProgress: return "In Progress"
            case .completed: return "Completed"
            case .cancelled: return "Cancelled"
            }
        }
    }
}

// MARK: - Feature Model
struct Feature {
    let iconName: String
    let title: String
    let description: String
    let color: Color
}

// MARK: - Sample Data
extension Location {
    static let sampleLocations: [Location] = [
        Location(id: "1", name: "University Main Campus", address: "123 University Ave, College Town", latitude: 40.7589, longitude: -73.9851, isUniversityLocation: true),
        Location(id: "2", name: "Downtown Station", address: "45 Market St, Downtown", latitude: 40.7500, longitude: -73.9900, isUniversityLocation: false)
    ]
}

extension User {
    static let sampleDriver = User(id: "driver1", name: "Sarah Chen", email: "sarah.chen@university.edu", studentId: "SC2024", university: "State University", phone: "(555) 123-4567", isDriver: true, isVerified: true, rating: 4.9, totalRides: 45)
}

extension Ride {
    static let sampleRides: [Ride] = [
        Ride(id: "1", driverId: "driver1", fromLocation: Location.sampleLocations[0], toLocation: Location.sampleLocations[1], departureTime: Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date(), price: 12.0, availableSeats: 2, totalSeats: 4, status: .pending, driver: User.sampleDriver, createdAt: Date())
    ]
}

extension Feature {
    static let appFeatures: [Feature] = [
        Feature(iconName: "shield.checkered", title: "Student Verified", description: "Only verified university students can join rides", color: .blue),
        Feature(iconName: "dollarsign.circle.fill", title: "Affordable", description: "Split costs with fellow students", color: .green)
    ]
}
