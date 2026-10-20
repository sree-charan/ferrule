// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Sree Charan

import Foundation

/// The price list shipped inside the app. It is never fetched: a newer list
/// arrives with a newer build.
enum AgentPriceSource {
    static func bundled() -> AgentPriceList? {
        guard let url = Bundle.main.url(forResource: "agent-prices", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return AgentPriceList.decode(data)
    }
}
