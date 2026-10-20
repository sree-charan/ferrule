// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Sree Charan

import Foundation

/// Convert's decisions without running Recast: where its command is found, how
/// its replies read, which formats a set of files shares and what a
/// conversion passes. Nothing here starts a process.
enum FileConvertTests {
    static func run(_ suite: TestSuite) {
        locating(suite)
        replies(suite)
        targets(suite)
        ordering(suite)
        arguments(suite)
        strings(suite)
    }

    private static func locating(_ suite: TestSuite) {
        let home = "/Users/test"
        let resources = "/Applications/Ferrule.app/Contents/Resources"
        suite.expect(RecastSupport.candidatePaths(home: home, resources: resources) == [
            "/Applications/Ferrule.app/Contents/Resources/Recast/recast-cli",
            "/Users/test/.local/bin/recast",
            "/Users/test/Applications/Recast.app/Contents/MacOS/recast-cli",
            "/Applications/Recast.app/Contents/MacOS/recast-cli",
        ], "the converter embedded in the app comes first, a separate Recast only after")
        suite.expect(RecastSupport.locate(home: home, resources: resources, isExecutable: { _ in true })?.path
                        == "/Applications/Ferrule.app/Contents/Resources/Recast/recast-cli",
                     "the embedded converter wins over any separate install")
        suite.expect(RecastSupport.locate(home: home, resources: resources, isExecutable: { _ in false }) == nil,
                     "no runnable converter means Convert has none")
        let shared = RecastSupport.locate(home: home, resources: resources,
                                          isExecutable: { $0.hasPrefix("/Applications/Recast.app") })
        suite.expect(shared?.path == "/Applications/Recast.app/Contents/MacOS/recast-cli",
                     "a build without the embedded converter still finds a separate Recast")
        suite.expect(RecastSupport.dataDirectory(applicationSupport: URL(fileURLWithPath: "/Users/test/Library/Application Support"),
                                                 bundleIdentifier: "com.sreecharan.ferrule").path
                        == "/Users/test/Library/Application Support/com.sreecharan.ferrule/Recast",
                     "the converter's data lives inside the app's own data folder")
    }

    private static func replies(_ suite: TestSuite) {
        let formats = Data("""
            {"from": "png", "name": "PNG", "targets": [
              {"id": "jpg", "name": "JPG", "category": "image", "extension": "jpg"},
              {"id": "pdf", "name": "PDF", "category": "document", "extension": "pdf"}],
             "withOptionalEngines": ["svg"]}
            """.utf8)
        let decoded = RecastSupport.decodeFormats(formats)
        suite.expect(decoded?.from == "png" && decoded?.targets.map(\.id) == ["jpg", "pdf"]
                        && decoded?.withOptionalEngines == ["svg"],
                     "a formats reply lists its targets in Recast's order")
        suite.expect(RecastSupport.decodeFormats(Data("recast: unknown format".utf8)) == nil,
                     "an error message is not a formats reply")

        let convert = Data("""
            {"preset": "WEBP", "target": "webp", "converted": 1, "skipped": 0, "failed": 1, "files": [
              {"source": "/a.png", "state": "done", "outputs": ["/a.webp"]},
              {"source": "/b.png", "state": "failed", "outputs": [], "error": "conversion failed"}]}
            """.utf8)
        let result = RecastSupport.decodeConvert(convert)
        suite.expect(result?.converted == 1 && result?.failed == 1 && result?.outputs == ["/a.webp"]
                        && result?.files.last?.error == "conversion failed",
                     "a convert reply carries each file's outputs and errors")
    }

