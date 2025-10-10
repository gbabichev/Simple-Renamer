//
//  ViewModel.swift
//  Simple Renamer
//
//  Created by George Babichev on 8/28/25.
//

import SwiftUI
import Combine

// MARK: - Model

/// Represents a file or folder item for batch renaming.
struct FileItem: Identifiable {
    let id = UUID()
    /// The URL of the file or folder.
    let url: URL
    /// The proposed new name for the item.
    var newName: String
    /// The parent folder URL if the item is inside a subfolder, or nil otherwise.
    var parentFolder: URL?
}

// MARK: - Enum

/// The type of batch renaming: files, folders, or none.
enum BatchItemType {
    case files, folders, none
}

// MARK: - Main ViewModel

/// The main view model for managing batch renaming logic and UI state.
class BatchRenamerViewModel: ObservableObject {
    /// Struct to record rename operations for undo.
    struct RenameRecord {
        let originalURL: URL
        let newURL: URL
    }

    /// The list of file or folder items to be renamed.
    @Published var files: [FileItem] = []
    /// The user input for the base name and starting number.
    @Published var inputField: String = ""
    /// The currently selected parent folder.
    @Published var parentFolder: URL?
    /// Whether we're currently accessing a security-scoped resource.
    private var isAccessingSecurityScopedResource = false
    /// The error message to display, if any.
    @Published var error: String?
    /// Indicates whether a renaming operation is in progress.
    @Published var renaming: Bool = false
    /// Shows success notification after rename completes.
    @Published var showSuccessNotification: Bool = false
    /// Opacity for success notification fade animation.
    @Published var successNotificationOpacity: Double = 0.0
    /// The current batch item type (files, folders, or none).
    @Published var itemType: BatchItemType = .none
    /// Whether to process the contents of subfolders.
    @Published var processContents: Bool = false

    // MARK: - Undo Support

    /// The last batch of renames performed, for undo.
    private var lastRenameBatch: [RenameRecord] = []

    /// Whether an undo operation is available.
    var canUndo: Bool {
        !lastRenameBatch.isEmpty
    }

    /// Undo the last batch rename operation.
    func undoLastRename() {
        guard !lastRenameBatch.isEmpty else { return }
        let fm = FileManager.default
        var undoError: String?
        var didUndoAny = false
        // Move each file from newURL to originalURL, handling collisions.
        for record in lastRenameBatch {
            var targetURL = record.originalURL
            var suffix = 1
            // If the original file exists, add _undo# before extension.
            while fm.fileExists(atPath: targetURL.path) {
                let base = record.originalURL.deletingPathExtension().lastPathComponent
                let ext = record.originalURL.pathExtension
                let parent = record.originalURL.deletingLastPathComponent()
                let newBase = "\(base)_undo\(suffix)"
                let newName = ext.isEmpty ? newBase : "\(newBase).\(ext)"
                targetURL = parent.appendingPathComponent(newName)
                suffix += 1
            }
            do {
                try fm.moveItem(at: record.newURL, to: targetURL)
                didUndoAny = true
            } catch {
                undoError = "Failed to undo rename for \(record.newURL.lastPathComponent): \(error.localizedDescription)"
                // Continue and attempt to undo others.
            }
        }
        // Clear undo batch after attempting.
        lastRenameBatch.removeAll()
        // Refresh file list if any file was moved.
        if didUndoAny {
            selectFolderContentsBasedOnToggle(processContents: self.processContents)
        }
        // Show error if any.
        if let err = undoError {
            DispatchQueue.main.async {
                self.error = err
            }
        }
    }

    /// Opens an NSOpenPanel to allow the user to select a folder.
    func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Folder"

