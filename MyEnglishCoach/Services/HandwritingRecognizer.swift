import PencilKit
import Vision
import UIKit

enum HandwritingRecognizer {
    static func recognize(_ drawing: PKDrawing) async -> String {
        let bounds = drawing.bounds
        guard bounds.isNull == false, bounds.width > 6, bounds.height > 6 else { return "" }
        let padded = bounds.insetBy(dx: -20, dy: -20)
        let image = drawing.image(from: padded, scale: 3)
        guard let cgImage = image.cgImage else { return "" }

        return await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
                return (request.results ?? [])
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: " ")
            } catch {
                return ""
            }
        }.value
    }
}
