import Foundation
@preconcurrency import Vision

/// Run Apple's Vision text recognizer on a cropped frame and return the text in reading
/// order. Language correction is off — server screens are full of IPs, paths, and commands
/// that autocorrect would mangle.
func recognizeText(in cgImage: CGImage, completion: @escaping @Sendable (String) -> Void) {
    DispatchQueue.global(qos: .userInitiated).async {
        let request = VNRecognizeTextRequest { request, _ in
            let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
            // Vision boundingBox origin is bottom-left; sort top→bottom, then left→right.
            let ordered = observations.sorted { a, b in
                if abs(a.boundingBox.midY - b.boundingBox.midY) > 0.012 {
                    return a.boundingBox.midY > b.boundingBox.midY
                }
                return a.boundingBox.midX < b.boundingBox.midX
            }
            let text = ordered.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
            completion(text)
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        try? VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
    }
}
