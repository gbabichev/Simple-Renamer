//
//  MainView.swift
//  Simple Renamer
//
//  Created by George Babichev on 7/16/25.
//

// Main UI elements.

import SwiftUI
import UniformTypeIdentifiers

// MARK: - ContentView
// Main UI for batch file renaming app with sidebar for templates and detail pane for file previews

struct ContentView: View {
    
    // Track which template row is hovered for revealing row actions
    @State private var hoveredIdx: Int? = nil

    
    // Used to programmatically control focus on base name input
    @FocusState private var baseNameFieldFocused: Bool

    // Main ViewModel (must be injected in .environmentObject())
    @EnvironmentObject private var viewModel: BatchRenamerViewModel

    // Persist template list in user defaults (JSON-encoded)
    private static let defaultTemplates: [String] = ["Template", "Another Template"]
    @State private var templatesState: [String] = ContentView.defaultTemplates
    @AppStorage("templates") private var templatesData: Data = Data()

    // Which template is currently selected in the sidebar
    @State private var selectedTemplate: String?

    // Inline template editor state
    @State private var newTemplate: String = ""
    @FocusState private var addFieldFocused: Bool
    @State private var addError: String?

    // User-visible error messages
    @State private var importError: String?
    @State private var exportError: String?

    // Reset confirmation
    @State private var showResetConfirm = false
    

    // MARK: - Templates FileDocument (JSON) + Import/Export state
    struct TemplatesDocument: FileDocument {
        static var readableContentTypes: [UTType] { [.json] }
        static var writableContentTypes: [UTType] { [.json] }

        var templates: [String]

        init(templates: [String]) {
            self.templates = templates
        }

        init(configuration: ReadConfiguration) throws {
            guard let data = configuration.file.regularFileContents else {
                throw CocoaError(.fileReadCorruptFile)
            }
            self.templates = try JSONDecoder().decode([String].self, from: data)
        }

