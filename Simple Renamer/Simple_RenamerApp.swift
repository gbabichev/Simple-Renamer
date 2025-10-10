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
    @State private var showTutorial = !UserDefaults.standard.bool(forKey: "hasSeenTutorial")

    var body: some Scene {
        
        // MARK: - Main Window

        WindowGroup(id: "MainWindow") {
            ContentView(showTutorial: $showTutorial)
                .environmentObject(viewModel)
                .frame(minWidth: 800, minHeight: 750)
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
                // Button to open a new window, shortcut Cmd+N
                Button(action: {
                    openWindow(id: "MainWindow")
                }) {
                    Label("New Window", systemImage: "plus.rectangle.on.rectangle")
                }
                .keyboardShortcut("n", modifiers: .command)

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
                .disabled(viewModel.files.isEmpty)

                // Button to clear the current file list and reset state, shortcut Cmd+L
                Button(action: {
                    viewModel.clearFolder()
                }) {
                    Label("Clear List", systemImage: "arrow.uturn.left")
                }
                .keyboardShortcut("l", modifiers: .command)
                .disabled(viewModel.files.isEmpty)
                
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
                    showTutorial = true
                } label: {
                    Label("Show Tutorial", systemImage: "lightbulb")
                }

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
