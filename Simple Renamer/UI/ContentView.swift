//
//  MainView.swift
//  Gerobe Renamer
//
//  Created by George Babichev on 7/16/25.
//

// Main UI elements.

import SwiftUI
import UniformTypeIdentifiers

// MARK: - ContentView
// Main UI for batch file renaming app with sidebar for templates and detail pane for file previews

struct ContentView: View {
    // Used to programmatically control focus on base name input
    @FocusState private var baseNameFieldFocused: Bool

    // Settings popover control
    @State private var showSettingsPopover = false

    // Controls NavigationSplitView sidebar behavior (hidden, visible, etc.)
    @State private var splitVisibility: NavigationSplitViewVisibility = .automatic

    // Main ViewModel (must be injected in .environmentObject())
    @EnvironmentObject private var viewModel: BatchRenamerViewModel

    // Persist template list in user defaults (JSON-encoded)
    @AppStorage("templates") private var templatesData: Data = Data()

    // List of templates shown in sidebar and popover
    @State private var templatesState: [String] = ["cars", "flowers", "office"]

    // Which template is currently selected in the sidebar
    @State private var selectedTemplate: String?

    // Loads template list from user defaults at launch
    private func loadTemplates() {
        if let loaded = try? JSONDecoder().decode([String].self, from: templatesData), !loaded.isEmpty {
            templatesState = loaded
        }
    }
    // Saves template list to user defaults when changed
    private func saveTemplates() {
        templatesData = (try? JSONEncoder().encode(templatesState)) ?? Data()
    }

