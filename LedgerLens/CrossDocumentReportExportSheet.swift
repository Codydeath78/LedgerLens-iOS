// Cross-document professional PDF + CSV + native sharing.

import Foundation
import SwiftUI
import UniformTypeIdentifiers


struct CrossDocumentReportExportSheet:
    View {

    @Environment(\.dismiss)
    private var dismiss

    let pack:
        CrossDocumentFactPack

    let currentQuestion:
        String?

    let currentAnswer:
        String?


    @State private var saveDocument:
        ReportSaveDocument?

    @State private var saveContentType:
        UTType = .pdf

    @State private var saveDefaultFilename =
        "Cross-Document Financial Analysis"

    @State private var showFileExporter =
        false

    @State private var sharePayload:
        ReportSharePayload?

    @State private var errorMessage:
        String?


    var body: some View {

        NavigationStack {

            List {

                Section(
                    "Cross-Document Report"
                ) {

                    Label(
                        "\(pack.documents.count) selected documents",
                        systemImage:
                            "square.stack.3d.up.fill"
                    )
                    .font(
                        .headline
                    )


                    Text(
                        "The PDF includes a professional cover page, verified spending comparisons, recurring-payment analysis, merchant/category totals, source-document metadata, the current AI explanation when available, and a combined transaction table."
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }


                Section(
                    "Verified Snapshot"
                ) {

                    ForEach(
                        pack
                            .metrics
                    ) {
                        metric in

                        VStack(
                            alignment:
                                .leading,
                            spacing:
                                5
                        ) {

                            Text(
                                metric
                                    .document
                                    .displayName
                            )
                            .font(
                                .subheadline
                                .weight(.semibold)
                            )


                            if let period =
                                metric
                                    .document
                                    .periodCaption {

                                Text(
                                    period
                                )
                                .font(
                                    .caption
                                )
                                .foregroundStyle(
                                    .secondary
                                )
                            }


                            ForEach(
                                metric
                                    .spending
                            ) {
                                amount in

                                Text(
                                    "\(amount.currency): \(CrossDocumentAnalysisEngine.formatMoney(amount.amount, currency: amount.currency))"
                                )
                                .font(
                                    .caption
                                    .weight(.semibold)
                                )
                            }


                            Text(
                                "Basis: \(metric.spendingBasis)"
                            )
                            .font(
                                .caption2
                            )
                            .foregroundStyle(
                                .tertiary
                            )
                        }
                        .padding(
                            .vertical,
                            3
                        )
                    }
                }


                if !pack
                    .recurringPayments
                    .isEmpty {

                    Section(
                        "Recurring Payments"
                    ) {

                        ForEach(
                            pack
                                .recurringPayments
                                .prefix(
                                    8
                                )
                        ) {
                            pattern in

                            HStack {

                                VStack(
                                    alignment:
                                        .leading,
                                    spacing:
                                        3
                                ) {

                                    Text(
                                        pattern
                                            .merchant
                                    )
                                    .font(
                                        .subheadline
                                        .weight(.semibold)
                                    )


                                    Text(
                                        "\(pattern.cadence.rawValue) • \(pattern.confidence.rawValue)"
                                    )
                                    .font(
                                        .caption
                                    )
                                    .foregroundStyle(
                                        .secondary
                                    )
                                }


                                Spacer()


                                if let monthly =
                                    pattern
                                        .estimatedMonthlyAmount {

                                    Text(
                                        CrossDocumentAnalysisEngine
                                            .formatMoney(
                                                monthly,
                                                currency:
                                                    pattern
                                                        .currency
                                            )
                                    )
                                    .font(
                                        .caption
                                        .weight(.bold)
                                    )
                                }
                            }
                        }
                    }
                }


                if let currentQuestion,
                   let currentAnswer,
                   !currentQuestion
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        )
                        .isEmpty,
                   !currentAnswer
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        )
                        .isEmpty {

                    Section(
                        "AI Explanation"
                    ) {

                        Label(
                            "The current cross-document Q&A will be included in the PDF.",
                            systemImage:
                                "sparkles"
                        )
                        .font(
                            .caption
                        )
                        .foregroundStyle(
                            .green
                        )
                    }
                }


                Section(
                    "Save"
                ) {

                    Button {

                        savePDF()

                    } label: {

                        Label(
                            "Save Professional PDF",
                            systemImage:
                                "doc.richtext"
                        )
                    }


                    Button {

                        saveCSV()

                    } label: {

                        Label(
                            "Save Combined Transactions CSV",
                            systemImage:
                                "tablecells"
                        )
                    }
                }


                Section(
                    "Share"
                ) {

                    Button {

                        sharePDF()

                    } label: {

                        Label(
                            "Share PDF",
                            systemImage:
                                "square.and.arrow.up"
                        )
                    }


                    Button {

                        shareCSV()

                    } label: {

                        Label(
                            "Share CSV",
                            systemImage:
                                "square.and.arrow.up.on.square"
                        )
                    }


                    Button {

                        shareBoth()

                    } label: {

                        Label(
                            "Share PDF + CSV",
                            systemImage:
                                "square.stack.3d.up"
                        )
                    }
                }


                Section(
                    "CSV Data"
                ) {

                    Text(
                        "The CSV includes the source document, authoritative period, spending basis, raw transaction date, corrected effective date, vendor/category, amount, currency, flow, status, role, and whether each record was included in spending analysis."
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }


                if let errorMessage {

                    Section {

                        Text(
                            errorMessage
                        )
                        .foregroundStyle(
                            .red
                        )
                    }
                }
            }
            .navigationTitle(
                "Export Analysis"
            )
            .navigationBarTitleDisplayMode(
                .inline
            )
            .toolbar {

                ToolbarItem(
                    placement:
                        .topBarLeading
                ) {

                    Button(
                        "Done"
                    ) {

                        dismiss()
                    }
                }
            }
        }
        .fileExporter(
            isPresented:
                $showFileExporter,
            document:
                saveDocument,
            contentType:
                saveContentType,
            defaultFilename:
                saveDefaultFilename
        ) {
            result in

            handleExport(
                result
            )

            saveDocument =
                nil
        }
        .sheet(
            item:
                $sharePayload
        ) {
            payload in

            ReportShareSheet(
                urls:
                    payload
                        .urls
            )
        }
    }


    // Generate

    private func makePDFData()
        -> Data {

        DocumentReportPDFBuilder
            .makeProfessionalCrossDocumentPDF(
                pack:
                    pack,
                currentQuestion:
                    currentQuestion,
                currentAnswer:
                    currentAnswer
            )
    }


    private func makeCSVText()
        -> String {

        FinancialCSVBuilder
            .makeCrossDocumentCSV(
                pack:
                    pack
            )
    }


    // Save

    private func savePDF() {

        errorMessage =
            nil


        saveContentType =
            .pdf

        saveDefaultFilename =
            pdfSaveBaseName

        saveDocument =
            ReportSaveDocument(
                data:
                    makePDFData()
            )

        showFileExporter =
            true
    }


    private func saveCSV() {

        errorMessage =
            nil


        saveContentType =
            .commaSeparatedText

        saveDefaultFilename =
            csvSaveBaseName

        saveDocument =
            ReportSaveDocument(
                text:
                    makeCSVText()
            )

        showFileExporter =
            true
    }


    // Share

    private func sharePDF() {

        errorMessage =
            nil


        do {

            let url =
                try ReportTemporaryFileStore
                    .write(
                        data:
                            makePDFData(),
                        fileName:
                            pdfFileName
                    )


            sharePayload =
                ReportSharePayload(
                    urls: [
                        url
                    ]
                )

        } catch {

            errorMessage =
                error
                    .localizedDescription
        }
    }


    private func shareCSV() {

        errorMessage =
            nil


        do {

            let url =
                try ReportTemporaryFileStore
                    .write(
                        text:
                            makeCSVText(),
                        fileName:
                            csvFileName
                    )


            sharePayload =
                ReportSharePayload(
                    urls: [
                        url
                    ]
                )

        } catch {

            errorMessage =
                error
                    .localizedDescription
        }
    }


    private func shareBoth() {

        errorMessage =
            nil


        do {

            let pdfURL =
                try ReportTemporaryFileStore
                    .write(
                        data:
                            makePDFData(),
                        fileName:
                            pdfFileName
                    )


            let csvURL =
                try ReportTemporaryFileStore
                    .write(
                        text:
                            makeCSVText(),
                        fileName:
                            csvFileName
                    )


            sharePayload =
                ReportSharePayload(
                    urls: [
                        pdfURL,
                        csvURL
                    ]
                )

        } catch {

            errorMessage =
                error
                    .localizedDescription
        }
    }


    private func handleExport(
        _ result:
            Result<URL, Error>
    ) {

        if case .failure(
            let error
        ) = result {

            errorMessage =
                error
                    .localizedDescription
        }
    }


    private var pdfSaveBaseName:
        String {

        "Cross-Document Financial Analysis"
    }


    private var csvSaveBaseName:
        String {

        "Cross-Document Transactions"
    }


    private var pdfFileName:
        String {

        "\(pdfSaveBaseName).pdf"
    }


    private var csvFileName:
        String {

        "\(csvSaveBaseName).csv"
    }
}
