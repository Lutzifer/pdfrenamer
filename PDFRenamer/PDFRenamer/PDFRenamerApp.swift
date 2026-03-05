import AppKit
import SwiftUI

@main
struct PDFRenamerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = RenamerViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .onAppear {
                    appDelegate.model = model
                    appDelegate.flushPendingOpenFiles()
                }
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 900, height: 620)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var model: RenamerViewModel?
    private var pendingURLs: [URL] = []

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        let urls = filenames.map { URL(fileURLWithPath: $0) }
        if let model {
            Task { @MainActor in
                model.enqueue(urls: urls)
            }
        } else {
            pendingURLs.append(contentsOf: urls)
        }
        sender.reply(toOpenOrPrint: .success)
    }

    func flushPendingOpenFiles() {
        guard let model, !pendingURLs.isEmpty else {
            return
        }
        let urls = pendingURLs
        pendingURLs.removeAll()
        Task { @MainActor in
            model.enqueue(urls: urls)
        }
    }
}
