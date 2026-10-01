import SwiftUI

struct RideDetailsView: View {
    let rideId: String
    var initialSeats = 1
    @EnvironmentObject private var store: AppStore
    @State private var seats = 1
    @State private var cancelling = false
    @State private var showingEdit = false
    @State private var showingReview = false
    @State private var showingChat: Booking?
    @State private var lifecycleAction: String?
    private var ride: Ride? { store.ride(rideId) }
    var body: some View {
        ScrollView {
            if let ride {
                VStack(alignment: .leading, spacing: 24) {
                    HStack { StatusPill(title: ride.status.label); Spacer(); if store.isPreview { StatusPill(title: "Preview mode") } }
                    Text(ride.route).font(.title2.bold())
                    CampusMap(locations: [ride.fromLocation, ride.toLocation]).frame(height: 190).clipShape(RoundedRectangle(cornerRadius: 20))
                    if let driver = store.profile(ride.driverId) {
                        NavigationLink { DriverProfileView(userId: driver.id) } label: {
                            HStack(spacing: 12) {
                                DriverAvatar(user: driver, size: 52)
                                VStack(alignment: .leading, spacing: 5) { Text(driver.name).font(.headline); Text(driver.university).font(.caption).foregroundStyle(UniRideTheme.muted) }
                                Spacer(); Image(systemName: "chevron.right")
                            }.foregroundStyle(.white)
                        }
                        VStack(spacing: 14) {
                            TripInfoRow(icon: "car.fill", title: "Car", value: [driver.carColor, driver.carModel].filter { !$0.isEmpty }.joined(separator: " "))
                            TripInfoRow(icon: "number", title: "Plate", value: driver.plate)
                            TripInfoRow(icon: "clock", title: "Departure", value: ride.departureTime.formatted(date: .abbreviated, time: .shortened))
                            TripInfoRow(icon: "person.2", title: "Seats available", value: "\(ride.availableSeats)")
                            TripInfoRow(icon: "banknote", title: "Price per seat", value: "\(ride.price.formatted(.number.precision(.fractionLength(0...2)))) Dhs")
                        }.cardStyle()
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Meeting point", systemImage: "mappin.and.ellipse").font(.headline).foregroundStyle(UniRideTheme.lime)
                        Text(ride.pickupNote).font(.subheadline)
                        if ride.status == .scheduled { HStack { Text("Departure countdown"); Spacer(); Text(ride.departureTime, style: .relative) }.font(.caption).foregroundStyle(UniRideTheme.muted) }
                        ShareLink(item: "UniRide · \(ride.route) · \(ride.departureTime.formatted()) · \(ride.pickupNote)") { Label("Share trip details", systemImage: "square.and.arrow.up").font(.caption) }
                    }.cardStyle()
                    if ride.driverId == store.user?.id { driverControls(ride) } else { passengerControls(ride) }
                }.padding(20)
            } else { EmptyState(title: "Ride not found", detail: "Refresh your rides and try again.") }
        }.background(.black).navigationTitle("Ride Details").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar).keyboardDone()
            .onAppear { seats = initialSeats }
            .sheet(isPresented: $showingEdit) { if let ride { EditRideView(ride: ride) } }
            .sheet(isPresented: $showingReview) { ReviewTripView(rideId: rideId) }
            .sheet(item: $showingChat) { booking in NavigationStack { ConversationView(bookingId: booking.id).toolbar { Button("Close") { showingChat = nil } } } }
            .confirmationDialog("Cancel this ride?", isPresented: $cancelling, titleVisibility: .visible) {
                Button("Cancel ride", role: .destructive) {
                    guard let ride else { return }
                    let path = ride.driverId == store.user?.id ? "/rides/\(ride.id)/cancel" : "/bookings/\(store.booking(for: ride)?.id ?? "")/cancel"
                    Task { await store.perform(path, success: "Ride cancelled") }
                }
                Button("Keep ride", role: .cancel) {}
            } message: { Text("Passengers will see the updated status. Cancelled seats become available again.") }
            .confirmationDialog(lifecycleAction == "start" ? store.text("Start this ride?") : store.text("Complete this trip?"), isPresented: Binding(get: { lifecycleAction != nil }, set: { if !$0 { lifecycleAction = nil } }), titleVisibility: .visible) {
                Button("Confirm") { if let action = lifecycleAction { Task { await store.perform("/rides/\(rideId)/\(action)", success: "Ride updated") } }; lifecycleAction = nil }
                Button("Cancel", role: .cancel) { lifecycleAction = nil }
            }
    }
    private func driverControls(_ ride: Ride) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Passengers & requests").font(.title3.bold())
            let requests = store.bookings.filter { $0.rideId == ride.id }
            if requests.isEmpty { Text("No seat requests yet").foregroundStyle(UniRideTheme.muted).font(.subheadline) }
            ForEach(requests) { request in
                VStack(alignment: .leading, spacing: 12) {
                    HStack { Text(store.profile(request.passengerId)?.name ?? store.text("Student")).font(.headline); Spacer(); StatusPill(title: request.status.label) }
                    Text("\(request.seats) seats").font(.caption).foregroundStyle(UniRideTheme.muted)
                    if request.status == .requested && ride.status == .scheduled {
                        HStack {
                            Button("Accept") { Task { await store.perform("/bookings/\(request.id)/accept", success: "Seat confirmed") } }.buttonStyle(LimeButtonStyle())
                            Button("Decline", role: .destructive) { Task { await store.perform("/bookings/\(request.id)/decline", success: "Request declined") } }.frame(minHeight: 44)
                        }.disabled(store.isBusy)
                    }
                    if [.requested,.confirmed].contains(request.status) { Button { showingChat = request } label: { Label("Message passenger", systemImage: "bubble.left") } }
                }.cardStyle()
            }
            if ride.status == .scheduled {
                Button("Edit departure & meeting point") { showingEdit = true }.frame(minHeight: 44)
                Button("Start ride") { lifecycleAction = "start" }.buttonStyle(LimeButtonStyle()).disabled(store.isBusy)
                Text("Starting a ride closes any unaccepted seat requests.").font(.caption).foregroundStyle(UniRideTheme.muted)
            }
            if ride.status == .inProgress { Button("Complete trip") { lifecycleAction = "complete" }.buttonStyle(LimeButtonStyle()).disabled(store.isBusy) }
            if [.scheduled,.inProgress].contains(ride.status) { Button("Cancel ride", role: .destructive) { cancelling = true }.frame(minHeight: 44).disabled(store.isBusy) }
        }
    }
    private func passengerControls(_ ride: Ride) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if let booking = store.booking(for: ride), [.requested,.confirmed].contains(booking.status) {
                HStack { StatusPill(title: booking.status.label); Spacer(); Text("\(booking.seats) seats").font(.caption) }
                if [.scheduled,.inProgress].contains(ride.status) {
                    Button { showingChat = booking } label: { Label("Message driver", systemImage: "bubble.left.fill") }.buttonStyle(LimeButtonStyle())
                    Button("Cancel request", role: .destructive) { cancelling = true }.frame(minHeight: 44).disabled(store.isBusy)
                }
                if ride.status == .completed && !(store.snapshot?.reviews ?? []).contains(where: { $0.rideId == ride.id && $0.authorId == store.user?.id }) {
                    Button("Rate your driver") { showingReview = true }.buttonStyle(LimeButtonStyle())
                }
            } else if ride.status == .scheduled && ride.departureTime > Date() && ride.availableSeats > 0 {
                Stepper("\(seats) seats", value: $seats, in: 1...max(1, ride.availableSeats))
                HStack { Text("Total"); Spacer(); Text("\((ride.price * Double(seats)).formatted(.number.precision(.fractionLength(0...2)))) Dhs").font(.title3.bold()).foregroundStyle(UniRideTheme.lime) }
                Text("Your seat is reserved after the driver accepts.").font(.caption).foregroundStyle(UniRideTheme.muted)
                Button("Request seat") { Task { await store.perform("/rides/\(ride.id)/request", body: ["seats": seats], success: "Seat request sent") } }
                    .buttonStyle(LimeButtonStyle()).disabled(store.isBusy || seats > ride.availableSeats)
            } else { Text("This ride is no longer available.").font(.subheadline).foregroundStyle(UniRideTheme.muted) }
        }
    }
}
struct EditRideView: View {
    let ride: Ride
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var departure = Date()
    @State private var note = ""
    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Departure", selection: $departure, in: Date()...Date().addingTimeInterval(90 * 86400))
                TextField("Meeting point", text: $note, axis: .vertical).lineLimit(3...5)
                Text("Changes apply to this departure only. Passengers receive an update.").font(.caption)
                Button("Save changes") { Task { if await store.perform("/rides/\(ride.id)", method: "PATCH", body: ["departureTime": departure.timeIntervalSince1970, "pickupNote": note], success: "Departure updated") { dismiss() } } }.disabled(store.isBusy || note.trimmingCharacters(in: .whitespaces).isEmpty || note.count > 300)
            }.navigationTitle("Edit ride").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar).keyboardDone().toolbar { Button("Close") { dismiss() } }
                .onAppear { departure = ride.departureTime; note = ride.pickupNote }
        }
    }
}
struct ReviewTripView: View {
    let rideId: String
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var stars = 5
    @State private var comment = ""
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("How was your trip?").font(.title2.bold())
                HStack { ForEach(1...5, id: \.self) { value in Button { stars = value } label: { Image(systemName: value <= stars ? "star.fill" : "star").font(.title).foregroundStyle(UniRideTheme.lime) }.accessibilityLabel("\(value) stars") } }
                TextField("Share your experience (optional)", text: $comment, axis: .vertical).lineLimit(3...6).uniRideField()
                Button("Submit review") { Task { if await store.perform("/reviews", body: ["rideId": rideId, "stars": stars, "comment": comment], success: "Review submitted") { dismiss() } } }.buttonStyle(LimeButtonStyle()).disabled(store.isBusy || comment.count > 500)
                Spacer()
            }.padding(24).background(.black).navigationTitle("Rate your driver").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar).keyboardDone().toolbar { Button("Close") { dismiss() } }
        }
    }
}
struct DriverProfileView: View {
    let userId: String
    @EnvironmentObject private var store: AppStore
    var body: some View {
        ScrollView {
            if let user = store.profile(userId) {
                VStack(spacing: 20) {
                    DriverAvatar(user: user, size: 80)
                    Text(user.name).font(.title2.bold())
                    Text(user.university).foregroundStyle(UniRideTheme.muted)
                    if user.studentEmailVerified { Label("University email verified", systemImage: "checkmark.shield.fill").foregroundStyle(UniRideTheme.lime) }
                    else if user.emailVerified { Label("Email verified", systemImage: "checkmark.circle").foregroundStyle(UniRideTheme.lime) }
                    else { Text("Email not verified").font(.caption).foregroundStyle(UniRideTheme.muted) }
                    Text(user.bio).font(.subheadline)
                    VStack(spacing: 14) {
                        TripInfoRow(icon: "car", title: "Car", value: "\(user.carColor) \(user.carModel)")
                        TripInfoRow(icon: "number", title: "Plate", value: user.plate)
                        TripInfoRow(icon: "checkmark.circle", title: "Completed trips", value: "\(user.totalRides)")
                        TripInfoRow(icon: "star", title: "Reviews", value: user.reviewCount > 0 ? "\(user.rating.formatted(.number.precision(.fractionLength(1)))) / 5 · \(user.reviewCount)" : store.text("No reviews yet"))
                    }.cardStyle()
                    ForEach(store.snapshot?.reviews.filter { $0.subjectId == userId } ?? []) { review in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack { Text(store.profile(review.authorId)?.name ?? store.text("Student")); Spacer(); Label("\(review.stars)", systemImage: "star.fill").foregroundStyle(UniRideTheme.lime) }
                            if !review.comment.isEmpty { Text(review.comment).font(.subheadline) }
                        }.frame(maxWidth: .infinity, alignment: .leading).cardStyle()
                    }
                }.padding(24)
            }
        }.background(.black).navigationTitle("Driver profile").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar).keyboardDone()
    }
}
