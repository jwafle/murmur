import SwiftUI
import Speech

struct SettingsView: View {
    let controller: DictationController
    @AppStorage("shortcutMode") private var shortcutMode = ShortcutMode.hold.rawValue
    @AppStorage("shortcutText") private var shortcutText = "Option + Space"
    @AppStorage("preRollSeconds") private var preRollSeconds = 3.0
    @AppStorage("historyDays") private var historyDays = 30

    @AppStorage("transcriptionModel") private var transcriptionModel = TranscriptionModel.all[0].id
    @AppStorage("transcriptionLanguage") private var transcriptionLanguage = "en"

    private var model: TranscriptionModel { TranscriptionModel.find(transcriptionModel) }
    private var languageCodes: [String] {
        if transcriptionModel == TranscriptionModel.appleID {
            return SFSpeechRecognizer.supportedLocales().map(\.identifier).sorted()
        }
        let codes = model.languages == ["*"] ? TranscriptionModel.languageCodes : model.languages
        return (model.detectsLanguage ? ["auto"] : []) + codes.sorted()
    }

    var body: some View {
        Form {
            Section("Transcription") {
                Picker("Model", selection: $transcriptionModel) {
                    ForEach(TranscriptionModel.all) { model in Text(model.name).tag(model.id) }
                    Text("Apple Speech").tag(TranscriptionModel.appleID)
                }
                Picker("Language", selection: $transcriptionLanguage) {
                    ForEach(languageCodes, id: \.self) { code in
                        Text(code == "auto" ? "Detect automatically" : Locale.current.localizedString(forIdentifier: code) ?? code).tag(code)
                    }
                }
                if transcriptionModel != TranscriptionModel.appleID {
                    Text("\(model.sizeLabel) download · runs locally with transcribe.cpp")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text(controller.modelStatus).font(.caption).foregroundStyle(.secondary)
                Button(controller.isPreparingModel ? "Preparing…" : "Download / Prepare Model") {
                    Task { await controller.prepareSelectedModel() }
                }
                .disabled(controller.isPreparingModel || controller.isRecording || controller.isTranscribing)
                if controller.isPreparingModel { ProgressView() }
            }
            .disabled(controller.isRecording || controller.isTranscribing || controller.isPreparingModel)
            Section("Shortcut") {
                Picker("Activation", selection: $shortcutMode) {
                    ForEach(ShortcutMode.allCases) { mode in Text(mode.rawValue).tag(mode.rawValue) }
                }
                ShortcutRecorder(shortcut: $shortcutText, controller: controller)
            }
            Section("Audio") {
                Slider(value: $preRollSeconds, in: 1...8, step: 1) {
                    Text("Pre-roll")
                } minimumValueLabel: { Text("1s") } maximumValueLabel: { Text("8s") }
                Text("Include the previous \(Int(preRollSeconds)) seconds before you press the shortcut.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("History") {
                Picker("Keep recordings and text", selection: $historyDays) {
                    Text("7 days").tag(7)
                    Text("30 days").tag(30)
                    Text("90 days").tag(90)
                    Text("1 year").tag(365)
                }
            }
            Section("Permissions") {
                Text("Microphone access is required to dictate. Speech Recognition access is needed only for Apple Speech. Accessibility access is used for the global shortcut and pasting into the active app.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Open Privacy & Security Settings") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                }
            }
        }
        .formStyle(.grouped)
        .onChange(of: transcriptionModel) { _, _ in
            if !languageCodes.contains(transcriptionLanguage) { transcriptionLanguage = languageCodes.contains("en") ? "en" : languageCodes[0] }
            controller.transcriptionSettingsChanged()
        }
        .onChange(of: transcriptionLanguage) { _, _ in controller.transcriptionSettingsChanged() }
        .onChange(of: shortcutMode) { _, _ in controller.settingsChanged() }
        .onChange(of: shortcutText) { _, _ in controller.settingsChanged() }
        .onChange(of: preRollSeconds) { _, _ in controller.settingsChanged() }
        .onChange(of: historyDays) { _, _ in controller.settingsChanged() }
    }
}
