//
//  ImageProcessing.swift
//  Calor
//

import UIKit

enum ImageProcessing {
    /// Longest side sent to Claude. Image tokens ≈ width × height ÷ 750,
    /// so 768 px keeps a photo to ~590 tokens (PRD 6.3).
    static let analysisMaxDimension: CGFloat = 768
    static let analysisJPEGQuality: CGFloat = 0.6

    /// Longest side of the small thumbnail saved with each entry.
    static let thumbnailMaxDimension: CGFloat = 200

    static func analysisJPEG(from image: UIImage) -> Data? {
        resized(image, maxDimension: analysisMaxDimension)
            .jpegData(compressionQuality: analysisJPEGQuality)
    }

    static func thumbnailJPEG(from image: UIImage) -> Data? {
        resized(image, maxDimension: thumbnailMaxDimension)
            .jpegData(compressionQuality: 0.7)
    }

    /// Scales the image down (never up) so its longest side is `maxDimension`
    /// pixels. Drawing also applies the photo's rotation.
    private static func resized(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        let scale = min(1, maxDimension / longest)
        let size = CGSize(width: (image.size.width * scale).rounded(),
                          height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
