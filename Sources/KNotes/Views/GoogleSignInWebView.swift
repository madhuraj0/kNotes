import SwiftUI
import WebKit

public struct GoogleSignInWebView: NSViewRepresentable {
    @Binding var isLoading: Bool
    var onTokenCaptured: (String, String?) -> Void
    var onCancel: () -> Void

    public init(
        isLoading: Binding<Bool>,
        onTokenCaptured: @escaping (String, String?) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self._isLoading = isLoading
        self.onTokenCaptured = onTokenCaptured
        self.onCancel = onCancel
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.default()

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        // Standard macOS Safari User-Agent
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15"

        if let url = URL(string: "https://accounts.google.com/EmbeddedSetup") {
            let request = URLRequest(url: url)
            webView.load(request)
        }
        return webView
    }

    public func updateNSView(_ nsView: WKWebView, context: Context) {}

    public class Coordinator: NSObject, WKNavigationDelegate {
        var parent: GoogleSignInWebView
        private var checkTimer: Timer?
        private var tokenFound = false

        init(_ parent: GoogleSignInWebView) {
            self.parent = parent
            super.init()
        }

        deinit {
            checkTimer?.invalidate()
        }

        public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
            }
            startCookiePolling(webView)
        }

        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
            checkCookies(webView)
        }

        public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }

        private func startCookiePolling(_ webView: WKWebView) {
            checkTimer?.invalidate()
            checkTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self, weak webView] _ in
                guard let self = self, let wv = webView, !self.tokenFound else { return }
                self.checkCookies(wv)
            }
        }

        private func checkCookies(_ webView: WKWebView) {
            guard !tokenFound else { return }
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
                guard let self = self, !self.tokenFound else { return }
                var oauthToken: String?
                var email: String?

                for cookie in cookies {
                    if cookie.name == "oauth_token" && cookie.value.starts(with: "oauth2_4/") {
                        oauthToken = cookie.value
                    }
                    if cookie.name == "identifier" || cookie.name == "account" || cookie.name == "Email" {
                        email = cookie.value
                    }
                }

                if let token = oauthToken {
                    self.tokenFound = true
                    self.checkTimer?.invalidate()
                    DispatchQueue.main.async {
                        self.parent.onTokenCaptured(token, email)
                    }
                }
            }
        }
    }
}
