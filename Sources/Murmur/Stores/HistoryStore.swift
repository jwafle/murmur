import Foundation

@MainActor
final class HistoryStore {
    private(set) var entries: [DictationEntry] = []
    let directory: URL
    private let indexURL: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Murmur", isDirectory: true)
        directory = base.appendingPathComponent("Recordings", isDirectory: true)
        indexURL = base.appendingPathComponent("history.json")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        load()
    }

    func add(transcript: String, audioURL: URL) {
        let name = "\(UUID().uuidString).wav"
        let destination = directory.appendingPathComponent(name)
        try? FileManager.default.moveItem(at: audioURL, to: destination)
        entries.insert(DictationEntry(transcript: transcript, audioFileName: name), at: 0)
        save()
    }

    func delete(_ entry: DictationEntry) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(entry.audioFileName))
        entries.removeAll { $0.id == entry.id }
        save()
    }

    func purge(olderThanDays days: Int) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .distantPast
        let expired = entries.filter { $0.createdAt < cutoff }
        for entry in expired {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(entry.audioFileName))
        }
        entries.removeAll { $0.createdAt < cutoff }
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: indexURL),
              let decoded = try? JSONDecoder().decode([DictationEntry].self, from: data) else { return }
        entries = decoded.filter { FileManager.default.fileExists(atPath: directory.appendingPathComponent($0.audioFileName).path) }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }
}
