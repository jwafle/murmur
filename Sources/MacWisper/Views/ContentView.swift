import SwiftUI

struct ContentView: View {
    let controller: DictationController
    @State private var selection: Destination? = .dictation

    private enum Destination: String, CaseIterable, Identifiable {
        case dictation = "Dictation", dictionary = "Dictionary", history = "History"
        var id: Self { self }
        var symbol: String {
            switch self {
            case .dictation: "waveform"
            case .dictionary: "character.book.closed"
            case .history: "clock"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(Destination.allCases, selection: $selection) { destination in
                Label(destination.rawValue, systemImage: destination.symbol)
                    .tag(destination)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 190)
            .navigationTitle("MacWisper")
        } detail: {
            Group {
                switch selection ?? .dictation {
                case .dictation: DictationView(controller: controller)
                case .dictionary: DictionaryView(controller: controller).padding(24)
                case .history: HistoryView(controller: controller)
                }
            }
            .navigationTitle((selection ?? .dictation).rawValue)
            .toolbar {
                ToolbarItem {
                    SettingsLink { Label("Settings", systemImage: "gearshape") }
                }
            }
        }
    }
}
