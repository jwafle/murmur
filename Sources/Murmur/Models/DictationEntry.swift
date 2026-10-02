import Foundation

struct DictationEntry: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var createdAt: Date = .now
    var transcript: String
    var audioFileName: String
}

struct DictionaryTerm: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var grapheme: String
    var phonemes: String
}

enum ShortcutMode: String, CaseIterable, Identifiable {
    case hold = "Hold to dictate"
    case toggle = "Press to start, press again to stop"
    var id: String { rawValue }
}
