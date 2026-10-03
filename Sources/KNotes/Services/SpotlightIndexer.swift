import Foundation
import CoreSpotlight
import UniformTypeIdentifiers

public final class SpotlightIndexer {
    public static let shared = SpotlightIndexer()

    private init() {}

    private var lastIndexedSignature: Int = 0

    public func indexNotesIfChanged(_ notes: [Note]) {
        var hasher = Hasher()
        for note in notes {
            hasher.combine(note.id)
            hasher.combine(note.updated)
            hasher.combine(note.title)
        }
        let currentSignature = hasher.finalize()
        if currentSignature == lastIndexedSignature {
            return
        }
        lastIndexedSignature = currentSignature
        indexNotes(notes)
    }

    public func indexNotes(_ notes: [Note]) {
        guard CSSearchableIndex.isIndexingAvailable() else { return }

        let searchableItems: [CSSearchableItem] = notes.map { note in
            let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
            attributeSet.title = note.displayTitle
            attributeSet.contentDescription = note.previewSnippet
            attributeSet.textContent = "\(note.title)\n\(note.text)\n\(note.items.map(\.text).joined(separator: " "))"
            attributeSet.keywords = note.labels + [note.color, "KNotes", "Google Keep"]

            if let dateStr = note.updated ?? note.created,
               let d = NoteDateFormatters.parse(dateStr) {
                attributeSet.contentModificationDate = d
            }

            return CSSearchableItem(
                uniqueIdentifier: "knotes.note.\(note.id)",
                domainIdentifier: "com.madhuraj.KNotes",
                attributeSet: attributeSet
            )
        }

        CSSearchableIndex.default().indexSearchableItems(searchableItems) { error in
            if let error = error {
                print("[SpotlightIndexer] Error indexing items: \(error)")
            } else {
                print("[SpotlightIndexer] Successfully indexed \(searchableItems.count) notes into Spotlight")
            }
        }
    }

    public func indexSingleNote(_ note: Note) {
        guard CSSearchableIndex.isIndexingAvailable() else { return }
        let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
        attributeSet.title = note.displayTitle
        attributeSet.contentDescription = note.previewSnippet
        attributeSet.textContent = "\(note.title)\n\(note.text)\n\(note.items.map(\.text).joined(separator: " "))"
        attributeSet.keywords = note.labels + [note.color, "KNotes", "Google Keep"]

        if let dateStr = note.updated ?? note.created,
           let d = NoteDateFormatters.parse(dateStr) {
            attributeSet.contentModificationDate = d
        }

        let item = CSSearchableItem(
            uniqueIdentifier: "knotes.note.\(note.id)",
            domainIdentifier: "com.madhuraj.KNotes",
            attributeSet: attributeSet
        )
        CSSearchableIndex.default().indexSearchableItems([item], completionHandler: nil)
    }

    public func deindexNote(id: String) {
        guard CSSearchableIndex.isIndexingAvailable() else { return }
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: ["knotes.note.\(id)"]) { error in
            if let error = error {
                print("[SpotlightIndexer] Error deindexing note: \(error)")
            }
        }
    }
}
