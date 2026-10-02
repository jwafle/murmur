import AppKit
import ApplicationServices

@MainActor
final class ShortcutService {
    var onStart: (() -> Void)?
    var onStop: (() -> Void)?
    var mode: ShortcutMode = .hold
    var shortcut = "Option + Space" { didSet { tapState.update(shortcut) } }
    private(set) var isReady = false
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private let tapState = ShortcutTapState("Option + Space")
    private var tapContext: ShortcutTapContext?
    private var retryTimer: Timer?
    var onReadinessChanged: ((Bool) -> Void)?
    private var isDown = false
    private var isActive = false

    func setRecordingShortcut(_ recording: Bool) {
        tapState.setSuspended(recording)
        if recording {
            isDown = false
            if isActive { isActive = false; onStop?() }
        }
    }

    func start() {
        if retryTimer == nil {
            retryTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.installTap() }
            }
        }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        installTap()
    }

    private func installTap() {
        guard tap == nil, AXIsProcessTrusted() else { return }
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        let context = ShortcutTapContext(service: self, state: tapState)
        tapContext = context
        let pointer = Unmanaged.passUnretained(context).toOpaque()
        tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: CGEventMask(mask), callback: { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let context = Unmanaged<ShortcutTapContext>.fromOpaque(userInfo).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                MainActor.assumeIsolated {
                    if let service = context.service {
                        if let tap = service.tap { CGEvent.tapEnable(tap: tap, enable: true) }
                        service.isDown = false
                        if service.isActive { service.isActive = false; service.onStop?() }
                    }
                }
                return Unmanaged.passUnretained(event)
            }
            guard context.state.matches(type: type, event: event) else { return Unmanaged.passUnretained(event) }
            MainActor.assumeIsolated { context.service?.handle(type: type, event: event) }
            return nil
        }, userInfo: pointer)
        if let tap {
            source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            if let source { CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes) }
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        isReady = tap != nil
        onReadinessChanged?(isReady)
    }

    private func handle(type: CGEventType, event: CGEvent) {
        guard let configured = ParsedShortcut(shortcut) else { return }
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags.intersection([.maskCommand, .maskAlternate, .maskShift, .maskControl])
        guard keyCode == configured.keyCode else { return }
        if type == .keyDown, !isDown, flags != configured.flags { return }
        if type == .keyDown {
            guard !isDown else { return }
            isDown = true
            switch mode {
            case .hold: isActive = true; onStart?()
            case .toggle:
                isActive.toggle()
                isActive ? onStart?() : onStop?()
            }
        } else if type == .keyUp {
            isDown = false
            if mode == .hold, isActive { isActive = false; onStop?() }
        }
    }
}

private final class ShortcutTapContext: @unchecked Sendable {
    weak var service: ShortcutService?
    let state: ShortcutTapState

    init(service: ShortcutService, state: ShortcutTapState) {
        self.service = service
        self.state = state
    }
}

final class ShortcutTapState: @unchecked Sendable {
    private let lock = NSLock()
    private var parsed: ParsedShortcut?
    private var suspended = false
    private var capturedKey: UInt16?

    init(_ shortcut: String) { parsed = ParsedShortcut(shortcut) }

    func update(_ shortcut: String) {
        lock.lock()
        parsed = ParsedShortcut(shortcut)
        lock.unlock()
    }

    func setSuspended(_ value: Bool) {
        lock.lock()
        suspended = value
        lock.unlock()
    }

    func matches(type: CGEventType, event: CGEvent) -> Bool {
        guard type == .keyDown || type == .keyUp else { return false }
        lock.lock()
        defer { lock.unlock() }
        guard !suspended, let parsed else { return false }
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags.intersection([.maskCommand, .maskAlternate, .maskShift, .maskControl])
        if keyCode == capturedKey {
            if type == .keyUp { capturedKey = nil }
            return true
        }
        if type == .keyDown, keyCode == parsed.keyCode, flags == parsed.flags {
            capturedKey = keyCode
            return true
        }
        return false
    }
}

struct ParsedShortcut {
    let keyCode: UInt16
    let flags: CGEventFlags

    init?(_ value: String) {
        let pieces = value.split(separator: "+").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        guard let key = pieces.last else { return nil }
        let keys = Self.keys
        guard let code = keys[key] else { return nil }
        keyCode = code
        var parsed: CGEventFlags = []
        for modifier in pieces.dropLast() {
            switch modifier {
            case "option", "alt": parsed.insert(.maskAlternate)
            case "command", "cmd", "⌘": parsed.insert(.maskCommand)
            case "control", "ctrl", "⌃": parsed.insert(.maskControl)
            case "shift", "⇧": parsed.insert(.maskShift)
            default: return nil
            }
        }
        flags = parsed
    }

    static let keys: [String: UInt16] = ["space": 49, "return": 36, "tab": 48, "escape": 53, "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "=": 24, "9": 25, "7": 26, "-": 27, "8": 28, "0": 29, "o": 31, "u": 32, "i": 34, "p": 35, "l": 37, "j": 38, "k": 40, "n": 45, "m": 46]

    static func recorded(from event: NSEvent) -> String? {
        guard let key = keys.first(where: { $0.value == event.keyCode })?.key else { return nil }
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard !flags.isEmpty else { return nil }
        var parts: [String] = []
        if flags.contains(.control) { parts.append("Control") }
        if flags.contains(.option) { parts.append("Option") }
        if flags.contains(.shift) { parts.append("Shift") }
        if flags.contains(.command) { parts.append("Command") }
        parts.append(key.count == 1 ? key.uppercased() : key.capitalized)
        return parts.joined(separator: " + ")
    }
}
