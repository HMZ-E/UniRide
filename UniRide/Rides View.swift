import SwiftUI
import UIKit

struct RidesView: View {
    @State private var rides: [Ride] = []
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var showingOfferRide = false
    
    var filteredRides: [Ride] {
        guard !searchText.isEmpty else { return rides }
        return rides.filter { $0.fromLocation.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search & Filter Header
                VStack(spacing: 16) {
                    HStack {
                        Text("Available Rides").font(.title).fontWeight(.bold)
                        Spacer()
                        Button("Offer") { showingOfferRide = true }
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(Color.green).foregroundColor(.white).cornerRadius(20)
                    }
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                        TextField("Search...", text: $searchText)
                    }
                    .padding(10).background(Color(UIColor.systemGray6)).cornerRadius(10)
                }
                .padding(20).background(Color(UIColor.systemBackground))
                
                // Content
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(filteredRides) { ride in
                            RideCardView(ride: ride) {
                                // Join Action
                            }
                        }
                    }
                    .padding(20)
                }
                .background(Color(UIColor.systemGroupedBackground))
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                rides = Ride.sampleRides
                isLoading = false
            }
        }
        .sheet(isPresented: $showingOfferRide) { OfferRideView() }
    }
}
