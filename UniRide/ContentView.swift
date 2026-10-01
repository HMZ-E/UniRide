import SwiftUI

struct ContentView: View {
    @StateObject private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase
    @State private var bootstrapped = false
    var body: some View {
        ZStack {
            if store.isAuthenticated { MainTabView() }
            else { AuthView() }
        }
        .environmentObject(store).preferredColorScheme(.dark).tint(UniRideTheme.lime)
        .environment(\.locale, Locale(identifier: store.language))
        .environment(\.layoutDirection, store.language == "ar" ? .rightToLeft : .leftToRight)
        .overlay(alignment: .top) {
            if let notice = store.notice {
                Label(store.text(notice), systemImage: "checkmark.circle.fill")
                    .font(.subheadline).padding(14).background(UniRideTheme.card, in: Capsule())
                    .padding(.top, 8).accessibilityAddTraits(.updatesFrequently)
            }
        }
        .background(AppErrorPresenter(message: store.error.map { store.text($0) }, title: store.text("Unable to complete the request"), onDismiss: { store.error = nil }))
        .onReceive(NotificationCenter.default.publisher(for: .uniRidePushRegistered)) { event in
            if let token = event.object as? String { Task { await store.registerPushToken(token) } }
        }
        .task {
            if !bootstrapped {
                bootstrapped = true
                #if DEBUG
                let arguments = ProcessInfo.processInfo.arguments
                if let index = arguments.firstIndex(of: "--server"), arguments.indices.contains(index + 1) { store.setServer(arguments[index + 1]) }
                if arguments.contains("--ui-testing") { await store.signOut(); store.language = "en" }
                if arguments.contains("--language-fr") { store.language = "fr" }
                if arguments.contains("--language-ar") { store.language = "ar" }
                if ProcessInfo.processInfo.arguments.contains("--fresh-preview") { store.resetPreview() }
                if ProcessInfo.processInfo.arguments.contains("--preview-home") || ProcessInfo.processInfo.arguments.contains("--preview-rides") { store.previewApp() }
                #endif
                await store.restore()
            }
            while !Task.isCancelled {
                do { try await Task.sleep(nanoseconds: 8_000_000_000) } catch { break }
                if scenePhase == .active { await store.refresh() }
            }
        }
    }
}
struct MainTabView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selectedTab = 0
    @State private var notificationRoute: TripRoute?
    var body: some View {
        VStack(spacing: 0) {
            if store.isPreview {
                HStack(spacing: 6) {
                    Image(systemName: "eye")
                    Text("Preview mode").fontWeight(.semibold)
                    Spacer()
                    Text(store.user?.id == "driver1" ? store.text("Driver") : store.text("Passenger"))
                }.font(.caption).foregroundStyle(UniRideTheme.lime).padding(.horizontal, 20).padding(.vertical, 8)
                    .background(UniRideTheme.lime.opacity(0.08))
            } else if !store.connected {
                Label("Reconnecting to server…", systemImage: "wifi.exclamationmark").font(.caption).padding(8)
            }
            Group {
                switch selectedTab {
                case 1: RidesView()
                case 2: MessagesView()
                case 3: ProfileView()
                default: HomeView(onProfile: { selectedTab = 3 })
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack(spacing: 0) {
                tab("Map", icon: "mappin.circle.fill", index: 0)
                tab("Rides", icon: "person.3.fill", index: 1)
                tab("Messages", icon: "bubble.left.fill", index: 2)
                tab("Profile", icon: "person.fill", index: 3)
            }.padding(.top, 8).padding(.bottom, 4).background(.black)
        }.background(.black)
        .onReceive(NotificationCenter.default.publisher(for: .uniRideOpenTrip)) { event in
            if let id = event.object as? String { notificationRoute = TripRoute(id: id) }
        }
        .sheet(item: $notificationRoute) { route in NavigationStack { RideDetailsView(rideId: route.id) } }
        #if DEBUG
        .onAppear { if ProcessInfo.processInfo.arguments.contains("--preview-rides") { selectedTab = 1 } }
        #endif
    }
    private func tab(_ title: String, icon: String, index: Int) -> some View {
        Button { selectedTab = index } label: {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 20))
                Text(store.text(title)).font(.system(size: 11))
            }.foregroundStyle(selectedTab == index ? UniRideTheme.lime : UniRideTheme.muted)
                .frame(minWidth: 54, minHeight: 54).padding(.horizontal, 6)
                .background(selectedTab == index ? UniRideTheme.lime.opacity(0.16) : .clear, in: RoundedRectangle(cornerRadius: 15))
                .frame(maxWidth: .infinity)
        }.accessibilityLabel(store.text(title)).accessibilityAddTraits(selectedTab == index ? .isSelected : [])
    }
}
