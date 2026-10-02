import AVFoundation
import CryptoKit
import CTranscribe
import Foundation

struct TranscriptionFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

// Actor ownership serializes model loading and native inference away from the UI.
actor TranscriptionService {
    private let modelDirectory: URL
    init(directory: URL = TranscriptionService.directory) { modelDirectory = directory }
    private var model: OpaquePointer?
    private var activeID: String?
    private var verifiedPaths: Set<String> = []

    static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Murmur/Models", isDirectory: true)
    }
    static func path(for definition: TranscriptionModel) -> URL {
        directory.appendingPathComponent(definition.filename)
    }
    static func isInstalled(_ definition: TranscriptionModel) -> Bool {
        let attrs = try? FileManager.default.attributesOfItem(atPath: path(for: definition).path)
        return (attrs?[.size] as? NSNumber)?.int64Value == definition.bytes
    }

    deinit { if let model { transcribe_model_free(model) } }

    func prepare(_ definition: TranscriptionModel, download: Bool) async throws {
        let path = modelDirectory.appendingPathComponent(definition.filename)
        if !verifiedPaths.contains(path.path) {
            do {
                try verify(path, definition: definition)
                verifiedPaths.insert(path.path)
            } catch {
                guard download else { throw TranscriptionFailure(message: "Prepare \(definition.name) in Settings → Transcription first. \(error.localizedDescription)") }
                try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
                let (temporary, response) = try await URLSession.shared.download(from: definition.downloadURL)
                defer { try? FileManager.default.removeItem(at: temporary) }
                guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
                    throw TranscriptionFailure(message: "Model download failed. Check your connection and retry.")
                }
                try verify(temporary, definition: definition)
                // Publish only a fully verified artifact; preserve the previous file on failure.
                if FileManager.default.fileExists(atPath: path.path) {
                    _ = try FileManager.default.replaceItemAt(path, withItemAt: temporary)
                } else {
                    try FileManager.default.moveItem(at: temporary, to: path)
                }
                verifiedPaths.insert(path.path)
            }
        }
        try load(definition, path: path)
    }

    private func verify(_ url: URL, definition: TranscriptionModel) throws {
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        guard (attrs[.size] as? NSNumber)?.int64Value == definition.bytes else {
            throw TranscriptionFailure(message: "Model size does not match the pinned artifact. Download it again.")
        }
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        var hash = SHA256()
        while let data = try file.read(upToCount: 1_048_576), !data.isEmpty { hash.update(data: data) }
        guard hash.finalize().map({ String(format: "%02x", $0) }).joined() == definition.sha256 else {
            throw TranscriptionFailure(message: "Model checksum does not match Hex's pinned artifact. Click Download / Prepare Model to download it again.")
        }
    }

    private func check(_ status: transcribe_status) throws {
        guard status == TRANSCRIBE_OK else {
            throw TranscriptionFailure(message: String(cString: transcribe_status_string(Int32(status.rawValue))))
        }
    }

    private func load(_ definition: TranscriptionModel, path: URL) throws {
        guard activeID != definition.id else { return }
        var params = transcribe_model_load_params()
        transcribe_model_load_params_init(&params)
        params.backend = TRANSCRIBE_BACKEND_METAL
        var candidate: OpaquePointer?
        try check(path.path.withCString { transcribe_model_load_file($0, &params, &candidate) })
        guard let candidate else { throw TranscriptionFailure(message: "The model could not be loaded.") }
        guard String(cString: transcribe_model_arch_string(candidate)) == definition.architecture,
              String(cString: transcribe_model_variant_string(candidate)) == definition.variant else {
            transcribe_model_free(candidate)
            throw TranscriptionFailure(message: "Model architecture or variant does not match the catalog.")
        }
        if let model { transcribe_model_free(model) }
        model = candidate
        activeID = definition.id
    }

    func transcribe(_ url: URL, definition: TranscriptionModel, language: String, hints: String) throws -> String {
        guard definition.supports(language) else { throw TranscriptionFailure(message: "Choose a supported language for \(definition.name).") }
        guard activeID == definition.id, let model else { throw TranscriptionFailure(message: "Prepare the selected model in Settings first.") }
        var samples = try Self.readAudio(url)
        samples += Array(repeating: 0, count: max(0, 24_000 - samples.count))
        if definition.id == "parakeet_unified_en" { samples += Array(repeating: 0, count: 3_200) }
        var capabilities = transcribe_capabilities()
        transcribe_capabilities_init(&capabilities)
        try check(transcribe_model_get_capabilities(model, &capabilities))
        let maximumMS = definition.architecture == "cohere_asr"
            ? (capabilities.max_audio_ms > 0 ? min(35_000, capabilities.max_audio_ms) : 35_000)
            : capabilities.max_audio_ms
        let chunkSize = maximumMS > 0 ? Int(maximumMS) * 16 : samples.count
        var results: [String] = []
        for offset in stride(from: 0, to: samples.count, by: chunkSize) {
            var chunk = Array(samples[offset..<min(offset + chunkSize, samples.count)])
            chunk += Array(repeating: 0, count: max(0, 24_000 - chunk.count))
            results.append(try run(chunk, model: model, definition: definition, language: language, hints: hints))
        }
        return results.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.joined(separator: " ")
    }

    private func run(_ samples: [Float], model: OpaquePointer, definition: TranscriptionModel, language: String, hints: String) throws -> String {
        // Recreate the session per chunk so native scratch does not accumulate.
        var session: OpaquePointer?
        try check(transcribe_session_init(model, nil, &session))
        guard let session else { throw TranscriptionFailure(message: "Could not create a transcription session.") }
        defer { transcribe_session_free(session) }
        var params = transcribe_run_params()
        transcribe_run_params_init(&params)
        var whisper = transcribe_whisper_run_ext()
        transcribe_whisper_run_ext_init(&whisper)
        let runtimeLanguage = language == "fil" && definition.architecture == "whisper" ? "tl" : language
        try runtimeLanguage.withCString { lang in
            params.language = definition.acceptsLanguageHint && language != "auto" ? lang : nil
            try hints.withCString { prompt in
                whisper.initial_prompt = hints.isEmpty ? nil : prompt
                try withUnsafePointer(to: &whisper) { ext in
                    if definition.architecture == "whisper" {
                        params.family = UnsafeRawPointer(ext).assumingMemoryBound(to: transcribe_ext.self)
                    }
                    try samples.withUnsafeBufferPointer { buffer in
                        try check(transcribe_run(session, buffer.baseAddress, Int32(buffer.count), &params))
                    }
                }
            }
        }
        return String(cString: transcribe_full_text(session))
    }

    static func readAudio(_ url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false)
        let sourceFormat = file.processingFormat
        guard sourceFormat.sampleRate > 0, sourceFormat.channelCount > 0,
              file.length > 0, file.length <= Int64(sourceFormat.sampleRate * 70),
              let input = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: AVAudioFrameCount(file.length)),
              let monoFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sourceFormat.sampleRate, channels: 1, interleaved: false),
              let mono = AVAudioPCMBuffer(pcmFormat: monoFormat, frameCapacity: AVAudioFrameCount(file.length)),
              let target = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false),
              let converter = AVAudioConverter(from: monoFormat, to: target) else {
            throw TranscriptionFailure(message: "Invalid or oversized recording.")
        }
        try file.read(into: input)
        mono.frameLength = input.frameLength
        guard let channels = input.floatChannelData, let mixed = mono.floatChannelData?[0] else {
            throw TranscriptionFailure(message: "Could not read audio channels.")
        }
        // AVAudioConverter's default channel map can discard stereo channels.
        // Average explicitly before resampling so every microphone channel contributes.
        for frame in 0..<Int(input.frameLength) {
            var sum: Float = 0
            for channel in 0..<Int(sourceFormat.channelCount) { sum += channels[channel][frame] }
            mixed[frame] = sum / Float(sourceFormat.channelCount)
        }
        let capacity = AVAudioFrameCount(ceil(Double(input.frameLength) * 16_000 / sourceFormat.sampleRate)) + 1_024
        guard let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else {
            throw TranscriptionFailure(message: "Could not allocate audio conversion buffer.")
        }
        var supplied = false
        var error: NSError?
        let result = converter.convert(to: output, error: &error) { _, status in
            if supplied { status.pointee = .endOfStream; return nil }
            supplied = true
            status.pointee = .haveData
            return mono
        }
        if let error { throw error }
        guard result != .error, let channel = output.floatChannelData?[0], output.frameLength > 0 else {
            throw TranscriptionFailure(message: "Audio conversion failed.")
        }
        let samples = Array(UnsafeBufferPointer(start: channel, count: Int(output.frameLength)))
        guard samples.allSatisfy(\.isFinite) else { throw TranscriptionFailure(message: "Recording contains invalid audio samples.") }
        return samples
    }
}
