import SwiftUI
import UserNotifications

struct ProfileView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showingServer = false
    @State private var showingVerify = false
    @State private var notificationsEnabled = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let user = store.user {
                        VStack(spacing: 12) {
                            DriverAvatar(user: user, size: 76)
                            Text(user.name).font(.title2.bold())
                            Text(user.university).foregroundStyle(UniRideTheme.muted)
                            if user.studentEmailVerified { Label("University email verified", systemImage: "checkmark.shield.fill").font(.caption).foregroundStyle(UniRideTheme.lime) }
                            else if user.emailVerified { Label("Email verified", systemImage: "checkmark.circle").font(.caption).foregroundStyle(UniRideTheme.lime) }
                            else { Text("Email not verified").font(.caption).foregroundStyle(UniRideTheme.muted) }
                        }.frame(maxWidth: .infinity).cardStyle()
                        if store.isPreview {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Try both sides of a booking").font(.headline)
                                Picker("Preview role", selection: Binding(get: { store.user?.id == "driver1" }, set: { store.switchPreviewRole(driver: $0) })) {
                                    Text("Passenger").tag(false); Text("Driver").tag(true)
                                }.pickerStyle(.segmented)
                                Text("Request a seat as a passenger, then switch to the driver to accept it. All preview data stays on this device.").font(.caption).foregroundStyle(UniRideTheme.muted)
                                Button("Reset preview") { store.resetPreview() }.font(.caption)
                            }.cardStyle()
                        }
                        NavigationLink { EditProfileView() } label: { profileRow("Edit profile & car", icon: "person.crop.circle") }
                        if !store.isPreview && !user.emailVerified { Button { showingVerify = true } label: { profileRow("Verify email", icon: "checkmark.shield") } }
                        NavigationLink { DriverProfileView(userId: user.id) } label: { profileRow("Public profile & reviews", icon: "star") }
                        NavigationLink { SavedPlacesView() } label: { profileRow("Saved places & commutes", icon: "bookmark") }
                        VStack(alignment: .leading, spacing: 16) {
                            Picker("Language", selection: $store.language) { Text("English").tag("en"); Text("Français").tag("fr"); Text("العربية").tag("ar") }
                            Button {
                                Task {
                                    do {
                                        notificationsEnabled = try await store.notifications.enable()
                                        if notificationsEnabled && store.remotePushEnabled && !store.isPreview { UIApplication.shared.registerForRemoteNotifications() }
                                        if let snapshot = store.snapshot { store.notifications.syncReminders(snapshot, title: store.text("Your ride leaves soon")) }
                                        store.flash(notificationsEnabled ? "Notifications enabled" : "Enable notifications in iPhone Settings")
                                    } catch { store.error = error.localizedDescription }
                                }
                            } label: { Label(notificationsEnabled ? store.text("Notifications enabled") : store.text("Enable notifications"), systemImage: "bell") }
                            Text("Departure reminders work when the app is closed. Booking and message updates refresh while the app is open.").font(.caption).foregroundStyle(UniRideTheme.muted)
                        }.cardStyle()
                        Button { showingServer = true } label: { profileRow("Server settings", icon: "server.rack") }
                        Button("Sign Out") { Task { await store.signOut() } }.buttonStyle(LimeButtonStyle())
                    }
                    Text("For Students By Students").font(.caption).foregroundStyle(UniRideTheme.muted)
                }.padding(20)
            }.background(.black).navigationTitle("Profile").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar).keyboardDone()
                .sheet(isPresented: $showingServer) { ServerSettingsView() }
                .sheet(isPresented: $showingVerify) { VerifyEmailView() }
                .task { notificationsEnabled = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .authorized }
        }
    }
    private func profileRow(_ title: String, icon: String) -> some View {
        HStack { Label(store.text(title), systemImage: icon); Spacer(); Image(systemName: "chevron.right") }.foregroundStyle(.white).padding(18).background(UniRideTheme.card, in: RoundedRectangle(cornerRadius: 16))
    }
}
struct EditProfileView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var university = ""
    @State private var model = ""
    @State private var color = ""
    @State private var plate = ""
    @State private var bio = ""
    var body: some View {
        Form {
            Section("Student profile") {
                TextField("Full name", text: $name).textContentType(.name)
                TextField("University", text: $university)
                TextField("About you", text: $bio, axis: .vertical).lineLimit(2...4)
            }
            Section("Car details") {
                TextField("Car model", text: $model)
                TextField("Car colour", text: $color)
                TextField("Number plate", text: $plate).textInputAutocapitalization(.characters)
                Text("Passengers use these details to find your car at pickup.").font(.caption)
            }
            Button("Save profile") {
                Task {
                    if await store.perform("/profile", method: "PATCH", body: ["name": name, "university": university, "carModel": model, "carColor": color, "plate": plate, "bio": bio], success: "Profile saved") { dismiss() }
                }
            }.disabled(store.isBusy || name.trimmingCharacters(in: .whitespaces).isEmpty || university.trimmingCharacters(in: .whitespaces).isEmpty || [name,university,model,color,plate,bio].contains { $0.count > 200 })
        }.navigationTitle("Edit profile & car").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar).keyboardDone()
            .onAppear { if let user = store.user { name = user.name; university = user.university; model = user.carModel; color = user.carColor; plate = user.plate; bio = user.bio } }
    }
}
struct SavedPlacesView: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        List {
            Section("Home meeting point") {
                Picker("Home", selection: Binding(get: { store.preferences.homeLocationId ?? "" }, set: { value in Task { var p = store.preferences; p.homeLocationId = value.isEmpty ? nil : value; await store.savePreferences(p) } })) {
                    Text("Not set").tag("")
                    ForEach(Location.sampleLocations) { Text($0.name).tag($0.id) }
                }
                Text("Choose a nearby public landmark, rather than your private address.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Favorite places") {
                ForEach(Location.sampleLocations) { place in
                    Button { Task { await store.toggleFavorite(place.id) } } label: {
                        HStack { Text(place.name).foregroundStyle(.white); Spacer(); Image(systemName: store.preferences.favoriteLocationIDs.contains(place.id) ? "star.fill" : "star").foregroundStyle(UniRideTheme.lime) }
                    }.disabled(store.isBusy)
                }
            }
            Section("Saved commutes") {
                ForEach(store.preferences.savedCommutes) { commute in Text(commute.name) }
                    .onDelete { indices in Task { var p = store.preferences; p.savedCommutes.remove(atOffsets: indices); await store.savePreferences(p) } }
                if store.preferences.savedCommutes.isEmpty { Text("Save a route from the home search.").font(.caption).foregroundStyle(.secondary) }
            }
        }.navigationTitle("Saved places & commutes").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar).keyboardDone()
    }
}
struct VerifyEmailView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var requested = false
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Label("Verify email", systemImage: "checkmark.shield").font(.title2.bold())
                Text(store.user?.email ?? "").foregroundStyle(UniRideTheme.muted)
                Text("A university badge appears only after a code is confirmed and your email domain is recognised by the server.").font(.subheadline)
                Button(requested ? store.text("Send another code") : store.text("Send verification code")) {
                    Task { if await store.perform("/verification/request", success: "Verification code sent") { requested = true } }
                }.buttonStyle(LimeButtonStyle()).disabled(store.isBusy)
                if requested {
                    TextField("6-digit code", text: $code).keyboardType(.numberPad).textContentType(.oneTimeCode).uniRideField()
                    Button("Confirm email") { Task { if await store.perform("/verification/confirm", body: ["code": code], success: "Email verified") { dismiss() } } }.buttonStyle(LimeButtonStyle()).disabled(store.isBusy || code.count != 6)
                }
                Spacer()
            }.padding(24).background(.black).navigationTitle("Verify email").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar).keyboardDone().toolbar { Button("Close") { dismiss() } }
        }
    }
}
struct NotificationsView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    let notes = (store.snapshot?.notifications ?? []).sorted { $0.createdAt > $1.createdAt }
                    if notes.isEmpty { EmptyState(title: "You’re all caught up", detail: "Seat requests, trip changes and messages appear here.", icon: "bell") }
                    ForEach(notes) { note in
                        NavigationLink { RideDetailsView(rideId: note.rideId) } label: {
                            HStack(alignment: .top) {
                                Image(systemName: "bell.fill").foregroundStyle(UniRideTheme.lime)
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(store.text(note.title)).font(.headline)
                                    Text(store.ride(note.rideId)?.route ?? "UniRide").font(.caption).foregroundStyle(UniRideTheme.muted)
                                    Text(note.createdAt, style: .relative).font(.caption2).foregroundStyle(UniRideTheme.muted)
                                }
                                Spacer()
                                if !note.read { Circle().fill(UniRideTheme.lime).frame(width: 7, height: 7) }
                            }.foregroundStyle(.white).cardStyle()
                        }.buttonStyle(.plain)
                    }
                }.padding(20)
            }.background(.black).navigationTitle("Notifications").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar).keyboardDone()
                .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("Close") { dismiss() } }; ToolbarItem(placement: .navigationBarTrailing) { Button("Mark all read") { Task { await store.perform("/notifications/read") } }.disabled(store.isBusy) } }
        }
    }
}
