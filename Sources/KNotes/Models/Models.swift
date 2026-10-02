import Foundation
import SwiftUI

public struct ChecklistItem: Identifiable, Codable, Equatable, Hashable {
    public var id: String?
    public var text: String
    public var checked: Bool

    public init(id: String? = nil, text: String = "", checked: Bool = false) {
        self.id = id ?? UUID().uuidString
        self.text = text
        self.checked = checked
    }

    private enum CodingKeys: String, CodingKey {
        case id, text, checked
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
        self.checked = try container.decodeIfPresent(Bool.self, forKey: .checked) ?? false
    }
}

public struct Note: Identifiable, Codable, Equatable, Hashable {
    public var id: String
    public var title: String
    public var text: String
    public var isList: Bool
    public var items: [ChecklistItem]
    public var color: String
    public var pinned: Bool
    public var archived: Bool
    public var trashed: Bool
    public var labels: [String]
    public var collaborators: [String]
    public var created: String?
    public var updated: String?

    public init(
        id: String = UUID().uuidString,
        title: String = "",
        text: String = "",
        isList: Bool = false,
        items: [ChecklistItem] = [],
        color: String = "White",
        pinned: Bool = false,
        archived: Bool = false,
        trashed: Bool = false,
        labels: [String] = [],
        collaborators: [String] = [],
        created: String? = nil,
        updated: String? = nil
    ) {
        self.id = id
        self.title = title
        self.text = text
        self.isList = isList
        self.items = items
        self.color = color
        self.pinned = pinned
        self.archived = archived
        self.trashed = trashed
        self.labels = labels
        self.collaborators = collaborators
        self.created = created
        self.updated = updated
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, text
        case isList = "is_list"
        case items, color, pinned, archived, trashed, labels, collaborators, created, updated
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
        self.isList = try container.decodeIfPresent(Bool.self, forKey: .isList) ?? false
        self.items = try container.decodeIfPresent([ChecklistItem].self, forKey: .items) ?? []
        self.color = try container.decodeIfPresent(String.self, forKey: .color) ?? "White"
        self.pinned = try container.decodeIfPresent(Bool.self, forKey: .pinned) ?? false
        self.archived = try container.decodeIfPresent(Bool.self, forKey: .archived) ?? false
        self.trashed = try container.decodeIfPresent(Bool.self, forKey: .trashed) ?? false
        self.labels = try container.decodeIfPresent([String].self, forKey: .labels) ?? []
        self.collaborators = try container.decodeIfPresent([String].self, forKey: .collaborators) ?? []
        self.created = try container.decodeIfPresent(String.self, forKey: .created)
        self.updated = try container.decodeIfPresent(String.self, forKey: .updated)
    }

    public var isQuickNote: Bool {
        labels.contains { $0.caseInsensitiveCompare("Quick Notes") == .orderedSame }
    }

    public var displayTitle: String {
        if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return title
        }
        if isList && !items.isEmpty {
            return items.first?.text ?? "New List"
        }
        let firstLine = text.components(separatedBy: .newlines).first ?? ""
        if !firstLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return firstLine
        }
        return "New Note"
    }

    public var previewSnippet: String {
        if isList {
            let total = items.count
            let done = items.filter { $0.checked }.count
            if total == 0 { return "Empty checklist" }
            return "\(done)/\(total) items completed"
        }
        let lines = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        if lines.count > 1 {
            return lines[1]
        } else if let first = lines.first, first != displayTitle {
            return first
        }
        return "No additional text"
    }

    public var shareText: String {
        var content = ""
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty {
            content += "\(trimmedTitle)\n\n"
        }
        if isList {
            for item in items {
                content += "\(item.checked ? "[x]" : "[ ]") \(item.text)\n"
            }
        } else {
            content += text
        }
        return content
    }

    public var formattedDate: String {
        guard let dateString = updated ?? created else {
            return "Just now"
        }
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = isoFormatter.date(from: dateString)
        if date == nil {
            isoFormatter.formatOptions = [.withInternetDateTime]
            date = isoFormatter.date(from: dateString)
        }

        guard let d = date else { return "Recent" }

        let calendar = Calendar.current
        if calendar.isDateInToday(d) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: d)
        } else if calendar.isDateInYesterday(d) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d/yy"
            return formatter.string(from: d)
        }
    }

    public var headerDate: String {
        guard let dateString = updated ?? created else {
            return "Today"
        }
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = isoFormatter.date(from: dateString)
        if date == nil {
            isoFormatter.formatOptions = [.withInternetDateTime]
            date = isoFormatter.date(from: dateString)
        }
        guard let d = date else { return "Today" }

        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: d)
    }

    public var swiftUIColor: Color {
        switch color {
        case "Red":
            return Color(red: 0.98, green: 0.86, blue: 0.85)
        case "Orange":
            return Color(red: 0.99, green: 0.90, blue: 0.80)
        case "Yellow":
            return Color(red: 1.0, green: 0.96, blue: 0.78)
        case "Green":
            return Color(red: 0.89, green: 0.96, blue: 0.89)
        case "Teal":
            return Color(red: 0.86, green: 0.96, blue: 0.95)
        case "Blue":
            return Color(red: 0.88, green: 0.93, blue: 0.99)
        case "DarkBlue":
            return Color(red: 0.84, green: 0.88, blue: 0.96)
        case "Purple":
            return Color(red: 0.93, green: 0.88, blue: 0.97)
        case "Pink":
            return Color(red: 0.99, green: 0.87, blue: 0.93)
        case "Brown":
            return Color(red: 0.93, green: 0.89, blue: 0.86)
        case "Gray":
            return Color(red: 0.92, green: 0.93, blue: 0.94)
        default:
            return Color(NSColor.textBackgroundColor)
        }
    }

    public var accentTint: Color {
        switch color {
        case "Red": return .red
        case "Orange": return .orange
        case "Yellow": return .yellow
        case "Green": return .green
        case "Teal": return .teal
        case "Blue": return .blue
        case "DarkBlue": return .indigo
        case "Purple": return .purple
        case "Pink": return .pink
        case "Brown": return Color(red: 0.6, green: 0.4, blue: 0.2)
        case "Gray": return .gray
        default: return Color.accentColor
        }
    }

    public static func swatchColor(for name: String) -> Color {
        switch name {
        case "Red": return Color(red: 0.96, green: 0.45, blue: 0.42)
        case "Orange": return Color(red: 0.98, green: 0.65, blue: 0.35)
        case "Yellow": return Color(red: 0.98, green: 0.86, blue: 0.35)
        case "Green": return Color(red: 0.50, green: 0.82, blue: 0.55)
        case "Teal": return Color(red: 0.40, green: 0.80, blue: 0.80)
        case "Blue": return Color(red: 0.45, green: 0.68, blue: 0.95)
        case "DarkBlue": return Color(red: 0.35, green: 0.48, blue: 0.88)
        case "Purple": return Color(red: 0.72, green: 0.55, blue: 0.90)
        case "Pink": return Color(red: 0.95, green: 0.52, blue: 0.75)
        case "Brown": return Color(red: 0.70, green: 0.58, blue: 0.48)
        case "Gray": return Color(red: 0.75, green: 0.78, blue: 0.80)
        default: return Color.white
        }
    }
}

