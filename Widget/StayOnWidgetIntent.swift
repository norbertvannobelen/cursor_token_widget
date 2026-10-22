import AppIntents

struct StayOnWidgetIntent: AppIntent {
    static var title: LocalizedStringResource = "Show usage"
    static var isDiscoverable: Bool = false
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        .result()
    }
}
