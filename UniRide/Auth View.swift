import SwiftUI

struct AuthView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var selectedTab = 0
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    // Form fields
    @State private var email = ""
    @State private var password = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var studentId = ""
    @State private var phone = ""
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 16) {
                        Spacer(minLength: 60)
                        ZStack {
                            Circle().fill(Color.green).frame(width: 80, height: 80)
                            Image(systemName: "graduationcap.fill").font(.system(size: 32)).foregroundColor(.white)
                        }
                        VStack(spacing: 8) {
                            Text("UniRide").font(.largeTitle).fontWeight(.bold).foregroundColor(.primary)
                            Text("Student ride sharing made simple").font(.subheadline).foregroundColor(.secondary)
                        }
                        Spacer(minLength: 40)
                    }
                    .frame(minHeight: geometry.size.height * 0.4)
                    
                    // Form Card
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            Button("Login") { withAnimation { selectedTab = 0 } }
                                .foregroundColor(selectedTab == 0 ? .primary : .secondary)
                                .fontWeight(selectedTab == 0 ? .semibold : .regular)
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(selectedTab == 0 ? Color(.systemBackground) : Color.clear)
                                .cornerRadius(8)
                            
                            Button("Sign Up") { withAnimation { selectedTab = 1 } }
                                .foregroundColor(selectedTab == 1 ? .primary : .secondary)
                                .fontWeight(selectedTab == 1 ? .semibold : .regular)
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(selectedTab == 1 ? Color(.systemBackground) : Color.clear)
                                .cornerRadius(8)
                        }
                        .padding(4).background(Color(.systemGray6)).cornerRadius(10).padding(.bottom, 24)
                        
                        if selectedTab == 0 { LoginForm() } else { SignUpForm() }
                    }
                    .padding(24)
                    .background(Color(.systemBackground))
                    .cornerRadius(16, corners: [.topLeft, .topRight])
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
                }
            }
            .ignoresSafeArea(.all, edges: .bottom)
        }
        .background(LinearGradient(gradient: Gradient(colors: [Color.green.opacity(0.1), Color.blue.opacity(0.1)]), startPoint: .topLeading, endPoint: .bottomTrailing))
        .alert("Error", isPresented: $showError) { Button("OK") { } } message: { Text(errorMessage) }
    }
    
    @ViewBuilder
    private func LoginForm() -> some View {
        VStack(spacing: 20) {
            TextField("University Email", text: $email)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
            
            SecureField("Password", text: $password)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
            
            Button(action: handleSignIn) {
                HStack {
                    if isLoading { ProgressView().padding(.trailing, 5) }
                    Text("Sign In")
                }
                .frame(maxWidth: .infinity).padding().background(Color.green).foregroundColor(.white).cornerRadius(10)
            }
        }
    }
    
    @ViewBuilder
    private func SignUpForm() -> some View {
        VStack(spacing: 16) {
            HStack {
                TextField("First Name", text: $firstName)
                TextField("Last Name", text: $lastName)
            }
            TextField("Email", text: $email).keyboardType(.emailAddress).autocapitalization(.none)
            TextField("Student ID", text: $studentId)
            TextField("Phone", text: $phone).keyboardType(.phonePad)
            SecureField("Password", text: $password)
            
            Button(action: handleSignUp) {
                HStack {
                    if isLoading { ProgressView().padding(.trailing, 5) }
                    Text("Create Account")
                }
                .frame(maxWidth: .infinity).padding().background(Color.green).foregroundColor(.white).cornerRadius(10)
            }
        }
        .textFieldStyle(RoundedBorderTextFieldStyle())
    }
    
    private func handleSignIn() {
        isLoading = true
        Task {
            let success = await authManager.signIn(email: email, password: password)
            await MainActor.run {
                isLoading = false
                if !success { errorMessage = "Invalid credentials"; showError = true }
            }
        }
    }
    
    private func handleSignUp() {
        isLoading = true
        Task {
            let success = await authManager.signUp(firstName: firstName, lastName: lastName, email: email, studentId: studentId, phone: phone, password: password)
            await MainActor.run {
                isLoading = false
                if !success { errorMessage = "Registration failed"; showError = true }
            }
        }
    }
}
