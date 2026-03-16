import SwiftUI

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @Binding var isLoggedIn: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.blue)
                Text("ScholarSync")
                    .font(.largeTitle)
                    .bold()
                Text("Your scholarly reading queue")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 16) {
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)

                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textContentType(isSignUp ? .newPassword : .password)
            }
            .padding(.horizontal)

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if let success = successMessage {
                Text(success)
                    .foregroundColor(.green)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button(action: { Task { await authenticate() } }) {
                Group {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(isSignUp ? "Create Account" : "Sign In")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .padding(.horizontal)
            .disabled(isLoading || email.isEmpty || password.isEmpty)

            Button(action: {
                isSignUp.toggle()
                errorMessage = nil
                successMessage = nil
            }) {
                Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }

            Spacer()
        }
    }

    func authenticate() async {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        do {
            if isSignUp {
                let response = try await SupabaseManager.shared.signUp(email: email, password: password)
                if response.access_token != nil {
                    isLoggedIn = true
                } else {
                    successMessage = "Account created! Check your email to confirm, then sign in."
                    isSignUp = false
                }
            } else {
                _ = try await SupabaseManager.shared.signIn(email: email, password: password)
                isLoggedIn = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
