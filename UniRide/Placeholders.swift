import SwiftUI
import Combine // FIXED: Required if checking AuthManager types

struct OfferRideView: View {
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationStack {
            VStack {
                Image(systemName: "steeringwheel").font(.system(size: 60)).foregroundColor(.green)
                Text("Offer a Ride").font(.title).bold()
                Text("Coming soon...").foregroundColor(.secondary)
            }
            .toolbar { Button("Close") { dismiss() } }
        }
    }
}

struct HistoryView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Text("Ride History").font(.title)
                Text("No past rides").foregroundColor(.secondary)
            }
        }
    }
}

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        NavigationStack {
            List {
                if let user = authManager.currentUser {
                    Section {
                        HStack {
                            Circle().fill(Color.gray.opacity(0.2)).frame(width: 50, height: 50)
                                .overlay(Text(user.initials))
                            VStack(alignment: .leading) {
                                Text(user.name).font(.headline)
                                Text(user.email).font(.subheadline).foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Section {
                        Button("Sign Out") {
                            authManager.signOut()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Profile")
        }
    }
}
