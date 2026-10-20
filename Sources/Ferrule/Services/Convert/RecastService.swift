// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Sree Charan

import Foundation

/// Runs Recast's command. Every call starts the command, waits for its JSON and
/// returns it; nothing stays running, and Recast itself never goes online for
/// a conversion. Calls are made off the main thread.
final class RecastService {
    static let shared = RecastService()

    enum Failure: Error, Equatable {
        case notInstalled
        case failed(String)
    }

    private let lock = NSLock()
    private var formatsCache: [String: [RecastSupport.Target]] = [:]

    var executable: URL? { RecastSupport.locate() }

    /// What a format converts to with the engines installed now. Answers are
    /// kept for the session: the list changes only when Recast does.
    func targets(forFormat key: String) -> Result<[RecastSupport.Target], Failure> {
        if let cached = lock.withLock({ formatsCache[key] }) { return .success(cached) }
        switch run(["formats", key, "--json"], timeout: 30) {
        case let .failure(failure):
            return .failure(failure)
        case let .success(output):
            // An unknown format exits with an error; it simply converts to nothing.
            let targets = output.status == 0 ? RecastSupport.decodeFormats(output.data)?.targets ?? [] : []
            lock.withLock { formatsCache[key] = targets }
            return .success(targets)
        }
    }

    /// Converts the files and reports each one. Exit code 1 (some failed) still
    /// carries a full reply; only a missing reply is a failure of the run.
    func convert(files: [URL], target: String, outputFolder: URL?,
                 cancellation: RecastCancellation) -> Result<RecastSupport.ConvertReply, Failure> {
        let arguments = RecastSupport.convertArguments(files: files, target: target, outputFolder: outputFolder)
        switch run(arguments, timeout: nil, cancellation: cancellation) {
        case let .failure(failure):
            return .failure(failure)
        case let .success(output):
            if let reply = RecastSupport.decodeConvert(output.data) { return .success(reply) }
            let message = String(data: output.errors, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return .failure(.failed(message.isEmpty ? "recast exited with status \(output.status)" : message))
        }
    }

    private struct Output {
        let status: Int32
        let data: Data
        let errors: Data
    }

    private func run(_ arguments: [String], timeout: TimeInterval?,
                     cancellation: RecastCancellation? = nil) -> Result<Output, Failure> {
        guard let executable else { return .failure(.notInstalled) }
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        // A launchd-started app has a bare PATH; Recast looks for the engines
        // it uses (FFmpeg, Pandoc, Ghostscript) on the usual install paths.
        var environment = ProcessInfo.processInfo.environment
        let path = environment["PATH"] ?? "/usr/bin:/bin"
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + path
        environment["DOTNET_CLI_TELEMETRY_OPTOUT"] = "1"
        if let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let data = RecastSupport.dataDirectory(applicationSupport: support,
                                                   bundleIdentifier: Bundle.main.bundleIdentifier ?? "com.sreecharan.ferrule")
            try? FileManager.default.createDirectory(at: data, withIntermediateDirectories: true)
            environment["RECAST_DATA_DIR"] = data.path
        }
        process.environment = environment
        process.currentDirectoryURL = FileManager.default.temporaryDirectory
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        process.standardInput = FileHandle.nullDevice

        var data = Data()
        var errors = Data()
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global(qos: .utility).async {
            data = stdout.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        group.enter()
        DispatchQueue.global(qos: .utility).async {
            errors = stderr.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        do {
            try process.run()
        } catch {
            return .failure(.failed(error.localizedDescription))
        }
        cancellation?.attach(process)
        if let timeout {
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { [weak process] in
                if process?.isRunning == true { process?.terminate() }
            }
        }
        process.waitUntilExit()
        group.wait()
        cancellation?.detach()
        return .success(Output(status: process.terminationStatus, data: data, errors: errors))
    }
}

/// Lets the window stop a conversion that is running.
final class RecastCancellation {
    private let lock = NSLock()
    private var process: Process?
    private var cancelled = false

    var isCancelled: Bool { lock.withLock { cancelled } }

    fileprivate func attach(_ process: Process) {
        let stopNow = lock.withLock { () -> Bool in
            self.process = process
            return cancelled
        }
        if stopNow { process.terminate() }
    }

    fileprivate func detach() {
        lock.withLock { process = nil }
    }

    func cancel() {
        let running = lock.withLock { () -> Process? in
            cancelled = true
            return process
        }
        if running?.isRunning == true { running?.terminate() }
    }
}
