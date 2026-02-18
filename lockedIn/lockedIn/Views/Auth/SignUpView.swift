import SwiftUI

struct SignUpView: View {
    @ObservedObject var viewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Create Account")
                        .font(AppFonts.title())
                        .foregroundColor(AppColors.gold)

                    // Clover accent
                    Text("☘")
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.goldMuted)

                    Text("Join the Notre Dame productivity community")
                        .font(AppFonts.body())
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)

                // Sign Up Form
                VStack(spacing: 16) {
                    TextField("Display Name", text: $viewModel.displayName)
                        .textFieldStyle(RoundedTextFieldStyle())
                        .textContentType(.name)
                        .autocapitalization(.words)

                    TextField("Email", text: $viewModel.email)
                        .textFieldStyle(RoundedTextFieldStyle())
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)

                    SecureField("Password", text: $viewModel.password)
                        .textFieldStyle(RoundedTextFieldStyle())
                        .textContentType(.newPassword)

                    SecureField("Confirm Password", text: $viewModel.confirmPassword)
                        .textFieldStyle(RoundedTextFieldStyle())
                        .textContentType(.newPassword)

                    // Password Requirements
                    VStack(alignment: .leading, spacing: 4) {
                        PasswordRequirementRow(
                            text: "At least 6 characters",
                            isMet: viewModel.password.count >= 6
                        )
                        PasswordRequirementRow(
                            text: "Passwords match",
                            isMet: viewModel.password == viewModel.confirmPassword && viewModel.password.isNotEmpty
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                }
                .padding(.horizontal)

                // Sign Up Button
                Button {
                    Task {
                        await viewModel.signUp()
                        if viewModel.isAuthenticated {
                            dismiss()
                        }
                    }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Create Account")
                    }
                }
                .primaryButtonStyle()
                .disabled(viewModel.isLoading || !viewModel.isSignUpFormValid)
                .padding(.horizontal)

                // Terms
                Text("By signing up, you agree to our Terms of Service and Privacy Policy")
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()
            }
            .padding(.bottom, 32)
        }
        .background(AppColors.background)
        .navigationTitle("Sign Up")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
    }
}

// MARK: - Password Requirement Row

struct PasswordRequirementRow: View {
    let text: String
    let isMet: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 14))
                .foregroundColor(isMet ? .green : .secondary)

            Text(text)
                .font(AppFonts.caption())
                .foregroundColor(isMet ? .primary : .secondary)
        }
    }
}

#Preview {
    NavigationStack {
        SignUpView(viewModel: AuthViewModel())
    }
}
