import SwiftUI
import UIKit

enum LocationPickerType {
    case from, to
}

struct RequestRideView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var fromLocation: Location?
    @State private var toLocation: Location?
    @State private var departureDate = Date()
    @State private var passengers = 1
    @State private var showingLocationPicker = false
    @State private var locationPickerType: LocationPickerType = .from
    
    var isFormValid: Bool { fromLocation != nil && toLocation != nil }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Route Selection
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Where are you going?", systemImage: "location.circle.fill")
                            .font(.headline)
                        
                        LocationPickerButton(title: "From", location: fromLocation, placeholder: "Pick up location") {
                            locationPickerType = .from
                            showingLocationPicker = true
                        }
                        
                        LocationPickerButton(title: "To", location: toLocation, placeholder: "Drop off location") {
                            locationPickerType = .to
                            showingLocationPicker = true
                        }
                    }
                    .cardStyle()
                    
                    // Departure Time
                    VStack(alignment: .leading, spacing: 16) {
                        Label("When?", systemImage: "clock.circle.fill").font(.headline)
                        DatePicker("Departure Time", selection: $departureDate, in: Date()...)
                    }
                    .cardStyle()
                    
                    // Passengers
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Passengers", systemImage: "person.2.fill").font(.headline)
                        Stepper("\(passengers) Passenger(s)", value: $passengers, in: 1...4)
                    }
                    .cardStyle()
                    
                    Button("Search Rides") {
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isFormValid ? Color.green : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .disabled(!isFormValid)
                }
                .padding()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Request Ride")
            .toolbar { Button("Cancel") { dismiss() } }
            .sheet(isPresented: $showingLocationPicker) {
                // Simple list to pick a sample location
                List(Location.sampleLocations) { loc in
                    Button(loc.name) {
                        if locationPickerType == .from { fromLocation = loc } else { toLocation = loc }
                        showingLocationPicker = false
                    }
                }
            }
        }
    }
}

struct LocationPickerButton: View {
    let title: String
    let location: Location?
    let placeholder: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading) {
                    Text(title).font(.caption).foregroundColor(.secondary)
                    Text(location?.name ?? placeholder)
                        .foregroundColor(location == nil ? .secondary : .primary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundColor(.gray)
            }
            .padding().background(Color(UIColor.systemGray6)).cornerRadius(8)
        }
    }
}
