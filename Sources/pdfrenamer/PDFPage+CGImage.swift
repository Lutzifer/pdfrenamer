import CoreGraphics
import PDFKit

extension PDFPage {
  var cgImage: CGImage? {
    let scale: CGFloat = 4.0
    let pageRect = self.bounds(for: .cropBox)

    let width = Int(pageRect.width * scale)
    let height = Int(pageRect.height * scale)

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bytesPerPixel = 4
    let bitsPerComponent = 8

    guard
      let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: bitsPerComponent,
        bytesPerRow: width * bytesPerPixel,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
      )
    else {
      print("Failed to create CGContext.")
      return nil
    }

    context.setFillColor(.white)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))

    context.saveGState()

    context.scaleBy(x: scale, y: scale)

    self.draw(with: .cropBox, to: context)

    context.restoreGState()

    return context.makeImage()
  }
}
