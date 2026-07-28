import SwiftUI
import UIKit // FIXED: Required for UIColor

struct HomeView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var nearbyRides: [Ride] = []
    @State private var showingRequestRide = false
    @State private var showingOfferRide = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("UniRide").font(.title).fontWeight(.bold)
                                Text("Student ride sharing made simple").font(.subheadline).foregroundColor(.secondary)
                            }
                            Spacer()
                            HStack(spacing: 4) {
                                Image(systemName: "person.3.fill").foregroundColor(.green)
                                Text("Student Only").font(.caption).fontWeight(.medium).foregroundColor(.green)
                            }
                            .padding(8).background(Color.green.opacity(0.1)).cornerRadius(16)
                        }
                        .padding(.horizontal, 20).padding(.top, 16)
                        
                        // Quick Actions
                        HStack(spacing: 16) {
                            Button(action: { showingRequestRide = true }) {
                                VStack(spacing: 8) {
                                    Image(systemName: "plus.circle.fill").font(.title2).foregroundColor(.white)
                                    Text("Request Ride").fontWeight(.semibold).foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 20).background(Color.green).cornerRadius(12)
                            }
                            
                            Button(action: { showingOfferRide = true }) {
                                VStack(spacing: 8) {
                                    Image(systemName: "plus.circle").font(.title2).foregroundColor(.green)
                                    Text("Offer Ride").fontWeight(.semibold).foregroundColor(.green)
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 20)
                                .background(Color.green.opacity(0.1)).cornerRadius(12)
                            }
                        }
                        .padding(.horizontal, 20).padding(.bottom, 16)
                    }
                    .background(Color(UIColor.systemBackground)) // FIXED
                    
                    // Content
                    LazyVStack(spacing: 24) {
                        FeaturesSectionView()
                        AvailableRidesSection(rides: nearbyRides)
                    }
                    .padding(20)
                }
            }
            .background(Color(UIColor.systemGroupedBackground)) // FIXED
            .onAppear { loadNearbyRides() }
            .sheet(isPresented: $showingRequestRide) { RequestRideView() }
            .sheet(isPresented: $showingOfferRide) { OfferRideView() }
        }
    }
    
    private func loadNearbyRides() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            nearbyRides = Ride.sampleRides
        }
    }
}

struct FeaturesSectionView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Why Choose UniRide?").font(.title2).fontWeight(.semibold)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(Feature.appFeatures, id: \.title) { feature in
                    FeatureCardView(feature: feature)
                }
            }
        }
        .padding(20).background(Color(UIColor.systemBackground)).cornerRadius(16) // FIXED
    }
}

struct FeatureCardView: View {
    let feature: Feature
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: feature.iconName).foregroundColor(feature.color).font(.title2)
            Text(feature.title).fontWeight(.semibold)
            Text(feature.description).font(.caption).foregroundColor(.secondary).lineLimit(2)
        }
        .padding(16).background(feature.color.opacity(0.05)).cornerRadius(12)
    }
}

struct AvailableRidesSection: View {
    let rides: [Ride]
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Available Rides").font(.title2).fontWeight(.semibold)
                Spacer()
                NavigationLink("View All", destination: RidesView()).foregroundColor(.green)
            }
            
            if rides.isEmpty {
                EmptyRidesView()
            } else {
                ForEach(rides.prefix(3)) { ride in
                    RideCardView(ride: ride) { print("Joining ride: \(ride.id)") }
                }
            }
        }
    }
}

struct EmptyRidesView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "car.circle").font(.system(size: 64)).foregroundColor(.secondary)
            Text("No rides available right now").fontWeight(.semibold)
        }
        .padding(40).frame(maxWidth: .infinity).background(Color(UIColor.systemBackground)).cornerRadius(16) // FIXED
    }
}
