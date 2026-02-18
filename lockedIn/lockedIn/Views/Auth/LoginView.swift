import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel = AuthViewModel()
    @State private var showSignUp = false
    @State private var showForgotPassword = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Logo and Title
                    VStack(spacing: 16) {
                        Image(systemName: "lock.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(AppColors.gold)
                            .goldGlow(radius: 12, opacity: 0.4)

                        Text("lockedIn")
                            .font(AppFonts.title())
                            .foregroundColor(AppColors.gold)

                        // Clover accent
                        Text("☘")
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.goldMuted)

                        Text("Focus. Compete. Succeed.")
                            .font(AppFonts.body())
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.top, 40)

                    // Login Form
                    VStack(spacing: 16) {
                        TextField("Email", text: $viewModel.email)
                            .textFieldStyle(RoundedTextFieldStyle())
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)

                        SecureField("Password", text: $viewModel.password)
                            .textFieldStyle(RoundedTextFieldStyle())
                            .textContentType(.password)

                        Button {
                            showForgotPassword = true
                        } label: {
                            Text("Forgot Password?")
                                .font(AppFonts.caption())
                                .foregroundColor(AppColors.gold)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(.horizontal)

                    // Login Button
                    Button {
                        Task {
                            await viewModel.signIn()
                        }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Sign In")
                        }
                    }
                    .primaryButtonStyle()
                    .disabled(viewModel.isLoading || !viewModel.isSignInFormValid)
                    .padding(.horizontal)

                    // Sign Up Link
                    HStack {
                        Text("Don't have an account?")
                            .foregroundColor(AppColors.textSecondary)

                        Button("Sign Up") {
                            showSignUp = true
                        }
                        .foregroundColor(AppColors.gold)
                        .fontWeight(.semibold)
                    }
                    .font(AppFonts.body())
                }
                .padding(.bottom, 32)
            }
            .background(AppColors.background)
            .navigationDestination(isPresented: $showSignUp) {
                SignUpView(viewModel: viewModel)
            }
            .sheet(isPresented: $showForgotPassword) {
                ForgotPasswordView(viewModel: viewModel)
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "An error occurred")
            }
        }
    }
}

// MARK: - Forgot Password Sheet

struct ForgotPasswordView: View {
    @ObservedObject var viewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var emailSent = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Enter your email address and we'll send you a link to reset your password.")
                    .font(AppFonts.body())
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                TextField("Email", text: $viewModel.email)
                    .textFieldStyle(RoundedTextFieldStyle())
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding(.horizontal)

                Button {
                    Task {
                        await viewModel.resetPassword()
                        emailSent = true
                    }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Send Reset Link")
                    }
                }
                .primaryButtonStyle()
                .disabled(viewModel.isLoading || !viewModel.email.isValidEmail)
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 24)
            .navigationTitle("Reset Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Email Sent", isPresented: $emailSent) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Check your inbox for password reset instructions.")
            }
        }
    }
}

// MARK: - Custom Text Field Style

struct RoundedTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(AppColors.surface)
            .foregroundColor(AppColors.textPrimary)
            .cornerRadius(Constants.UI.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Constants.UI.cornerRadius)
                    .stroke(AppColors.border, lineWidth: 1)
            )
    }
}

#Preview {
    LoginView()
}
