import SwiftUI
import VisionKit
import UIKit

struct DocumentScannerView: UIViewControllerRepresentable {

    let onComplete: ([UIImage]) -> Void
    let onCancel: () -> Void
    let onError: (Error) -> Void

    func makeUIViewController(
        context: Context
    ) -> VNDocumentCameraViewController {

        let scanner =
            VNDocumentCameraViewController()

        scanner.delegate =
            context.coordinator

        return scanner
    }

    func updateUIViewController(
        _ uiViewController: VNDocumentCameraViewController,
        context: Context
    ) {
        // Nothing to update.
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator:
        NSObject,
        VNDocumentCameraViewControllerDelegate {

        private let parent:
            DocumentScannerView

        init(
            parent: DocumentScannerView
        ) {
            self.parent = parent
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {

            var images: [UIImage] = []

            for pageIndex in 0..<scan.pageCount {

                let image =
                    scan.imageOfPage(
                        at: pageIndex
                    )

                images.append(image)
            }

            parent.onComplete(images)
        }

        func documentCameraViewControllerDidCancel(
            _ controller: VNDocumentCameraViewController
        ) {

            parent.onCancel()
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {

            parent.onError(error)
        }
    }
}
