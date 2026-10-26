import SwiftUI

@MainActor
@Observable
final class SearchState {
    var searchText: String = ""
    var debouncedSearchText: String = ""
    var selectedContentTypes: Set<ContentType> = []
    var dateFilter: DateFilter = .all
    var selectedIndex: Int? = nil
    /// Extra indices when ⌘/⇧ multi-select is active. Empty means single selection via `selectedIndex`.
    var selectedIndices: Set<Int> = []
    /// Anchor for ⇧-click range selection; updated on plain and ⌘ clicks, not on ⇧ clicks.
    var selectionAnchor: Int? = nil

    private var debounceTask: Task<Void, Never>?

    /// Indices that Enter / Delete should act on (sorted left-to-right).
    var effectiveSelectedIndices: [Int] {
        if !selectedIndices.isEmpty {
            return selectedIndices.sorted()
        }
        if let selectedIndex {
            return [selectedIndex]
        }
        return []
    }

    var isMultiSelecting: Bool {
        selectedIndices.count > 1
    }

    func isSelected(_ index: Int) -> Bool {
        if !selectedIndices.isEmpty {
            return selectedIndices.contains(index)
        }
        return selectedIndex == index
    }

    /// Plain click / arrow focus: one card only.
    func selectSingle(_ index: Int) {
        selectedIndex = index
        selectedIndices = []
        selectionAnchor = index
    }

    /// ⌘-click: toggle membership; keeps other selections.
    func commandSelect(_ index: Int) {
        if selectedIndices.isEmpty, let current = selectedIndex {
            selectedIndices = [current]
        }
        if selectedIndices.contains(index) {
            selectedIndices.remove(index)
        } else {
            selectedIndices.insert(index)
        }
        if selectedIndices.count <= 1 {
            // Collapse back to single-selection mode.
            selectedIndex = selectedIndices.first ?? index
            selectedIndices = []
        } else {
            selectedIndex = index
        }
        selectionAnchor = index
    }

    /// ⇧-click: select the contiguous range from the anchor to `index`.
    func shiftSelect(_ index: Int) {
        let anchor = selectionAnchor ?? selectedIndex ?? index
        let lo = min(anchor, index)
        let hi = max(anchor, index)
        selectedIndices = Set(lo...hi)
        selectedIndex = index
        if selectedIndices.count <= 1 {
            selectedIndices = []
        }
    }

    func clearMultiSelection() {
        selectedIndices = []
    }

    enum DateFilter: String, CaseIterable, Sendable {
        case all = "All"
        case today = "Today"
        case thisWeek = "This Week"
        case thisMonth = "This Month"

        /// Localized menu title. `rawValue` stays the stable English identifier.
        var displayName: String {
            switch self {
            case .all: String(localized: "All")
            case .today: String(localized: "Today")
            case .thisWeek: String(localized: "This Week")
            case .thisMonth: String(localized: "This Month")
            }
        }

        var startDate: Date? {
            let calendar = Calendar.current
            switch self {
            case .all: return nil
            case .today: return calendar.startOfDay(for: Date())
            case .thisWeek:
                return calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))
            case .thisMonth:
                return calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))
            }
        }
    }

    var isActive: Bool {
        !searchText.isEmpty || !selectedContentTypes.isEmpty || dateFilter != .all
    }

    func updateSearch(_ text: String) {
        // The field writes its text back when it loses focus. Same text, same
        // results: keep the selection (Tab out of the field relies on it).
        guard text != searchText else { return }
        searchText = text
        selectedIndex = nil
        selectedIndices = []
        selectionAnchor = nil
        debounceTask?.cancel()
        debounceTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            debouncedSearchText = text
        }
    }

    func reset() {
        clearSession()
        selectedContentTypes = []
        dateFilter = .all
    }

    /// Clears search and selection when the panel closes, but keeps Type/Date filters
    /// so the next open still shows the same filtered set.
    func clearSession() {
        searchText = ""
        debouncedSearchText = ""
        selectedIndex = nil
        selectedIndices = []
        selectionAnchor = nil
        debounceTask?.cancel()
    }

    func clearSearch() {
        searchText = ""
        debouncedSearchText = ""
        selectedIndex = nil
        selectedIndices = []
        selectionAnchor = nil
        debounceTask?.cancel()
    }

    func clearFilters() {
        selectedContentTypes = []
        dateFilter = .all
        selectedIndex = nil
        selectedIndices = []
        selectionAnchor = nil
    }

    var hasActiveFilters: Bool {
        !selectedContentTypes.isEmpty || dateFilter != .all
    }

    var contentTypeFilterLabel: String {
        if selectedContentTypes.isEmpty {
            return String(localized: "Type")
        }
        if selectedContentTypes.count == 1, let only = selectedContentTypes.first {
            return only.displayName
        }
        return String(localized: "Type (\(selectedContentTypes.count))")
    }

    var dateFilterLabel: String {
        dateFilter == .all ? String(localized: "Date") : dateFilter.displayName
    }

    func toggleContentType(_ type: ContentType) {
        if selectedContentTypes.contains(type) {
            selectedContentTypes.remove(type)
        } else {
            selectedContentTypes.insert(type)
        }
        selectedIndex = nil
        selectedIndices = []
        selectionAnchor = nil
    }

    func filteredItems(from items: [ClipboardItem]) -> [ClipboardItem] {
        let startDate = dateFilter.startDate
        let contentTypes = selectedContentTypes
        let query = debouncedSearchText

        guard startDate != nil || !contentTypes.isEmpty || !query.isEmpty else {
            return items
        }

        return items.filter { item in
            if let startDate, item.copiedAt < startDate {
                return false
            }

            if !contentTypes.isEmpty, !contentTypes.contains(item.contentType) {
                return false
            }

            if !query.isEmpty {
                return item.matchesSearchQuery(query)
            }

            return true
        }
    }

    func moveSelection(by offset: Int, maxIndex: Int) {
        selectedIndices = []
        guard maxIndex >= 0 else {
            selectedIndex = nil
            selectionAnchor = nil
            return
        }
        if let current = selectedIndex {
            selectedIndex = max(0, min(current + offset, maxIndex))
        } else {
            selectedIndex = 0
        }
        selectionAnchor = selectedIndex
    }

    func ensureSelection(itemCount: Int) {
        guard itemCount > 0 else {
            selectedIndex = nil
            selectedIndices = []
            selectionAnchor = nil
            return
        }

        if let current = selectedIndex {
            selectedIndex = max(0, min(current, itemCount - 1))
        } else {
            selectedIndex = 0
        }
        selectionAnchor = selectionAnchor.map { max(0, min($0, itemCount - 1)) } ?? selectedIndex
        selectedIndices = Set(selectedIndices.filter { $0 >= 0 && $0 < itemCount })
        if selectedIndices.count <= 1 {
            selectedIndices = []
        }
    }
}

private extension ClipboardItem {
    func matchesSearchQuery(_ query: String) -> Bool {
        // Source app names are left out: the card doesn't show the app name,
        // so a clip matching only through it (a clip from "Aside" for "a")
        // looked like a wrong result.
        textContent?.localizedCaseInsensitiveContains(query) == true ||
        userTitle?.localizedCaseInsensitiveContains(query) == true
    }
}
