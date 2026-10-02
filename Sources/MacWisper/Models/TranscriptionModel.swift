import Foundation

// Pinned catalog mirrors Hex's src/transcription_models.rs.
struct TranscriptionModel: Identifiable, Equatable {
    let id: String
    let name: String
    let filename: String
    let repository: String
    let revision: String
    let sha256: String
    let architecture: String
    let variant: String
    let bytes: Int64
    let languages: [String]
    let acceptsLanguageHint: Bool
    let detectsLanguage: Bool

    var downloadURL: URL { URL(string: "https://huggingface.co/\(repository)/resolve/\(revision)/\(filename)")! }
    var sizeLabel: String { ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file) }
    func supports(_ language: String) -> Bool {
        language == "auto" ? detectsLanguage : (languages.contains("*") && Self.languageCodes.contains(language)) || languages.contains(language)
    }
    static let languageCodes = ["en", "zh", "yue", "ja", "ko", "es", "fr", "de", "pt", "it", "ar", "hi", "vi", "ru", "uk", "nl", "pl", "tr", "sv", "da", "fi", "cs", "el", "ro", "hu", "id", "ms", "th", "fa", "bg", "hr", "et", "lv", "lt", "mt", "sk", "sl", "mk", "fil"]
    static let appleID = "apple_speech"
    static let all: [TranscriptionModel] = [
        TranscriptionModel(id: "parakeet_unified_en", name: "Parakeet Unified English", filename: "parakeet-unified-en-0.6b-Q8_0.gguf", repository: "handy-computer/parakeet-unified-en-0.6b-gguf", revision: "7e948f21b7bdbac698d3318db9d350f1096f3b6c", sha256: "4b50b6dd862bf6e346929aaf4f5eaacec003bfa3f56462d6c874b41ef2f38795", architecture: "parakeet", variant: "unified-en-0.6b", bytes: 731357568, languages: ["en"], acceptsLanguageHint: true, detectsLanguage: false),
        TranscriptionModel(id: "parakeet_v2", name: "Parakeet v2", filename: "parakeet-tdt-0.6b-v2-Q8_0.gguf", repository: "handy-computer/parakeet-tdt-0.6b-v2-gguf", revision: "07cee0616125a08ef619729bb47f40ef747e4bc4", sha256: "f0d0e99cebb6d3b83f1f7069b82b5d3c2e39a54545b0da039cb4bafd9c4e5caa", architecture: "parakeet", variant: "tdt-0.6b-v2", bytes: 729574912, languages: ["en"], acceptsLanguageHint: true, detectsLanguage: false),
        TranscriptionModel(id: "parakeet_v3", name: "Parakeet v3", filename: "parakeet-tdt-0.6b-v3-Q8_0.gguf", repository: "handy-computer/parakeet-tdt-0.6b-v3-gguf", revision: "85ac09ea12fc4b1112fa76810059364bc6adc9de", sha256: "5859f77944efcd8eafa23a6350731960b2b55b2203df51f319665c807d802cc7", architecture: "parakeet", variant: "tdt-0.6b-v3", bytes: 739508576, languages: ["bg", "hr", "cs", "da", "nl", "en", "et", "fi", "fr", "de", "el", "hu", "it", "lv", "lt", "mt", "pl", "pt", "ro", "ru", "sk", "sl", "es", "sv", "uk"], acceptsLanguageHint: false, detectsLanguage: false),
        TranscriptionModel(id: "whisper_large_v3_turbo", name: "Whisper large-v3-turbo", filename: "whisper-large-v3-turbo-Q8_0.gguf", repository: "handy-computer/whisper-large-v3-turbo-gguf", revision: "d222c9f621c1128299248f2ded4d8a1820519780", sha256: "d5e65f2b0828802ae2c231673d31982cebe3a778c95d9494a9f3efee6bd17448", architecture: "whisper", variant: "whisper-large-v3-turbo", bytes: 886381824, languages: ["*"], acceptsLanguageHint: true, detectsLanguage: true),
        TranscriptionModel(id: "qwen3_asr06_b", name: "Qwen3-ASR 0.6B", filename: "Qwen3-ASR-0.6B-Q8_0.gguf", repository: "handy-computer/Qwen3-ASR-0.6B-gguf", revision: "e4e16599b900eb0cb36e524514756bb92eb092b7", sha256: "f081b2d5e23bd669d92cc331d722a8a0681943b8e6f34b48996fd5c319b5acd8", architecture: "qwen3_asr", variant: "qwen3-asr-0.6b", bytes: 850423456, languages: ["zh", "en", "yue", "ar", "de", "fr", "es", "pt", "id", "it", "ko", "ru", "th", "vi", "ja", "tr", "hi", "ms", "nl", "sv", "da", "fi", "pl", "cs", "fil", "fa", "el", "ro", "hu", "mk"], acceptsLanguageHint: true, detectsLanguage: true),
        TranscriptionModel(id: "sense_voice_small", name: "SenseVoice Small", filename: "SenseVoiceSmall-Q8_0.gguf", repository: "handy-computer/SenseVoiceSmall-gguf", revision: "4a08b8e900b38a977e32eb08d5d0697d6e72ba04", sha256: "6c759ee4c9748c9b3f7a5a60ca74f0f7e685fb9d45d1378fce7cfd62f59adf29", architecture: "sensevoice", variant: "sensevoice-small", bytes: 252684608, languages: ["zh", "yue", "en", "ja", "ko"], acceptsLanguageHint: true, detectsLanguage: true),
        TranscriptionModel(id: "cohere_transcribe", name: "Cohere Transcribe", filename: "cohere-transcribe-03-2026-Q8_0.gguf", repository: "handy-computer/cohere-transcribe-03-2026-gguf", revision: "dfa4adebb64f3076b7b6b90b721275cc069cb421", sha256: "931916663432fd895423a4291a8400221802b288967ca2d435fc5e3141c9e71e", architecture: "cohere_asr", variant: "cohere-transcribe-03-2026", bytes: 2410655232, languages: ["en", "fr", "de", "es", "it", "pt", "nl", "pl", "el", "ar", "ja", "zh", "vi", "ko"], acceptsLanguageHint: true, detectsLanguage: false)
    ]
    static func find(_ id: String) -> TranscriptionModel { all.first { $0.id == id } ?? all[0] }
}
