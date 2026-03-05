import ArgumentParser
import Foundation
import PDFRenamerCore

@main
struct pdfrenamer: ParsableCommand {
    @Argument(help: "The files to rename.")
    var paths: [String]
    
    mutating func run() throws {
        let renamer = PDFRenamer()

        for path in paths {
            let result = renamer.rename(path: path)
            let destination = result.destinationPath.map { " -> \($0)" } ?? ""
            print("[\(result.status.rawValue.uppercased())] \(result.sourcePath)\(destination): \(result.message)")
        }
    }
}
