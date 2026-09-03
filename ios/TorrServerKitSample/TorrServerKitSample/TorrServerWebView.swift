import SwiftUI
import WebKit

struct TorrServerWebView: UIViewRepresentable {
  let url: URL
  @Binding var reloadToken: Int

  func makeUIView(context: Context) -> WKWebView {
    let config = WKWebViewConfiguration()
    config.allowsInlineMediaPlayback = true
    config.mediaTypesRequiringUserActionForPlayback = []
    let webView = WKWebView(frame: .zero, configuration: config)
    webView.allowsBackForwardNavigationGestures = true
    webView.isInspectable = true
    return webView
  }

  func updateUIView(_ webView: WKWebView, context: Context) {
    if context.coordinator.lastReloadToken != reloadToken {
      context.coordinator.lastReloadToken = reloadToken
      webView.load(URLRequest(url: url))
      return
    }
    if webView.url == nil {
      webView.load(URLRequest(url: url))
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  final class Coordinator {
    var lastReloadToken = -1
  }
}
