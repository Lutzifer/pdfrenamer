import PDFKit

extension PDFDocument {
  var pages: [PDFPage] {
    (0...(pageCount - 1))
      .compactMap { index in
        page(at: index)
      }
  }
}
