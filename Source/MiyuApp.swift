import SwiftUI

@main
struct MiyuApp: App {
    var body: some Scene {
        WindowGroup { MainView() }
    }
}

enum C {
    static let cream = Color(red: 0.98, green: 0.953, blue: 0.918)
    static let purple = Color(red: 0.545, green: 0.447, blue: 0.914)
    static let purpleDeep = Color(red: 0.427, green: 0.31, blue: 0.847)
    static let purpleSoft = Color(red: 0.937, green: 0.914, blue: 1.0)
    static let textDark = Color(red: 0.231, green: 0.231, blue: 0.31)
    static let textGray = Color(red: 0.663, green: 0.639, blue: 0.698)
}
