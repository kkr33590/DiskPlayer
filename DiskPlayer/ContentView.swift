import SwiftUI
import AVKit

struct ContentView: View {
    @State private var input = ""
    @State private var player: AVPlayer?
    @State private var statusObs: NSKeyValueObservation?
    @State private var webURL: URL?
    @State private var found: [URL] = []
    @State private var log: [String] = []
    @State private var message: String?
    @State private var desktop = false
    @State private var showLog = false

    private let nativeExts = ["mp4", "m4v", "mov", "m3u8", "mp3", "m4a", "aac", "wav"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
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

                HStack {
                    Toggle("Desktop site", isOn: $desktop).font(.footnote)
                    Spacer()
                    Button("Log (\(log.count))") { showLog = true }.font(.footnote)
                    if let webURL {
                        Button("Safari") { UIApplication.shared.open(webURL) }.font(.footnote)
                    }
                }

                if let message {
                    Text(message).foregroundColor(.red).font(.footnote)
                }

                if player == nil, !found.isEmpty {
                    Menu {
                        ForEach(found, id: \.self) { u in
                            Button(u.absoluteString) { playNative(u) }
                        }
                    } label: {
                        Label("Video found (\(found.count)) – tap to play",
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
                        WebView(url: webURL, desktop: desktop) { t, u in handle(t, u) }
                            .id("\(webURL.absoluteString)-\(desktop)")
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
            .sheet(isPresented: $showLog) { logSheet }
            .onChange(of: desktop) { _ in
                found = []; log = []
            }
        }
    }

    private var logSheet: some View {
        NavigationStack {
            List(log, id: \.self) { entry in
                Text(entry).font(.caption2).textSelection(.enabled)
                    .onTapGesture {
                        if let u = URL(string: entry), u.scheme?.hasPrefix("http") == true {
                            showLog = false
                            playNative(u)
                        }
                    }
            }
            .navigationTitle("Network log")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ShareLink(item: log.joined(separator: "\n"))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { showLog = false }
                }
            }
        }
    }

    private func handle(_ type: String, _ value: String) {
        switch type {
        case "m":
            if let u = URL(string: value), !found.contains(u) {
                if value.lowercased().contains(".m3u8") { found.insert(u, at: 0) } else { found.append(u) }
                log.append("[VIDEO] " + value)
            }
        case "b":
            log.append("[BLOB VIDEO – cannot extract] " + value)
        case "e":
            message = "Page error: " + value
        default:
            if log.count < 300 { log.append(value) }
        }
    }

    private func start() {
        message = nil
        player?.pause()
        player = nil
        webURL = nil
        found = []
        log = []

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
        message = nil
        var headers = ["User-Agent": desktop ? desktopUA : mobileUA]
        if let page = webURL {
            headers["Referer"] = page.absoluteString
            if let host = page.host, let scheme = page.scheme {
                headers["Origin"] = "\(scheme)://\(host)"
            }
        }
        let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        let item = AVPlayerItem(asset: asset)
        statusObs = item.observe(\.status, options: [.new]) { it, _ in
            if it.status == .failed {
                DispatchQueue.main.async {
                    message = "Native player failed: \(it.error?.localizedDescription ?? "unknown")"
                }
            }
        }
        let p = AVPlayer(playerItem: item)
        player = p
        p.play()
    }
}
