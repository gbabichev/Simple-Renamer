/*

 TutorialView.swift
 Simple Renamer

 First-launch tutorial overlay showing how to use the app.

 George Babichev

 */

import SwiftUI

struct TutorialView: View {
    @Binding var isPresented: Bool
    @State private var dontShowAgain = UserDefaults.standard.bool(forKey: "hasSeenTutorial")

    var body: some View {
        ZStack {
            // Semi-transparent background overlay
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            // Tutorial content card
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 48))
                        .foregroundColor(.accentColor)

                    Text("Welcome to Simple Renamer")
                        .font(.title)
                        .bold()

                    Text("Batch rename files and folders with ease")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 32)
                .padding(.horizontal, 32)
                .padding(.bottom, 16)

                Divider()
                    .padding(.horizontal, 32)

                // Tutorial steps (scrollable)
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                    TutorialStep(
                        icon: "folder",
                        title: "1. Open a Folder",
                        description: "Click the folder icon or use \u{2318}O to select a folder containing files you want to rename."
                    )

                    TutorialStep(
                        icon: "doc.text",
                        title: "2. Choose a Template, or Enter Base Name"
                    ) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Select a template from the sidebar or create a new one. Or enter your desired new name into the main text field.")

                            Text("Automatic Numbering:")
                                .font(.subheadline)
                                .bold()
                                .padding(.top, 4)

                            Group {
                                Text("• Default: ").bold() + Text("1, 2, 3...")
                                Text("• Padded: ").bold() + Text("01 → 01, 02, 03...")
                                Text("• Double padded: ").bold() + Text("002 → 002, 003, 004...")
                                Text("• Custom start: ").bold() + Text("5 → 5, 6, 7...")
                            }
                            .font(.caption)
                        }
                    }

                    TutorialStep(
                        icon: "eye",
                        title: "3. Preview Changes",
                        description: "Review the 'Original Name' and 'New Name' columns to verify the renaming looks correct."
                    )

                    TutorialStep(
                        icon: "arrow.right",
                        title: "4. Process Rename",
                        description: "Click 'Process' or press \u{2318}P to rename all files. Use \u{2318}L to clear the list if needed."
                    )


                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 20)
                }

                Divider()
                    .padding(.horizontal, 32)

                // Footer with checkbox and dismiss button
                VStack(spacing: 12) {
                    Text("You can always re-open the tutorial from the Help Menu!")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Toggle("Don't show this again", isOn: $dontShowAgain)
                        .toggleStyle(.checkbox)

                    Button {
                        dismiss()
                    } label: {
                        Text("Get Started")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 24)
            }
            .frame(width: 600)
            .frame(maxHeight: 700)
            .background(Color(nsColor: .windowBackgroundColor))
            .cornerRadius(16)
            .shadow(radius: 20)
        }
    }

    private func dismiss() {
        UserDefaults.standard.set(dontShowAgain, forKey: "hasSeenTutorial")
        isPresented = false
    }
}

// MARK: - Tutorial Step Component

struct TutorialStep<Description: View>: View {
    let icon: String
    let title: String
    let description: Description

    init(icon: String, title: String, description: String) where Description == Text {
        self.icon = icon
        self.title = title
        self.description = Text(description)
    }

    init(icon: String, title: String, @ViewBuilder description: () -> Description) {
        self.icon = icon
        self.title = title
        self.description = description()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.accentColor)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                description
                    .font(.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    TutorialView(isPresented: .constant(true))
}
