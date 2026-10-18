import AppKit
import Vision
import LinkPresentation

/// Background enrichment: OCR for screenshots, title + image for links.
enum OCR {
    static func recognize(_ png: Data, completion: @escaping (String) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            guard let src = CGImageSourceCreateWithData(png as CFData, nil),
                  let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return }
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            try? VNImageRequestHandler(cgImage: cg).perform([request])
            let text = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
            guard !text.isEmpty else { return }
            DispatchQueue.main.async { completion(text) }
        }
    }
}

enum LinkPreviewer {
    static func fetch(_ url: URL, completion: @escaping (_ title: String?, _ png: Data?) -> Void) {
        let provider = LPMetadataProvider()
        provider.timeout = 8
        provider.startFetchingMetadata(for: url) { metadata, _ in
            guard let metadata else { return }
            let title = metadata.title
            guard let imageProvider = metadata.imageProvider ?? metadata.iconProvider,
                  imageProvider.canLoadObject(ofClass: NSImage.self) else {
                DispatchQueue.main.async { completion(title, nil) }
                return
            }
            _ = imageProvider.loadObject(ofClass: NSImage.self) { object, _ in
                let png = (object as? NSImage).flatMap { img -> Data? in
                    guard let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
                    return rep.representation(using: .png, properties: [:])
                }
                DispatchQueue.main.async { completion(title, png) }
            }
        }
    }
}
