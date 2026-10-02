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
                    VStack(spacing: 12) {
                        WaveformView(
                            samples: controller.playbackEntryID == entry.id ? controller.playbackSamples : [],
                            color: .orange,
                            progress: controller.playbackEntryID == entry.id ? controller.playbackProgress : 0,
                            onSeek: { controller.seekPlayback(to: $0) }
                        )
                        .frame(height: 48)
                        HStack {
                            Text(Self.timeString(controller.playbackEntryID == entry.id ? controller.playbackTime : 0))
                            Spacer()
                            Text("−\(Self.timeString(controller.playbackEntryID == entry.id ? max(0, controller.playbackDuration - controller.playbackTime) : 0))")
                        }
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        HStack(spacing: 24) {
                            Button { controller.seekPlayback(to: max(0, controller.playbackProgress - 15 / max(controller.playbackDuration, 1))) } label: {
                                Image(systemName: "gobackward.15").font(.title3)
                            }
                            .buttonStyle(.plain)
                            Button { controller.play(entry) } label: {
                                Image(systemName: controller.isPlaying && controller.playbackEntryID == entry.id ? "pause.fill" : "play.fill")
                                    .font(.title2.weight(.semibold))
                                    .frame(width: 52, height: 52)
                                    .background(.orange, in: Circle())
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(controller.isPlaying && controller.playbackEntryID == entry.id ? "Pause recording" : "Play recording")
                            Button { controller.seekPlayback(to: min(1, controller.playbackProgress + 15 / max(controller.playbackDuration, 1))) } label: {
                                Image(systemName: "goforward.15").font(.title3)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Spacer()
                    HStack {
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
        .onChange(of: selection) { _, id in
            guard let entry = controller.history.first(where: { $0.id == id }) else { return }
            controller.preparePlayback(entry)
        }
    }

    private static func timeString(_ time: TimeInterval) -> String {
        let seconds = max(0, Int(time))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
