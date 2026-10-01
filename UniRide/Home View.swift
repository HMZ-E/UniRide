import SwiftUI

struct HomeView: View {
    var onProfile: () -> Void = {}
    @EnvironmentObject private var store: AppStore
    @State private var fromId = "station"
    @State private var toId = ""
    @State private var date = Date()
    @State private var passengers = 1
    @State private var showingOffer = false
    @State private var showingSaveCommute = false
    @State private var commuteName = ""
    @State private var showingNotifications = false
    var results: [Ride] {
        store.rides.filter {
            $0.status == .scheduled && $0.driverId != store.user?.id && $0.departureTime >= date && $0.departureTime < date.addingTimeInterval(86400)
            && $0.fromLocation.id == fromId && (toId.isEmpty || $0.toLocation.id == toId) && $0.availableSeats >= passengers
        }.sorted { $0.departureTime < $1.departureTime }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Text("UniRide").font(.title3.bold())
                        Spacer()
                        Button { showingNotifications = true } label: {
                            Image(systemName: store.unreadCount > 0 ? "bell.badge.fill" : "bell").frame(width: 44, height: 44)
                        }.accessibilityLabel("Notifications")
                        Button(action: onProfile) { Image(systemName: "person.fill").foregroundStyle(.black).frame(width: 36, height: 36).background(UniRideTheme.lime, in: Circle()) }.accessibilityLabel("Open profile")
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Your campus. Your way.").font(.caption).foregroundStyle(UniRideTheme.lime)
                        Text("Where are you going?").font(.system(size: 30, weight: .bold))
                    }
                    VStack(spacing: 12) {
                        PlaceMenu(title: "From", selection: $fromId)
                        PlaceMenu(title: "To", selection: $toId, allowAny: true)
                        HStack {
                            DatePicker("When?", selection: $date, in: Date()..., displayedComponents: [.date, .hourAndMinute]).labelsHidden()
                            Spacer()
                            Stepper(value: $passengers, in: 1...6) { Label("\(passengers)", systemImage: "person.fill") }.fixedSize()
                        }.font(.caption)
                        HStack {
                            Button { showingSaveCommute = true } label: { Label("Save commute", systemImage: "bookmark") }.disabled(toId.isEmpty || fromId == toId)
                            Spacer()
                            Text("\(results.count) rides").foregroundStyle(UniRideTheme.muted)
                        }.font(.caption)
                    }.padding(16).background(UniRideTheme.card, in: RoundedRectangle(cornerRadius: 20))
                    quickDestinations
                    if !store.preferences.savedCommutes.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(store.preferences.savedCommutes) { commute in
                                    Button { fromId = commute.fromId; toId = commute.toId } label: { Label(commute.name, systemImage: "bookmark.fill").font(.caption).padding(10).background(UniRideTheme.card, in: Capsule()) }
                                }
                            }
                        }
                    }
                    HStack { Text("Available Rides").font(.title2.bold()); Spacer(); Button("Offer a ride") { showingOffer = true }.font(.caption.bold()) }
                    if results.isEmpty { EmptyState(title: "No matching rides yet", detail: "Try another destination or departure time, or offer your own ride.") }
                    ForEach(results) { ride in
                        NavigationLink { RideDetailsView(rideId: ride.id, initialSeats: passengers) } label: { CompactRideRow(ride: ride) }.buttonStyle(.plain)
                    }
                    CampusMap { selected in toId = selected }.frame(height: 220).clipShape(RoundedRectangle(cornerRadius: 24))
                        .accessibilityLabel("Interactive Settat campus map")
                    Text("Pins show suggested landmarks. Confirm the entrance in the driver’s meeting note.").font(.caption2).foregroundStyle(UniRideTheme.muted)
                }.padding(20)
            }.background(.black).toolbar(.hidden, for: .navigationBar)
                .refreshable { await store.refresh() }
                .sheet(isPresented: $showingOffer) { OfferRideView() }
                .sheet(isPresented: $showingNotifications) { NotificationsView() }
                .alert("Save commute", isPresented: $showingSaveCommute) {
                    TextField("Commute name", text: $commuteName)
                    Button("Save") {
                        Task {
                            var prefs = store.preferences
                            prefs.savedCommutes.append(SavedCommute(id: UUID().uuidString, name: commuteName.isEmpty ? "\(Location.sampleLocations.first { $0.id == fromId }?.name ?? "") → \(Location.sampleLocations.first { $0.id == toId }?.name ?? "")" : commuteName, fromId: fromId, toId: toId))
                            await store.savePreferences(prefs); commuteName = ""
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                }
        }
    }
    private var quickDestinations: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                if let home = store.preferences.homeLocationId {
                    Button { toId = home } label: { Label("Home", systemImage: "house.fill").padding(12).background(UniRideTheme.card, in: Capsule()) }
                }
                ForEach(Location.sampleLocations.filter { store.preferences.favoriteLocationIDs.contains($0.id) || ["ista2","encg","station"].contains($0.id) }) { place in
                    Button { toId = place.id } label: { Text(place.name).foregroundStyle(toId == place.id ? .black : .white).padding(12).background(toId == place.id ? UniRideTheme.lime : UniRideTheme.card, in: Capsule()) }
                }
            }.font(.caption.weight(.semibold))
        }
    }
}
