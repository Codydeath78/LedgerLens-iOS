// One FileDocument type is used by ONE SwiftUI fileExporter.
// This avoids stacking two fileExporter modifiers on the same
// view, which can cause the later exporter to win presentation (race condition).

import Foundation
import SwiftUI
import UniformTypeIdentifiers


struct ReportSaveDocument:
    FileDocument {

    static var readableContentTypes:
        [UTType] {

        [
            .pdf,
            .commaSeparatedText,
            .plainText,
            .data
        ]
    }


    let data:
        Data


    init(
        data:
            Data
    ) {

        self.data =
            data
    }


    init(
        text:
            String
    ) {

        self.data =
            Data(
                text.utf8
            )
    }


    init(
        configuration:
            ReadConfiguration
    ) throws {

        data =
            configuration
                .file
                .regularFileContents
            ??
            Data()
    }


    func fileWrapper(
        configuration:
            WriteConfiguration
    ) throws -> FileWrapper {

        FileWrapper(
            regularFileWithContents:
                data
        )
    }
}
