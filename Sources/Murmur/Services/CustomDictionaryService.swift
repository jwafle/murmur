import Foundation
import Speech

@MainActor
final class CustomDictionaryService {
    private(set) var terms: [DictionaryTerm] = []
    private let directory: URL
    private let termsURL: URL
    private var modelReady = false
    private var preparedLocale: String?
    private var modelVersion = UUID().uuidString

    init() {
        directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Murmur", isDirectory: true)
        termsURL = directory.appendingPathComponent("dictionary.json")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: termsURL), let decoded = try? JSONDecoder().decode([DictionaryTerm].self, from: data) {
            terms = decoded
        }
    }

    func add(grapheme: String, phonemes: String) {
        terms.append(DictionaryTerm(grapheme: grapheme, phonemes: phonemes))
        save()
        modelReady = false
        modelVersion = UUID().uuidString
    }

    func remove(_ term: DictionaryTerm) {
        terms.removeAll { $0.id == term.id }
        save()
        modelReady = false
        modelVersion = UUID().uuidString
    }

    func prepareModel(locale: Locale) async throws -> SFSpeechLanguageModel.Configuration? {
        guard !terms.isEmpty else { return nil }
        let modelURL = directory.appendingPathComponent("custom.lm")
        let vocabularyURL = directory.appendingPathComponent("custom.vocab")
        let dataURL = directory.appendingPathComponent("custom-data.bin")
        if !modelReady || preparedLocale != locale.identifier {
            let data = SFCustomLanguageModelData(locale: locale, identifier: "com.murmur.user-dictionary", version: modelVersion)
            for term in terms {
                let phonemes = term.phonemes.split(whereSeparator: \.isWhitespace).map(String.init)
                data.insert(term: SFCustomLanguageModelData.CustomPronunciation(grapheme: term.grapheme, phonemes: phonemes))
            }
            try await data.export(to: dataURL)
            let configuration = SFSpeechLanguageModel.Configuration(languageModel: modelURL, vocabulary: vocabularyURL)
            try await SFSpeechLanguageModel.prepareCustomLanguageModel(for: dataURL, configuration: configuration)
            modelReady = true
            preparedLocale = locale.identifier
        }
        return SFSpeechLanguageModel.Configuration(languageModel: modelURL, vocabulary: vocabularyURL)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(terms) else { return }
        try? data.write(to: termsURL, options: .atomic)
    }
}
