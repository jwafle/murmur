import SwiftUI
import AppKit

struct ShortcutRecorder: View {
    @Binding var shortcut: String
    let controller: DictationController
    @State private var isRecording = false
    @State private var monitor: Any?
    @State private var pending: (keyCode: UInt16, value: String)?
    @State private var hint = "Click to record, then press a modifier and a key."

    var body: some View {
        HStack {
            Text("Key combination")
            Spacer()
            Button {
                if isRecording { finish() } else { begin() }
            } label: {
                Text(isRecording ? "Press shortcut…" : shortcut)
                    .monospaced()
                    .frame(minWidth: 180)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.glass)
            .accessibilityLabel(isRecording ? "Cancel shortcut recording" : "Record keyboard shortcut, currently \(shortcut)")
        }
        Text(isRecording ? hint : "Click the box to record a shortcut. Escape cancels.")
            .font(.caption)
            .foregroundStyle(.secondary)
        .onDisappear { finish() }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in finish() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in finish() }
    }

    private func begin() {
        controller.setRecordingShortcut(true)
        pending = nil
        hint = "Press a modifier and a key. Escape cancels."
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { event in
            guard isRecording else { return event }
            if event.type == .keyUp {
                if let pending, pending.keyCode == event.keyCode {
                    shortcut = pending.value
                    finish()
                }
                return nil
            }
            guard !event.isARepeat, pending == nil else { return nil }
            if event.keyCode == 53 && event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty {
                finish()
            } else if let value = ParsedShortcut.recorded(from: event) {
                pending = (event.keyCode, value)
                hint = "Release the keys to save \(value)."
            } else {
                hint = "Use a modifier with a letter, number, Space, Tab, Return, Escape, −, or =."
            }
            return nil
        }
    }

    private func finish() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        pending = nil
        isRecording = false
        controller.setRecordingShortcut(false)
    }
}
