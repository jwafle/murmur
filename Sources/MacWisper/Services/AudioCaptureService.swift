import AVFoundation
import AudioToolbox
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
    var onInputLevel: ((Float) -> Void)?
    private let engine = AVAudioEngine()
    private var format: AVAudioFormat?
    private var preRoll: [AVAudioPCMBuffer] = []
    private var recording: [AVAudioPCMBuffer]? = nil
    private var preRollFrames: AVAudioFramePosition = 0
    private var activeFrames: AVAudioFramePosition = 0
    private var tapInstalled = false
    var preRollSeconds: Double = 3
    var inputDeviceUID = ""
    private let maximumRecordingSeconds: Double = 60

    var isRecording: Bool { recording != nil }
    var isListening: Bool { engine.isRunning }

    func startListening() throws {
        guard !engine.isRunning else { return }
        let input = engine.inputNode
        if !inputDeviceUID.isEmpty {
            guard let deviceID = MicrophoneInput.deviceID(for: inputDeviceUID) else {
                throw NSError(domain: "MacWisper.Audio", code: 2, userInfo: [NSLocalizedDescriptionKey: "The selected microphone is no longer available."])
            }
            guard let audioUnit = input.audioUnit else {
                throw NSError(domain: "MacWisper.Audio", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not configure the selected microphone."])
            }
            var selectedDeviceID = deviceID
            let status = AudioUnitSetProperty(
                audioUnit,
                kAudioOutputUnitProperty_CurrentDevice,
                kAudioUnitScope_Global,
                0,
                &selectedDeviceID,
                UInt32(MemoryLayout<AudioDeviceID>.size)
            )
            guard status == noErr else {
                throw NSError(domain: "MacWisper.Audio", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Could not select the microphone (Core Audio error \(status))."])
            }
        }
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
        onInputLevel?(Self.level(in: buffer))
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

    private static func level(in buffer: AVAudioPCMBuffer) -> Float {
        guard buffer.frameLength > 0 else { return 0.035 }
        var sum: Float = 0
        let count = Int(buffer.frameLength)
        if let channels = buffer.floatChannelData {
            let samples = channels[0]
            for index in 0..<count { sum += samples[index] * samples[index] }
        } else if let channels = buffer.int16ChannelData {
            let samples = channels[0]
            for index in 0..<count {
                let sample = Float(samples[index]) / Float(Int16.max)
                sum += sample * sample
            }
        } else {
            return 0.08
        }
        let rms = sqrt(sum / Float(count))
        return min(1, max(0.035, rms * 5))
    }
}
