// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Sree Charan

import Foundation
import UniformTypeIdentifiers

/// Everything Convert decides about Recast without running it: where its command
/// lives, how its JSON replies read, which formats a set of files shares and
/// what to pass for a conversion. Recast does the converting; Ferrule only asks.
enum RecastSupport {
    /// Where Recast's converter is: inside this app, where build.sh embeds it.
    /// A separate Recast install is only used by a build made without it.
    static func candidatePaths(home: String, resources: String?) -> [String] {
        (resources.map { [$0 + "/Recast/recast-cli"] } ?? []) + [
            home + "/.local/bin/recast",
            home + "/Applications/Recast.app/Contents/MacOS/recast-cli",
            "/Applications/Recast.app/Contents/MacOS/recast-cli",
        ]
    }

    /// The first candidate that can be run, with a link resolved to its file.
    static func locate(home: String = NSHomeDirectory(),
                       resources: String? = Bundle.main.resourcePath,
                       isExecutable: (String) -> Bool = FileManager.default.isExecutableFile(atPath:)) -> URL? {
        for path in candidatePaths(home: home, resources: resources) where isExecutable(path) {
            return URL(fileURLWithPath: path).resolvingSymlinksInPath()
        }
        return nil
    }

    /// One format a file can become.
    struct Target: Decodable, Hashable, Identifiable {
        let id: String
        let name: String
        let category: String
        let `extension`: String
    }

    /// `recast formats <format> --json`.
    struct FormatsReply: Decodable {
        let from: String
        let name: String
        let targets: [Target]
        let withOptionalEngines: [String]
    }

    /// `recast convert … --json`.
    struct ConvertReply: Decodable, Equatable {
        struct File: Decodable, Equatable {
            let source: String
            let state: String
            let outputs: [String]
            let error: String?
            let notice: String?
        }

        let target: String
        let converted: Int
        let skipped: Int
        let failed: Int
        let files: [File]

        var outputs: [String] { files.flatMap(\.outputs) }
    }

    static func decodeFormats(_ data: Data) -> FormatsReply? {
        try? JSONDecoder().decode(FormatsReply.self, from: data)
    }

    static func decodeConvert(_ data: Data) -> ConvertReply? {
        try? JSONDecoder().decode(ConvertReply.self, from: data)
    }

    /// The lookup key for a file: its extension, lowercased. Recast knows a
    /// format by any of its extensions, so "jpeg" and "jpg" both answer.
    static func formatKey(for url: URL) -> String? {
        let ext = url.pathExtension.lowercased()
        return ext.isEmpty ? nil : ext
    }

    /// The targets every list shares, in the first list's order. One file that
    /// can't become a format keeps that format off the list for all of them.
    static func commonTargets(_ lists: [[Target]]) -> [Target] {
        guard let first = lists.first else { return [] }
        let shared = lists.dropFirst().reduce(Set(first.map(\.id))) { $0.intersection($1.map(\.id)) }
        return first.filter { shared.contains($0.id) }
    }

    /// Targets grouped by category, categories in the order they first appear.
    static func grouped(_ targets: [Target]) -> [(category: String, targets: [Target])] {
        var order: [String] = []
        var groups: [String: [Target]] = [:]
        for target in targets {
            if groups[target.category] == nil { order.append(target.category) }
            groups[target.category, default: []].append(target)
        }
        return order.map { ($0, groups[$0] ?? []) }
    }

    /// The target categories a file's own kind makes likely, most likely first:
    /// a PDF most likely becomes another document, a photo another image.
    static func preferredCategories(forExtension ext: String) -> [String] {
        guard let type = UTType(filenameExtension: ext) else { return [] }
        if type.conforms(to: .image) { return ["image"] }
        if type.conforms(to: .audio) { return ["audio"] }
        if type.conforms(to: .movie) || type.conforms(to: .audiovisualContent) { return ["video", "audio"] }
        if type.conforms(to: .presentation) { return ["presentation", "document"] }
        if type.conforms(to: .spreadsheet) { return ["spreadsheet", "document"] }
        if type.conforms(to: .pdf) || type.conforms(to: .compositeContent) || type.conforms(to: .text) {
            return ["document", "text", "presentation", "ebook"]
        }
        return []
    }

    /// Groups with the categories the files point to first, the rest after in
    /// Recast's order.
    static func ordered(_ groups: [(category: String, targets: [Target])],
                        preferring preferred: [String]) -> [(category: String, targets: [Target])] {
        let rank = { (category: String) in preferred.firstIndex(of: category) ?? preferred.count }
        return groups.enumerated()
            .sorted { (rank($0.element.category), $0.offset) < (rank($1.element.category), $1.offset) }
            .map(\.element)
    }

    /// Targets whose id, name or extension contains the query; all of them for
    /// an empty query.
    static func filtered(_ targets: [Target], query: String) -> [Target] {
        let needle = query.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()
        guard !needle.isEmpty else { return targets }
        return targets.filter {
            $0.id.lowercased().contains(needle) || $0.name.lowercased().contains(needle)
                || $0.extension.lowercased().contains(needle)
        }
    }

    /// Arguments for one conversion. Without a folder Recast saves next to
    /// each original; existing files are kept and the new one gets a number.
    static func convertArguments(files: [URL], target: String, outputFolder: URL?) -> [String] {
        var arguments = ["convert"] + files.map(\.path) + ["--to", target, "--json"]
        if let outputFolder {
            arguments += ["--output", outputFolder.path]
        }
        return arguments
    }

    /// Where the embedded converter keeps its settings, logs and downloaded
    /// engines: inside this app's own data folder, so uninstalling the app
    /// takes them along and nothing lands in a separate Recast folder.
    static func dataDirectory(applicationSupport: URL, bundleIdentifier: String) -> URL {
        applicationSupport
            .appendingPathComponent(bundleIdentifier, isDirectory: true)
            .appendingPathComponent("Recast", isDirectory: true)
    }

    /// Files once, in the order given, without folders or duplicates.
    static func addingFiles(_ urls: [URL], to existing: [URL],
                            isDirectory: (URL) -> Bool = { url in
                                (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
                            }) -> [URL] {
        var seen = Set(existing.map { $0.standardizedFileURL.path })
        var result = existing
        for url in urls where url.isFileURL && !isDirectory(url) {
            let path = url.standardizedFileURL.path
            if seen.insert(path).inserted { result.append(url.standardizedFileURL) }
        }
        return result
    }
}
