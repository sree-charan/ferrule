// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Sree Charan

import AppKit
import SwiftUI

/// What the Convert window shows: the files, the formats they share and the
/// state of a conversion. Recast's answers arrive off the main thread and are
/// applied here on it.
@MainActor
final class ConvertModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case converting
        case finished(RecastSupport.ConvertReply)
        case failed(String)
    }

    @Published private(set) var files: [URL] = []
    @Published private(set) var targets: [RecastSupport.Target] = []
    @Published private(set) var loadingTargets = false
    @Published var selectedTarget: String?
    @Published var filter = ""
    @Published var outputFolder: URL?
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var recastPath: String?

    private var targetsRequest = 0
    private var cancellation: RecastCancellation?

    init() {
        refreshRecast()
    }

    func refreshRecast() {
        recastPath = RecastService.shared.executable?.path
    }

    func add(_ urls: [URL]) {
        let merged = RecastSupport.addingFiles(urls, to: files)
        guard merged != files else { return }
        files = merged
        if case .finished = phase { phase = .idle }
        loadTargets()
    }

    func remove(_ url: URL) {
        files.removeAll { $0 == url }
        loadTargets()
    }

    func clear() {
        files = []
        targets = []
        selectedTarget = nil
        filter = ""
        phase = .idle
    }

    func addFinderSelection() {
        DispatchQueue.global(qos: .userInitiated).async {
            let urls = FinderBridge.selectionURLs()
            DispatchQueue.main.async { [weak self] in self?.add(urls) }
        }
    }

    private func loadTargets() {
        targetsRequest += 1
        let request = targetsRequest
        let fileKeys = files.map(RecastSupport.formatKey(for:))
        // A file without an extension can't be matched to a format, so it
        // leaves nothing in common.
        guard !files.isEmpty, !fileKeys.contains(nil) else {
            loadingTargets = false
            targets = []
            selectedTarget = nil
            return
        }
        let keys = fileKeys.compactMap { $0 }.reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
        loadingTargets = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var lists: [[RecastSupport.Target]] = []
            var missing = false
            for key in keys {
                switch RecastService.shared.targets(forFormat: key) {
                case let .success(targets): lists.append(targets)
                case .failure: missing = true
                }
            }
            let common = missing ? [] : RecastSupport.commonTargets(lists)
            DispatchQueue.main.async {
                guard let self, request == self.targetsRequest else { return }
                self.loadingTargets = false
                self.targets = common
                if let selected = self.selectedTarget, !common.contains(where: { $0.id == selected }) {
                    self.selectedTarget = nil
                }
                self.refreshRecast()
            }
        }
    }

    /// The formats on screen: matching the filter, grouped, with the kinds the
    /// files point to (documents for a PDF, images for a photo) first.
    var visibleGroups: [(category: String, targets: [RecastSupport.Target])] {
        let preferred = files.compactMap(RecastSupport.formatKey(for:))
            .flatMap(RecastSupport.preferredCategories(forExtension:))
            .reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
        return RecastSupport.ordered(RecastSupport.grouped(RecastSupport.filtered(targets, query: filter)),
                                     preferring: preferred)
    }

    var canConvert: Bool {
        !files.isEmpty && selectedTarget != nil && phase != .converting && recastPath != nil
    }

    func convert() {
        guard canConvert, let target = selectedTarget else { return }
        let files = files
        let folder = outputFolder
        let cancellation = RecastCancellation()
        self.cancellation = cancellation
        phase = .converting
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = RecastService.shared.convert(files: files, target: target, outputFolder: folder,
                                                       cancellation: cancellation)
            DispatchQueue.main.async {
                guard let self, self.cancellation === cancellation else { return }
                self.cancellation = nil
                if cancellation.isCancelled {
                    self.phase = .idle
                    return
                }
                switch result {
                case let .success(reply): self.phase = .finished(reply)
                case .failure(.notInstalled):
                    self.refreshRecast()
                    self.phase = .idle
                case let .failure(.failed(message)): self.phase = .failed(message)
                }
            }
        }
    }

    func cancel() {
        cancellation?.cancel()
    }

    func chooseFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK { add(panel.urls) }
    }

    func chooseOutputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK { outputFolder = panel.url }
    }

    func revealOutputs() {
        guard case let .finished(reply) = phase else { return }
        let urls = reply.outputs.map { URL(fileURLWithPath: $0) }
        guard !urls.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }
}

/// Owns the one Convert window. Opening it again brings it forward and adds
/// any files it was opened with.
@MainActor
final class ConvertWindowController: NSObject, NSWindowDelegate {
    static let shared = ConvertWindowController()

    private var window: NSWindow?
    private let model = ConvertModel()

    func show(adding urls: [URL] = []) {
        guard AppFeature.fileConvert.isAvailable else { return }
        model.refreshRecast()
        model.add(urls)
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        let host = NSHostingController(rootView: ConvertView(model: model))
        host.sizingOptions = .preferredContentSize
        let window = NSWindow(contentViewController: host)
        window.title = FeatureStrings.convert(L10n.shared.language).title
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.delegate = self
        window.center()
        self.window = window
        WindowActivationPolicy.retain()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    /// Opens the window with whatever Finder has selected, when Finder is in front.
    func showWithFinderSelection() {
        let finderInFront = NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.finder"
        show()
        if finderInFront { model.addFinderSelection() }
    }

    func close() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        guard (notification.object as? NSWindow) === window else { return }
        model.cancel()
        window = nil
        WindowActivationPolicy.release()
    }
}