    var body: some View {
        NavigationSplitView {
            // MARK: - Sidebar (Templates + Settings Popover)
            VStack(spacing: 0) {
                // List of templates
                List(selection: $selectedTemplate) {
                    ForEach(templatesState, id: \.self) { template in
                        HStack {
                            Image(systemName: "list.bullet")
                            Text(template)
                        }
                    }
                }
                .listStyle(.sidebar)
                .onChange(of: selectedTemplate) { _, newValue in
                    if let newValue {
                        // Selecting a template pre-fills the input and recalculates
                        viewModel.inputField = newValue
                        viewModel.updateProposedNames()
                    }
                }
                // Divider between template list and settings button
                Divider()
                Button {
                    showSettingsPopover = true
                } label: {
                    Label("Settings", systemImage: "gearshape")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .buttonStyle(.plain)
                // Settings popover for managing templates
                .popover(isPresented: $showSettingsPopover, arrowEdge: .top) {
                    SettingsPopoverView(templates: $templatesState)
                        .frame(width: 250, height: 320)
                }
                .padding(.bottom, 8)
                .padding(.horizontal, 8)
            }
            .frame(minWidth: 200)
        } detail: {
            // MARK: - Detail View (Main Rename Interface)
            ZStack {
                VStack(alignment: .leading, spacing: 15) {
                    // Main text field for inputting base name for renaming
                    TextField("Base Name", text: $viewModel.inputField)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .controlSize(.large)
                        .focused($baseNameFieldFocused)
                        .onChange(of: viewModel.inputField) {
                            viewModel.updateProposedNames()
                        }
                    // Show error message if validation fails
                    if let error = viewModel.error, !error.isEmpty {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.vertical, 2)
                    }
                    // Show parent folder path if available (shows "Base: /path/to/parent")
                    else if let parent = viewModel.parentFolder {
                        HStack {
                            Text("Base:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(parent.path)
                                .font(.caption)
                                .foregroundColor(.accentColor)
                        }
                    }
                    // Toggle for processing files inside subfolders (controls viewModel.processContents)
                    Toggle("Process files inside subfolders", isOn: $viewModel.processContents)
                    // Table showing original and proposed file names
                    Table(viewModel.files) {
                        // Show icon based on file or folder type
                        TableColumn("Type") { item in
                            Image(systemName: viewModel.itemType == .folders ? "folder.fill" : "doc.fill")
                                .foregroundColor(viewModel.itemType == .folders ? .accentColor : .gray)
                                .frame(width: 20)
                        }
                        .width(32)
                        if viewModel.processContents {
                            // Show parent folder if processing subfolder contents
                            TableColumn("Folder") { item in
                                Text(item.parentFolder?.lastPathComponent ?? "")
                                    .foregroundStyle(.secondary)
                                    .font(.callout)
                                    .frame(minWidth: 80, maxWidth: 180, alignment: .leading)
                                    .lineLimit(1)
                            }
                            .width(min: 80, ideal: 110, max: 180)
                        }
                        // Display original and proposed names for each item
                        TableColumn("Original Name") { item in
                            Text(item.url.lastPathComponent)
                                .font(.body)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .width(min: 150, ideal: 220, max: 400)
                        TableColumn("New Name") { item in
                            Text(item.newName)
                                .font(.callout)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .width(min: 120, ideal: 180, max: 400)
                    }
                    // MARK: - Drag-and-Drop Handling
                    .onDrop(of: [UTType.fileURL.identifier], isTargeted: nil) { providers in
                        handleDrop(providers: providers)
                    }
                    // Right-click menu for clearing the file list
                    .contextMenu {
                        Button("Clear List") {
                            viewModel.files.removeAll()
                            viewModel.parentFolder = nil
                            viewModel.itemType = .none
                        }
                    }
                    // Stylized background and border for file list area
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(.windowBackgroundColor))
                            .shadow(color: Color.black.opacity(0.07), radius: 8, y: 2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                    )
                    // Clip file table to match rounded rectangle background
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(15)
                .frame(minWidth: 400, maxWidth: .infinity, alignment: .leading)
                // MARK: - Renaming Progress Overlay
                if viewModel.renaming {
                    Color.black.opacity(0.15).ignoresSafeArea()
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(1.5)
                        Text("Renaming...")
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding(.top, 8)
                    }
                    .padding(40)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.75)))
                }
            }
        }
        // MARK: - Toolbar
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: viewModel.selectFolder) {
                    Image(systemName: "folder")
                }
                .help("Open Folder")
            }
            ToolbarItem(placement: .navigation) {
                Button(action: {
                    viewModel.files.removeAll()
                    viewModel.parentFolder = nil
                    viewModel.itemType = .none
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Clear List")
            }
            ToolbarItem(placement: .navigation) {
                Button(action: viewModel.safeBatchRename) {
                    Image(systemName: "arrow.right")
                }
            }
            ToolbarItem(placement: .navigation) {
                Button(action: { viewModel.undoLastRename() }) {
                    Image(systemName: "arrow.uturn.left")
                }
                .help("Undo Last Rename")
                .disabled(!viewModel.canUndo)
            }
            ToolbarItem(placement: .principal) {
                Text("Renamer")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
            }
        }
        // MARK: - Template Persistence
        .onAppear(perform: loadTemplates)
        .onChange(of: templatesState) {
            saveTemplates()
        }
        // Re-evaluate folder contents when toggle changes
        .onChange(of: viewModel.processContents) { _, newValue in
            viewModel.selectFolderContentsBasedOnToggle(processContents: newValue)
        }
    }

    // MARK: - Drag-and-Drop Logic (Helper)

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var didAccept = false

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (item, error) in
                    // Convert item (Data or String) to URL
                    let url: URL?
                    if let data = item as? Data {
                        url = NSURL(absoluteURLWithDataRepresentation: data, relativeTo: nil) as URL?
                    } else if let str = item as? String {
                        url = URL(string: str)
                    } else {
                        url = nil
                    }

                    guard let realURL = url else { return }
                    DispatchQueue.main.async {
                        // Folder drop: replace contents and parse
                        if realURL.hasDirectoryPath {
                            viewModel.parentFolder = realURL
                            viewModel.files.removeAll()
                            viewModel.selectFolderContentsBasedOnToggle(processContents: viewModel.processContents)
                        } else {
                            // File drop: add individual file to batch
                            if viewModel.parentFolder == nil {
                                viewModel.parentFolder = realURL.deletingLastPathComponent()
                            }
                            let item = FileItem(url: realURL, newName: "", parentFolder: realURL.deletingLastPathComponent())
                            viewModel.files.append(item)
                            viewModel.itemType = .files
                            viewModel.error = nil
                            viewModel.updateProposedNames()
                        }
                    }
                }
                didAccept = true
            }
        }
        return didAccept
    }
}
