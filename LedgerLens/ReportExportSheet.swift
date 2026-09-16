// Professional PDF + CSV + native iOS sharing.

import Foundation
import SwiftUI
import UniformTypeIdentifiers


struct ReportExportSheet:
    View {

    @Environment(\.dismiss)
    private var dismiss

    @ObservedObject private var network =
        NetworkMonitor.shared

    let document:
        HistoryDocument

    let summary:
        HistoryDocumentSummary?

    let conversations:
        [DocumentConversation]


    @State private var selectedIDs:
        Set<UUID>

    @State private var includeTransactions =
        true

    @State private var loadedDocument:
        CrossDocumentLoadedDocument?

    @State private var metric:
        CrossDocumentMetric?

    @State private var isLoading =
        true

    @State private var errorMessage:
        String?

    @State private var saveDocument:
        ReportSaveDocument?

    @State private var saveContentType:
        UTType = .pdf

    @State private var saveDefaultFilename =
        "Financial Report"

    @State private var showFileExporter =
        false

    @State private var sharePayload:
        ReportSharePayload?


    init(
        document:
            HistoryDocument,
        summary:
            HistoryDocumentSummary?,
        conversations:
            [DocumentConversation]
    ) {

        self.document =
            document

        self.summary =
            summary

        self.conversations =
            conversations


        _selectedIDs =
            State(
                initialValue:
                    Set(
                        conversations.map(
                            \.id
                        )
                    )
            )
    }


    var body: some View {

        NavigationStack {

            List {

                Section(
                    "Professional Report"
                ) {

                    Label(
                        document
                            .resolvedDisplayName,
                        systemImage:
                            "doc.richtext.fill"
                    )
                    .font(
                        .headline
                    )


                    Text(
                        "Create a polished report with a cover page, deterministic summary, calculated totals, source metadata, selected AI explanations, and an optional transaction table."
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )


                    Toggle(
                        "Include transaction table",
                        isOn:
                            $includeTransactions
                    )
                    .disabled(
                        isLoading
                        ||
                        loadedDocument
                        ==
                        nil
                    )
                }


                if isLoading {

                    Section {

                        HStack(
                            spacing:
                                11
                        ) {

                            ProgressView()


                            VStack(
                                alignment:
                                    .leading,
                                spacing:
                                    3
                            ) {

                                Text(
                                    "Preparing verified report data…"
                                )
                                .font(
                                    .subheadline
                                    .weight(.semibold)
                                )


                                Text(
                                    "Restoring the saved document locally. This does not call Veryfi again."
                                )
                                .font(
                                    .caption
                                )
                                .foregroundStyle(
                                    .secondary
                                )
                            }
                        }
                    }

                } else if
                    let metric {

                    verifiedTotalsSection(
                        metric
                    )
                }


                Section(
                    "Selected AI Explanations"
                ) {

                    if conversations
                        .isEmpty {

                        Text(
                            "No saved Q&A yet. The PDF can still include the summary, verified totals, metadata, and transaction table."
                        )
                        .font(
                            .subheadline
                        )
                        .foregroundStyle(
                            .secondary
                        )

                    } else {

                        ForEach(
                            conversations
                        ) {
                            item in

                            Button {

                                toggle(
                                    item.id
                                )

                            } label: {

                                HStack(
                                    alignment:
                                        .top,
                                    spacing:
                                        11
                                ) {

                                    Image(
                                        systemName:
                                            selectedIDs
                                                .contains(
                                                    item.id
                                                )
                                            ? "checkmark.circle.fill"
                                            : "circle"
                                    )
                                    .foregroundStyle(
                                        selectedIDs
                                            .contains(
                                                item.id
                                            )
                                        ? .blue
                                        : .secondary
                                    )


                                    VStack(
                                        alignment:
                                            .leading,
                                        spacing:
                                            4
                                    ) {

                                        Text(
                                            PlainTextSanitizer
                                                .clean(
                                                    item
                                                        .question
                                                )
                                        )
                                        .font(
                                            .subheadline
                                            .weight(.semibold)
                                        )
                                        .foregroundStyle(
                                            .primary
                                        )


                                        Text(
                                            PlainTextSanitizer
                                                .clean(
                                                    item
                                                        .answer
                                                )
                                        )
                                        .font(
                                            .caption
                                        )
                                        .foregroundStyle(
                                            .secondary
                                        )
                                        .lineLimit(
                                            3
                                        )
                                    }
                                }
                            }
                            .buttonStyle(
                                .plain
                            )
                        }
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
                    .disabled(
                        !canExport
                    )


                    Button {

                        saveCSV()

                    } label: {

                        Label(
                            "Save Transactions CSV",
                            systemImage:
                                "tablecells"
                        )
                    }
                    .disabled(
                        !canExport
                    )
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
                    .disabled(
                        !canExport
                    )


                    Button {

                        shareCSV()

                    } label: {

                        Label(
                            "Share CSV",
                            systemImage:
                                "square.and.arrow.up.on.square"
                        )
                    }
                    .disabled(
                        !canExport
                    )


                    Button {

                        shareBoth()

                    } label: {

                        Label(
                            "Share PDF + CSV",
                            systemImage:
                                "square.stack.3d.up"
                        )
                    }
                    .disabled(
                        !canExport
                    )


                    Text(
                        "Sharing uses the standard iOS share sheet, so users can send files through AirDrop, Messages, Mail, Drive, Files, or any installed compatible app."
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }


                Section(
                    "CSV Data"
                ) {

                    Text(
                        "CSV includes document metadata, period information, raw and corrected transaction dates, vendor/category, amount, currency, flow, status, role, and whether the record was included in deterministic spending analysis."
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
                "Export & Share"
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


                if !conversations
                    .isEmpty {

                    ToolbarItem(
                        placement:
                            .topBarTrailing
                    ) {

                        Button(
                            selectedIDs.count
                            ==
                            conversations.count
                            ? "None"
                            : "All"
                        ) {

                            if selectedIDs.count
                                ==
                                conversations.count {

                                selectedIDs =
                                    []

                            } else {

                                selectedIDs =
                                    Set(
                                        conversations.map(
                                            \.id
                                        )
                                    )
                            }
                        }
                    }
                }
            }
            .task {

                await loadReportContext()
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


    // Verified Totals Preview

    private func verifiedTotalsSection(
        _ metric:
            CrossDocumentMetric
    ) -> some View {

        Section(
            "Verified Totals"
        ) {

            ForEach(
                metric
                    .spending
            ) {
                item in

                HStack {

                    Text(
                        "Spending • \(item.currency)"
                    )


                    Spacer()


                    Text(
                        CrossDocumentAnalysisEngine
                            .formatMoney(
                                item
                                    .amount,
                                currency:
                                    item
                                        .currency
                            )
                    )
                    .font(
                        .subheadline
                        .weight(.semibold)
                    )
                }
            }


            HStack(
                alignment:
                    .top
            ) {

                Text(
                    "Basis"
                )


                Spacer()


                Text(
                    metric
                        .spendingBasis
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )
                .multilineTextAlignment(
                    .trailing
                )
            }
        }
    }


    // Load

    @MainActor
    private func loadReportContext()
        async {

        guard
            network
                .isConnected
        else {

            isLoading =
                false

            errorMessage =
                "Reconnect to prepare the transaction-level report and CSV."

            return
        }


        isLoading =
            true

        errorMessage =
            nil


        do {

            let data =
                try await
                    DocumentHistoryService
                        .shared
                        .fetchPayloadData(
                            id:
                                document
                                    .id
                        )


            let rootObject =
                try JSONSerialization
                    .jsonObject(
                        with:
                            data
                    )


            guard
                let root =
                    rootObject
                        as?
                        [String: Any],

                let payload =
                    root[
                        "veryfi_payload"
                    ]
                        as?
                        [String: Any]
            else {

                throw
                    DocumentHistoryError
                        .malformedSavedDocument
            }


            let financialDocument =
                try VeryfiService
                    .restoreFinancialDocument(
                        payload:
                            payload,
                        classification:
                            document
                                .documentType
                    )


            let profile =
                CrossDocumentProfileResolver
                    .makeProfile(
                        payload:
                            payload,
                        history:
                            document,
                        financialDocument:
                            financialDocument
                    )


            let loaded =
                CrossDocumentLoadedDocument(
                    history:
                        document,
                    financialDocument:
                        financialDocument,
                    summary:
                        summary,
                    conversations:
                        conversations,
                    profile:
                        profile
                )


            let pack =
                CrossDocumentAnalysisEngine
                    .analyze(
                        [
                            loaded
                        ]
                    )


            loadedDocument =
                loaded

            metric =
                pack
                    .metrics
                    .first


        } catch {

            errorMessage =
                AppFriendlyError
                    .message(
                        for:
                            error,
                        context:
                            .history,
                        isConnected:
                            network
                                .isConnected
                    )
        }


        isLoading =
            false
    }


    // Generate

    private var canExport:
        Bool {

        loadedDocument
            !=
            nil
        &&
        metric
            !=
            nil
        &&
        !isLoading
    }


    private var selectedConversations:
        [DocumentConversation] {

        conversations
            .filter {
                selectedIDs
                    .contains(
                        $0.id
                    )
            }
    }


    private func makePDFData()
        -> Data? {

        guard
            let loadedDocument,
            let metric
        else {

            errorMessage =
                "The report data is still loading."

            return nil
        }


        return
            DocumentReportPDFBuilder
                .makeProfessionalSingleDocumentPDF(
                    document:
                        loadedDocument,
                    metric:
                        metric,
                    conversations:
                        selectedConversations,
                    includeTransactions:
                        includeTransactions
                )
    }


    private func makeCSVText()
        -> String? {

        guard
            let loadedDocument
        else {

            errorMessage =
                "The report data is still loading."

            return nil
        }


        return
            FinancialCSVBuilder
                .makeSingleDocumentCSV(
                    document:
                        loadedDocument
                )
    }


    // Save

    private func savePDF() {

        errorMessage =
            nil


        guard
            let data =
                makePDFData()
        else {
            return
        }


        saveContentType =
            .pdf

        saveDefaultFilename =
            pdfSaveBaseName

        saveDocument =
            ReportSaveDocument(
                data:
                    data
            )

        showFileExporter =
            true
    }


    private func saveCSV() {

        errorMessage =
            nil


        guard
            let text =
                makeCSVText()
        else {
            return
        }


        saveContentType =
            .commaSeparatedText

        saveDefaultFilename =
            csvSaveBaseName

        saveDocument =
            ReportSaveDocument(
                text:
                    text
            )

        showFileExporter =
            true
    }


    // Share

    private func sharePDF() {

        errorMessage =
            nil


        guard
            let data =
                makePDFData()
        else {
            return
        }


        do {

            let url =
                try ReportTemporaryFileStore
                    .write(
                        data:
                            data,
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


        guard
            let text =
                makeCSVText()
        else {
            return
        }


        do {

            let url =
                try ReportTemporaryFileStore
                    .write(
                        text:
                            text,
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


        guard
            let pdf =
                makePDFData(),
            let csv =
                makeCSVText()
        else {
            return
        }


        do {

            let pdfURL =
                try ReportTemporaryFileStore
                    .write(
                        data:
                            pdf,
                        fileName:
                            pdfFileName
                    )


            let csvURL =
                try ReportTemporaryFileStore
                    .write(
                        text:
                            csv,
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

    // Helpers

    private func toggle(
        _ id:
            UUID
    ) {

        if selectedIDs
            .contains(
                id
            ) {

            selectedIDs
                .remove(
                    id
                )

        } else {

            selectedIDs
                .insert(
                    id
                )
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


    private var safeBaseName:
        String {

        document
            .resolvedDisplayName
            .replacingOccurrences(
                of:
                    "/",
                with:
                    "-"
            )
            .replacingOccurrences(
                of:
                    ":",
                with:
                    "-"
            )
    }


    private var pdfSaveBaseName:
        String {

        "\(safeBaseName) - Financial Report"
    }


    private var csvSaveBaseName:
        String {

        "\(safeBaseName) - Transactions"
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
