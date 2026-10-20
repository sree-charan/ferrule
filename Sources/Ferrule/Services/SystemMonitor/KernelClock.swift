// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Sree Charan

import Darwin

/// The time in the units the kernel stamps processes with (`ri_proc_start_abstime`),
/// so a sample's start can be compared with when a process began.
///
/// Natively that is `mach_absolute_time()`: ticks on Apple Silicon, nanoseconds
/// on Intel, each matching its kernel. An Intel build running under Rosetta is
/// the exception: Rosetta reports `mach_absolute_time()` in nanoseconds while
/// the kernel keeps its own 24 MHz ticks, so every process would look older
/// than any sample. There the nanoseconds are turned back into kernel ticks.
enum KernelClock {
    static func now() -> UInt64 {
        convert(mach_absolute_time(), translated: isTranslated, tickFrequency: tickFrequency)
    }

    static func convert(_ absolute: UInt64, translated: Bool, tickFrequency: UInt64?) -> UInt64 {
        guard translated, let frequency = tickFrequency, frequency > 0 else { return absolute }
        // Whole seconds and the remainder apart, so the product never overflows.
        let seconds = absolute / 1_000_000_000
        let nanoseconds = absolute % 1_000_000_000
        return seconds &* frequency &+ nanoseconds &* frequency / 1_000_000_000
    }

    private static let isTranslated: Bool = {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        return sysctlbyname("sysctl.proc_translated", &value, &size, nil, 0) == 0 && value == 1
    }()

    private static let tickFrequency: UInt64? = {
        var value: Int64 = 0
        var size = MemoryLayout<Int64>.size
        guard sysctlbyname("hw.tbfrequency", &value, &size, nil, 0) == 0, value > 0 else { return nil }
        return UInt64(value)
    }()
}
