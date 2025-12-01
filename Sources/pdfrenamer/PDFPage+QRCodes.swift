import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import PDFKit

extension PDFPage {
  func qrCodes(sharpenRadius: Float = 1.0, sharpenIntensity: Float = 3.0) -> [String] {
      autoreleasepool {
          let originalImage = CIImage(cgImage: cgImage!)
          
          let unsharpMask = CIFilter.unsharpMask()
          unsharpMask.inputImage = originalImage
          unsharpMask.radius = sharpenRadius
          unsharpMask.intensity = sharpenIntensity
          
          let ciImage = unsharpMask.outputImage!
          
          var options: [String: Any]
          let context = CIContext()
          options = [CIDetectorAccuracy: CIDetectorAccuracyHigh]
          
          let qrDetector = CIDetector(ofType: CIDetectorTypeQRCode, context: context, options: options)
          
          if ciImage.properties.keys.contains((kCGImagePropertyOrientation as String)) {
              options = [
                CIDetectorImageOrientation: ciImage.properties[(kCGImagePropertyOrientation as String)] ?? 1
              ]
          } else {
              options = [CIDetectorImageOrientation: 1]
          }
          
          let features = qrDetector?.features(in: ciImage, options: options)
          
          return features?.compactMap { $0 as? CIQRCodeFeature }.map(\.messageString!) ?? []
      }
  }
}
