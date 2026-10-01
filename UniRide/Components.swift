import SwiftUI

struct EmptyState: View {
    let title: String
    let detail: String
    var icon = "car.fill"
    @EnvironmentObject private var store: AppStore
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 36)).foregroundStyle(UniRideTheme.lime)
            Text(store.text(title)).font(.headline)
            Text(store.text(detail)).font(.subheadline).foregroundStyle(UniRideTheme.muted).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.vertical, 32)
    }
}
struct StatusPill: View {
    let title: String
    @EnvironmentObject private var store: AppStore
    var body: some View {
        Text(store.text(title)).font(.caption.weight(.semibold)).foregroundStyle(UniRideTheme.lime)
            .padding(.horizontal, 10).padding(.vertical, 6).background(UniRideTheme.lime.opacity(0.12), in: Capsule())
    }
}
struct DriverAvatar: View {
    let user: User
    var size: CGFloat = 44
    var body: some View {
        Text(user.initials).font(.system(size: size / 3, weight: .semibold)).foregroundStyle(UniRideTheme.lime)
            .frame(width: size, height: size).background(UniRideTheme.lime.opacity(0.18), in: Circle())
    }
}
struct CompactRideRow: View {
    let ride: Ride
    @EnvironmentObject private var store: AppStore
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Text(ride.route).font(.headline).foregroundStyle(.white).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(ride.price.formatted(.number.precision(.fractionLength(0...2)))) Dhs").font(.headline).foregroundStyle(UniRideTheme.lime)
                    Text("per seat").font(.caption2).foregroundStyle(UniRideTheme.muted)
                }
            }
            if let driver = store.profile(ride.driverId) {
                HStack(spacing: 10) {
                    DriverAvatar(user: driver, size: 34)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack { Text(driver.name).font(.subheadline); if driver.studentEmailVerified { Image(systemName: "checkmark.shield.fill").foregroundStyle(UniRideTheme.lime).accessibilityLabel("University email verified") } }
                        if driver.reviewCount > 0 {
                            Label("\(driver.rating.formatted(.number.precision(.fractionLength(1)))) · \(driver.reviewCount)", systemImage: "star.fill").font(.caption).foregroundStyle(UniRideTheme.muted)
                        } else { Text("New driver · No reviews yet").font(.caption).foregroundStyle(UniRideTheme.muted) }
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right").foregroundStyle(UniRideTheme.muted)
                }.foregroundStyle(.white)
            }
            HStack {
                Label { Text(ride.departureTime, format: .dateTime.weekday(.abbreviated).hour().minute()) } icon: { Image(systemName: "clock") }
                Spacer()
                Label { Text("\(ride.availableSeats) seats") } icon: { Image(systemName: "person.2") }
                if !ride.repeatWeekdays.isEmpty { Image(systemName: "repeat").accessibilityLabel("Repeating commute") }
            }.font(.caption).foregroundStyle(UniRideTheme.muted)
        }.padding(18).background(UniRideTheme.card, in: RoundedRectangle(cornerRadius: 20))
    }
}
struct PlaceMenu: View {
    let title: String
    @Binding var selection: String
    var allowAny = false
    @EnvironmentObject private var store: AppStore
    var body: some View {
        HStack {
            Image(systemName: title == "From" ? "circle.fill" : "mappin").font(.caption).foregroundStyle(UniRideTheme.lime)
            VStack(alignment: .leading, spacing: 2) {
                Text(store.text(title)).font(.caption).foregroundStyle(UniRideTheme.muted)
                Picker(store.text(title), selection: $selection) {
                    if allowAny { Text("Any campus").tag("") }
                    ForEach(Location.sampleLocations) { Text($0.name).tag($0.id) }
                }.labelsHidden().pickerStyle(.menu).tint(.white).frame(maxWidth: .infinity, alignment: .leading)
            }
        }.padding(.horizontal, 12).frame(maxWidth: .infinity, minHeight: 60).background(UniRideTheme.field.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
    }
}
struct TripInfoRow: View {
    let icon: String
    let title: String
    let value: String
    @EnvironmentObject private var store: AppStore
    var body: some View {
        HStack { Label(store.text(title), systemImage: icon).foregroundStyle(UniRideTheme.muted); Spacer(); Text(value).multilineTextAlignment(.trailing) }.font(.subheadline)
    }
}

extension View {
    func keyboardDone() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
            }
        }
    }
}
