import Foundation
import WebKit

enum WebSessionCleaner {
    static func clear() {
        let store = WKWebsiteDataStore.default().httpCookieStore
        store.getAllCookies { cookies in
            for cookie in cookies where cookie.name == "WorkosCursorSessionToken" || cookie.domain.contains("cursor.com") {
                store.delete(cookie)
            }
        }
    }
}