    private static func targets(_ suite: TestSuite) {
        func target(_ id: String, _ category: String = "image") -> RecastSupport.Target {
            RecastSupport.Target(id: id, name: id.uppercased(), category: category, extension: id)
        }
        let png = [target("jpg"), target("webp"), target("pdf", "document")]
        let heic = [target("pdf", "document"), target("jpg"), target("png")]
        suite.expect(RecastSupport.commonTargets([png, heic]).map(\.id) == ["jpg", "pdf"],
                     "files share only the formats every one of them converts to, in the first file's order")
        suite.expect(RecastSupport.commonTargets([png, []]).isEmpty,
                     "a file that converts to nothing leaves nothing in common")
        suite.expect(RecastSupport.commonTargets([]).isEmpty, "no files, no formats")
        let groups = RecastSupport.grouped(png)
        suite.expect(groups.map(\.category) == ["image", "document"]
                        && groups.first?.targets.map(\.id) == ["jpg", "webp"],
                     "formats group by category in the order the categories first appear")

        suite.expect(RecastSupport.formatKey(for: URL(fileURLWithPath: "/x/Photo.HEIC")) == "heic"
                        && RecastSupport.formatKey(for: URL(fileURLWithPath: "/x/README")) == nil,
                     "a file's format key is its lowercased extension, and none without one")

        let a = URL(fileURLWithPath: "/x/a.png")
        let b = URL(fileURLWithPath: "/x/b.png")
        let folder = URL(fileURLWithPath: "/x/folder")
        let added = RecastSupport.addingFiles([b, a, URL(fileURLWithPath: "/x/./a.png"), folder], to: [a],
                                              isDirectory: { $0 == folder })
        suite.expect(added == [a, b], "files are added once, in order, and folders are left out")
    }

    private static func ordering(_ suite: TestSuite) {
        func target(_ id: String, _ category: String) -> RecastSupport.Target {
            RecastSupport.Target(id: id, name: id.uppercased(), category: category, extension: id)
        }
        // Recast lists a PDF's 30 image targets before its documents.
        let pdfTargets = [target("png", "image"), target("jpg", "image"), target("docx", "document"),
                          target("odt", "document"), target("md", "text"), target("mp4", "video")]
        let preferred = RecastSupport.preferredCategories(forExtension: "pdf")
        suite.expect(preferred.first == "document", "a PDF most likely becomes another document")
        let ordered = RecastSupport.ordered(RecastSupport.grouped(pdfTargets), preferring: preferred)
        suite.expect(ordered.map(\.category) == ["document", "text", "image", "video"],
                     "a PDF's document formats come before its image ones, the rest keep Recast's order")
        suite.expect(ordered.first?.targets.first?.id == "docx", "DOCX is the first format a PDF offers")
        suite.expect(RecastSupport.preferredCategories(forExtension: "heic") == ["image"]
                        && RecastSupport.preferredCategories(forExtension: "wav") == ["audio"]
                        && RecastSupport.preferredCategories(forExtension: "mov").first == "video"
                        && RecastSupport.preferredCategories(forExtension: "nothing-known").isEmpty,
                     "photos point to images, sound to audio, video to video, and an unknown kind to nothing")
        suite.expect(RecastSupport.filtered(pdfTargets, query: " .DocX ").map(\.id) == ["docx"]
                        && RecastSupport.filtered(pdfTargets, query: "").count == pdfTargets.count,
                     "the filter matches ids case-insensitively, a leading dot allowed, and an empty one shows all")
    }

    private static func arguments(_ suite: TestSuite) {
        let files = [URL(fileURLWithPath: "/x/a b.png")]
        suite.expect(RecastSupport.convertArguments(files: files, target: "webp", outputFolder: nil)
                        == ["convert", "/x/a b.png", "--to", "webp", "--json"],
                     "without a folder Recast saves next to the original, and answers in JSON")
        suite.expect(RecastSupport.convertArguments(files: files, target: "webp",
                                                    outputFolder: URL(fileURLWithPath: "/out"))
                        == ["convert", "/x/a b.png", "--to", "webp", "--json", "--output", "/out"],
                     "a chosen folder is passed as Recast's output")
    }

    private static func strings(_ suite: TestSuite) {
        for language in AppLanguage.allCases {
            let text = FeatureStrings.convert(language)
            let values = Mirror(reflecting: text).children.compactMap { $0.value as? String }
            suite.expect(values.allSatisfy { !$0.isEmpty && !$0.contains("—") },
                         "Convert strings are complete and have no em dash (\(language.rawValue))")
            suite.expect(text.resultFormat.components(separatedBy: "%d").count == 3
                            && text.recastFoundFormat.contains("%@"),
                         "Convert formats keep their placeholders (\(language.rawValue))")
        }
    }
}
