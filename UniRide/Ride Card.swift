import SwiftUI
import UIKit // FIXED: Required for UIColor

struct RideCardView: View {
    let ride: Ride
    let onJoin: () -> Void
    @State private var showingDetails = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Circle().fill(Color.green.opacity(0.1)).frame(width: 40, height: 40)
                    .overlay(Text(ride.driver.initials).foregroundColor(.green))
                
                VStack(alignment: .leading) {
                    Text(ride.driver.name).fontWeight(.semibold)
                    Text(ride.driver.university).font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Text(ride.status.displayText)
                    .font(.caption).padding(6).background(ride.status.color.opacity(0.1)).foregroundColor(ride.status.color).cornerRadius(8)
            }
            
            // Route
            HStack {
                VStack {
                    Circle().fill(Color.green).frame(width: 8, height: 8)
                    Rectangle().fill(Color.gray.opacity(0.3)).frame(width: 2, height: 24)
                    Circle().fill(Color.red).frame(width: 8, height: 8)
                }
                VStack(alignment: .leading, spacing: 20) {
                    Text(ride.fromLocation.name).font(.subheadline)
                    Text(ride.toLocation.name).font(.subheadline)
                }
                Spacer()
            }
            
            // Footer Info
            HStack {
                Label(ride.departureTime.formatted(date: .omitted, time: .shortened), systemImage: "clock")
                Spacer()
                Label("$\(Int(ride.price))", systemImage: "dollarsign.circle")
            }
            .font(.caption).foregroundColor(.secondary)
            
            // Buttons
            if ride.status == .pending {
                HStack {
                    Button("Join", action: onJoin)
                        .frame(maxWidth: .infinity).padding(10).background(Color.green).foregroundColor(.white).cornerRadius(8)
                    
                    Button("Details") { showingDetails = true }
                        .frame(width: 80).padding(10)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.green))
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground)) // FIXED
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .sheet(isPresented: $showingDetails) {
            RideDetailsView(ride: ride)
        }
    }
}

// MARK: - Ride Details & Helpers
// Merged here to ensure they are found by RideCardView
struct RideDetailsView: View {
    let ride: Ride
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Driver Info
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Driver").font(.headline)
                        HStack {
                            Circle().fill(Color.green.opacity(0.1)).frame(width: 60, height: 60)
                                .overlay(Text(ride.driver.initials).font(.title2).foregroundColor(.green))
                            VStack(alignment: .leading) {
                                Text(ride.driver.name).font(.title3).fontWeight(.semibold)
                                HStack {
                                    Image(systemName: "star.fill").foregroundColor(.yellow)
                                    Text(String(format: "%.1f", ride.driver.rating))
                                }
                            }
                        }
                    }
                    .cardStyle()
                    
                    // Route
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Route").font(.headline)
                        RouteLocationView(location: ride.fromLocation, icon: "circle.fill", color: .green, title: "Pickup")
                        RouteLocationView(location: ride.toLocation, icon: "circle.fill", color: .red, title: "Dropoff")
                    }
                    .cardStyle()
                    
                    // Trip Info
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Trip Details").font(.headline)
                        TripInfoRow(icon: "calendar", title: "Date", value: ride.departureTime.formatted(date: .abbreviated, time: .shortened))
                        TripInfoRow(icon: "person.2", title: "Seats", value: "\(ride.availableSeats) available")
                        TripInfoRow(icon: "dollarsign.circle", title: "Price", value: "$\(Int(ride.price))")
                    }
                    .cardStyle()
                }
                .padding()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Ride Details")
            .toolbar { Button("Done") { dismiss() } }
        }
    }
}

struct RouteLocationView: View {
    let location: Location
    let icon: String
    let color: Color
    let title: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundColor(color).font(.caption)
            VStack(alignment: .leading) {
                Text(title).font(.caption).foregroundColor(.secondary)
                Text(location.name).font(.subheadline).fontWeight(.medium)
            }
        }
    }
}

struct TripInfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Label(title, systemImage: icon).foregroundColor(.secondary)
            Spacer()
            Text(value).fontWeight(.medium)
        }
    }
}
