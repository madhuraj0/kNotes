import Foundation
import SwiftUI
import Combine

@MainActor
public final class NotesStore: ObservableObject {
    public static let shared = NotesStore()

    @Published public var notes: [Note] = []
    @Published public var selectedNoteId: String? = nil
    @Published public var selectedFolder: Folder = .all
    @Published public var selectedLabel: String? = nil
    @Published public var searchQuery: String = ""
    @Published public var labels: [LabelItem] = []
    @Published public var status: AppStatus? = nil

    @Published public var sidebarSelection: SidebarItem = .folder(.all) {
        didSet {
            switch sidebarSelection {
            case .folder(let f):
                selectedFolder = f
                selectedLabel = nil
            case .tag(let t):
                selectedFolder = .all
                selectedLabel = t
            }
            Task {
                await fetchNotes()
            }
        }
    }

    @Published public var isLoading: Bool = false
    @Published public var isSyncing: Bool = false
    @Published public var showAccountSheet: Bool = false
    @Published public var showNewLabelSheet: Bool = false
    @Published public var errorMessage: String? = nil

    @Published public var shouldFocusTitle: Bool = false
    @Published public var shouldFocusSearch: Bool = false
    @Published public var shouldToggleMarkdownPreview: Bool = false
    @Published public var shouldShowColorPicker: Bool = false

    private var saveDebounceTask: Task<Void, Never>?
    private var searchDebounceTask: Task<Void, Never>?
    private var preSearchSelectedNoteId: String? = nil
    private var cancellables = Set<AnyCancellable>()

