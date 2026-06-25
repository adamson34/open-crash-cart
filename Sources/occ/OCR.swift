import Foundation
@preconcurrency import Vision

/// Run Apple's Vision text recognizer on a cropped frame and return the text in reading
/// order. Language correction is off — server screens are full of IPs, paths, and commands
/// that autocorrect would mangle.
/// Recognized text is delivered as a `Result` so a Vision failure is distinguishable from a
/// genuinely-empty result — a thrown error must never silently present as "no text found"
/// (BC-1.03.012). Exactly one completion call is made per request.
func recognizeText(in cgImage: CGImage, completion: @escaping @Sendable (Result<String, Error>) -> Void) {
    DispatchQueue.global(qos: .userInitiated).async {
        let request = VNRecognizeTextRequest { request, error in
            if let error { completion(.failure(error)); return }
            let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
            // Vision boundingBox origin is bottom-left; sort top→bottom, then left→right.
            let ordered = observations.sorted { a, b in
                if abs(a.boundingBox.midY - b.boundingBox.midY) > 0.012 {
                    return a.boundingBox.midY > b.boundingBox.midY
                }
                return a.boundingBox.midX < b.boundingBox.midX
            }
            let text = ordered.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
            completion(.success(text))
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        do {
            try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
        } catch {
            completion(.failure(error))   // was `try?` — the stuck-status defect
        }
    }
}
