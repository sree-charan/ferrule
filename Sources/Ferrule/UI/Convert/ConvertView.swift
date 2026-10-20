// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Sree Charan

import SwiftUI
import UniformTypeIdentifiers

/// The Convert window: files on the left of the decision, formats they share,
/// where the results go, and one button. Recast does the work.
struct ConvertView: View {
    @ObservedObject var model: ConvertModel
    @ObservedObject private var l10n = L10n.shared
    @State private var dropTargeted = false

    private var text: ConvertFeatureStrings { FeatureStrings.convert(l10n.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if model.recastPath == nil {
                recastMissing
            } else {
                filesArea
                if !model.files.isEmpty {
                    formatsArea
                    outputRow
                    footer
                }
            }
        }
        .padding(18)
        .frame(minWidth: 460, idealWidth: 520, minHeight: 360, alignment: .topLeading)
        .onDrop(of: [.fileURL], isTargeted: $dropTargeted, perform: handleDrop)
    }

    // MARK: Files

    private var filesArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            if model.files.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(dropTargeted ? Theme.accent : .secondary)
                    Text(text.dropPrompt).font(.headline)
                    Text(text.dropHint).font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 150)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(dropTargeted ? Theme.accent : Color.secondary.opacity(0.35),
                                      style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(model.files, id: \.self) { url in
                            fileRow(url)
                        }
                    }
                }
                .frame(maxHeight: 150)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(dropTargeted ? Theme.accent : Color.secondary.opacity(0.2), lineWidth: 1)
                )
            }
            HStack(spacing: 8) {
                Button(text.addFinderSelection) { model.addFinderSelection() }
                Button(text.chooseFiles) { model.chooseFiles() }
                Spacer()
                if !model.files.isEmpty {
                    Button(text.clear) { model.clear() }
                        .disabled(model.phase == .converting)
                }
            }
            .controlSize(.small)
        }
    }

    private func fileRow(_ url: URL) -> some View {
        HStack(spacing: 8) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .frame(width: 16, height: 16)
            Text(url.lastPathComponent)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 4)
            Button {
                model.remove(url)
            } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
            }
            .buttonStyle(.borderless)
            .help(text.removeFile)
            .accessibilityLabel(text.removeFile)
            .disabled(model.phase == .converting)
        }
        .font(.system(size: 12))
    }

    // MARK: Formats

    private var formatsArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionTitle(text.formatsTitle)
                Spacer()
                if !model.targets.isEmpty {
                    TextField(text.filterPlaceholder, text: $model.filter)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                        .frame(width: 150)
                }
            }
            if model.loadingTargets {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text(text.loadingFormats).font(.caption).foregroundStyle(.secondary)
                }
            } else if model.targets.isEmpty {
                Text(text.noCommonFormat).font(.caption).foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(model.visibleGroups, id: \.category) { group in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(group.category.uppercased())
                                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                                    .kerning(1)
                                    .foregroundStyle(.tertiary)
                                FlowRow(spacing: 6) {
                                    ForEach(group.targets) { target in
                                        formatChip(target)
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 260)
            }
        }
    }

    private func formatChip(_ target: RecastSupport.Target) -> some View {
        let selected = model.selectedTarget == target.id
        return Button {
            model.selectedTarget = target.id
        } label: {
            Text(target.name)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .foregroundStyle(selected ? Color.white : Color.primary)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(selected ? Theme.accent : Color.primary.opacity(0.07))
                )
        }
        .buttonStyle(.plain)
        .disabled(model.phase == .converting)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: Output and convert

    private var outputRow: some View {
        HStack(spacing: 8) {
            Text(text.outputLabel).font(.system(size: 12))
            Menu {
                Button(text.outputNextToOriginals) { model.outputFolder = nil }
                Button(text.outputChooseFolder) { model.chooseOutputFolder() }
            } label: {
                Text(model.outputFolder.map { FileManager.default.displayName(atPath: $0.path) }
                     ?? text.outputNextToOriginals)
            }
            .fixedSize()
            .disabled(model.phase == .converting)
            Spacer()
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            switch model.phase {
            case .converting:
                ProgressView().controlSize(.small)
                Text(text.converting).font(.caption).foregroundStyle(.secondary)
            case let .finished(reply):
                Image(systemName: reply.failed == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(reply.failed == 0 ? Color.green : PanelMetricColor.red(for: .dark))
                Text(String(format: text.resultFormat, reply.converted, reply.files.count))
                    .font(.caption)
                if let error = reply.files.first(where: { $0.error != nil })?.error {
                    Text(error).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                if !reply.outputs.isEmpty {
                    Button(text.reveal) { model.revealOutputs() }.controlSize(.small)
                }
            case let .failed(message):
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(PanelMetricColor.red(for: .dark))
                Text(message).font(.caption).foregroundStyle(.secondary).lineLimit(3)
            case .idle:
                EmptyView()
            }
            Spacer()
            if model.phase == .converting {
                Button(text.cancel) { model.cancel() }
            } else {
                Button(text.convertButton) { model.convert() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!model.canConvert)
            }
        }
    }

    private var recastMissing: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(text.recastMissingTitle, systemImage: "shippingbox")
                .font(.headline)
            Text(text.recastMissingMessage)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        let fileProviders = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard !fileProviders.isEmpty, model.phase != .converting else { return false }
        for provider in fileProviders {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                DispatchQueue.main.async { model.add([url]) }
            }
        }
        return true
    }
}

/// Lays chips out left to right, wrapping onto new lines.
private struct FlowRow: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: min(widest, width), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
