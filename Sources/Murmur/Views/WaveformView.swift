import SwiftUI

struct WaveformView: View {
    var samples: [CGFloat]
    var color: Color
    var progress: Double? = nil
    var onSeek: ((Double) -> Void)? = nil

    private let barCount = 72

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let spacing: CGFloat = 2
                let barWidth = max(1, (size.width - spacing * CGFloat(barCount - 1)) / CGFloat(barCount))
                let midY = size.height / 2
                let progressX = size.width * CGFloat(progress ?? 0)

                for index in 0..<barCount {
                    let value = level(at: index)
                    let height = max(3, min(size.height, value * size.height * 1.9))
                    let x = CGFloat(index) * (barWidth + spacing)
                    let rect = CGRect(x: x, y: midY - height / 2, width: barWidth, height: height)
                    let played = progress == nil || x + barWidth / 2 <= progressX
                    context.fill(Path(roundedRect: rect, cornerRadius: barWidth / 2), with: .color(played ? color : Color.secondary.opacity(0.28)))
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard onSeek != nil else { return }
                        onSeek?(min(1, max(0, value.location.x / max(geometry.size.width, 1))))
                    }
            )
        }
        .accessibilityLabel("Audio waveform")
    }

    private func level(at index: Int) -> CGFloat {
        guard !samples.isEmpty else {
            let x = CGFloat(index)
            return 0.08 + abs(sin(x * 0.51) * cos(x * 0.19)) * 0.32
        }
        let sourceIndex = index * (samples.count - 1) / (barCount - 1)
        return samples[sourceIndex]
    }
}
