import SwiftUI

struct RidesView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var history = false
    @State private var showingOffer = false
    private var myRides: [Ride] {
        store.rides.filter { ride in
            let booking = store.booking(for: ride)
            let involved = ride.driverId == store.user?.id || booking != nil
            let finished = [.completed, .cancelled].contains(ride.status) || (booking?.status == .cancelled || booking?.status == .declined)
            return involved && finished == history
        }.sorted { history ? $0.departureTime > $1.departureTime : $0.departureTime < $1.departureTime }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack { Text("My rides").font(.largeTitle.bold()); Spacer(); Button { showingOffer = true } label: { Image(systemName: "plus").font(.headline).foregroundStyle(.black).frame(width: 44, height: 44).background(UniRideTheme.lime, in: Circle()) }.accessibilityLabel("Offer a ride") }
                    Picker("Trips", selection: $history) { Text("Upcoming").tag(false); Text("History").tag(true) }.pickerStyle(.segmented)
                    if myRides.isEmpty { EmptyState(title: history ? "No past rides yet" : "Your next campus trip starts here", detail: "Find a ride on the map or offer your own commute.") }
                    ForEach(myRides) { ride in
                        NavigationLink { RideDetailsView(rideId: ride.id) } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    StatusPill(title: store.booking(for: ride)?.status == .requested ? "Awaiting driver" : ride.status.label)
                                    if ride.driverId == store.user?.id { StatusPill(title: "Driving") }
                                    let requests = store.bookings.filter { $0.rideId == ride.id && $0.status == .requested }
                                    if ride.driverId == store.user?.id && !requests.isEmpty { Text("\(requests.count) requests").font(.caption).foregroundStyle(UniRideTheme.lime) }
                                }
                                CompactRideRow(ride: ride)
                            }
                        }.buttonStyle(.plain).transition(.opacity.combined(with: .move(edge: .trailing)))
                    }
                }.padding(20).animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.9), value: myRides.map(\.id))
            }.background(.black).toolbar(.hidden, for: .navigationBar)
                .sheet(isPresented: $showingOffer) { OfferRideView() }.refreshable { await store.refresh() }
        }
    }
}