    public init() {
        $searchQuery
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] newQuery in
                guard let self = self else { return }
                if !newQuery.isEmpty && self.preSearchSelectedNoteId == nil {
                    self.preSearchSelectedNoteId = self.selectedNoteId
                }
            }
            .store(in: &cancellables)

        $searchQuery
            .dropFirst()
            .removeDuplicates()
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                Task {
                    await self?.fetchNotes()
                }
            }
            .store(in: &cancellables)

        // Periodic background refresh
        Timer.publish(every: 40, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.fetchStatus()
                    await self?.fetchNotes()
                }
            }
            .store(in: &cancellables)
    }

    public var selectedNote: Note? {
        guard let id = selectedNoteId else { return notes.first }
        return notes.first(where: { $0.id == id })
    }

    public func initialize() async {
        isLoading = true
        _ = await ProcessManager.shared.ensureBackendRunning()
        await fetchStatus()
        await fetchLabels()
        await fetchNotes()
        isLoading = false

        if selectedNoteId == nil, let first = notes.first {
            selectedNoteId = first.id
        }
    }

    public func fetchStatus() async {
        do {
            self.status = try await APIClient.shared.fetchStatus()
        } catch {
            print("[NotesStore] fetchStatus error: \(error)")
        }
    }

    public func fetchLabels() async {
        do {
            self.labels = try await APIClient.shared.fetchLabels()
        } catch {
            print("[NotesStore] fetchLabels error: \(error)")
        }
    }

    public func fetchNotes() async {
        do {
            let fetched = try await APIClient.shared.fetchNotes(
                folder: selectedFolder.rawValue,
                label: selectedLabel,
                query: searchQuery.isEmpty ? nil : searchQuery
            )

            // Protect pending autosaves on active note from being overwritten by stale server fetch
            if let activeId = selectedNoteId,
               saveDebounceTask != nil,
               let localIndex = self.notes.firstIndex(where: { $0.id == activeId }) {
                let localActive = self.notes[localIndex]
                self.notes = fetched.map { note in
                    if note.id == activeId {
                        var merged = note
                        merged.title = localActive.title
                        merged.text = localActive.text
                        merged.items = localActive.items
                        return merged
                    }
                    return note
                }
            } else {
                self.notes = fetched
            }
            SpotlightIndexer.shared.indexNotesIfChanged(fetched)

            // Keep selected note, restore pre-search note if search cleared, or select first matching
            if self.searchQuery.isEmpty, let restoreId = self.preSearchSelectedNoteId, self.notes.contains(where: { $0.id == restoreId }) {
                self.selectedNoteId = restoreId
                self.preSearchSelectedNoteId = nil
            } else if let selId = selectedNoteId, self.notes.contains(where: { $0.id == selId }) {
                // Keep currently selected note if it's still in the results
            } else {
                self.selectedNoteId = self.notes.first?.id
            }
        } catch {
            print("[NotesStore] fetchNotes error: \(error)")
            self.errorMessage = "Failed to load notes: \(error.localizedDescription)"
        }
    }

    public func selectFolder(_ folder: Folder) {
        sidebarSelection = .folder(folder)
    }

    public func selectLabel(_ labelName: String) {
        sidebarSelection = .tag(labelName)
    }

    public func createNote(isList: Bool = false) {
        Task {
            do {
                var defaultLabels: [String] = []
                var isPinned = false
                var isArchived = false

                switch sidebarSelection {
                case .folder(.quick):
                    defaultLabels.append("Quick Notes")
                case .folder(.pinned):
                    isPinned = true
                case .folder(.archived):
                    isArchived = true
                case .tag(let t):
                    defaultLabels.append(t)
                default:
                    if let sel = selectedLabel {
                        defaultLabels.append(sel)
                    }
                }

                let newNote = try await APIClient.shared.createNote(
                    title: "",
                    text: "",
                    isList: isList,
                    items: isList ? [ChecklistItem(text: "", checked: false)] : [],
                    color: "White",
                    pinned: isPinned,
                    archived: isArchived,
                    labels: defaultLabels
                )
                self.notes.insert(newNote, at: 0)
                self.selectedNoteId = newNote.id
                self.shouldFocusTitle = true
                SpotlightIndexer.shared.indexSingleNote(newNote)
                await fetchStatus()
                await fetchLabels()
            } catch {
                self.errorMessage = "Failed to create note: \(error.localizedDescription)"
            }
        }
    }

    public func updateSelectedNoteLocally(title: String? = nil, text: String? = nil, items: [ChecklistItem]? = nil) {
        guard let id = selectedNoteId, let index = notes.firstIndex(where: { $0.id == id }) else { return }

        if let title = title {
            notes[index].title = title
        }
        if let text = text {
            notes[index].text = text
        }
        if let items = items {
            notes[index].items = items
        }

        // Debounce backend save
        let currentNote = notes[index]
        saveDebounceTask?.cancel()
        saveDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            do {
                let saved = try await APIClient.shared.updateNote(
                    id: currentNote.id,
                    title: currentNote.title,
                    text: currentNote.text,
                    isList: currentNote.isList,
                    items: currentNote.items,
                    color: currentNote.color,
                    pinned: currentNote.pinned,
                    archived: currentNote.archived,
                    trashed: currentNote.trashed,
                    labels: currentNote.labels,
                    collaborators: currentNote.collaborators
                )
                SpotlightIndexer.shared.indexSingleNote(saved)
            } catch {
                print("[NotesStore] Auto-save error: \(error)")
            }
            self.saveDebounceTask = nil
        }
    }

    public func togglePin(note: Note) {
        Task {
            let newPinned = !note.pinned
            if let index = notes.firstIndex(where: { $0.id == note.id }) {
                notes[index].pinned = newPinned
            }
            do {
                _ = try await APIClient.shared.updateNote(id: note.id, pinned: newPinned)
                await fetchNotes()
                await fetchStatus()
            } catch {
                self.errorMessage = "Failed to update pin: \(error.localizedDescription)"
            }
        }
    }

    public func toggleArchive(note: Note) {
        Task {
            let newArchived = !note.archived
            if let index = notes.firstIndex(where: { $0.id == note.id }) {
                notes[index].archived = newArchived
            }
            do {
                _ = try await APIClient.shared.updateNote(id: note.id, archived: newArchived)
                await fetchNotes()
                await fetchStatus()
            } catch {
                self.errorMessage = "Failed to update archive: \(error.localizedDescription)"
            }
        }
    }

    public func changeColor(note: Note, color: String) {
        Task {
            if let index = notes.firstIndex(where: { $0.id == note.id }) {
                notes[index].color = color
            }
            do {
                _ = try await APIClient.shared.updateNote(id: note.id, color: color)
            } catch {
                self.errorMessage = "Failed to change color: \(error.localizedDescription)"
            }
        }
    }

    public func toggleNoteType(note: Note) {
        Task {
            let targetIsList = !note.isList
            var items: [ChecklistItem] = []
            var text = note.text

            if targetIsList {
                let lines = note.text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                items = lines.isEmpty ? [ChecklistItem(text: "", checked: false)] : lines.map { ChecklistItem(text: $0, checked: false) }
            } else {
                text = note.items.map { "- \($0.text)" }.joined(separator: "\n")
            }

            if let index = notes.firstIndex(where: { $0.id == note.id }) {
                notes[index].isList = targetIsList
                notes[index].items = items
                notes[index].text = text
            }

            do {
                let updated = try await APIClient.shared.updateNote(
                    id: note.id,
                    text: text,
                    isList: targetIsList,
                    items: items
                )
                if let index = notes.firstIndex(where: { $0.id == note.id }) {
                    notes[index] = updated
                }
            } catch {
                self.errorMessage = "Failed to convert note: \(error.localizedDescription)"
            }
        }
    }

    public func toggleLabel(note: Note, labelName: String) {
        Task {
            var updatedLabels = note.labels
            if let idx = updatedLabels.firstIndex(of: labelName) {
                updatedLabels.remove(at: idx)
            } else {
                updatedLabels.append(labelName)
            }

            if let index = notes.firstIndex(where: { $0.id == note.id }) {
                notes[index].labels = updatedLabels
            }

            do {
                _ = try await APIClient.shared.updateNote(id: note.id, labels: updatedLabels)
                await fetchLabels()
            } catch {
                self.errorMessage = "Failed to update labels: \(error.localizedDescription)"
            }
        }
    }

    public func addCollaborator(note: Note, email: String) {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !note.collaborators.contains(trimmed) else { return }
        Task {
            var updated = note.collaborators
            updated.append(trimmed)
            if let index = notes.firstIndex(where: { $0.id == note.id }) {
                notes[index].collaborators = updated
            }
            do {
                _ = try await APIClient.shared.updateNote(id: note.id, collaborators: updated)
            } catch {
                self.errorMessage = "Failed to add collaborator: \(error.localizedDescription)"
            }
        }
    }

    public func removeCollaborator(note: Note, email: String) {
        Task {
            var updated = note.collaborators
            updated.removeAll(where: { $0 == email })
            if let index = notes.firstIndex(where: { $0.id == note.id }) {
                notes[index].collaborators = updated
            }
            do {
                _ = try await APIClient.shared.updateNote(id: note.id, collaborators: updated)
            } catch {
                self.errorMessage = "Failed to remove collaborator: \(error.localizedDescription)"
            }
        }
    }

    public func deleteNote(note: Note) {
        Task {
            // Find next note to select
            if let currentIndex = notes.firstIndex(where: { $0.id == note.id }) {
                notes.remove(at: currentIndex)
                if selectedNoteId == note.id {
                    if currentIndex < notes.count {
                        selectedNoteId = notes[currentIndex].id
                    } else {
                        selectedNoteId = notes.last?.id
                    }
                }
            }

            do {
                SpotlightIndexer.shared.deindexNote(id: note.id)
                try await APIClient.shared.deleteNote(id: note.id)
                await fetchStatus()
            } catch {
                self.errorMessage = "Failed to delete note: \(error.localizedDescription)"
            }
        }
    }

    public func restoreNote(note: Note) {
        Task {
            do {
                _ = try await APIClient.shared.untrashNote(id: note.id)
                await fetchNotes()
                await fetchStatus()
            } catch {
                self.errorMessage = "Failed to restore note: \(error.localizedDescription)"
            }
        }
    }

    public func selectNextNote() {
        guard !notes.isEmpty else { return }
        guard let currentId = selectedNoteId, let index = notes.firstIndex(where: { $0.id == currentId }) else {
            selectedNoteId = notes.first?.id
            return
        }
        if index + 1 < notes.count {
            selectedNoteId = notes[index + 1].id
        }
    }

    public func selectPreviousNote() {
        guard !notes.isEmpty else { return }
        guard let currentId = selectedNoteId, let index = notes.firstIndex(where: { $0.id == currentId }) else {
            selectedNoteId = notes.first?.id
            return
        }
        if index > 0 {
            selectedNoteId = notes[index - 1].id
        }
    }

    public func syncNow() {
        Task {
            isSyncing = true
            do {
                try await APIClient.shared.sync()
                await fetchNotes()
                await fetchLabels()
                await fetchStatus()
            } catch {
                self.errorMessage = "Sync note: \(error.localizedDescription)"
            }
            isSyncing = false
        }
    }

    public func createLabel(name: String) async -> Bool {
        do {
            let created = try await APIClient.shared.createLabel(name: name)
            self.labels.append(created)
            return true
        } catch {
            self.errorMessage = "Failed to create tag: \(error.localizedDescription)"
            return false
        }
    }

    public func deleteLabel(id: String) async {
        do {
            try await APIClient.shared.deleteLabel(id: id)
            self.labels.removeAll(where: { $0.id == id })
            await fetchNotes()
        } catch {
            self.errorMessage = "Failed to delete tag: \(error.localizedDescription)"
        }
    }

    public func login(email: String, password: String? = nil, masterToken: String? = nil) async -> (Bool, String) {
        isLoading = true
        do {
            let (success, message) = try await APIClient.shared.login(email: email, password: password, masterToken: masterToken)
            if success {
                await fetchStatus()
                await fetchNotes()
                await fetchLabels()
            }
            isLoading = false
            return (success, message)
        } catch {
            isLoading = false
            return (false, error.localizedDescription)
        }
    }

    public func logout() async {
        isLoading = true
        do {
            try await APIClient.shared.logout()
            await fetchStatus()
            await fetchNotes()
            await fetchLabels()
        } catch {
            print("[NotesStore] logout error: \(error)")
        }
        isLoading = false
    }
}
