import AVFoundation
import Foundation

private extension AVAudioPCMBuffer {
    func cloned() -> AVAudioPCMBuffer? {
        guard let copy = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else { return nil }
        copy.frameLength = frameLength
        let source = UnsafeMutableAudioBufferListPointer(mutableAudioBufferList)
        let target = UnsafeMutableAudioBufferListPointer(copy.mutableAudioBufferList)
        for index in 0..<min(source.count, target.count) {
            guard let src = source[index].mData, let dst = target[index].mData else { continue }
            memcpy(dst, src, Int(source[index].mDataByteSize))
            target[index].mDataByteSize = source[index].mDataByteSize
        }
        return copy
    }
}

@MainActor
final class AudioCaptureService {
    var onLimitReached: (() -> Void)?
    private let engine = AVAudioEngine()
    private var format: AVAudioFormat?
    private var preRoll: [AVAudioPCMBuffer] = []
    private var recording: [AVAudioPCMBuffer]? = nil
    private var preRollFrames: AVAudioFramePosition = 0
    private var activeFrames: AVAudioFramePosition = 0
    private var tapInstalled = false
    var preRollSeconds: Double = 3
    private let maximumRecordingSeconds: Double = 60

    var isRecording: Bool { recording != nil }
    var isListening: Bool { engine.isRunning }

    func startListening() throws {
        guard !engine.isRunning else { return }
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw NSError(domain: "MacWisper.Audio", code: 1, userInfo: [NSLocalizedDescriptionKey: "No microphone input is available."])
        }
        format = inputFormat
        if !tapInstalled {
            input.installTap(onBus: 0, bufferSize: 1_024, format: inputFormat) { [weak self] buffer, _ in
                guard let copy = buffer.cloned() else { return }
                Task { @MainActor [weak self] in self?.receive(copy) }
            }
            tapInstalled = true
        }
        engine.prepare()
        try engine.start()
    }

    func beginRecording() {
        guard recording == nil else { return }
        recording = preRoll
        activeFrames = 0
    }

    func finishRecording(in directory: URL) throws -> URL? {
        guard let captured = recording, !captured.isEmpty, let format else { recording = nil; return nil }
        recording = nil
        let url = directory.appendingPathComponent("capture-\(UUID().uuidString).wav")
        let file = try AVAudioFile(forWriting: url, settings: format.settings, commonFormat: format.commonFormat, interleaved: format.isInterleaved)
        for buffer in captured { try file.write(from: buffer) }
        return url
    }

    func stopListening() {
        recording = nil
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        engine.stop()
        preRoll.removeAll()
        preRollFrames = 0
    }

    private func receive(_ buffer: AVAudioPCMBuffer) {
        if var active = recording {
            active.append(buffer)
            recording = active
            activeFrames += AVAudioFramePosition(buffer.frameLength)
            if let format, Double(activeFrames) / format.sampleRate >= maximumRecordingSeconds {
                onLimitReached?()
            }
            return
        }
        preRoll.append(buffer)
        preRollFrames += AVAudioFramePosition(buffer.frameLength)
        guard let format else { return }
        let targetFrames = AVAudioFramePosition(format.sampleRate * preRollSeconds)
        while preRollFrames > targetFrames, let first = preRoll.first {
            preRollFrames -= AVAudioFramePosition(first.frameLength)
            preRoll.removeFirst()
        }
    }
}
