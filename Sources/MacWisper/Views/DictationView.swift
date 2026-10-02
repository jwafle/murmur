import SwiftUI

struct DictationView: View {
    let controller: DictationController
    @AppStorage("shortcutText") private var shortcutText = "Option + Space"
    @AppStorage("alwaysListening") private var alwaysListening = true
    @AppStorage("preRollSeconds") private var preRollSeconds = 3.0

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: controller.isRecording ? "record.circle.fill" : "waveform")
                .font(.system(size: 42, weight: .regular))
                .foregroundStyle(controller.isRecording ? .red : .primary)
                .frame(width: 100, height: 100)
                .glassEffect(.regular, in: .circle)
            Text(controller.isRecording ? "Recording" : "MacWisper")
                .font(.title2.weight(.semibold))
            Text(controller.status)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            WaveformView(
                samples: controller.waveformSamples(for: preRollSeconds),
                color: controller.isRecording ? .orange : .gray
            )
            .frame(height: 54)
            .padding(.horizontal, 20)
            .accessibilityLabel(controller.isRecording ? "Recording waveform" : "Microphone waveform")
            if !controller.modelReady {
                Text(controller.modelStatus).font(.caption).foregroundStyle(.secondary)
                SettingsLink { Label("Set up transcription", systemImage: "arrow.down.circle") }
                    .buttonStyle(.glass)
            }
            Toggle("Keep microphone ready", isOn: $alwaysListening)
                .toggleStyle(.switch)
                .frame(maxWidth: 300)
                .onChange(of: alwaysListening) { _, enabled in
                    controller.settingsChanged()
                    controller.toggleListening(enabled)
                }
            Text("Shortcut: \(shortcutText)")
                .font(.caption)
                .foregroundStyle(.secondary)
            SettingsLink { Label("Configure shortcut", systemImage: "keyboard") }
                .buttonStyle(.glass)
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
