import ArgumentParser
import Foundation
import PDFKit
import Path

@main
struct pdfrenamer: ParsableCommand {
    @Argument(help: "The files to rename.")
    var paths: [String]
    
    mutating func run() throws {
        let filePaths = paths.map { Path($0) ?? Path.cwd / $0 }.filter { $0.string.hasSuffix(".pdf") }
        
        filePaths.forEach { path in
            renameFile(at: path)
        }
    }
    
    func renameFile(at path: Path) {
        // 1. Load PDF File as PDF Document
        let document = PDFDocument(url: path.url)!
        
        // 2. Go through all the pages and check if they contain a qrcode that starts with the text doc-id:
        let identifierArrays =
        // todo: remove prefixing
        document.pages.map { page in
            for radius in (1...2) {
                for sharpening in (1...8) {
                        let newIdentifiers = page.qrCodes(
                            sharpenRadius: Float(radius),
                            sharpenIntensity: Float(sharpening)
                        ).filter { $0.hasPrefix("doc-id:") }
                        
                        if !newIdentifiers.isEmpty {
                            print("Found \(newIdentifiers) for \(radius) and \(sharpening)")
                            return newIdentifiers
                        }
                }
            }
            
            return []
        }
        
        // 3. Fail if a page has multiple identifiers
        for (index, array) in identifierArrays.enumerated() {
            if array.count > 1 {
                print("\(path): Page \(index + 1) has multiple identifiers.")
                return
            }
        }
        
        // 4. Fail if a page after the first has an identifier
        for (index, array) in identifierArrays.dropFirst().enumerated() {
            if array.count > 0 {
                print("\(path): Page \(index + 1) has an identifier. Only allowed on first page.")
                return
            }
        }
        
        // 5. Ensure that first page has an doc-id: identifier
        guard let identifier = identifierArrays[0].first else {
            print("\(path): First page has no identifier")
            return
        }
        
        print("Found \(identifier) on page 1.")
        
        // 5. Rename the file
        let newURL = path.url.deletingLastPathComponent().appending(
            path: identifier.replacingOccurrences(of: "doc-id:", with: "") + ".pdf"
        ).absoluteURL
        
        
        if newURL.path() == path.string {
            print("\(path) is already named correctly.")
            
            return
        }
        
        if FileManager.default.fileExists(atPath: newURL.path()) {
            print("skipping renaming of \(path.string) to \(newURL.path) as the target already exists.")
        } else {
            try! FileManager.default.moveItem(atPath: path.string, toPath: newURL.path())
        }
    }
}
