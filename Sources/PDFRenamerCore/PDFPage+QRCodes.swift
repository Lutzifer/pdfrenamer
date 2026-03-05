import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import PDFKit

extension PDFPage {
  func qrCodes(sharpenRadius: Float = 1.0, sharpenIntensity: Float = 3.0) -> [String] {
    autoreleasepool {
      guard let pageImage = cgImage else {
        return []
      }

      let originalImage = CIImage(cgImage: pageImage)
      let unsharpMask = CIFilter.unsharpMask()
      unsharpMask.inputImage = originalImage
      unsharpMask.radius = sharpenRadius
      unsharpMask.intensity = sharpenIntensity

      guard let ciImage = unsharpMask.outputImage else {
        return []
      }

      let context = CIContext()
      let detectorOptions = [CIDetectorAccuracy: CIDetectorAccuracyHigh]
      let qrDetector = CIDetector(
        ofType: CIDetectorTypeQRCode,
        context: context,
        options: detectorOptions
      )

      let orientation: Any
      if let imageOrientation = ciImage.properties[kCGImagePropertyOrientation as String] {
        orientation = imageOrientation
      } else {
        orientation = 1
      }

      let imageOptions = [CIDetectorImageOrientation: orientation]
      let features = qrDetector?.features(in: ciImage, options: imageOptions) ?? []

      return features.compactMap { feature in
        (feature as? CIQRCodeFeature)?.messageString
      }
    }
  }
}
