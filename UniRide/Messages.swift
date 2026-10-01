import SwiftUI

struct MessagesView: View {
    @EnvironmentObject private var store: AppStore
    private var conversations: [Booking] {
        store.bookings.filter { booking in
            booking.passengerId == store.user?.id || store.ride(booking.rideId)?.driverId == store.user?.id
        }.sorted { a, b in
            (store.messages.last { $0.bookingId == a.id }?.createdAt ?? a.createdAt) > (store.messages.last { $0.bookingId == b.id }?.createdAt ?? b.createdAt)
        }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if conversations.isEmpty { EmptyState(title: "Your conversations", detail: "Request a seat to message your driver about pickup.", icon: "bubble.left.and.bubble.right") }
                    ForEach(conversations) { booking in
                        NavigationLink { ConversationView(bookingId: booking.id) } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                let ride = store.ride(booking.rideId)
                                let other = booking.passengerId == store.user?.id ? ride?.driverId : booking.passengerId
                                HStack { Text(store.profile(other ?? "")?.name ?? store.text("Student")).font(.headline); Spacer(); StatusPill(title: booking.status.label) }
                                Text(ride?.route ?? "UniRide").font(.caption).foregroundStyle(UniRideTheme.lime)
                                Text(store.messages.last { $0.bookingId == booking.id }?.text ?? store.text("Arrange your meeting point"))
                                    .font(.subheadline).lineLimit(2).foregroundStyle(UniRideTheme.muted)
                            }.frame(maxWidth: .infinity, alignment: .leading).cardStyle().foregroundStyle(.white)
                        }.buttonStyle(.plain)
                    }
                }.padding(20)
            }.background(.black).navigationTitle("Messages").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar).keyboardDone().refreshable { await store.refresh() }
        }
    }
}
struct ConversationView: View {
    let bookingId: String
    @EnvironmentObject private var store: AppStore
    @State private var draft = ""
    @FocusState private var composing: Bool
    private var booking: Booking? { store.bookings.first { $0.id == bookingId } }
    private var messages: [ChatMessage] { store.messages.filter { $0.bookingId == bookingId }.sorted { $0.createdAt < $1.createdAt } }
    private var canSend: Bool { booking.map { [.requested,.confirmed].contains($0.status) } ?? false }
    var body: some View {
        VStack(spacing: 0) {
            if let ride = store.ride(booking?.rideId ?? "") {
                NavigationLink { RideDetailsView(rideId: ride.id) } label: {
                    VStack(alignment: .leading, spacing: 4) { Text(ride.route).font(.caption.bold()); Text(ride.pickupNote).font(.caption).foregroundStyle(UniRideTheme.muted) }
                        .frame(maxWidth: .infinity, alignment: .leading).padding(16).background(UniRideTheme.card)
                }
            }
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if messages.isEmpty { EmptyState(title: "Arrange your meeting point", detail: "Only you and the other person in this booking can read this conversation.", icon: "bubble.left") }
                        ForEach(messages) { message in
                            let mine = message.senderId == store.user?.id
                            HStack {
                                if mine { Spacer(minLength: 48) }
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(message.text).font(.subheadline)
                                    Text(message.createdAt, style: .time).font(.caption2).opacity(0.6)
                                }.padding(14).foregroundStyle(mine ? .black : .white)
                                    .background(mine ? UniRideTheme.lime : UniRideTheme.card, in: RoundedRectangle(cornerRadius: 18))
                                if !mine { Spacer(minLength: 48) }
                            }.id(message.id)
                        }
                    }.padding(16)
                }.scrollDismissesKeyboard(.interactively)
                    .onChange(of: messages.count) { _ in if let last = messages.last { proxy.scrollTo(last.id, anchor: .bottom) } }
                    .onAppear { if let last = messages.last { proxy.scrollTo(last.id, anchor: .bottom) } }
            }
            if canSend {
                HStack(alignment: .bottom, spacing: 12) {
                    TextField("Message", text: $draft, axis: .vertical).lineLimit(1...4).uniRideField().focused($composing)
                    Button {
                        let content = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                        Task { if await store.perform("/bookings/\(bookingId)/message", body: ["text": content]) { draft = ""; composing = false } }
                    } label: { Image(systemName: "arrow.up").font(.headline).foregroundStyle(.black).frame(width: 48, height: 48).background(UniRideTheme.lime, in: Circle()) }
                    .accessibilityLabel("Send message").disabled(store.isBusy || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draft.count > 2000)
                }.padding(16)
            } else { Text("This conversation is closed.").font(.caption).foregroundStyle(UniRideTheme.muted).padding(16) }
        }.background(.black).navigationTitle("Conversation").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar).keyboardDone()
    }
}
