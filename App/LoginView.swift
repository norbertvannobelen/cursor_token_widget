import SwiftUI
import WebKit

struct LoginView: View {
    var onSession: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Sign in to Cursor")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()
            LoginWebView { session in
                onSession(session)
            }
        }
        .frame(minWidth: 760, minHeight: 640)
    }
}

struct LoginWebView: NSViewRepresentable {
    var onSession: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSession: onSession)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.6 Safari/605.1.15"
        webView.allowsBackForwardNavigationGestures = true
        context.coordinator.attach(to: webView)
        webView.load(URLRequest(url: URL(string: "https://cursor.com/dashboard/usage")!))
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        coordinator.detach(from: nsView)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKHTTPCookieStoreObserver {
        var onSession: (String) -> Void
        private var delivered = false
        private var timer: Timer?

        init(onSession: @escaping (String) -> Void) {
            self.onSession = onSession
        }

        func attach(to webView: WKWebView) {
            let store = webView.configuration.websiteDataStore.httpCookieStore
            store.add(self)
            let timer = Timer(timeInterval: 1, repeats: true) { [weak self, weak webView] _ in
                guard let self, let webView else { return }
                self.capture(from: webView)
            }
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }

        func detach(from webView: WKWebView) {
            timer?.invalidate()
            timer = nil
            webView.configuration.websiteDataStore.httpCookieStore.remove(self)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            capture(from: webView)
        }

        func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
            cookieStore.getAllCookies { [weak self] cookies in
                self?.deliver(cookies)
            }
        }

        private func capture(from webView: WKWebView) {
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
                self?.deliver(cookies)
            }
        }

        private func deliver(_ cookies: [HTTPCookie]) {
            guard !delivered,
                  let cookie = cookies.first(where: { $0.name == "WorkosCursorSessionToken" && $0.value.count > 20 }) else {
                return
            }
            DispatchQueue.main.async { [weak self] in
                guard let self, !self.delivered else { return }
                self.delivered = true
                self.timer?.invalidate()
                self.onSession(cookie.value)
            }
        }
    }
}
