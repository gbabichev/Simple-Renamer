//
//  SettingsView.swift
//  Gerobe Renamer
//
//  Created by George Babichev on 7/16/25.
//

// UI for the settings popover.

import SwiftUI

// MARK: - SettingsPopoverView

/// UI for viewing, editing, and adding name templates in a popover.
struct SettingsPopoverView: View {
    // MARK: - Bindings & State
    
    /// List of template strings, bound to parent.
    @Binding var templates: [String]
    
    /// Holds the input value for a new template.
    @State private var newTemplate: String = ""
    
    /// Stores error message for invalid template input.
    @State private var addError: String? = nil
    
    /// Tracks whether the new template TextField is focused.
    @FocusState private var addFieldFocused: Bool

    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // MARK: - Editable Template List
            
            // Displays list of templates, each with editable text and remove button.
            List {
                ForEach(Array(templates.enumerated()), id: \.offset) { index, template in
                    HStack {
                        // Editable field for template. Updates template in array on change.
                        TextField("Template", text: Binding(
                            get: { templates[index] },
                            set: { newValue in
                                templates[index] = newValue
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                        
                        // Remove button
                        Button(action: {
                            if let idx = templates.firstIndex(of: template) {
                                _ = withAnimation {
                                    templates.remove(at: idx)
                                }
                            }
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove template")
                    }
                    .padding(.vertical, 2)
                }
                // Allows swipe-to-delete (mainly for iOS/iPadOS, harmless on Mac)
                .onDelete { indexSet in
                    templates.remove(atOffsets: indexSet)
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Divider()
            
            // MARK: - Add Template Field
            
            // Field for adding a new template
            TextField("Add New Template", text: $newTemplate)
                .textFieldStyle(.roundedBorder)
                .focused($addFieldFocused)
                // Red border for error state
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(addError != nil ? Color.red : Color.clear, lineWidth: 2)
                )
                // On enter, add if not duplicate or empty
                .onSubmit {
                    let trimmed = newTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    if templates.contains(trimmed) {
                        addError = "Duplicate Entry"
                    } else {
                        withAnimation {
                            templates.append(trimmed)
                        }
                        newTemplate = ""
                        addError = nil
                        addFieldFocused = false
                    }
                }
                // Clear error as user types
                .onChange(of: newTemplate) { _, _ in
                    addError = nil
                }

            // MARK: - Error Message
            
            // Display validation error, if present
            if let addError = addError {
                Text(addError)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.leading, 4)
            }

            Spacer() // Push content to the top
        }
        .padding()
        .frame(width: 250) // Fixed popover width
    }
}
