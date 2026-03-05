import PDFKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var model: RenamerViewModel
    @State private var isDropTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Button("Choose PDFs") {
                    model.pickFiles()
                }

                Button("Clear Log") {
                    model.clear()
                }
                .disabled(model.rows.isEmpty)

                Spacer()

                if model.isProcessing {
                    ProgressView()
                    Text("Processing...")
                        .foregroundStyle(.secondary)
                }
            }

            DropZone(isHighlighted: isDropTargeted)

            if model.rows.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No results yet.")
                        .font(.title3.weight(.semibold))
                    Text("Drop PDF files onto this window, or drop files onto the app icon.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                List(model.rows) { row in
                    HStack(alignment: .top, spacing: 12) {
                        Text(row.status.rawValue.uppercased())
                            .font(.caption.monospaced())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(statusColor(for: row.status).opacity(0.16))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .foregroundStyle(statusColor(for: row.status))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.sourcePath)
                                .textSelection(.enabled)
                                .lineLimit(1)

                            if let destinationPath = row.destinationPath {
                                Text("-> \(destinationPath)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                                    .lineLimit(1)
                            }

                            Text(row.message)
                                .font(.callout)
                                .foregroundStyle(.secondary)

                            Text(row.timestamp, style: .time)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 3)
                }
            }
        }
        .padding(16)
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
        }
    }

    private func statusColor(for status: RenameStatus) -> Color {
        switch status {
        case .renamed:
            return .green
        case .skipped:
            return .orange
        case .failed:
            return .red
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        if providers.isEmpty {
            return false
        }

        let collector = DroppedURLCollector()
        let group = DispatchGroup()

        for provider in providers where provider.canLoadObject(ofClass: URL.self) {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { object, _ in
                defer { group.leave() }
                if let url = object {
                    Task {
                        await collector.add(url)
                    }
                }
            }
        }

        group.notify(queue: .main) {
            Task { @MainActor in
                let urls = await collector.urls
                model.enqueue(urls: urls)
            }
        }

        return true
    }
}

struct DropZone: View {
    let isHighlighted: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.viewfinder.fill")
                .font(.system(size: 36))
            Text("Drop PDF files here")
                .font(.headline)
            Text("Files are renamed in place using doc-id QR codes on page 1.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isHighlighted ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    isHighlighted ? Color.accentColor : Color.secondary.opacity(0.4),
                    style: StrokeStyle(lineWidth: 1.5, dash: [7, 4])
                )
        )
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(model: RenamerViewModel())
    }
}
