import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showAddToolSheet = false
    @State private var newTool = ""

    var body: some View {
        NavigationStack {
            Form {
                // Profile Photo Section
                Section {
                    HStack {
                        Spacer()
                        
                        let selectedImage = viewModel.selectedImage
                        let photoURLString = viewModel.user?.photoURL

                        PhotosPicker(selection: $viewModel.selectedPhotoItem, matching: .images) {
                            if let image = selectedImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            } else if let photoURLString = photoURLString,
                                      let url = URL(string: photoURLString) {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .foregroundColor(.gray)
                                }
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .foregroundColor(.gray)
                                    .frame(width: 100, height: 100)
                            }
                        }
                        .onChange(of: viewModel.selectedPhotoItem) { _, _ in
                            Task { @MainActor in
                                await viewModel.loadPhoto()
                            }
                        }

                        Spacer()
                    }
                } header: {
                    Text("Profile Photo")
                } footer: {
                    Text("Tap to change your profile photo")
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                // Basic Info
                Section("Basic Info") {
                    TextField("Display Name", text: $viewModel.editDisplayName)

                    TextField("Major", text: $viewModel.editMajor)

                    Picker("Year", selection: $viewModel.editYear) {
                        Text("Select Year").tag("")
                        ForEach(viewModel.yearOptions, id: \.self) { year in
                            Text(year).tag(year)
                        }
                    }
                }

                // Spotify
                Section {
                    TextField("Spotify Playlist URL", text: $viewModel.editSpotifyURL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                } header: {
                    HStack {
                        Image(systemName: "music.note")
                            .foregroundColor(.green)
                        Text("Study Playlist")
                    }
                } footer: {
                    Text("Share your favorite study playlist with others")
                }

                // Study Tools
                Section {
                    // Common Tools
                    ForEach(viewModel.commonStudyTools, id: \.self) { tool in
                        Button {
                            viewModel.toggleStudyTool(tool)
                        } label: {
                            HStack {
                                Text(tool)
                                    .foregroundColor(.primary)
                                Spacer()
                                if viewModel.editStudyTools.contains(tool) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(AppColors.navyBlue)
                                }
                            }
                        }
                    }

                    // Custom Tools
                    ForEach(viewModel.editStudyTools.filter { !viewModel.commonStudyTools.contains($0) }, id: \.self) { tool in
                        HStack {
                            Text(tool)
                            Spacer()
                            Button {
                                viewModel.editStudyTools.removeAll { $0 == tool }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Button {
                        showAddToolSheet = true
                    } label: {
                        Label("Add Custom Tool", systemImage: "plus")
                    }
                } header: {
                    Text("Study Tools")
                } footer: {
                    Text("Select the tools you use for studying")
                }

                // Tips
                Section {
                    TextEditor(text: $viewModel.editTips)
                        .frame(minHeight: 100)
                } header: {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(AppColors.gold)
                        Text("Study Tips & Advice")
                    }
                } footer: {
                    Text("Share your best study tips with the community")
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await viewModel.saveProfile()
                            dismiss()
                        }
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(viewModel.isSaving || viewModel.editDisplayName.trimmed.isEmpty)
                }
            }
            .alert(isPresented: $showAddToolSheet) {
                Alert(
                    title: Text("Add Custom Tool"),
                    message: Text("Enter the name of your study tool"),
                    primaryButton: .default(Text("Add")) {
                        viewModel.addCustomTool(newTool)
                        newTool = ""
                    },
                    secondaryButton: .cancel {
                        newTool = ""
                    }
                )
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "An error occurred")
            }
        }
    }
}

#Preview {
    EditProfileView(viewModel: ProfileViewModel())
}