public struct LabelItem: Identifiable, Codable, Equatable, Hashable {
    public var id: String
    public var name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

public struct AppStatus: Codable, Equatable {
    public var authenticated: Bool
    public var email: String?
    public var syncStatus: String
    public var lastSynced: String?
    public var totalNotes: Int
    public var pinnedNotes: Int
    public var archivedNotes: Int
    public var trashNotes: Int
    public var quickNotes: Int

    private enum CodingKeys: String, CodingKey {
        case authenticated, email
        case syncStatus = "sync_status"
        case lastSynced = "last_synced"
        case totalNotes = "total_notes"
        case pinnedNotes = "pinned_notes"
        case archivedNotes = "archived_notes"
        case trashNotes = "trash_notes"
        case quickNotes = "quick_notes"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.authenticated = try container.decodeIfPresent(Bool.self, forKey: .authenticated) ?? false
        self.email = try container.decodeIfPresent(String.self, forKey: .email)
        self.syncStatus = try container.decodeIfPresent(String.self, forKey: .syncStatus) ?? "offline"
        self.lastSynced = try container.decodeIfPresent(String.self, forKey: .lastSynced)
        self.totalNotes = try container.decodeIfPresent(Int.self, forKey: .totalNotes) ?? 0
        self.pinnedNotes = try container.decodeIfPresent(Int.self, forKey: .pinnedNotes) ?? 0
        self.archivedNotes = try container.decodeIfPresent(Int.self, forKey: .archivedNotes) ?? 0
        self.trashNotes = try container.decodeIfPresent(Int.self, forKey: .trashNotes) ?? 0
        self.quickNotes = try container.decodeIfPresent(Int.self, forKey: .quickNotes) ?? 0
    }
}

public enum Folder: String, CaseIterable, Identifiable, Hashable {
    case all = "all"
    case quick = "quick"
    case pinned = "pinned"
    case archived = "archived"
    case trash = "trash"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .all: return "All Notes"
        case .quick: return "Quick Notes"
        case .pinned: return "Pinned"
        case .archived: return "Archive"
        case .trash: return "Recently Deleted"
        }
    }

    public var iconName: String {
        switch self {
        case .all: return "note.text"
        case .quick: return "bolt.fill"
        case .pinned: return "pin.fill"
        case .archived: return "archivebox.fill"
        case .trash: return "trash.fill"
        }
    }

    public var iconColor: Color {
        switch self {
        case .all: return .accentColor
        case .quick: return .yellow
        case .pinned: return .orange
        case .archived: return .indigo
        case .trash: return .secondary
        }
    }
}

public enum SidebarItem: Hashable, Identifiable {
    case folder(Folder)
    case tag(String)

    public var id: String {
        switch self {
        case .folder(let f): return "folder_\(f.rawValue)"
        case .tag(let t): return "tag_\(t)"
        }
    }

    public var title: String {
        switch self {
        case .folder(let f): return f.title
        case .tag(let t): return "# \(t)"
        }
    }
}
