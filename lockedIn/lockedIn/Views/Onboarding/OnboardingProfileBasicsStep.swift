import SwiftUI

struct OnboardingProfileBasicsStep: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var majorQuery = ""
    @State private var showMajorSuggestions = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tell us about yourself")
                .font(AppFonts.headline())
                .foregroundColor(AppColors.textPrimary)

            Text("Your profile is yours to shape. We prefill what we can, and you can edit everything here.")
                .font(AppFonts.caption())
                .foregroundColor(AppColors.textSecondary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Display Name")
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.textSecondary)

                TextField("Your name", text: $viewModel.displayName)
                    .textContentType(.name)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
                    .onboardingTextField()
                    .onChange(of: viewModel.displayName) { _, _ in
                        viewModel.syncValidationErrors()
                    }

                if let error = viewModel.displayNameError {
                    Text(error)
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.warning)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Major")
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.textSecondary)

                TextField("e.g. Computer Science", text: $viewModel.major)
                    .autocorrectionDisabled()
                    .onboardingTextField()
                    .onChange(of: viewModel.major) { _, newValue in
                        majorQuery = newValue
                        showMajorSuggestions = newValue.trimmed.isNotEmpty
                        viewModel.syncValidationErrors()
                    }

                if showMajorSuggestions {
                    let filtered = viewModel.filteredMajors(query: majorQuery)
                    if !filtered.isEmpty && filtered.count < viewModel.commonMajors.count {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(filtered.prefix(5), id: \.self) { suggestion in
                                    Button {
                                        viewModel.major = suggestion
                                        showMajorSuggestions = false
                                    } label: {
                                        Text(suggestion)
                                            .font(AppFonts.caption())
                                            .foregroundColor(AppColors.textSecondary)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(AppColors.surface)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                if let error = viewModel.majorError {
                    Text(error)
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.warning)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Academic Year")
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.textSecondary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(viewModel.yearOptions, id: \.self) { year in
                        let isSelected = viewModel.year == year
                        Button {
                            viewModel.year = year
                            viewModel.errorMessage = nil
                        } label: {
                            Text(shortYear(year))
                                .font(AppFonts.caption())
                                .foregroundColor(isSelected ? AppColors.background : AppColors.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(isSelected ? AppColors.gold : AppColors.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            OnboardingFeatureCard(
                icon: "person.crop.circle.badge.checkmark",
                title: "Own your profile",
                description: "Students will see your name, major, and class context when they discover your study stacks and tips."
            )
        }
        .focusCardStyle()
    }

    private func shortYear(_ year: String) -> String {
        switch year {
        case "Freshman": return "Fr"
        case "Sophomore": return "So"
        case "Junior": return "Jr"
        case "Senior": return "Sr"
        case "Graduate": return "Grad"
        default: return year
        }
    }
}

private extension View {
    func onboardingTextField() -> some View {
        self
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.surface.opacity(0.88))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.borderSubtle, lineWidth: 1)
            )
            .foregroundColor(AppColors.textPrimary)
    }
}

#Preview {
    OnboardingProfileBasicsStep(viewModel: OnboardingViewModel())
        .padding()
        .background(AppColors.background)
}
