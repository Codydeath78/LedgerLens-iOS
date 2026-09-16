import Foundation
import SwiftUI
import UIKit


struct ReportSharePayload:
    Identifiable {

    let id =
        UUID()

    let urls:
        [URL]
}


struct ReportShareSheet:
    UIViewControllerRepresentable {

    let urls:
        [URL]


    func makeUIViewController(
        context:
            Context
    ) -> UIActivityViewController {

        UIActivityViewController(
            activityItems:
                urls,
            applicationActivities:
                nil
        )
    }


    func updateUIViewController(
        _ uiViewController:
            UIActivityViewController,
        context:
            Context
    ) {}
}


enum ReportTemporaryFileStore {

    static func write(
        data:
            Data,
        fileName:
            String
    ) throws -> URL {

        let directory =
            FileManager
                .default
                .temporaryDirectory
                .appendingPathComponent(
                    "AI-Document-Exports",
                    isDirectory:
                        true
                )
                .appendingPathComponent(
                    UUID()
                        .uuidString,
                    isDirectory:
                        true
                )


        try FileManager
            .default
            .createDirectory(
                at:
                    directory,
                withIntermediateDirectories:
                    true
            )


        let url =
            directory
                .appendingPathComponent(
                    sanitizedFileName(
                        fileName
                    ),
                    isDirectory:
                        false
                )


        try data.write(
            to:
                url,
            options:
                .atomic
        )


        return url
    }


    static func write(
        text:
            String,
        fileName:
            String
    ) throws -> URL {

        guard
            let data =
                text.data(
                    using:
                        .utf8
                )
        else {

            throw
                CocoaError(
                    .fileWriteInapplicableStringEncoding
                )
        }


        return
            try write(
                data:
                    data,
                fileName:
                    fileName
            )
    }


    private static func sanitizedFileName(
        _ raw:
            String
    ) -> String {

        let invalid =
            CharacterSet(
                charactersIn:
                    "/:\\?%*|\"<>"
            )


        let pieces =
            raw
                .components(
                    separatedBy:
                        invalid
                )
                .filter {
                    !$0.isEmpty
                }


        let cleaned =
            pieces
                .joined(
                    separator:
                        "-"
                )
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )


        return
            cleaned.isEmpty
            ? "Financial Report"
            : cleaned
    }
}
