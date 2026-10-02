import SwiftUI
import Speech

struct DictionaryView: View {
    let controller: DictationController
    @State private var grapheme = ""
    @State private var phonemes = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Custom words")
                .font(.title2.weight(.semibold))
            Text("Written words provide recognition hints for Whisper. Optional X-SAMPA pronunciations are used only by Apple Speech. Other transcribe.cpp models do not support custom word hints.")
                .font(.callout)
                .foregroundStyle(.secondary)
            HStack {
                TextField("Written word", text: $grapheme)
                TextField("X-SAMPA phonemes", text: $phonemes)
                Button("Add") {
                    controller.addDictionaryTerm(grapheme.trimmingCharacters(in: .whitespacesAndNewlines), phonemes: phonemes.trimmingCharacters(in: .whitespacesAndNewlines))
                    grapheme = ""
                    phonemes = ""
                }
                .disabled(grapheme.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            List {
                ForEach(controller.dictionary) { term in
                    HStack {
                        Text(term.grapheme).fontWeight(.medium)
                        Spacer()
                        Text(term.phonemes.isEmpty ? "No phonemes" : term.phonemes)
                            .foregroundStyle(.secondary)
                        Button(role: .destructive) { controller.removeDictionaryTerm(term) } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            .listStyle(.inset)
            Text("Available X-SAMPA symbols depend on the selected Apple Speech locale.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .textFieldStyle(.roundedBorder)
    }
}
