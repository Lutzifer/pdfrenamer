import AppKit
import Combine
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import PDFKit
import UniformTypeIdentifiers

enum RenameStatus: String, Sendable {
    case renamed
    case skipped
    case failed
}

struct RenameOutcome: Sendable {
    let sourcePath: String
    let destinationPath: String?
    let status: RenameStatus
    let message: String
}

struct PDFRenamerEngine {
    func rename(url: URL) -> RenameOutcome {
        guard url.pathExtension.lowercased() == "pdf" else {
            return RenameOutcome(
                sourcePath: url.path,
                destinationPath: nil,
                status: .skipped,
                message: "Skipped: not a PDF file."
            )
        }

        guard let document = PDFDocument(url: url) else {
            return RenameOutcome(
                sourcePath: url.path,
                destinationPath: nil,
                status: .failed,
                message: "Failed: could not read PDF."
            )
        }

        guard document.pageCount > 0 else {
            return RenameOutcome(
                sourcePath: url.path,
                destinationPath: nil,
                status: .failed,
                message: "Failed: PDF has no pages."
            )
        }

        let identifierArrays = document.pages.map { page in
            for radius in 1...2 {
                for sharpening in 1...8 {
                    let identifiers = page.qrCodes(
                        sharpenRadius: Float(radius),
                        sharpenIntensity: Float(sharpening)
                    ).filter { $0.hasPrefix("doc-id:") }

                    if !identifiers.isEmpty {
                        return identifiers
                    }
                }
            }
            return []
        }

        for (index, identifiers) in identifierArrays.enumerated() where identifiers.count > 1 {
            return RenameOutcome(
                sourcePath: url.path,
                destinationPath: nil,
                status: .failed,
                message: "Failed: page \(index + 1) has multiple doc-id QR codes."
            )
        }

        for (offset, identifiers) in identifierArrays.dropFirst().enumerated() where !identifiers.isEmpty {
            return RenameOutcome(
                sourcePath: url.path,
                destinationPath: nil,
                status: .failed,
                message: "Failed: page \(offset + 2) has a doc-id QR code (only page 1 is allowed)."
            )
        }

        guard let firstIdentifier = identifierArrays.first?.first else {
            return RenameOutcome(
                sourcePath: url.path,
                destinationPath: nil,
                status: .failed,
                message: "Failed: first page has no doc-id QR code."
            )
        }

        let id = firstIdentifier.replacingOccurrences(of: "doc-id:", with: "")
        let newURL = url.deletingLastPathComponent().appending(path: "\(id).pdf").absoluteURL

        if newURL.path == url.path {
            return RenameOutcome(
                sourcePath: url.path,
                destinationPath: newURL.path,
                status: .skipped,
                message: "Skipped: already named correctly."
            )
        }

        if FileManager.default.fileExists(atPath: newURL.path) {
            return RenameOutcome(
                sourcePath: url.path,
                destinationPath: newURL.path,
                status: .skipped,
                message: "Skipped: target file already exists."
            )
        }

        do {
            try FileManager.default.moveItem(atPath: url.path, toPath: newURL.path)
            return RenameOutcome(
                sourcePath: url.path,
                destinationPath: newURL.path,
                status: .renamed,
                message: "Renamed successfully."
            )
        } catch {
            return RenameOutcome(
                sourcePath: url.path,
                destinationPath: newURL.path,
                status: .failed,
                message: "Failed: \(error.localizedDescription)"
            )
        }
    }
}

@MainActor
final class RenamerViewModel: ObservableObject {
    @Published var rows: [LogRow] = []
    @Published var isProcessing = false

    func clear() {
        rows.removeAll()
    }

    func pickFiles() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.pdf]

        if panel.runModal() == .OK {
            enqueue(urls: panel.urls)
        }
    }

    func enqueue(urls: [URL]) {
        guard !urls.isEmpty else {
            return
        }

        Task {
            await process(urls: urls)
        }
    }

    private func process(urls: [URL]) async {
        isProcessing = true
        defer { isProcessing = false }

        let pdfURLs = urls.filter { $0.pathExtension.lowercased() == "pdf" }
        let ignoredCount = urls.count - pdfURLs.count

        if ignoredCount > 0 {
            rows.insert(
                LogRow(
                    timestamp: Date.now,
                    sourcePath: "-",
                    destinationPath: nil,
                    status: .skipped,
                    message: "Skipped \(ignoredCount) non-PDF file(s)."
                ),
                at: 0
            )
        }

        let results = await Task.detached(priority: .userInitiated) { () -> [RenameOutcome] in
            let engine = PDFRenamerEngine()
            return pdfURLs.map { engine.rename(url: $0) }
        }.value

        let newRows = results.map {
            LogRow(
                timestamp: Date.now,
                sourcePath: $0.sourcePath,
                destinationPath: $0.destinationPath,
                status: $0.status,
                message: $0.message
            )
        }
        rows.insert(contentsOf: newRows.reversed(), at: 0)
    }
}

struct LogRow: Identifiable {
    let id = UUID()
    let timestamp: Date
    let sourcePath: String
    let destinationPath: String?
    let status: RenameStatus
    let message: String
}

actor DroppedURLCollector {
    private(set) var urls: [URL] = []

    func add(_ url: URL) {
        urls.append(url)
    }
}

private extension PDFDocument {
    var pages: [PDFPage] {
        (0..<pageCount).compactMap { page(at: $0) }
    }
}

private extension PDFPage {
    var cgImage: CGImage? {
        let scale: CGFloat = 4.0
        let pageRect = bounds(for: .cropBox)
        let width = Int(pageRect.width * scale)
        let height = Int(pageRect.height * scale)

        guard
            let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
            )
        else {
            return nil
        }

        context.setFillColor(.white)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.saveGState()
        context.scaleBy(x: scale, y: scale)
        draw(with: .cropBox, to: context)
        context.restoreGState()

        return context.makeImage()
    }

    func qrCodes(sharpenRadius: Float = 1.0, sharpenIntensity: Float = 3.0) -> [String] {
        autoreleasepool {
            guard let pageImage = cgImage else { return [] }
            let originalImage = CIImage(cgImage: pageImage)

            let unsharpMask = CIFilter.unsharpMask()
            unsharpMask.inputImage = originalImage
            unsharpMask.radius = sharpenRadius
            unsharpMask.intensity = sharpenIntensity

            guard let ciImage = unsharpMask.outputImage else { return [] }

            let detector = CIDetector(
                ofType: CIDetectorTypeQRCode,
                context: CIContext(),
                options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]
            )

            let orientation = ciImage.properties[kCGImagePropertyOrientation as String] ?? 1
            let features = detector?.features(
                in: ciImage,
                options: [CIDetectorImageOrientation: orientation]
            ) ?? []

            return features.compactMap { ($0 as? CIQRCodeFeature)?.messageString }
        }
    }
}
