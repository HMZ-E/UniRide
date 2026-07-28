import SwiftUI
import Combine // FIXED: Required for ObservableObject

class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    
    func signIn(email: String, password: String) async -> Bool {
        // Simulate API call
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        
        // Mock authentication logic
        if email.contains("@university.edu") {
            await MainActor.run {
                self.isAuthenticated = true
                self.currentUser = User(
                    id: UUID().uuidString,
                    name: "Alex Thompson",
                    email: email,
                    studentId: "AT2024",
                    university: "State University",
                    phone: "(555) 123-4567",
                    isDriver: true,
                    isVerified: true,
                    rating: 4.8,
                    totalRides: 12
                )
            }
            return true
        }
        return false
    }
    
    func signUp(firstName: String, lastName: String, email: String, studentId: String, phone: String, password: String) async -> Bool {
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        if email.contains("@university.edu") {
            await MainActor.run {
                self.isAuthenticated = true
                self.currentUser = User(
                    id: UUID().uuidString,
                    name: "\(firstName) \(lastName)",
                    email: email,
                    studentId: studentId,
                    university: "State University",
                    phone: phone,
                    isDriver: false,
                    isVerified: false,
                    rating: 0.0,
                    totalRides: 0
                )
            }
            return true
        }
        return false
    }
    
    func signOut() {
        isAuthenticated = false
        currentUser = nil
    }
}
