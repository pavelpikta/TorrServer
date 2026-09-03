import SwiftUI
import TorrServerKit

struct ContentView: View {
  @State private var status = "Starting…"
  @State private var running = false
  @State private var busy = false
  @State private var reloadToken = 0
  @State private var webURL: URL?

  private let port = 8090

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        if let webURL, running {
          TorrServerWebView(url: webURL, reloadToken: $reloadToken)
        } else {
          ContentUnavailableView(
            status,
            systemImage: running ? "hourglass" : "play.circle",
            description: Text("TorrServer web UI at http://127.0.0.1:\(port)")
          )
        }
      }
      .navigationTitle("TorrServer")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItemGroup(placement: .bottomBar) {
          Button("Start") { start() }
            .disabled(busy || running)
          Button("Reload") { reloadToken += 1 }
            .disabled(!running)
          Spacer()
          Text(status)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
          Spacer()
          Button("Stop") { stop() }
            .disabled(busy || !running)
        }
      }
      .task { start() }
    }
  }

  private var dataDir: String {
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? FileManager.default.temporaryDirectory
    let dir = base.appendingPathComponent("torrserver_data", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.path
  }

  private func start() {
    guard !busy, !running else { return }
    busy = true
    status = "Starting…"
    webURL = nil
    let dir = dataDir
    DispatchQueue.global(qos: .userInitiated).async {
      let err = TorrserverkitStartServer(port, dir)
      Task { @MainActor in
        if !err.isEmpty {
          busy = false
          status = "Start failed: \(err)"
          return
        }
        status = "Waiting for web UI…"
        let ready = await waitForEcho()
        busy = false
        if ready {
          running = true
          status = "Running"
          webURL = URL(string: "http://127.0.0.1:\(port)/")
          reloadToken += 1
        } else {
          status = "Server started but /echo did not respond"
        }
      }
    }
  }

  private func stop() {
    busy = true
    DispatchQueue.global(qos: .userInitiated).async {
      let err = TorrserverkitStopServer()
      DispatchQueue.main.async {
        busy = false
        running = false
        webURL = nil
        if err.isEmpty {
          status = "Stopped"
        } else {
          status = "Stop failed: \(err)"
        }
      }
    }
  }

  private func waitForEcho() async -> Bool {
    guard let url = URL(string: "http://127.0.0.1:\(port)/echo") else { return false }
    for _ in 0..<40 {
      do {
        let (data, response) = try await URLSession.shared.data(from: url)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        let body = String(data: data, encoding: .utf8) ?? ""
        if code == 200, !body.isEmpty {
          return true
        }
      } catch {}
      try? await Task.sleep(for: .milliseconds(250))
    }
    return false
  }
}

#Preview {
  ContentView()
}
