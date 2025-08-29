//
//  Simple_RenamerApp.swift
//  Simple Renamer
//
//  Created by George Babichev on 8/28/25.
//

import SwiftUI

@main
struct Simple_RenamerApp: App {
    
    @StateObject private var viewModel = BatchRenamerViewModel()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        
        // MARK: - Main Window
        
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 720) 
        
        // MARK: - About Window
        
        Window("About Simple Renamer", id: "AboutWindow") {
            AboutView()
                // Unusually small frame size for the About window
                .frame(width: 400, height: 400)
        }
        .windowResizability(.contentSize) // Makes window non-resizable and size == content
        .defaultSize(width: 400, height: 400)
        .windowStyle(.hiddenTitleBar)
        
        // MARK: - Menu Bar Commands
        .commands {
            SidebarCommands() // Enables native show/hide keyboard shortcuts for the sidebar.
            // Remove the default New Item commands
            CommandGroup(replacing: .newItem) {}

            // Add custom commands after the New Item section
            CommandGroup(after: .newItem) {
                // Button to open folder selection dialog, shortcut Cmd+O
                Button(action: {
                    viewModel.selectFolder()
                }) {
                    Label("Open…", systemImage: "folder")
                }
                .keyboardShortcut("o", modifiers: .command)

                // Button to start the batch renaming process, shortcut Cmd+P
                Button(action: {
                    viewModel.safeBatchRename()
                }) {
                    Label("Process", systemImage: "arrow.right")
                }
                .keyboardShortcut("p", modifiers: .command)
                
                // Button to clear the current file list and reset state, shortcut Cmd+L
                Button(action: {
                    viewModel.files.removeAll()
                    viewModel.parentFolder = nil
                    viewModel.itemType = .none
                }) {
                    Label("Clear List", systemImage: "arrow.uturn.left")
                }
                .keyboardShortcut("l", modifiers: .command)
                
            }

            // Replace the default About menu item with a custom About window opener
            CommandGroup(replacing: .appInfo) {
                Button(action: {
                    openWindow(id: "AboutWindow")
                }) {
                    Label("About Simple Renamer", systemImage: "info.circle")
                }
            }
            
            CommandGroup(replacing: .help) {
                Button {
                    if let url = URL(string: "https://github.com/gbabichev/Simple-Renamer") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label("Simple Renamer Help", systemImage: "questionmark.circle")
                }
                .keyboardShortcut("?", modifiers: [.command])
            }
            
        }
        
    }
    

}
