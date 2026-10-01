import SwiftUI

struct OfferRideView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var fromId = "station"
    @State private var toId = "ista2"
    @State private var departure = Date().addingTimeInterval(3600)
    @State private var price = "6"
    @State private var seats = 2
    @State private var note = ""
    @State private var days: Set<Int> = []
    private var hasCar: Bool { !(store.user?.carModel.isEmpty ?? true) && !(store.user?.carColor.isEmpty ?? true) && !(store.user?.plate.isEmpty ?? true) }
    private var valid: Bool { fromId != toId && (1...200).contains(Double(price.replacingOccurrences(of: ",", with: ".")) ?? 0) && !note.trimmingCharacters(in: .whitespaces).isEmpty && note.count <= 300 && hasCar }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Share your campus commute").font(.title2.bold())
                    if !hasCar {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Add your car details before offering a ride.").font(.subheadline)
                            NavigationLink("Add car details") { EditProfileView() }.font(.subheadline.bold())
                        }.cardStyle()
                    }
                    VStack(spacing: 12) { PlaceMenu(title: "From", selection: $fromId); PlaceMenu(title: "To", selection: $toId) }
                    DatePicker("Departure", selection: $departure, in: Date().addingTimeInterval(60)...Date().addingTimeInterval(90 * 86400))
                    VStack(alignment: .leading, spacing: 16) {
                        HStack { Text("Price per seat (Dhs)"); Spacer(); TextField("6", text: $price).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 80) }
                        Stepper("\(seats) seats", value: $seats, in: 1...6)
                    }.cardStyle()
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Meeting point").font(.headline)
                        TextField("Entrance, landmark and how to find your car", text: $note, axis: .vertical).lineLimit(3...5).uniRideField()
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Repeat commute", systemImage: "repeat").font(.headline)
                        HStack(spacing: 6) {
                            ForEach(1...7, id: \.self) { day in
                                Button { if days.contains(day) { days.remove(day) } else { days.insert(day) } } label: {
                                    Text(store.text(["Mon","Tue","Wed","Thu","Fri","Sat","Sun"][day-1])).font(.caption2.bold()).frame(maxWidth: .infinity, minHeight: 44)
                                        .foregroundStyle(days.contains(day) ? .black : .white).background(days.contains(day) ? UniRideTheme.lime : UniRideTheme.card, in: RoundedRectangle(cornerRadius: 10))
                                }.accessibilityAddTraits(days.contains(day) ? .isSelected : [])
                            }
                        }
                        Text(days.isEmpty ? store.text("One departure") : store.text("Repeats for two weeks. Each departure has its own seats.")).font(.caption).foregroundStyle(UniRideTheme.muted)
                    }
                    Button("Publish ride") {
                        Task {
                            let body: [String: Any] = ["fromId": fromId, "toId": toId, "departureTime": departure.timeIntervalSince1970, "price": Double(price.replacingOccurrences(of: ",", with: ".")) ?? 0, "totalSeats": seats, "pickupNote": note, "repeatWeekdays": days.sorted()]
                            if await store.perform("/rides", body: body, success: "Ride published") { dismiss() }
                        }
                    }.buttonStyle(LimeButtonStyle()).disabled(!valid || store.isBusy)
                }.padding(20)
            }.background(.black).navigationTitle("Offer a ride").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar).keyboardDone()
                .toolbar { Button("Close") { dismiss() } }
        }
    }
}
