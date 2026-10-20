// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Sree Charan

import SwiftUI

/// Convert's page: whether Recast is there to do the work, and a way in.
struct ConvertSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @State private var recastPath = RecastService.shared.executable?.path

    private var text: ConvertFeatureStrings { FeatureStrings.convert(l10n.language) }

    var body: some View {
        Form {
            Section {
                if let recastPath {
                    Label(String(format: text.recastFoundFormat, recastPath), systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                } else {
                    Label(text.recastMissingTitle, systemImage: "exclamationmark.triangle.fill")
                    Text(text.recastMissingMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(text.settingsCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(text.openWindow) {
                    ConvertWindowController.shared.show()
                }
                .disabled(recastPath == nil)
            } header: {
                Text(text.title)
            }
        }
        .formStyle(.grouped)
        .onAppear { recastPath = RecastService.shared.executable?.path }
    }
}
