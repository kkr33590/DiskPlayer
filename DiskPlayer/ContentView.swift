import SwiftUI
import AVKit

struct ContentView: View {
    @State private var input = ""
    @State private var player: AVPlayer?
    @State private var webURL: URL?
    @State private var found: [URL] = []
    @State private var message: String?

    private let nativeExts = ["mp4", "m4v", "mov", "m3u8", "mp3", "m4a", "aac", "wav"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack {
                    TextField("Paste Diskwala or video link", text: $input)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    Button("Paste") { input = UIPasteboard.general.string ?? "" }
                        .buttonStyle(.bordered)
                }
                Button { start() } label: {
                    Label("Play", systemImage: "play.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                if let message {
                    Text(message).foregroundColor(.red).font(.footnote)
                }

                if player == nil, !found.isEmpty {
                    Button { playNative(found[0]) } label: {
                        Label("Video found – play in native player (\(found.count))",
                              systemImage: "play.rectangle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent).tint(.green)
                }

                if player != nil, webURL != nil {
                    Button("Back to page") { player?.pause(); player = nil }
                        .buttonStyle(.bordered)
                }

                Group {
                    if let player {
                        VideoPlayer(player: player)
                    } else if let webURL {
                        WebView(url: webURL) { u in
                            if !found.contains(u) { found.append(u) }
                        }
                        .id(webURL)
                    } else {
                        ZStack {
                            Color.gray.opacity(0.1)
                            Text("Paste a link and tap Play").foregroundColor(.secondary)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding()
            .navigationTitle("DiskPlayer")
        }
    }

    private func start() {
        message = nil
        player?.pause()
        player = nil
        webURL = nil
        found = []

        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: text), url.scheme?.hasPrefix("http") == true else {
            message = "Please enter a valid http(s) link."
            return
        }
        if nativeExts.contains(url.pathExtension.lowercased()) {
            playNative(url)
        } else {
            webURL = url
        }
    }

    private func playNative(_ url: URL) {
        let p = AVPlayer(url: url)
        player = p
        p.play()
    }
}
