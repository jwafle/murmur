import AppKit
import AVFoundation
import Observation
import Speech

@Observable
@MainActor
final class DictationController {
    private(set) var history: [DictationEntry] = []
    private(set) var dictionary: [DictionaryTerm] = []
    private(set) var status = "Checking permissions…"
    private(set) var isListening = false
    private(set) var isRecording = false
    private(set) var selectedEntry: UUID?
    private(set) var isPreparingModel = false
    private(set) var isTranscribing = false
    private(set) var modelReady = false
    private(set) var modelStatus = "Choose and prepare a model in Settings."
    private let transcription = TranscriptionService()

    var selectedModelID: String { UserDefaults.standard.string(forKey: "transcriptionModel") ?? TranscriptionModel.all[0].id }
    var selectedLanguage: String { UserDefaults.standard.string(forKey: "transcriptionLanguage") ?? "en" }

    func prepareSelectedModel(download: Bool = true) async {
        guard !isPreparingModel, !isRecording, !isTranscribing else { return }
        isPreparingModel = true
        modelReady = false
        let id = selectedModelID
        defer { isPreparingModel = false }
        if id == TranscriptionModel.appleID {
            let authorization = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
            }
            guard authorization == .authorized else {
                modelStatus = "Allow Speech Recognition for Apple Speech in System Settings."
                return
            }
            recognizer = SFSpeechRecognizer(locale: Locale(identifier: selectedLanguage))
            modelReady = recognizer?.supportsOnDeviceRecognition == true
            modelStatus = modelReady ? "Apple Speech ready" : "Apple Speech is unavailable for this language."
            return
        }
        let definition = TranscriptionModel.find(id)
        modelStatus = TranscriptionService.isInstalled(definition) ? "Verifying and loading \(definition.name)…" : "Downloading \(definition.name) (\(definition.sizeLabel))…"
        do {
            try await transcription.prepare(definition, download: download)
            modelReady = true
            modelStatus = "\(definition.name) ready · on-device Metal"
        } catch {
            modelStatus = error.localizedDescription
        }
    }

    func transcriptionSettingsChanged() {
        modelReady = false
        modelStatus = "Prepare the selected model to dictate."
    }

    private let audio = AudioCaptureService()
    private let historyStore = HistoryStore()
    private let dictionaryService = CustomDictionaryService()
    private let shortcut = ShortcutService()
    private let indicator = DictationIndicator()
    private var recognizer: SFSpeechRecognizer?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioPlayer: AVAudioPlayer?

    init() {
        refresh()
        audio.onLimitReached = { [weak self] in self?.stopDictation() }
        shortcut.onReadinessChanged = { [weak self] ready in
            guard let self, !self.isRecording, !self.isTranscribing, self.isListening else { return }
            self.status = ready ? "Listening for \(self.shortcut.shortcut)" : "Enable Accessibility access to use the global shortcut."
        }
        shortcut.onStart = { [weak self] in self?.beginDictation() }
        shortcut.onStop = { [weak self] in self?.stopDictation() }
    }

    func start() async {
        UserDefaults.standard.register(defaults: ["alwaysListening": true, "preRollSeconds": 3.0, "historyDays": 30, "shortcutText": "Option + Space", "shortcutMode": ShortcutMode.hold.rawValue])
        shortcut.shortcut = UserDefaults.standard.string(forKey: "shortcutText") ?? "Option + Space"
        shortcut.mode = ShortcutMode(rawValue: UserDefaults.standard.string(forKey: "shortcutMode") ?? "Hold to dictate") ?? .hold
        shortcut.start()
        historyStore.purge(olderThanDays: UserDefaults.standard.integer(forKey: "historyDays").nonZero(or: 30))
        let microphone = await AVCaptureDevice.requestAccess(for: .audio)
        guard microphone else { status = "Allow Microphone access in System Settings to continue."; return }
        if selectedModelID == TranscriptionModel.appleID || TranscriptionService.isInstalled(TranscriptionModel.find(selectedModelID)) {
            await prepareSelectedModel(download: false)
        }
        if UserDefaults.standard.bool(forKey: "alwaysListening") {
            do {
                audio.preRollSeconds = UserDefaults.standard.double(forKey: "preRollSeconds")
                try audio.startListening()
                isListening = true
                status = shortcut.isReady ? "Listening for \(shortcut.shortcut)" : "Enable Accessibility access to use the global shortcut."
            } catch {
                status = "Microphone unavailable: \(error.localizedDescription)"
            }
        } else {
            status = "Microphone paused"
        }
    }

    func setRecordingShortcut(_ recording: Bool) {
        shortcut.setRecordingShortcut(recording)
    }

    func settingsChanged() {
        shortcut.shortcut = UserDefaults.standard.string(forKey: "shortcutText") ?? "Option + Space"
        shortcut.mode = ShortcutMode(rawValue: UserDefaults.standard.string(forKey: "shortcutMode") ?? "Hold to dictate") ?? .hold
        audio.preRollSeconds = UserDefaults.standard.double(forKey: "preRollSeconds")
        let days = UserDefaults.standard.integer(forKey: "historyDays").nonZero(or: 30)
        historyStore.purge(olderThanDays: days)
        refresh()
    }

    func addDictionaryTerm(_ grapheme: String, phonemes: String) {
        dictionaryService.add(grapheme: grapheme, phonemes: phonemes)
        dictionary = dictionaryService.terms
    }

    func removeDictionaryTerm(_ term: DictionaryTerm) {
        dictionaryService.remove(term)
        dictionary = dictionaryService.terms
    }

    func delete(_ entry: DictationEntry) {
        historyStore.delete(entry)
        refresh()
    }

    func select(_ entry: DictationEntry) { selectedEntry = entry.id }

    func play(_ entry: DictationEntry) {
        let url = historyStore.directory.appendingPathComponent(entry.audioFileName)
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } catch {
            status = "Could not play recording: \(error.localizedDescription)"
        }
    }

    func toggleListening(_ enabled: Bool) {
        if enabled {
            do { audio.preRollSeconds = UserDefaults.standard.double(forKey: "preRollSeconds"); try audio.startListening(); isListening = true; status = shortcut.isReady ? "Listening for \(shortcut.shortcut)" : "Enable Accessibility access to use the global shortcut." }
            catch { status = error.localizedDescription }
        } else {
            audio.stopListening()
            isListening = false
            status = "Microphone paused"
        }
    }

    private func beginDictation() {
        guard !isRecording, !isTranscribing, !isPreparingModel else { return }
        guard modelReady else { status = "Prepare your transcription model in Settings first."; return }
        if selectedModelID != TranscriptionModel.appleID && !TranscriptionModel.find(selectedModelID).supports(selectedLanguage) {
            status = "Choose a supported transcription language in Settings."
            return
        }
        if !isListening {
            do {
                audio.preRollSeconds = UserDefaults.standard.bool(forKey: "alwaysListening")
                    ? UserDefaults.standard.double(forKey: "preRollSeconds") : 0
                try audio.startListening()
                isListening = true
            } catch {
                status = "Could not start microphone: \(error.localizedDescription)"
                return
            }
        }
        audio.beginRecording()
        isRecording = true
        indicator.show()
        status = "Recording…"
    }

    private func stopDictation() {
        guard isRecording else { return }
        isRecording = false
        indicator.release()
        do {
            guard let audioURL = try audio.finishRecording(in: historyStore.directory) else { status = "No audio captured"; return }
            if !UserDefaults.standard.bool(forKey: "alwaysListening") {
                audio.stopListening()
                isListening = false
            }
            status = "Transcribing…"
            transcribe(audioURL)
        } catch {
            status = "Could not save recording: \(error.localizedDescription)"
        }
    }

    private func transcribe(_ url: URL) {
        if selectedModelID != TranscriptionModel.appleID {
            isTranscribing = true
            let definition = TranscriptionModel.find(selectedModelID)
            let language = selectedLanguage
            let hints = dictionary.map(\.grapheme).joined(separator: ", ")
            Task {
                defer { isTranscribing = false }
                do {
                    let text = try await transcription.transcribe(url, definition: definition, language: language, hints: hints)
                    completeTranscription(text, url: url)
                } catch { status = "Transcription failed: \(error.localizedDescription)" }
            }
            return
        }
        transcribeWithApple(url)
    }

    private func completeTranscription(_ transcript: String, url: URL) {
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { status = "No speech recognized"; return }
        historyStore.add(transcript: text, audioURL: url)
        history = historyStore.entries
        copyAndPaste(text)
        status = "Copied and pasted · \(shortcut.shortcut) to dictate again"
    }

    private func transcribeWithApple(_ url: URL) {
        guard let recognizer, recognizer.isAvailable else { status = "Apple Speech is unavailable right now."; return }
        isTranscribing = true
        Task { [self] in
            let request = SFSpeechURLRecognitionRequest(url: url)
            request.shouldReportPartialResults = false
            request.requiresOnDeviceRecognition = true
            request.contextualStrings = dictionary.map(\.grapheme)
            do { request.customizedLanguageModel = try await dictionaryService.prepareModel(locale: recognizer.locale) }
            catch { /* Contextual phrases remain a useful fallback when model compilation is unsupported. */ }
            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let result, result.isFinal {
                        self.recognitionTask = nil
                        self.isTranscribing = false
                        self.completeTranscription(result.bestTranscription.formattedString, url: url)
                    } else if let error {
                        self.recognitionTask = nil
                        self.isTranscribing = false
                        self.status = "Transcription failed: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    private func copyAndPaste(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let source = CGEventSource(stateID: .combinedSessionState)
            let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
            down?.flags = .maskCommand
            let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
            up?.flags = .maskCommand
            down?.post(tap: .cghidEventTap)
            up?.post(tap: .cghidEventTap)
        }
    }

    private func refresh() {
        history = historyStore.entries
        dictionary = dictionaryService.terms
    }
}

private extension Int {
    func nonZero(or fallback: Int) -> Int { self == 0 ? fallback : self }
}