        if panel.runModal() == .OK, let url = panel.url {
            setCurrentFolder(url: url)
        }
    }

    func setFolderFromDrop(url: URL, createBookmark: Bool = true) {
        // Stop accessing previous security-scoped resource if needed
        if isAccessingSecurityScopedResource, let oldFolder = parentFolder {
            oldFolder.stopAccessingSecurityScopedResource()
            isAccessingSecurityScopedResource = false
        }

        #if APPSTORE
        // For sandboxed App Store builds, drag-and-drop doesn't provide security-scoped access
        // We need to prompt the user with NSOpenPanel to get proper access
        if createBookmark {
            // Open a panel to let the user grant access to the dropped folder
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            panel.allowsMultipleSelection = false
            panel.message = "Grant access to this folder for renaming"
            panel.prompt = "Grant Access"
            panel.directoryURL = url

            if panel.runModal() == .OK, let grantedURL = panel.url {
                // Now we have a proper security-scoped URL
                let didStart = grantedURL.startAccessingSecurityScopedResource()
                isAccessingSecurityScopedResource = didStart

                setCurrentFolder(url: grantedURL)
            } else {
                // User cancelled the access grant
                return
            }
        } else {
            setCurrentFolder(url: url)
        }
        #else
        // For direct distribution (non-sandboxed), drag-and-drop works directly
        if createBookmark {
            // Try to start accessing (will return false for non-security-scoped URLs, which is fine)
            isAccessingSecurityScopedResource = url.startAccessingSecurityScopedResource()
        }

        setCurrentFolder(url: url)
        #endif
    }
    
    /// Sets the current folder and populates its contents.
    /// - Parameter url: The URL of the selected folder.
    private func setCurrentFolder(url: URL) {
        parentFolder = url
        files.removeAll()
        selectFolderContentsBasedOnToggle(processContents: self.processContents)
    }

    /// Clears the current folder and releases security-scoped resources.
    func clearFolder() {
        // Stop accessing security-scoped resource if needed
        if isAccessingSecurityScopedResource, let folder = parentFolder {
            folder.stopAccessingSecurityScopedResource()
            isAccessingSecurityScopedResource = false
        }

        parentFolder = nil
        files.removeAll()
        itemType = .none
    }

    // MARK: - Content Population

    /// Populates the files/folders list based on the current folder and settings.
    /// - Parameter processContents: Whether to process files inside subfolders.
    /// Populates the files/folders list based on the current folder and settings.
    /// - Parameter processContents: Whether to process files inside subfolders.
    func selectFolderContentsBasedOnToggle(processContents: Bool) {
        guard let url = parentFolder else {
            return
        }

        // Try to access the folder - for drag-and-drop, this might not be needed
        let needsSecurityAccess = url.startAccessingSecurityScopedResource()
        defer {
            if needsSecurityAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            // List all visible files and folders in the selected directory
            let contents = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            
            // Sort and filter files and folders separately
            let fileURLs = contents
                .filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) ?? false }
                .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

            let folderURLs = contents
                .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false }
                .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }


            if !fileURLs.isEmpty && folderURLs.isEmpty {
                // Only files in the base folder
                files = fileURLs.map { fileURL in
                    FileItem(url: fileURL, newName: "", parentFolder: url)
                }
                itemType = .files
            } else if fileURLs.isEmpty && !folderURLs.isEmpty {
                // Only folders in the base folder
                if processContents {
                    // Flatten all files inside subfolders (with parentFolder marked)
                    var batchItems: [FileItem] = []
                    for folder in folderURLs {
                        let innerFiles = try FileManager.default.contentsOfDirectory(
                            at: folder,
                            includingPropertiesForKeys: [.isRegularFileKey],
                            options: [.skipsHiddenFiles]
                        ).filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) ?? false }
                        .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

                        for fileURL in innerFiles {
                            batchItems.append(FileItem(url: fileURL, newName: "", parentFolder: folder))
                        }
                    }
                    files = batchItems
                    itemType = .files // treat as files for renaming purposes
                } else {
                    // Standard: rename the folders themselves
                    files = folderURLs.map { folderURL in
                        FileItem(url: folderURL, newName: "", parentFolder: nil)
                    }
                    itemType = .folders
                }
            } else if fileURLs.isEmpty && folderURLs.isEmpty {
                // The folder is empty
                files = []
                itemType = .none
            } else {
                // Mixed content: both files and folders present (unsupported)
                files = []
                itemType = .none
                self.error = "Cannot batch rename: folder contains both files and folders."
                return
            }
            error = nil
            updateProposedNames()
        } catch {
            // Handle file system errors
            self.error = "Failed to list folder: \(error.localizedDescription)"
            itemType = .none
        }
    }
    // MARK: - Name Parsing

    /// Parses the input field for a base name and trailing number.
    /// - Parameter input: The input string (e.g., "Name01").
    /// - Returns: A tuple with base, starting number, and padding, or nil if no number found.
    func parseBaseNameAndNumber(_ input: String) -> (base: String, start: Int, pad: Int)? {
        guard let range = input.range(of: "\\d+$", options: .regularExpression) else { return nil }
        let base = String(input[..<range.lowerBound])
        let numberStr = String(input[range])
        return (base, Int(numberStr) ?? 1, numberStr.count)
    }

    // MARK: - Proposed Name Updates

    /// Updates the proposed new names for all items, based on the current input and settings.
    func updateProposedNames() {
        let parsed = parseBaseNameAndNumber(inputField)
        let base = parsed?.base ?? inputField
        let start = parsed?.start ?? 1
        let pad = parsed?.pad ?? 0
        let isFile = (itemType == .files)

        if processContents && isFile {
            // Renaming files inside subfolders: reset numbering per folder
            let grouped = Dictionary(grouping: files) { $0.parentFolder ?? URL(fileURLWithPath: "") }
            // Iterate folders in a stable, Finder-like order
            let foldersInOrder = grouped.keys.sorted {
                $0.path.localizedStandardCompare($1.path) == .orderedAscending
            }
            var newFileList: [FileItem] = []

            for folder in foldersInOrder {
                // Sort files within each folder in Finder-like order
                let items = (grouped[folder] ?? []).sorted {
                    $0.url.lastPathComponent.localizedStandardCompare($1.url.lastPathComponent) == .orderedAscending
                }
                for (idx, old) in items.enumerated() {
                    let n = start + idx
                    let ext = old.url.pathExtension
                    let newName = makeNewName(base: base, number: n, pad: pad, ext: ext, isFile: true)
                    newFileList.append(FileItem(url: old.url, newName: newName, parentFolder: folder))
                }
            }
            // Stable display order: parent folder (natural), then name (natural)
            files = newFileList.sorted(by: displayAscending)
        } else {
            // Regular batch renaming (files or folders)
            files = files.enumerated().map { idx, old in
                let n = start + idx
                let ext = isFile ? old.url.pathExtension : nil
                let newName = makeNewName(base: base, number: n, pad: pad, ext: ext, isFile: isFile)
                return FileItem(url: old.url, newName: newName, parentFolder: old.parentFolder)
            }
        }
    }

    // MARK: - Name Construction

    /// Constructs a new name for a file or folder.
    /// - Parameters:
    ///   - base: The base name.
    ///   - number: The number to append.
    ///   - pad: The number of digits for zero-padding.
    ///   - ext: The file extension, if any.
    ///   - isFile: Whether the item is a file.
    /// - Returns: The constructed name.
    nonisolated private func makeNewName(base: String, number: Int, pad: Int, ext: String?, isFile: Bool) -> String {
        let numString = pad > 0 ? String(format: "%0\(pad)d", number) : "\(number)"
        let name = "\(base)\(numString)"
        if isFile, let ext = ext, !ext.isEmpty {
            return "\(name).\(ext)"
        }
        return name
    }

    // MARK: - Batch Rename Operation

    /// Performs the batch rename operation, with error handling and UI updates.
    func safeBatchRename() {
        guard let parent = parentFolder else {
            DispatchQueue.main.async {
                self.error = "Please select a folder before renaming."
            }
            return
        }

        DispatchQueue.main.async {
            self.renaming = true
            self.error = nil
            self.lastRenameBatch.removeAll()
        }

        let filesToRename = self.files
        let renameType = self.itemType
        let input = self.inputField
        let processContents = self.processContents
        let alreadyAccessingResource = self.isAccessingSecurityScopedResource

        let parsed = parseBaseNameAndNumber(input)
        let base = parsed?.base ?? input
        let start = parsed?.start ?? 1
        let pad = parsed?.pad ?? 0
        let isFile = (renameType == .files)

        DispatchQueue.global(qos: .userInitiated).async {
            var tempURLs: [URL] = []
            let fm = FileManager.default

            var localFiles = filesToRename
            localFiles.sort(by: self.naturalAscending) // ensure numbering matches Finder-like display order
            var localError: String?
            // For undo: collect rename records.
            var renameRecords: [RenameRecord] = []

            // Request access to the parent folder for file operations
            // Only start accessing if we're not already accessing (to avoid nested calls)
            let needsAccess = !alreadyAccessingResource && parent.startAccessingSecurityScopedResource()
            let hasAccess = alreadyAccessingResource || needsAccess

            if hasAccess {
                defer {
                    // Only stop if we started it in this function
                    if needsAccess {
                        parent.stopAccessingSecurityScopedResource()
                    }
                }

                if processContents && isFile {
                    // Renaming files inside subfolders: handle each subfolder separately
                    let grouped = Dictionary(grouping: localFiles) { $0.parentFolder ?? URL(fileURLWithPath: "") }
                    var allTempURLs: [URL] = []
                    var allFinals: [FileItem] = []

                    for (folder, unsortedItems) in grouped {
                        // Use the same per-folder natural order as the preview
                        let items = unsortedItems.sorted {
                            $0.url.lastPathComponent.localizedStandardCompare($1.url.lastPathComponent) == .orderedAscending
                        }
                        var folderTempURLs: [URL] = []
                        // First: move all to temp names
                        for item in items {
                            // Generate a unique temporary name to avoid collisions
                            var tempName: String
                            var tempURL: URL
                            repeat {
                                tempName = UUID().uuidString
                                let ext = item.url.pathExtension
                                tempName += ext.isEmpty ? "" : ".\(ext)"
                                tempURL = item.url.deletingLastPathComponent().appendingPathComponent(tempName)
                            } while fm.fileExists(atPath: tempURL.path)

                            do {
                                try fm.moveItem(at: item.url, to: tempURL)
                                folderTempURLs.append(tempURL)
                            } catch {
                                // Abort on failure to move to temp
                                localError = "Error during temp rename of \(item.url.lastPathComponent): \(error.localizedDescription)"
                                break
                            }
                        }
                        if localError == nil {
                            // Second: move temp files to final names, record for undo
                            for (idx, tempURL) in folderTempURLs.enumerated() {
                                let n = start + idx
                                let ext = tempURL.pathExtension
                                let finalName = self.makeNewName(base: base, number: n, pad: pad, ext: ext, isFile: true)
                                let finalURL = tempURL.deletingLastPathComponent().appendingPathComponent(finalName)
                                do {
                                    try fm.moveItem(at: tempURL, to: finalURL)
                                    allFinals.append(FileItem(url: finalURL, newName: finalName, parentFolder: folder))
                                    // Record for undo
                                    renameRecords.append(RenameRecord(originalURL: items[idx].url, newURL: finalURL))
                                } catch {
                                    // Abort on failure to finalize rename
                                    localError = "Error finalizing rename for \(finalName): \(error.localizedDescription)"
                                    break
                                }
                            }
                        }
                        allTempURLs.append(contentsOf: folderTempURLs)
                        if localError != nil { break }
                    }
                    // Update the file list with the new URLs and names
                    localFiles = allFinals.sorted(by: self.displayAscending)
                } else {
                    // Standard batch renaming (files or folders)
                    for item in localFiles {
                        // Generate a unique temporary name to avoid collisions
                        var tempName: String
                        var tempURL: URL
                        repeat {
                            tempName = UUID().uuidString
                            if isFile {
                                let ext = item.url.pathExtension
                                tempName += ext.isEmpty ? "" : ".\(ext)"
                            }
                            tempURL = item.url.deletingLastPathComponent().appendingPathComponent(tempName)
                        } while fm.fileExists(atPath: tempURL.path)

                        do {
                            try fm.moveItem(at: item.url, to: tempURL)
                            tempURLs.append(tempURL)
                        } catch {
                            // Abort on failure to move to temp
                            localError = "Error during temp rename of \(item.url.lastPathComponent): \(error.localizedDescription)"
                            break
                        }
                    }

                    if localError == nil {
                        for (idx, tempURL) in tempURLs.enumerated() {
                            let n = start + idx
                            let ext = isFile ? tempURL.pathExtension : nil
                            let finalName = self.makeNewName(base: base, number: n, pad: pad, ext: ext, isFile: isFile)
                            let finalURL = tempURL.deletingLastPathComponent().appendingPathComponent(finalName)
                            do {
                                try fm.moveItem(at: tempURL, to: finalURL)
                                // Record for undo
                                renameRecords.append(RenameRecord(originalURL: localFiles[idx].url, newURL: finalURL))
                                localFiles[idx] = FileItem(url: finalURL, newName: finalName, parentFolder: localFiles[idx].parentFolder)
                            } catch {
                                // Abort on failure to finalize rename
                                localError = "Error finalizing rename for \(finalName): \(error.localizedDescription)"
                                break
                            }
                        }
                    }
                }
            } else {
                // Unable to access the folder due to sandbox or permissions
                localError = "Can't access folder (sandbox error)"
            }

            DispatchQueue.main.async {
                self.files = localFiles.sorted(by: self.displayAscending)
                self.renaming = false
                self.error = localError
                // Set up undo batch if successful and no error
                if localError == nil {
                    self.lastRenameBatch = renameRecords
                    // Show success notification with fade in
                    self.showSuccessNotification = true
                    self.successNotificationOpacity = 1.0
                    // Fade out after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        self.successNotificationOpacity = 0.0
                    }
                    // Remove from view after fade completes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                        self.showSuccessNotification = false
                    }
                }
            }
        }
    }
    
    // MARK: - Natural (Finder-like) sorting

    /// Compare two file items using Finder-like natural ordering on their names.
    nonisolated private func naturalAscending(_ lhs: FileItem, _ rhs: FileItem) -> Bool {
        lhs.url.lastPathComponent.localizedStandardCompare(
            rhs.url.lastPathComponent
        ) == .orderedAscending
    }

    /// Compare first by parent folder path (natural), then by file name (natural).
    nonisolated private func displayAscending(_ lhs: FileItem, _ rhs: FileItem) -> Bool {
        let lp = lhs.parentFolder?.path ?? ""
        let rp = rhs.parentFolder?.path ?? ""
        if lp != rp {
            return lp.localizedStandardCompare(rp) == .orderedAscending
        }
        return lhs.url.lastPathComponent.localizedStandardCompare(
            rhs.url.lastPathComponent
        ) == .orderedAscending
    }

    // MARK: - Templates JSON Utilities (UI-independent)
    /// Normalize a list of template strings: trim whitespace/newlines, drop empties, and de‑duplicate while preserving first-seen order.
    /// These are pure helpers so ContentView can keep SwiftUI's fileImporter/fileExporter
    /// but still reuse a single source of truth for how templates are serialized/validated.
    func normalizeTemplates(_ list: [String]) -> [String] {
        var seen = Set<String>()
        return list
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0).inserted }
    }

    /// Decode templates from JSON data. Expects a top-level JSON array of strings.
    func decodeTemplatesJSON(_ data: Data) throws -> [String] {
        let decoded = try JSONDecoder().decode([String].self, from: data)
        return normalizeTemplates(decoded)
    }

    // MARK: - Templates From Subfolders

    /// Returns template strings derived from the items currently shown in the table.
    /// Each template is the item's "Original Name" as displayed: for files this is the
    /// filename (including extension), and for folders this is the folder name.
    /// The result is normalized (trimmed, de-duplicated, original order preserved).
    /// - Throws: An error if no items are currently loaded.
    func templatesFromSubfolders() throws -> [String] {
        // Build templates directly from what's shown in the table: each item's original name.
        // For files, we use the filename including extension; for folders, the folder name.
        guard !files.isEmpty else {
            throw NSError(
                domain: "BatchRenamerViewModel",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "No items loaded. Select a folder first."]
            )
        }

        let rawTemplates: [String] = files.map { $0.url.lastPathComponent }
        return normalizeTemplates(rawTemplates)
    }
}
