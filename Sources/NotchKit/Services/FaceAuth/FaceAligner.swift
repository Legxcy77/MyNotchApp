import CoreGraphics
import CoreImage
import Foundation
import Vision

public struct FaceAlignmentSpec: Equatable, Sendable {
    public let cropRect: CGRect
    public let rollAngleRadians: Double
    public let eyeMidpoint: CGPoint
    public let targetSize: CGSize

    public init(
        cropRect: CGRect,
        rollAngleRadians: Double,
        eyeMidpoint: CGPoint,
        targetSize: CGSize = CGSize(width: 112, height: 112)
    ) {
        self.cropRect = cropRect
        self.rollAngleRadians = rollAngleRadians
        self.eyeMidpoint = eyeMidpoint
        self.targetSize = targetSize
    }
}

/// Pure geometry + CoreImage 112×112 affine face alignment pipeline inspired by OpenCV SFace.
public enum FaceAligner {
    public static let targetDimension: CGFloat = 112

    /// Computes the roll angle between the eyes and a padded square crop rect in image coordinates.
    public static func computeAlignedCropRectAndAngle(
        leftEye: CGPoint,
        rightEye: CGPoint,
        faceBoundingBox: CGRect,
        imageSize: CGSize
    ) -> FaceAlignmentSpec {
        let dx = rightEye.x - leftEye.x
        let dy = rightEye.y - leftEye.y
        let rollAngle = atan2(Double(dy), Double(dx))
        let midpoint = CGPoint(x: (leftEye.x + rightEye.x) / 2, y: (leftEye.y + rightEye.y) / 2)

        let padX = faceBoundingBox.width * 0.12
        let padY = faceBoundingBox.height * 0.12
        let padded = CGRect(
            x: max(0, faceBoundingBox.minX - padX),
            y: max(0, faceBoundingBox.minY - padY),
            width: min(1, faceBoundingBox.width + padX * 2),
            height: min(1, faceBoundingBox.height + padY * 2)
        )

        let imageBounds = CGRect(origin: .zero, size: imageSize)
        let rawCrop = CGRect(
            x: padded.minX * imageSize.width,
            y: padded.minY * imageSize.height,
            width: padded.width * imageSize.width,
            height: padded.height * imageSize.height
        ).intersection(imageBounds)

        return FaceAlignmentSpec(
            cropRect: rawCrop,
            rollAngleRadians: rollAngle,
            eyeMidpoint: midpoint,
            targetSize: CGSize(width: targetDimension, height: targetDimension)
        )
    }

    /// Produces a roll-normalized `112×112` `CIImage` crop from a `VNFaceObservation`.
    public static func alignedFace112(from image: CIImage, face: VNFaceObservation) -> CIImage? {
        let extent = image.extent
        guard extent.width > 0, extent.height > 0 else { return nil }

        guard let leftEyePoints = face.landmarks?.leftEye?.normalizedPoints,
              let rightEyePoints = face.landmarks?.rightEye?.normalizedPoints,
              !leftEyePoints.isEmpty, !rightEyePoints.isEmpty else {
            return fallbackCrop112(from: image, faceBoundingBox: face.boundingBox)
        }

        let leftCenterNorm = centroid(of: leftEyePoints)
        let rightCenterNorm = centroid(of: rightEyePoints)

        // Convert normalized face-box coordinates to image pixel coordinates
        let leftEye = CGPoint(
            x: (face.boundingBox.minX + leftCenterNorm.x * face.boundingBox.width) * extent.width,
            y: (face.boundingBox.minY + leftCenterNorm.y * face.boundingBox.height) * extent.height
        )
        let rightEye = CGPoint(
            x: (face.boundingBox.minX + rightCenterNorm.x * face.boundingBox.width) * extent.width,
            y: (face.boundingBox.minY + rightCenterNorm.y * face.boundingBox.height) * extent.height
        )

        let spec = computeAlignedCropRectAndAngle(
            leftEye: leftEye,
            rightEye: rightEye,
            faceBoundingBox: face.boundingBox,
            imageSize: extent.size
        )
        guard !spec.cropRect.isEmpty else { return nil }

        // Rotate around eye midpoint by -rollAngle so eyes lie horizontally
        let t1 = CGAffineTransform(translationX: -spec.eyeMidpoint.x, y: -spec.eyeMidpoint.y)
        let rot = CGAffineTransform(rotationAngle: CGFloat(-spec.rollAngleRadians))
        let t2 = CGAffineTransform(translationX: spec.eyeMidpoint.x, y: spec.eyeMidpoint.y)
        let rotated = image.transformed(by: t1.concatenating(rot).concatenating(t2))

        let cropped = rotated.cropped(to: spec.cropRect.intersection(rotated.extent))
        guard !cropped.extent.isEmpty else { return nil }

        let scaleX = targetDimension / cropped.extent.width
        let scaleY = targetDimension / cropped.extent.height
        return cropped
            .transformed(by: CGAffineTransform(translationX: -cropped.extent.minX, y: -cropped.extent.minY))
            .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
    }

    private static func fallbackCrop112(from image: CIImage, faceBoundingBox: CGRect) -> CIImage? {
        let extent = image.extent
        let padX = faceBoundingBox.width * 0.10
        let padY = faceBoundingBox.height * 0.10
        let padded = CGRect(
            x: max(0, faceBoundingBox.minX - padX),
            y: max(0, faceBoundingBox.minY - padY),
            width: min(1, faceBoundingBox.width + padX * 2),
            height: min(1, faceBoundingBox.height + padY * 2)
        )
        let cropRect = CGRect(
            x: padded.minX * extent.width,
            y: padded.minY * extent.height,
            width: padded.width * extent.width,
            height: padded.height * extent.height
        ).intersection(extent)
        guard !cropRect.isEmpty else { return nil }
        let cropped = image.cropped(to: cropRect)
        let scaleX = targetDimension / cropped.extent.width
        let scaleY = targetDimension / cropped.extent.height
        return cropped
            .transformed(by: CGAffineTransform(translationX: -cropped.extent.minX, y: -cropped.extent.minY))
            .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
    }

    private static func centroid(of points: [CGPoint]) -> CGPoint {
        let sum = points.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
        return CGPoint(x: sum.x / CGFloat(points.count), y: sum.y / CGFloat(points.count))
    }
}

