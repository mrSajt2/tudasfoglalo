import SwiftUI
import WebKit

@main
struct TudasfoglaloApp: App {
    var body: some Scene {
        WindowGroup {
            GameContainerView()
                .preferredColorScheme(.dark)
        }
    }
}

private struct GameContainerView: View {
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var reloadToken = UUID()

    private var gameURL: URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "AppWebURL") as? String,
              let url = URL(string: raw),
              url.scheme?.lowercased() == "https",
              let host = url.host,
              !host.contains("YOUR-GITHUB-USERNAME") else {
            return nil
        }
        return url
    }

    var body: some View {
        ZStack {
            Color(red: 0.035, green: 0.07, blue: 0.13).ignoresSafeArea()

            if let gameURL {
                GameWebView(
                    url: gameURL,
                    reloadToken: reloadToken,
                    isLoading: $isLoading,
                    loadError: $loadError
                )
                .ignoresSafeArea()

                if isLoading && loadError == nil {
                    VStack(spacing: 12) {
                        ProgressView().tint(Color(red: 1.0, green: 0.68, blue: 0.10))
                        Text("Tudásfoglaló betöltése…")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                    .padding(22)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                    .allowsHitTesting(false)
                }

                if let loadError {
                    VStack(spacing: 14) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(Color(red: 1.0, green: 0.68, blue: 0.10))
                        Text("Nem sikerült betölteni a játékot")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                        Text(loadError)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.75))
                        Button {
                            self.loadError = nil
                            self.isLoading = true
                            self.reloadToken = UUID()
                        } label: {
                            Label("Újrapróbálás", systemImage: "arrow.clockwise")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(red: 0.96, green: 0.57, blue: 0.08))
                    }
                    .padding(24)
                    .frame(maxWidth: 360)
                    .background(Color(red: 0.07, green: 0.12, blue: 0.21), in: RoundedRectangle(cornerRadius: 22))
                    .padding(24)
                }
            } else {
                VStack(spacing: 14) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 42))
                        .foregroundStyle(Color(red: 1.0, green: 0.68, blue: 0.10))
                    Text("A játék webcíme még nincs beállítva")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                    Text("A GitHub Actions futtatásakor add meg az APP_WEB_URL értékét a GitHub Pages-oldalad HTTPS-címére.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.75))
                }
                .padding(28)
                .frame(maxWidth: 400)
            }
        }
        .statusBarHidden(true)
    }
}

private struct GameWebView: UIViewRepresentable {
    let url: URL
    let reloadToken: UUID
    @Binding var isLoading: Bool
    @Binding var loadError: String?

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading, loadError: $loadError)
    }

    func makeUIView(context: Context) -> WKWebView {
        context.coordinator.lastReloadToken = reloadToken
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true

        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences = preferences

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.alwaysBounceVertical = false
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 0.035, green: 0.07, blue: 0.13, alpha: 1)
        webView.scrollView.backgroundColor = webView.backgroundColor
        if #available(iOS 16.4, *) {
            webView.isInspectable = false
        }
        webView.load(URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 30))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.isLoading = $isLoading
        context.coordinator.loadError = $loadError
        if uiView.url?.absoluteString != url.absoluteString || context.coordinator.lastReloadToken != reloadToken {
            context.coordinator.lastReloadToken = reloadToken
            loadError = nil
            isLoading = true
            uiView.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30))
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var isLoading: Binding<Bool>
        var loadError: Binding<String?>
        var lastReloadToken = UUID()

        init(isLoading: Binding<Bool>, loadError: Binding<String?>) {
            self.isLoading = isLoading
            self.loadError = loadError
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            isLoading.wrappedValue = true
            loadError.wrappedValue = nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading.wrappedValue = false
            loadError.wrappedValue = nil
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            report(error)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            report(error)
        }

        private func report(_ error: Error) {
            isLoading.wrappedValue = false
            let nsError = error as NSError
            if nsError.code != NSURLErrorCancelled {
                loadError.wrappedValue = error.localizedDescription
            }
        }
    }
}
