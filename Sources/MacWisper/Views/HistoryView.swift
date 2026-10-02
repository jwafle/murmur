import SwiftUI

struct HistoryView: View {
    let controller: DictationController
    @State private var selection: UUID?

    var body: some View {
        HStack(spacing: 0) {
            List(selection: $selection) {
                ForEach(controller.history) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.transcript).lineLimit(2)
                        Text(entry.createdAt, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(entry.id)
                    .contextMenu {
                        Button("Copy transcription") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(entry.transcript, forType: .string)
                        }
                        Button("Delete", role: .destructive) {
                            controller.delete(entry)
                        }
                    }
                }
            }
            .frame(minWidth: 240)
            if let entry = controller.history.first(where: { $0.id == selection }) {
                Divider()
                VStack(alignment: .leading, spacing: 14) {
                    Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .foregroundStyle(.secondary)
                    Text(entry.transcript).textSelection(.enabled)
                    Spacer()
                    HStack {
                        Button("Play recording") { controller.play(entry) }
                        Button("Copy") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(entry.transcript, forType: .string)
                        }
                        Button("Delete", role: .destructive) { controller.delete(entry); selection = nil }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ContentUnavailableView("No dictation selected", systemImage: "waveform")
                    .frame(maxWidth: .infinity)
            }
        }
    }
}
