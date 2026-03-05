import PDFKit

extension PDFDocument {
  var pages: [PDFPage] {
    (0..<pageCount).compactMap { index in
      page(at: index)
    }
  }
}