        func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
            let data = try JSONEncoder().encode(templates)
            return .init(regularFileWithContents: data)
        }
    }

    @State private var isImportingTemplates = false
    @State private var isExportingTemplates = false
    @State private var templatesDoc = TemplatesDocument(templates: [])

    
    
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

    // MARK: - Reset templates helper
    private func resetTemplatesToDefault() {
        withAnimation {
            templatesState = Self.defaultTemplates
            saveTemplates()
            // Clear selection and base name if they no longer exist
            if let sel = selectedTemplate, !Self.defaultTemplates.contains(sel) {
                selectedTemplate = nil
            }
            if !Self.defaultTemplates.contains(viewModel.inputField) {
                viewModel.inputField = ""
                viewModel.updateProposedNames()
            }
        }
    }
    
    private func nextAvailableTemplateName(base: String = "New Template") -> String {
        // Case-insensitive uniqueness
        let existing = Set(templatesState.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })

        // If "New Template" is free, use it
        if !existing.contains(base.lowercased()) { return base }

        // Otherwise find "New Template 2", "New Template 3", ...
        var i = 2
        while true {
            let candidate = "\(base) \(i)"
            if !existing.contains(candidate.lowercased()) {
                return candidate
            }
            i += 1
        }
    }


    var body: some View {
            NavigationSplitView {
                // MARK: - Sidebar
                VStack(spacing: 0) {
                    // List of templates
                    List(selection: $selectedTemplate) {
                        Section(
                            header:
                                HStack {
                                    Text("Templates")
                                        .font(.headline)
                                        .foregroundStyle(.secondary)
                                        .textCase(.uppercase)
                                    Spacer()
                                    Button {
                                        withAnimation {
                                            let new = nextAvailableTemplateName()
                                            templatesState.append(new)
                                            selectedTemplate = new
                                            viewModel.inputField = new
                                            viewModel.updateProposedNames()
                                        }
                                    } label: {
                                        Image(systemName: "plus")
                                            .imageScale(.medium)
                                            .padding(.trailing, 6)
                                    }
                                    .buttonStyle(.borderless)
                                    .help("Add template")
                                }
                                .padding(.bottom, 10)
                                .font(.headline)
                                .textCase(nil)
                        ) {
                            ForEach(templatesState.indices, id: \.self) { idx in
                                HStack {
                                    Image(systemName: "doc.text")
                                        .imageScale(.medium)
                                        .foregroundStyle(.secondary)
                                    TextField("Template", text: $templatesState[idx])
                                        .textFieldStyle(.plain)
                                        .onSubmit {
                                            // Trim whitespace on submit
                                            templatesState[idx] = templatesState[idx]
                                                .trimmingCharacters(in: .whitespacesAndNewlines)
                                        }
                                    if hoveredIdx == idx {
                                                Button {
                                                    withAnimation {
                                                        let removedValue = templatesState[idx]
                                                        templatesState.remove(at: idx)
                                                        if selectedTemplate == removedValue { selectedTemplate = nil }
                                                        if viewModel.inputField == removedValue {
                                                            viewModel.inputField = ""
                                                            viewModel.updateProposedNames()
                                                        }
                                                    }
                                                } label: {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .imageScale(.small)
                                                        .foregroundStyle(.tertiary)
                                                        .accessibilityLabel("Delete template")
                                                }
                                                .buttonStyle(.borderless)
                                            }
                                }
                                .padding(.vertical, 1)
                                .onHover { inside in
                                    hoveredIdx = inside ? idx : (hoveredIdx == idx ? nil : hoveredIdx)
                                }
                                .tag(templatesState[idx])
                                
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
                    
                    TextField("Add New Template", text: $newTemplate)
                        .focused($addFieldFocused)
                        // internal padding
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .textFieldStyle(.plain)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        // draw the pill background first, so strokes sit outside
                        .background(.regularMaterial, in: Capsule())
                        // focus ring (suppressed if there's an error)
                        .overlay(
                            Capsule()
                                .stroke((addError == nil && addFieldFocused) ? Color.accentColor.opacity(0.9) : .clear,
                                        lineWidth: (addError == nil && addFieldFocused) ? 3 : 0)
                        )
                        // error ring on top so it is visible immediately
                        .overlay(
                            Capsule()
                                .stroke(addError != nil ? Color.red : .clear,
                                        lineWidth: addError != nil ? 2 : 0)
                        )
                        .animation(.snappy(duration: 0.18), value: addFieldFocused)
                        // outer spacing relative to neighbors
                        .padding(20)
                        // On enter, add if not duplicate or empty
                        .onSubmit {
                            let trimmed = newTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            if templatesState.contains(trimmed) {
                                addError = "Duplicate Entry"
                            } else {
                                withAnimation {
                                    templatesState.append(trimmed)
                                }
                                newTemplate = ""
                                addError = nil
                                addFieldFocused = false
                            }
                        }
                        // Validate duplicates live while typing
                        .onChange(of: newTemplate) { _, value in
                            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { addError = nil; return }
                            let exists = templatesState.contains { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == trimmed.lowercased() }
                            addError = exists ? "Duplicate Entry" : nil
                        }

                }
                .frame(minWidth: 200)
                
            } detail: {
            // MARK: - Detail View (Main Rename Interface)
            ZStack {
                VStack(alignment: .leading, spacing: 15) {
                    // Main text field for inputting base name for renaming
                    HStack {
                        Image(systemName: "square.and.pencil")   // pick your SF Symbol
                            .foregroundStyle(.secondary)

                        TextField("Base Name", text: $viewModel.inputField)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .controlSize(.large)
                            .focused($baseNameFieldFocused)
                            .onChange(of: viewModel.inputField) {
                                viewModel.updateProposedNames()
                            }
                    }
                    .padding(.horizontal, 12)   // internal padding for text+icon
                    .padding(.vertical, 6)
                    .textFieldStyle(.plain)     // avoid the AppKit bezel
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial, in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(baseNameFieldFocused ? Color.accentColor.opacity(0.9) : .clear,
                                    lineWidth: baseNameFieldFocused ? 3 : 0)
                    )
                    .animation(.snappy(duration: 0.18), value: baseNameFieldFocused)
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
                    HStack {
                        
                        Toggle("", isOn: $viewModel.processContents)
                            .toggleStyle(.switch)
                        
                        Text("Process contents inside of subfolders. ")
                    }


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
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                    )
                    // Clip file table to match rounded rectangle background
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        if viewModel.files.isEmpty {
                            ContentUnavailableView("No files",
                                                   systemImage: "magnifyingglass",
                                                   description: Text("Drop a folder or add files to begin."))
                                .transition(.opacity)
                        }
                    }
                }
                .padding(15)
                .frame(minWidth: 500, minHeight: 400)

                
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

                // MARK: - Success Notification
                if viewModel.showSuccessNotification {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                        Text("Rename Complete")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.ultraThickMaterial)
                            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    )
                    .opacity(viewModel.successNotificationOpacity)
                    .scaleEffect(viewModel.successNotificationOpacity * 0.2 + 0.8)
                    .animation(.easeInOut(duration: 0.5), value: viewModel.successNotificationOpacity)
                }
            }
        }
        // MARK: - Toolbar
        .toolbar {
            // Left side - Open and Clear with labels
            ToolbarItem(placement: .navigation) {
                Button(action: viewModel.selectFolder) {
                    Label("Open", systemImage: "folder")
                }
                .help("Open Folder")
            }
            ToolbarItem(placement: .navigation) {
                Button(action: {
                    viewModel.files.removeAll()
                    viewModel.parentFolder = nil
                    viewModel.itemType = .none
                }) {
                    Label("Clear", systemImage: "arrow.clockwise")
                }
                .help("Clear List")
            }
            
            // Center - Just a spacer
            ToolbarItem(placement: .principal) {
                Spacer()
            }
            
            // Templates Import/Export
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        isImportingTemplates = true
                    } label: {
                        Label("Import Templates", systemImage: "square.and.arrow.down")
                    }
                    Button {
                        templatesDoc = TemplatesDocument(templates: viewModel.normalizeTemplates(templatesState))
                        isExportingTemplates = true
                    } label: {
                        Label("Export Templates", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        do {
                            let leafTemplates = try viewModel.templatesFromSubfolders()
                            // Merge, normalize, then sort Finder-style (human alphabetical)
                            let merged = viewModel.normalizeTemplates(templatesState + leafTemplates)
                                .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
                            templatesState = merged
                        } catch {
                            exportError = error.localizedDescription
                        }
                    } label: {
                        Label("Append Templates from Subfolders", systemImage: "list.bullet")
                    }
                    .disabled(viewModel.parentFolder == nil)
                    Divider()
                    Button {
                        showResetConfirm = true
                    } label: {
                        Label("Reset Templates", systemImage: "arrow.counterclockwise")
                    }
                } label: {
                    Label("Templates", systemImage: "tray.full")
                }
                .help("Import/Export Templates JSON")
            }
            
            // Right side - Process and Undo
            ToolbarItem(placement: .primaryAction) {
                Button(action: { viewModel.undoLastRename() }) {
                    Label("Undo", systemImage: "arrow.uturn.left")
                }
                .help("Undo Last Rename")
                .disabled(!viewModel.canUndo)
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: viewModel.safeBatchRename) {
                    Label("Process", systemImage: "arrow.right")
                }
                .help("Process Rename")
                .disabled(viewModel.files.isEmpty)
            }
        }
        .onAppear {
            loadTemplates()
            baseNameFieldFocused = false
        }
        .onChange(of: templatesState) {
            saveTemplates()
        }
        // Re-evaluate folder contents when toggle changes
        .onChange(of: viewModel.processContents) { _, newValue in
            viewModel.selectFolderContentsBasedOnToggle(processContents: newValue)
        }
        // Templates: Import via SwiftUI fileImporter
        .fileImporter(
            isPresented: $isImportingTemplates,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                do {
                    let data = try Data(contentsOf: url)
                    let cleaned = try viewModel.decodeTemplatesJSON(data)
                    withAnimation {
                        templatesState = cleaned
                    }
                    saveTemplates()
                    if let sel = selectedTemplate, !cleaned.contains(sel) {
                        selectedTemplate = nil
                    }
                    if !cleaned.contains(viewModel.inputField) {
                        viewModel.inputField = ""
                        viewModel.updateProposedNames()
                    }
                } catch {
                    let friendly: String
                    if let decodeErr = error as? DecodingError {
                        friendly = "Invalid JSON. Expected a JSON array of strings. (\(decodeErr))"
                    } else {
                        friendly = error.localizedDescription
                    }
                    importError = friendly
                    print("Import failed: \(friendly)")
                }
            case .failure(let error):
                print("Import canceled/failed: \(error)")
            }
        }
        // Templates: Export via SwiftUI fileExporter
        .fileExporter(
            isPresented: $isExportingTemplates,
            document: templatesDoc,
            contentType: .json,
            defaultFilename: "Templates"
        ) { result in
            switch result {
            case .success:
                break
            case .failure(let error):
                print("Export failed: \(error)")
                exportError = error.localizedDescription
            }
        }
        // Alert for import errors
        .alert("Import Failed", isPresented: Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("OK", role: .cancel) { importError = nil }
        } message: {
            Text(importError ?? "Unknown error")
        }
        // Alert for export errors
        .alert("Export Failed", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("OK", role: .cancel) { exportError = nil }
        } message: {
            Text(exportError ?? "Unknown error")
        }
        // Confirm reset templates
        .modifier(ResetConfirmationModifier(showResetConfirm: $showResetConfirm, resetAction: resetTemplatesToDefault))

    }

    
    struct ResetConfirmationModifier: ViewModifier {
        @Binding var showResetConfirm: Bool
        let resetAction: () -> Void
        
        func body(content: Content) -> some View {
            content
                .confirmationDialog("Reset Templates?", isPresented: $showResetConfirm, titleVisibility: .visible) {
                    Button("Reset", role: .destructive, action: resetAction)
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("This will remove all current templates and restore the default set.")
                }
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
                        // Folder drop: use the exact same logic as the toolbar button
                        if realURL.hasDirectoryPath {
                            // Clear any selected template first
                            selectedTemplate = nil
                            
                            // Use the same logic as the toolbar button
                            viewModel.setFolderFromDrop(url: realURL)
                            
                            // Focus the input field (same as clicking Open Folder)
                            baseNameFieldFocused = true
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
