import Foundation
import PDFKit
import Path

public enum RenameStatus: String, Sendable {
  case renamed
  case skipped
  case failed
}

public struct RenameOutcome: Sendable {
  public let sourcePath: String
  public let destinationPath: String?
  public let status: RenameStatus
  public let message: String

  public init(sourcePath: String, destinationPath: String?, status: RenameStatus, message: String) {
    self.sourcePath = sourcePath
    self.destinationPath = destinationPath
    self.status = status
    self.message = message
  }
}

public struct PDFRenamer {
  public init() {}

  public func rename(path: String) -> RenameOutcome {
    let pathObject = Path(path) ?? Path.cwd / path
    return rename(url: pathObject.url)
  }

  public func rename(url: URL) -> RenameOutcome {
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

    for (index, identifiers) in identifierArrays.enumerated() {
      if identifiers.count > 1 {
        return RenameOutcome(
          sourcePath: url.path,
          destinationPath: nil,
          status: .failed,
          message: "Failed: page \(index + 1) has multiple doc-id QR codes."
        )
      }
    }

    for (offset, identifiers) in identifierArrays.dropFirst().enumerated() {
      if !identifiers.isEmpty {
        let page = offset + 2
        return RenameOutcome(
          sourcePath: url.path,
          destinationPath: nil,
          status: .failed,
          message: "Failed: page \(page) has a doc-id QR code (only page 1 is allowed)."
        )
      }
    }

    guard let firstPageIdentifier = identifierArrays[0].first else {
      return RenameOutcome(
        sourcePath: url.path,
        destinationPath: nil,
        status: .failed,
        message: "Failed: first page has no doc-id QR code."
      )
    }

    let id = firstPageIdentifier.replacingOccurrences(of: "doc-id:", with: "")
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
