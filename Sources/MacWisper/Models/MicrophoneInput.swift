import CoreAudio
import Foundation

struct MicrophoneInput: Identifiable, Hashable {
    let id: String
    let name: String

    static func available() -> [MicrophoneInput] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize) == noErr else {
            return []
        }

        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &deviceIDs) == noErr else {
            return []
        }

        return deviceIDs.compactMap { deviceID in
            guard hasInputChannels(deviceID), isUserFacingInput(deviceID),
                  let uid = stringProperty(kAudioDevicePropertyDeviceUID, on: deviceID),
                  let name = stringProperty(kAudioObjectPropertyName, on: deviceID) else { return nil }
            return MicrophoneInput(id: uid, name: name)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func deviceID(for uid: String) -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyTranslateUIDToDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var cfUID: CFString? = uid as CFString
        var deviceID = AudioDeviceID(kAudioObjectUnknown)
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = withUnsafeBytes(of: &cfUID) { qualifier in
            AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                UInt32(MemoryLayout<CFString?>.size),
                qualifier.baseAddress,
                &dataSize,
                &deviceID
            )
        }
        return status == noErr && deviceID != AudioObjectID(kAudioObjectUnknown) ? deviceID : nil
    }

    private static func stringProperty(_ selector: AudioObjectPropertySelector, on deviceID: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: CFString?
        var dataSize = UInt32(MemoryLayout<CFString?>.size)
        let status = withUnsafeMutableBytes(of: &value) { output in
            AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, output.baseAddress!)
        }
        guard status == noErr, let value else { return nil }
        return value as String
    }

    private static func hasInputChannels(_ deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &dataSize) == noErr, dataSize > 0 else { return false }
        let storage = UnsafeMutableRawPointer.allocate(byteCount: Int(dataSize), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { storage.deallocate() }
        let buffers = storage.assumingMemoryBound(to: AudioBufferList.self)
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, buffers) == noErr else { return false }
        return UnsafeMutableAudioBufferListPointer(buffers).contains { $0.mNumberChannels > 0 }
    }

    private static func isUserFacingInput(_ deviceID: AudioDeviceID) -> Bool {
        guard let transport = integerProperty(kAudioDevicePropertyTransportType, on: deviceID) else { return true }
        return ![
            kAudioDeviceTransportTypeAggregate,
            kAudioDeviceTransportTypeVirtual,
            kAudioDeviceTransportTypeAirPlay,
            kAudioDeviceTransportTypeRemoteScreen,
            kAudioDeviceTransportTypeRemoteStreaming
        ].contains(transport)
    }

    private static func integerProperty(_ selector: AudioObjectPropertySelector, on deviceID: AudioDeviceID) -> UInt32? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: UInt32 = 0
        var dataSize = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &value) == noErr else { return nil }
        return value
    }
}
