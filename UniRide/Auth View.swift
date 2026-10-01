import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var store: AppStore
    @State private var creatingAccount = false
    @State private var name = ""
    @State private var university = "Université Hassan I"
    @State private var email = ""
    @State private var password = ""
    @State private var showingServer = false
    @FocusState private var passwordFocused: Bool
    var body: some View {
        NavigationStack {
        GeometryReader { geometry in
            ZStack {
                NetworkBackground()
                ScrollView {
                    VStack(spacing: 24) {
                        HStack {
                            Menu {
                                Button("English") { store.language = "en" }
                                Button("Français") { store.language = "fr" }
                                Button("العربية") { store.language = "ar" }
                            } label: { Label("Language", systemImage: "globe").font(.caption) }
                            Spacer()
                            Button { showingServer = true } label: { Image(systemName: "server.rack").frame(width: 44, height: 44) }.accessibilityLabel("Server settings")
                        }
                        VStack(spacing: 14) {
                            UniRideLogo(size: 90, glow: true)
                            Text("UniRide").font(.system(size: 34, weight: .bold))
                            Text("For Students By Students").font(.subheadline).foregroundStyle(.white.opacity(0.85))
                        }
                        VStack(spacing: 14) {
                            if creatingAccount {
                                Text("Create your account").font(.title3.bold())
                                TextField("Full name", text: $name).textContentType(.name).uniRideField()
                                TextField("University", text: $university).uniRideField()
                            }
                            TextField("Email", text: $email).keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never).autocorrectionDisabled().textContentType(.username)
                                .submitLabel(.next).onSubmit { passwordFocused = true }.uniRideField()
                            SecureField("Password (10+ characters)", text: $password)
                                .textContentType(creatingAccount ? .newPassword : .password).focused($passwordFocused)
                                .submitLabel(.go).onSubmit(submit).uniRideField()
                            Button(action: submit) {
                                HStack { if store.isBusy { ProgressView().tint(.black) }; Text(creatingAccount ? store.text("Create Account") : store.text("Sign In")) }
                            }.buttonStyle(LimeButtonStyle()).disabled(store.isBusy || !valid)
                            Button { withAnimation(.easeInOut(duration: 0.2)) { creatingAccount.toggle() } } label: {
                                Text(creatingAccount ? store.text("Already a student? Sign in") : store.text("New student? Create account"))
                                    .font(.caption).foregroundStyle(UniRideTheme.muted).frame(minHeight: 44)
                            }
                        }.padding(16).background(UniRideTheme.card.opacity(0.98), in: RoundedRectangle(cornerRadius: 28))
                        Button("Preview the app") { store.previewApp() }.font(.subheadline).frame(minHeight: 44)
                        Text("Preview data is separate from real accounts.").font(.caption).foregroundStyle(UniRideTheme.muted)
                        if store.restoring { ProgressView() }
                    }.frame(maxWidth: 420).padding(.horizontal, 24).padding(.vertical, 16)
                        .frame(maxWidth: .infinity).frame(minHeight: geometry.size.height, alignment: .top)
                }.scrollDismissesKeyboard(.interactively)
            }
        }.keyboardDone().toolbar(.hidden, for: .navigationBar)
        }.sheet(isPresented: $showingServer) { ServerSettingsView() }
    }
    private func submit() {
        guard valid && !store.isBusy else { return }
        passwordFocused = false
        Task { await store.authenticate(name: creatingAccount ? name : nil, email: email, password: password, university: university) }
    }
    private var valid: Bool { email.contains("@") && password.count >= 10 && (!creatingAccount || (!name.trimmingCharacters(in: .whitespaces).isEmpty && !university.isEmpty)) }
}
struct ServerSettingsView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var address = ""
    var body: some View {
        NavigationStack {
            Form {
                Section("Server address") {
                    TextField("https://api.example.com", text: $address).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Text("For development, use your Mac’s local address on the same Wi-Fi. Hosted servers must use HTTPS.").font(.caption).foregroundStyle(.secondary)
                }
                Button("Save") { store.setServer(address); dismiss() }.disabled(URL(string: address)?.host == nil)
            }.navigationTitle("Server settings").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar).keyboardDone()
                .toolbar { Button("Close") { dismiss() } }.onAppear { address = store.endpoint }
        }
    }
}
