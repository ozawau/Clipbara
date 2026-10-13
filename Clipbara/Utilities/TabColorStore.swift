import Foundation
import SwiftUI

/// Persists History / pinboard tab accent colors without touching the SwiftData schema.
@MainActor
enum TabColorStore {
    private static let historyKey = "historyTabColorIndex"
    private static let pinboardKey = "pinboardTabColorIndices"

    static let colors: [Color] = [
        Color(red: 0.94, green: 0.30, blue: 0.29), // red
        Color(red: 0.97, green: 0.58, blue: 0.16), // orange
        Color(red: 0.96, green: 0.77, blue: 0.10), // yellow
        Color(red: 0.25, green: 0.73, blue: 0.40), // green
        Color(red: 0.13, green: 0.68, blue: 0.75), // teal
        Color(red: 0.23, green: 0.44, blue: 0.95), // blue
        Color(red: 0.45, green: 0.36, blue: 0.90), // indigo
        Color(red: 0.72, green: 0.36, blue: 0.86), // purple
        Color(red: 0.93, green: 0.36, blue: 0.62), // pink
    ]

    static func color(at index: Int) -> Color {
        let count = colors.count
        let normalized = ((index % count) + count) % count
        return colors[normalized]
    }

    static func historyColor() -> Color {
        color(at: historyIndex())
    }

    static func historyIndex() -> Int {
        UserDefaults.standard.integer(forKey: historyKey)
    }

    static func cycleHistoryColor() {
        UserDefaults.standard.set((historyIndex() + 1) % colors.count, forKey: historyKey)
    }

    static func color(for pinboardID: UUID) -> Color {
        color(at: index(for: pinboardID))
    }

    static func index(for pinboardID: UUID) -> Int {
        let map = pinboardMap()
        if let stored = map[pinboardID.uuidString] {
            return stored
        }
        // Stable fallback from the UUID so existing boards already look distinct.
        var hasher = Hasher()
        hasher.combine(pinboardID)
        let hashed = hasher.finalize()
        return Int(UInt(bitPattern: hashed) % UInt(colors.count))
    }

    static func cycleColor(for pinboardID: UUID) {
        var map = pinboardMap()
        map[pinboardID.uuidString] = (index(for: pinboardID) + 1) % colors.count
        UserDefaults.standard.set(map, forKey: pinboardKey)
    }

    /// Assigns the least-used palette index when a pinboard is created.
    static func assignDefaultColor(for pinboardID: UUID, existingIDs: [UUID]) {
        var map = pinboardMap()
        guard map[pinboardID.uuidString] == nil else { return }
        let used = Set(existingIDs.map { index(for: $0) })
        let preferred = colors.indices.first { !used.contains($0) } ?? existingIDs.count % colors.count
        map[pinboardID.uuidString] = preferred
        UserDefaults.standard.set(map, forKey: pinboardKey)
    }

    private static func pinboardMap() -> [String: Int] {
        UserDefaults.standard.dictionary(forKey: pinboardKey) as? [String: Int] ?? [:]
    }
}
