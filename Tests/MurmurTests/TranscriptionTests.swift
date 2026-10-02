import AVFoundation
import CTranscribe
import XCTest
@testable import Murmur

final class TranscriptionTests: XCTestCase {
    func testNativeABIAndMetalBackend() {
        XCTAssertEqual(String(cString: transcribe_version()), "0.1.3")
        XCTAssertTrue(transcribe_backend_available(TRANSCRIBE_BACKEND_METAL))
    }

    func testLanguageConstraints() {
        XCTAssertFalse(TranscriptionModel.find("parakeet_unified_en").supports("auto"))
        XCTAssertFalse(TranscriptionModel.find("parakeet_v2").supports("fr"))
        XCTAssertTrue(TranscriptionModel.find("parakeet_v3").supports("fr"))
        XCTAssertTrue(TranscriptionModel.find("whisper_large_v3_turbo").supports("auto"))
        XCTAssertTrue(TranscriptionModel.find("qwen3_asr06_b").supports("yue"))
        XCTAssertFalse(TranscriptionModel.find("sense_voice_small").supports("fr"))
        XCTAssertFalse(TranscriptionModel.find("cohere_transcribe").supports("auto"))
    }

    func testStereoResamplingPreservesDurationAndMixesChannels() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("audio-test-\(UUID()).wav")
        defer { try? FileManager.default.removeItem(at: url) }
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48_000, channels: 2, interleaved: false)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 48_000)!
        buffer.frameLength = 48_000
        for index in 0..<48_000 {
            buffer.floatChannelData![0][index] = 0.25
            buffer.floatChannelData![1][index] = 0.75
        }
        do {
            let file = try AVAudioFile(forWriting: url, settings: format.settings)
            try file.write(from: buffer)
        }
        let samples = try TranscriptionService.readAudio(url)
        XCTAssertEqual(Double(samples.count), 16_000, accuracy: 32)
        XCTAssertEqual(samples[8_000], 0.5, accuracy: 0.01)
    }

    // Set these paths to opt into actual Metal inference without recording a microphone.
    func testPinnedParakeetSpeechFixture() async throws {
        guard let modelPath = ProcessInfo.processInfo.environment["MURMUR_TEST_MODEL"],
              let audioPath = ProcessInfo.processInfo.environment["MURMUR_TEST_AUDIO"] else {
            throw XCTSkip("Set MURMUR_TEST_MODEL and MURMUR_TEST_AUDIO for native inference.")
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("model-test-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let definition = TranscriptionModel.all[0]
        try FileManager.default.linkItem(at: URL(fileURLWithPath: modelPath), to: directory.appendingPathComponent(definition.filename))
        let service = TranscriptionService(directory: directory)
        try await service.prepare(definition, download: false)
        let text = try await service.transcribe(URL(fileURLWithPath: audioPath), definition: definition, language: "en", hints: "")
        XCTAssertTrue(text.lowercased().contains("quick brown fox"), "Unexpected transcript: \(text)")
        let again = try await service.transcribe(URL(fileURLWithPath: audioPath), definition: definition, language: "en", hints: "")
        XCTAssertEqual(text, again)
    }
}
