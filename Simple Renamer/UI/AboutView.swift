//
//  AboutView.swift
//  Gerobe Renamer
//
//  Created by George Babichev on 7/21/25.
//

/*
 AboutView.swift provides the About screen for the Gerobe Renamer app.
 It displays app branding, version info, copyright, and a link to the author’s GitHub.
 This view is intended to inform users about the app and its creator.
*/

import SwiftUI

// MARK: - AboutView

/// A view presenting information about the app, including branding, version, copyright, and author link.
struct AboutView: View {
    var body: some View {
        // Main vertical stack arranging all elements with spacing
        VStack(spacing: 20) {
            // App logo or personal branding image.
            // Requires "gbabichev" asset in app resources.
            Image("gbabichev")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .shadow(radius: 10)

            // App name displayed prominently
            Text(Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "Name")
                .font(.title)
                .bold()
            // App version fetched dynamically from Info.plist; fallback to "1.0"
            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                .foregroundColor(.secondary)
            // Current year dynamically retrieved for copyright notice
            Text("© \(String(Calendar.current.component(.year, from: Date()))) George Babichev")
                .font(.footnote)
                .foregroundColor(.secondary)
            // Link to the author's GitHub profile for project reference
            Link("GitHub", destination: URL(string: "https://github.com/gbabichev/Simple-Renamer")!)
                .font(.footnote)
                .foregroundColor(.accentColor)
        }
        .padding(40)
    }
}
