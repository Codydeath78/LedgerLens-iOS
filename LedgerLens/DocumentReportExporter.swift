// Professional PDF reports + CSV transaction export.
// Fixed PDF colors prevent Dark Mode text from becoming
// invisible on the white PDF page.

import SwiftUI
import UIKit
import UniformTypeIdentifiers


// File Documents

struct DocumentReportFile:
    FileDocument {

    static var readableContentTypes:
        [UTType] {

        [.pdf]
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


struct FinancialCSVFile:
    FileDocument {

    static var readableContentTypes:
        [UTType] {

        [
            .commaSeparatedText,
            .plainText
        ]
    }


    let text:
        String


    init(
        text:
            String
    ) {

        self.text =
            text
    }


    init(
        configuration:
            ReadConfiguration
    ) throws {

        let data =
            configuration
                .file
                .regularFileContents
            ??
            Data()


        text =
            String(
                data:
                    data,
                encoding:
                    .utf8
            )
            ??
            ""
    }


    func fileWrapper(
        configuration:
            WriteConfiguration
    ) throws -> FileWrapper {

        FileWrapper(
            regularFileWithContents:
                Data(
                    text.utf8
                )
        )
    }
}


// Professional PDF Builder

enum DocumentReportPDFBuilder {

    // Backward-compatible entry point retained so any older
    // call site does not break. The export sheet uses
    // makeProfessionalSingleDocumentPDF(...) below.
    static func makePDF(
        document:
            HistoryDocument,
        summary:
            HistoryDocumentSummary?,
        conversations:
            [DocumentConversation]
    ) -> Data {

        render {
            writer in

            writer.coverPage(
                title:
                    document
                        .resolvedDisplayName,
                subtitle:
                    "Financial Document Explanation Report",
                details: [
                    document
                        .prettyDocumentType,
                    "Processed \(document.createdAt.formatted(date: .long, time: .shortened))"
                ]
            )


            writer.beginSectionPage(
                "Document Summary"
            )


            if let summary {

                writer.heading(
                    summary
                        .headline
                )


                if let subheadline =
                    summary
                        .subheadline {

                    writer.paragraph(
                        subheadline,
                        secondary:
                            true
                    )
                }


                for item
                    in summary
                        .items {

                    writer.keyValue(
                        item.label,
                        item.value
                    )
                }

            } else {

                writer.paragraph(
                    "No deterministic summary was available for this document."
                )
            }


            writer.space(
                12
            )

            writer.subheading(
                "Source metadata"
            )

            writer.keyValue(
                "Source",
                document
                    .sourceType
                    .capitalized
            )

            writer.keyValue(
                "Original file",
                document
                    .fileName
            )


            writeConversations(
                conversations,
                writer:
                    writer
            )


            writer.reportNotes()
        }
    }


    static func makeProfessionalSingleDocumentPDF(
        document:
            CrossDocumentLoadedDocument,
        metric:
            CrossDocumentMetric,
        conversations:
            [DocumentConversation],
        includeTransactions:
            Bool
    ) -> Data {

        render {
            writer in

            let profile =
                document
                    .profile


            var coverDetails:
                [String] = [
                document
                    .history
                    .prettyDocumentType
            ]


            if let period =
                profile
                    .period {

                coverDetails.append(
                    period
                        .caption
                )
            }


            if let vendor =
                profile
                    .vendorName {

                coverDetails.append(
                    vendor
                )
            }


            coverDetails.append(
                "Generated \(Date().formatted(date: .long, time: .shortened))"
            )


            writer.coverPage(
                title:
                    document
                        .displayName,
                subtitle:
                    "Professional Financial Report",
                details:
                    coverDetails
            )


            writer.beginSectionPage(
                "Executive Summary"
            )


            if let summary =
                document
                    .summary {

                writer.heading(
                    summary
                        .headline
                )


                if let subheadline =
                    summary
                        .subheadline {

                    writer.paragraph(
                        subheadline,
                        secondary:
                            true
                    )
                }


                writer.space(
                    6
                )


                for item
                    in summary
                        .items {

                    writer.keyValue(
                        item.label,
                        item.value
                    )
                }


                writer.space(
                    12
                )
            }


            writer.subheading(
                "Verified calculated totals"
            )


            if metric
                .spending
                .isEmpty {

                writer.paragraph(
                    "No verified spending total was available."
                )

            } else {

                for total
                    in metric
                        .spending {

                    writer.keyValue(
                        "Spending • \(total.currency)",
                        CrossDocumentAnalysisEngine
                            .formatMoney(
                                total.amount,
                                currency:
                                    total.currency
                            )
                    )
                }
            }


            writer.keyValue(
                "Spending basis",
                metric
                    .spendingBasis
            )


            if !metric
                .inflows
                .isEmpty {

                writer.space(
                    7
                )

                for total
                    in metric
                        .inflows {

                    writer.keyValue(
                        "Detected inflows • \(total.currency)",
                        CrossDocumentAnalysisEngine
                            .formatMoney(
                                total.amount,
                                currency:
                                    total.currency
                            )
                    )
                }
            }


            if let largest =
                metric
                    .largestCharge {

                writer.space(
                    7
                )

                writer.keyValue(
                    "Largest included charge",
                    "\(CrossDocumentAnalysisEngine.merchantLabel(largest)) • \(CrossDocumentAnalysisEngine.formatMoney(largest.amount, currency: largest.currency))"
                )
            }


            writer.keyValue(
                "Extracted record count",
                "\(metric.transactionCount)"
            )


            writer.space(
                14
            )

            writer.subheading(
                "Source-document metadata"
            )


            writer.keyValue(
                "Document type",
                document
                    .history
                    .prettyDocumentType
            )

            writer.keyValue(
                "Source",
                document
                    .history
                    .sourceType
                    .capitalized
            )

            writer.keyValue(
                "Original file",
                document
                    .history
                    .fileName
            )

            writer.keyValue(
                "Processed",
                document
                    .history
                    .createdAt
                    .formatted(
                        date:
                            .long,
                        time:
                            .shortened
                    )
            )


            if let period =
                profile
                    .period {

                writer.keyValue(
                    period
                        .kind
                        .rawValue,
                    period
                        .formatted
                )
            }


            if let date =
                profile
                    .documentDate {

                writer.keyValue(
                    "Document date",
                    date.formatted(
                        date:
                            .long,
                        time:
                            .omitted
                    )
                )
            }


            if let due =
                profile
                    .dueDate {

                writer.keyValue(
                    "Due date",
                    due.formatted(
                        date:
                            .long,
                        time:
                            .omitted
                    )
                )
            }


            if let vendor =
                profile
                    .vendorName {

                writer.keyValue(
                    "Institution / Merchant",
                    vendor
                )
            }


            if let mime =
                document
                    .history
                    .originalMimeType {

                writer.keyValue(
                    "Original format",
                    mime
                )
            }


            if let bytes =
                document
                    .history
                    .originalSizeBytes {

                writer.keyValue(
                    "Original size",
                    ByteCountFormatter
                        .string(
                            fromByteCount:
                                bytes,
                            countStyle:
                                .file
                        )
                )
            }


            writeConversations(
                conversations,
                writer:
                    writer
            )


            if includeTransactions {

                writer.beginSectionPage(
                    "Normalized Transaction Table"
                )


                writer.paragraph(
                    "This table contains the normalized records restored from the saved document. The Spending Analysis column indicates whether each record was included in Phase 6A's cleaned spending dataset."
                )


                let pack =
                    CrossDocumentAnalysisEngine
                        .analyze(
                            [
                                document
                            ]
                        )


                writer.transactionTable(
                    transactions:
                        pack
                            .transactions,
                    spendingTransactions:
                        pack
                            .spendingTransactions
                )
            }


            writer.reportNotes()
        }
    }


    static func makeProfessionalCrossDocumentPDF(
        pack:
            CrossDocumentFactPack,
        currentQuestion:
            String?,
        currentAnswer:
            String?
    ) -> Data {

        render {
            writer in

            writer.coverPage(
                title:
                    "Cross-Document Financial Analysis",
                subtitle:
                    "\(pack.documents.count) Selected Documents",
                details: [
                    "Deterministic spending comparison",
                    "Recurring-payment detection",
                    "Merchant and category totals",
                    "Generated \(Date().formatted(date: .long, time: .shortened))"
                ]
            )


            writer.beginSectionPage(
                "Executive Comparison"
            )


            for metric
                in pack
                    .metrics {

                writer.heading(
                    metric
                        .document
                        .displayName
                )


                if let period =
                    metric
                        .document
                        .profile
                        .period {

                    writer.keyValue(
                        period
                            .kind
                            .rawValue,
                        period
                            .formatted
                    )
                }


                for spending
                    in metric
                        .spending {

                    writer.keyValue(
                        "Verified spending • \(spending.currency)",
                        CrossDocumentAnalysisEngine
                            .formatMoney(
                                spending
                                    .amount,
                                currency:
                                    spending
                                        .currency
                            )
                    )
                }


                writer.keyValue(
                    "Spending basis",
                    metric
                        .spendingBasis
                )


                writer.keyValue(
                    "Extracted records",
                    "\(metric.transactionCount)"
                )


                if let largest =
                    metric
                        .largestCharge {

                    writer.keyValue(
                        "Largest included charge",
                        "\(CrossDocumentAnalysisEngine.merchantLabel(largest)) • \(CrossDocumentAnalysisEngine.formatMoney(largest.amount, currency: largest.currency))"
                    )
                }


                writer.space(
                    12
                )
            }


            if !pack
                .spendingChanges
                .isEmpty {

                writer.subheading(
                    "Changes between periods"
                )


                for change
                    in pack
                        .spendingChanges {

                    let percent =
                        change
                            .percentChange
                            .map {
                                String(
                                    format:
                                        " (%.1f%%)",
                                    $0
                                )
                            }
                        ??
                        ""


                    writer.bullet(
                        "\(change.fromDocumentName) → \(change.toDocumentName): \(CrossDocumentAnalysisEngine.formatMoney(change.previousAmount, currency: change.currency)) → \(CrossDocumentAnalysisEngine.formatMoney(change.currentAmount, currency: change.currency)); change \(CrossDocumentAnalysisEngine.formatMoney(change.delta, currency: change.currency))\(percent)"
                    )
                }
            }


            writer.beginSectionPage(
                "Recurring Payments"
            )


            if pack
                .recurringPayments
                .isEmpty {

                writer.paragraph(
                    "No recurring-payment patterns were detected across the selected documents."
                )

            } else {

                let monthlyByCurrency =
                    Dictionary(
                        grouping:
                            pack
                                .recurringPayments
                                .compactMap {
                                    pattern
                                    ->
                                    (
                                        String,
                                        Decimal
                                    )?
                                    in

                                    guard
                                        let monthly =
                                            pattern
                                                .estimatedMonthlyAmount
                                    else {
                                        return nil
                                    }


                                    return (
                                        pattern
                                            .currency,
                                        monthly
                                    )
                                },
                        by:
                            \.0
                    )


                if !monthlyByCurrency
                    .isEmpty {

                    writer.subheading(
                        "Estimated recurring monthly impact"
                    )


                    for currency
                        in monthlyByCurrency
                            .keys
                            .sorted() {

                        let total =
                            monthlyByCurrency[
                                currency,
                                default: []
                            ]
                            .reduce(
                                Decimal.zero
                            ) {
                                partial,
                                item in

                                partial
                                +
                                item.1
                            }


                        writer.keyValue(
                            currency,
                            CrossDocumentAnalysisEngine
                                .formatMoney(
                                    total,
                                    currency:
                                        currency
                                )
                        )
                    }


                    writer.space(
                        10
                    )
                }


                for pattern
                    in pack
                        .recurringPayments {

                    writer.heading(
                        pattern
                            .merchant
                    )

                    writer.keyValue(
                        "Cadence",
                        pattern
                            .cadence
                            .rawValue
                    )

                    writer.keyValue(
                        "Typical charge",
                        CrossDocumentAnalysisEngine
                            .formatMoney(
                                pattern
                                    .typicalAmount,
                                currency:
                                    pattern
                                        .currency
                            )
                    )

                    writer.keyValue(
                        "Confidence",
                        pattern
                            .confidence
                            .rawValue
                    )

                    writer.keyValue(
                        "Occurrences",
                        "\(pattern.occurrences.count)"
                    )


                    if let monthly =
                        pattern
                            .estimatedMonthlyAmount {

                        writer.keyValue(
                            "Estimated monthly",
                            CrossDocumentAnalysisEngine
                                .formatMoney(
                                    monthly,
                                    currency:
                                        pattern
                                            .currency
                                )
                        )
                    }


                    if let annual =
                        pattern
                            .estimatedAnnualAmount {

                        writer.keyValue(
                            "Estimated annual",
                            CrossDocumentAnalysisEngine
                                .formatMoney(
                                    annual,
                                    currency:
                                        pattern
                                            .currency
                                )
                        )
                    }


                    for occurrence
                        in pattern
                            .occurrences {

                        writer.bullet(
                            "\(occurrence.date.formatted(date: .abbreviated, time: .omitted)) • \(occurrence.documentName) • \(CrossDocumentAnalysisEngine.formatMoney(occurrence.amount, currency: occurrence.currency))"
                        )
                    }


                    writer.space(
                        10
                    )
                }
            }


            writer.beginSectionPage(
                "Spending Breakdown"
            )


            writer.subheading(
                "Top merchants"
            )


            if pack
                .merchantTotals
                .isEmpty {

                writer.paragraph(
                    "No merchant totals were available."
                )

            } else {

                for item
                    in pack
                        .merchantTotals
                        .prefix(
                            30
                        ) {

                    writer.keyValue(
                        item
                            .merchant,
                        "\(CrossDocumentAnalysisEngine.formatMoney(item.amount, currency: item.currency)) • \(item.count) included charge\(item.count == 1 ? "" : "s")"
                    )
                }
            }


            writer.space(
                14
            )

            writer.subheading(
                "Top categories"
            )


            if pack
                .categoryTotals
                .isEmpty {

                writer.paragraph(
                    "No category totals were available."
                )

            } else {

                for item
                    in pack
                        .categoryTotals
                        .prefix(
                            30
                        ) {

                    writer.keyValue(
                        item
                            .category,
                        "\(CrossDocumentAnalysisEngine.formatMoney(item.amount, currency: item.currency)) • \(item.count) included charge\(item.count == 1 ? "" : "s")"
                    )
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

                writer.beginSectionPage(
                    "AI Explanation"
                )

                writer.subheading(
                    "Question"
                )

                writer.paragraph(
                    currentQuestion,
                    bold:
                        true
                )

                writer.subheading(
                    "Explanation"
                )

                writer.paragraph(
                    currentAnswer
                )

                writer.smallText(
                    "This explanation was constrained to the verified fact pack generated by the app."
                )
            }


            writer.beginSectionPage(
                "Source-Document Metadata"
            )


            for document
                in pack
                    .documents {

                writer.heading(
                    document
                        .displayName
                )

                writer.keyValue(
                    "Type",
                    document
                        .history
                        .prettyDocumentType
                )

                writer.keyValue(
                    "Source",
                    document
                        .history
                        .sourceType
                        .capitalized
                )

                writer.keyValue(
                    "Original file",
                    document
                        .history
                        .fileName
                )


                if let period =
                    document
                        .profile
                        .period {

                    writer.keyValue(
                        period
                            .kind
                            .rawValue,
                        period
                            .formatted
                    )
                }


                if let date =
                    document
                        .profile
                        .documentDate {

                    writer.keyValue(
                        "Document date",
                        date.formatted(
                            date:
                                .long,
                            time:
                                .omitted
                        )
                    )
                }


                if let due =
                    document
                        .profile
                        .dueDate {

                    writer.keyValue(
                        "Due date",
                        due.formatted(
                            date:
                                .long,
                            time:
                                .omitted
                        )
                    )
                }


                if let vendor =
                    document
                        .profile
                        .vendorName {

                    writer.keyValue(
                        "Institution / Merchant",
                        vendor
                    )
                }


                writer.space(
                    12
                )
            }


            writer.beginSectionPage(
                "Combined Transaction Table"
            )


            writer.paragraph(
                "All normalized records are shown below. Spending Analysis = Yes only when the cleaned Phase 6A dataset included that record in spending and recurring-payment analytics."
            )


            writer.transactionTable(
                transactions:
                    pack
                        .transactions,
                spendingTransactions:
                    pack
                        .spendingTransactions
            )


            writer.reportNotes()
        }
    }


    // Shared PDF Helpers

    private static func writeConversations(
        _ conversations:
            [DocumentConversation],
        writer:
            ProfessionalPDFWriter
    ) {

        guard
            !conversations
                .isEmpty
        else {
            return
        }


        writer.beginSectionPage(
            "Selected AI Explanations"
        )


        for (
            index,
            conversation
        ) in conversations
            .enumerated() {

            writer.subheading(
                "Question \(index + 1)"
            )

            writer.paragraph(
                conversation
                    .question,
                bold:
                    true
            )

            writer.paragraph(
                conversation
                    .answer
            )

            writer.smallText(
                "\(conversation.retrievalMode.lowercased().capitalized) analysis • \(conversation.createdAt.formatted(date: .abbreviated, time: .shortened))"
            )

            writer.space(
                12
            )
        }
    }


    private static func render(
        _ build:
            (ProfessionalPDFWriter) -> Void
    ) -> Data {

        let pageRect =
            CGRect(
                x: 0,
                y: 0,
                width: 612,
                height: 792
            )


        let renderer =
            UIGraphicsPDFRenderer(
                bounds:
                    pageRect
            )


        return
            renderer.pdfData {
                context in

                let writer =
                    ProfessionalPDFWriter(
                        context:
                            context,
                        pageRect:
                            pageRect
                    )


                build(
                    writer
                )
            }
    }
}


// CSV Builder

enum FinancialCSVBuilder {

    static func makeSingleDocumentCSV(
        document:
            CrossDocumentLoadedDocument
    ) -> String {

        let pack =
            CrossDocumentAnalysisEngine
                .analyze(
                    [
                        document
                    ]
                )


        return
            makeCSV(
                pack:
                    pack
            )
    }


    static func makeCrossDocumentCSV(
        pack:
            CrossDocumentFactPack
    ) -> String {

        makeCSV(
            pack:
                pack
        )
    }


    private static func makeCSV(
        pack:
            CrossDocumentFactPack
    ) -> String {

        let header =
            [
                "document_name",
                "document_type",
                "period_kind",
                "period_start",
                "period_end",
                "spending_basis",
                "included_in_spending_analysis",
                "record_id",
                "transaction_date",
                "effective_date",
                "posted_date",
                "description",
                "vendor",
                "category",
                "amount",
                "currency",
                "flow",
                "status",
                "role"
            ]


        var rows:
            [String] = [
                header.joined(
                    separator:
                        ","
                )
            ]


        let spendingIDs =
            Set(
                pack
                    .spendingTransactions
                    .map(
                        \.id
                    )
            )


        let metricByDocumentID =
            Dictionary(
                uniqueKeysWithValues:
                    pack
                        .metrics
                        .map {
                            (
                                $0.document.id,
                                $0
                            )
                        }
            )


        let loadedByDocumentID =
            Dictionary(
                uniqueKeysWithValues:
                    pack
                        .documents
                        .map {
                            (
                                $0.id,
                                $0
                            )
                        }
            )


        for item
            in pack
                .transactions {

            guard
                let loaded =
                    loadedByDocumentID[
                        item
                            .documentID
                    ]
            else {
                continue
            }


            let metric =
                metricByDocumentID[
                    item
                        .documentID
                ]


            let period =
                loaded
                    .profile
                    .period


            let values =
                [
                    loaded
                        .displayName,

                    loaded
                        .history
                        .prettyDocumentType,

                    period?
                        .kind
                        .rawValue
                    ??
                    "",

                    csvDate(
                        period?
                            .start
                    ),

                    csvDate(
                        period?
                            .end
                    ),

                    metric?
                        .spendingBasis
                    ??
                    "",

                    spendingIDs
                        .contains(
                            item.id
                        )
                    ? "yes"
                    : "no",

                    item
                        .record
                        .id
                        .uuidString,

                    csvDate(
                        item
                            .record
                            .date
                    ),

                    csvDate(
                        item
                            .effectiveDate
                    ),

                    csvDate(
                        item
                            .record
                            .postedDate
                    ),

                    item
                        .record
                        .description,

                    item
                        .record
                        .vendor
                    ??
                    "",

                    item
                        .record
                        .category
                    ??
                    "",

                    NSDecimalNumber(
                        decimal:
                            item
                                .record
                                .amount
                    )
                    .stringValue,

                    item
                        .record
                        .currency,

                    item
                        .record
                        .flow
                        .rawValue,

                    item
                        .record
                        .status
                        .rawValue,

                    item
                        .record
                        .role
                        .rawValue
                ]


            rows.append(
                values
                    .map(
                        csvEscape
                    )
                    .joined(
                        separator:
                            ","
                    )
            )
        }


        // UTF-8 BOM improves opening CSVs directly in Excel
        // while remaining valid plain CSV text.
        return
            "\u{FEFF}"
            +
            rows
                .joined(
                    separator:
                        "\n"
                )
    }


    private static func csvDate(
        _ date:
            Date?
    ) -> String {

        guard
            let date
        else {
            return ""
        }


        let formatter =
            DateFormatter()

        formatter.locale =
            Locale(
                identifier:
                    "en_US_POSIX"
            )

        formatter.timeZone =
            TimeZone(
                secondsFromGMT:
                    0
            )

        formatter.dateFormat =
            "yyyy-MM-dd"


        return
            formatter.string(
                from:
                    date
            )
    }


    private static func csvEscape(
        _ raw:
            String
    ) -> String {

        let clean =
            PlainTextSanitizer
                .clean(
                    raw
                )


        let escaped =
            clean
                .replacingOccurrences(
                    of:
                        "\"",
                    with:
                        "\"\""
                )


        if escaped
            .contains(
                ","
            )
            ||
            escaped
                .contains(
                    "\""
                )
            ||
            escaped
                .contains(
                    "\n"
                ) {

            return
                "\"\(escaped)\""
        }


        return escaped
    }
}


// Fixed PDF Palette

private enum ProfessionalPDFPalette {

    static let pageBackground =
        UIColor.white

    static let primary =
        UIColor(
            red: 0.075,
            green: 0.09,
            blue: 0.13,
            alpha: 1
        )

    static let secondary =
        UIColor(
            red: 0.34,
            green: 0.37,
            blue: 0.43,
            alpha: 1
        )

    static let accent =
        UIColor(
            red: 0.12,
            green: 0.43,
            blue: 0.95,
            alpha: 1
        )

    static let accentDark =
        UIColor(
            red: 0.18,
            green: 0.20,
            blue: 0.58,
            alpha: 1
        )

    static let accentLight =
        UIColor(
            red: 0.93,
            green: 0.96,
            blue: 1.00,
            alpha: 1
        )

    static let rule =
        UIColor(
            red: 0.84,
            green: 0.86,
            blue: 0.89,
            alpha: 1
        )

    static let success =
        UIColor(
            red: 0.12,
            green: 0.50,
            blue: 0.30,
            alpha: 1
        )
}


// Professional PDF Writer

private final class ProfessionalPDFWriter {

    private let context:
        UIGraphicsPDFRendererContext

    private let pageRect:
        CGRect

    private let margin:
        CGFloat = 46

    private var y:
        CGFloat = 46

    private var pageNumber =
        0


    private var contentWidth:
        CGFloat {

        pageRect.width
        -
        margin
        *
        2
    }


    private var bottomLimit:
        CGFloat {

        pageRect.height
        -
        54
    }


    init(
        context:
            UIGraphicsPDFRendererContext,
        pageRect:
            CGRect
    ) {

        self.context =
            context

        self.pageRect =
            pageRect
    }


    // Pages

    func beginPage() {

        context.beginPage()

        pageNumber +=
            1


        ProfessionalPDFPalette
            .pageBackground
            .setFill()


        UIRectFill(
            pageRect
        )


        drawFooter()


        y =
            margin
    }


    func beginSectionPage(
        _ title:
            String
    ) {

        beginPage()


        drawText(
            title,
            font:
                .systemFont(
                    ofSize: 22,
                    weight:
                        .bold
                ),
            color:
                ProfessionalPDFPalette
                    .primary,
            spacingAfter:
                9
        )


        rule()


        space(
            5
        )
    }


    func coverPage(
        title:
            String,
        subtitle:
            String,
        details:
            [String]
    ) {

        beginPage()


        let band =
            CGRect(
                x: 0,
                y: 0,
                width:
                    pageRect
                        .width,
                height:
                    174
            )


        ProfessionalPDFPalette
            .accentLight
            .setFill()


        UIRectFill(
            band
        )


        let accentBar =
            CGRect(
                x: 0,
                y: 0,
                width: 9,
                height:
                    174
            )


        ProfessionalPDFPalette
            .accent
            .setFill()


        UIRectFill(
            accentBar
        )


        y =
            62


        drawText(
            "AI DOCUMENT & BILL EXPLAINER",
            font:
                .systemFont(
                    ofSize: 11,
                    weight:
                        .bold
                ),
            color:
                ProfessionalPDFPalette
                    .accent,
            spacingAfter:
                21
        )


        drawText(
            title,
            font:
                .systemFont(
                    ofSize: 30,
                    weight:
                        .bold
                ),
            color:
                ProfessionalPDFPalette
                    .primary,
            spacingAfter:
                9
        )


        drawText(
            subtitle,
            font:
                .systemFont(
                    ofSize: 16,
                    weight:
                        .medium
                ),
            color:
                ProfessionalPDFPalette
                    .secondary,
            spacingAfter:
                30
        )


        for detail
            in details {

            bullet(
                detail
            )
        }


        space(
            26
        )

        rule()


        space(
            15
        )


        paragraph(
            "This report combines normalized financial-document data, deterministic calculations, and selected AI explanations. Important financial decisions should be verified against the original source document."
        )
    }


    // MARK: Text Styles

    func heading(
        _ text:
            String
    ) {

        ensureRoom(
            34
        )


        drawText(
            text,
            font:
                .systemFont(
                    ofSize: 17,
                    weight:
                        .bold
                ),
            color:
                ProfessionalPDFPalette
                    .primary,
            spacingAfter:
                7
        )
    }


    func subheading(
        _ text:
            String
    ) {

        ensureRoom(
            30
        )


        drawText(
            text,
            font:
                .systemFont(
                    ofSize: 12.5,
                    weight:
                        .bold
                ),
            color:
                ProfessionalPDFPalette
                    .primary,
            spacingAfter:
                6
        )
    }


    func paragraph(
        _ text:
            String,
        bold:
            Bool = false,
        secondary:
            Bool = false
    ) {

        drawText(
            text,
            font:
                .systemFont(
                    ofSize: 10.4,
                    weight:
                        bold
                        ? .semibold
                        : .regular
                ),
            color:
                secondary
                ? ProfessionalPDFPalette
                    .secondary
                : ProfessionalPDFPalette
                    .primary,
            spacingAfter:
                8
        )
    }


    func smallText(
        _ text:
            String
    ) {

        drawText(
            text,
            font:
                .systemFont(
                    ofSize: 8.4
                ),
            color:
                ProfessionalPDFPalette
                    .secondary,
            spacingAfter:
                7
        )
    }


    func bullet(
        _ text:
            String
    ) {

        drawText(
            "• \(text)",
            font:
                .systemFont(
                    ofSize: 10.2
                ),
            color:
                ProfessionalPDFPalette
                    .primary,
            spacingAfter:
                6
        )
    }


    func keyValue(
        _ key:
            String,
        _ value:
            String
    ) {

        drawText(
            "\(key): \(value)",
            font:
                .systemFont(
                    ofSize: 10.2,
                    weight:
                        .regular
                ),
            color:
                ProfessionalPDFPalette
                    .primary,
            spacingAfter:
                5
        )
    }


    func space(
        _ amount:
            CGFloat
    ) {

        ensureRoom(
            amount
        )


        y +=
            amount
    }


    func rule() {

        ensureRoom(
            11
        )


        let path =
            UIBezierPath()


        path.move(
            to:
                CGPoint(
                    x:
                        margin,
                    y:
                        y
                )
        )


        path.addLine(
            to:
                CGPoint(
                    x:
                        pageRect
                            .width
                        -
                        margin,
                    y:
                        y
                )
        )


        ProfessionalPDFPalette
            .rule
            .setStroke()


        path.lineWidth =
            0.7


        path.stroke()


        y +=
            11
    }


    // Transaction Table

    func transactionTable(
        transactions:
            [CrossDocumentTransaction],
        spendingTransactions:
            [CrossDocumentTransaction]
    ) {

        if transactions
            .isEmpty {

            paragraph(
                "No normalized records were available."
            )

            return
        }


        let includedIDs =
            Set(
                spendingTransactions
                    .map(
                        \.id
                    )
            )


        drawTransactionHeader()


        for item
            in transactions {

            drawTransactionRow(
                item,
                included:
                    includedIDs
                        .contains(
                            item.id
                        )
            )
        }
    }


    private func drawTransactionHeader() {

        ensureRoom(
            29
        )


        let rect =
            CGRect(
                x:
                    margin,
                y:
                    y,
                width:
                    contentWidth,
                height:
                    23
            )


        ProfessionalPDFPalette
            .accentLight
            .setFill()


        UIBezierPath(
            roundedRect:
                rect,
            cornerRadius:
                5
        )
        .fill()


        drawCell(
            "Date",
            x:
                margin + 4,
            width:
                61,
            y:
                y + 6,
            bold:
                true
        )

        drawCell(
            "Description",
            x:
                margin + 68,
            width:
                209,
            y:
                y + 6,
            bold:
                true
        )

        drawCell(
            "Amount",
            x:
                margin + 281,
            width:
                82,
            y:
                y + 6,
            bold:
                true
        )

        drawCell(
            "Role",
            x:
                margin + 367,
            width:
                70,
            y:
                y + 6,
            bold:
                true
        )

        drawCell(
            "Spend?",
            x:
                margin + 441,
            width:
                69,
            y:
                y + 6,
            bold:
                true
        )


        y +=
            29
    }


    private func drawTransactionRow(
        _ item:
            CrossDocumentTransaction,
        included:
            Bool
    ) {

        let height:
            CGFloat =
            28


        if y
            +
            height
            >
            bottomLimit {

            beginSectionPage(
                "Transaction Table — Continued"
            )

            drawTransactionHeader()
        }


        let record =
            item
                .record


        let dateText =
            item
                .effectiveDate?
                .formatted(
                    date:
                        .numeric,
                    time:
                        .omitted
                )
            ??
            record
                .date?
                .formatted(
                    date:
                        .numeric,
                    time:
                        .omitted
                )
            ??
            "—"


        let merchant =
            CrossDocumentAnalysisEngine
                .merchantLabel(
                    record
                )


        let description =
            merchant
            ==
            record
                .description
            ? record
                .description
            : "\(merchant) — \(record.description)"


        drawCell(
            dateText,
            x:
                margin + 4,
            width:
                61,
            y:
                y + 7
        )

        drawCell(
            description,
            x:
                margin + 68,
            width:
                209,
            y:
                y + 7
        )

        drawCell(
            CrossDocumentAnalysisEngine
                .formatMoney(
                    record
                        .amount,
                    currency:
                        record
                            .currency
                ),
            x:
                margin + 281,
            width:
                82,
            y:
                y + 7
        )

        drawCell(
            record
                .role
                .rawValue
                .capitalized,
            x:
                margin + 367,
            width:
                70,
            y:
                y + 7
        )

        drawCell(
            included
            ? "Yes"
            : "No",
            x:
                margin + 441,
            width:
                69,
            y:
                y + 7,
            bold:
                included
        )


        let line =
            UIBezierPath()


        line.move(
            to:
                CGPoint(
                    x:
                        margin,
                    y:
                        y
                        +
                        height
                )
        )


        line.addLine(
            to:
                CGPoint(
                    x:
                        pageRect
                            .width
                        -
                        margin,
                    y:
                        y
                        +
                        height
                )
        )


        ProfessionalPDFPalette
            .rule
            .setStroke()


        line.lineWidth =
            0.35


        line.stroke()


        y +=
            height
    }


    private func drawCell(
        _ raw:
            String,
        x:
            CGFloat,
        width:
            CGFloat,
        y:
            CGFloat,
        bold:
            Bool = false
    ) {

        let text =
            clean(
                raw
            )


        let paragraph =
            NSMutableParagraphStyle()


        paragraph.lineBreakMode =
            .byTruncatingTail


        (
            text
            as NSString
        )
        .draw(
            in:
                CGRect(
                    x:
                        x,
                    y:
                        y,
                    width:
                        width,
                    height:
                        14
                ),
            withAttributes: [
                .font:
                    UIFont
                        .systemFont(
                            ofSize:
                                7.4,
                            weight:
                                bold
                                ? .semibold
                                : .regular
                        ),
                .foregroundColor:
                    ProfessionalPDFPalette
                        .primary,
                .paragraphStyle:
                    paragraph
            ]
        )
    }


    // Report Notes

    func reportNotes() {

        beginSectionPage(
            "Report Notes"
        )


        paragraph(
            "Verified spending totals are produced by deterministic application logic. Phase 6A uses authoritative statement purchases or bill totals when available and excludes known card payments, credits, and duplicate bill representations from spending analytics."
        )


        paragraph(
            "Different currencies are never silently combined or converted."
        )


        paragraph(
            "Recurring-payment detection uses repeated merchant, amount, timing, and cross-document patterns. A recurring pattern is a review signal, not proof that a subscription is currently active."
        )


        paragraph(
            "AI explanations are constrained to verified application facts, but AI can still make mistakes. Review important financial details against the original statement, bill, receipt, or invoice."
        )
    }


    // Drawing Engine

    private func drawText(
        _ raw:
            String,
        font:
            UIFont,
        color:
            UIColor,
        spacingAfter:
            CGFloat
    ) {

        let text =
            clean(
                raw
            )


        let paragraphs =
            text
                .replacingOccurrences(
                    of:
                        "\r\n",
                    with:
                        "\n"
                )
                .components(
                    separatedBy:
                        "\n"
                )


        for paragraph
            in paragraphs {

            if paragraph
                .isEmpty {

                space(
                    font
                        .lineHeight
                    *
                    0.55
                )

                continue
            }


            writeParagraph(
                paragraph,
                font:
                    font,
                color:
                    color
            )
        }


        y +=
            spacingAfter
    }


    private func writeParagraph(
        _ text:
            String,
        font:
            UIFont,
        color:
            UIColor
    ) {

        let attributes:
            [NSAttributedString.Key:
                Any] = [
            .font:
                font,
            .foregroundColor:
                color
        ]


        let words =
            text
                .split(
                    separator:
                        " ",
                    omittingEmptySubsequences:
                        true
                )
                .map(
                    String.init
                )


        guard
            !words
                .isEmpty
        else {
            return
        }


        var current =
            ""


        for word
            in words {

            let candidate =
                current
                    .isEmpty
                ? word
                : "\(current) \(word)"


            let height =
                measuredHeight(
                    candidate,
                    attributes:
                        attributes
                )


            if height
                >
                bottomLimit
                -
                y,
               !current
                    .isEmpty {

                drawBlock(
                    current,
                    attributes:
                        attributes
                )

                beginPage()

                current =
                    word

            } else {

                current =
                    candidate
            }
        }


        if !current
            .isEmpty {

            if measuredHeight(
                current,
                attributes:
                    attributes
            )
            >
            bottomLimit
                -
                y {

                beginPage()
            }


            drawBlock(
                current,
                attributes:
                    attributes
            )
        }
    }


    private func drawBlock(
        _ text:
            String,
        attributes:
            [NSAttributedString.Key:
                Any]
    ) {

        let height =
            measuredHeight(
                text,
                attributes:
                    attributes
            )


        let rect =
            CGRect(
                x:
                    margin,
                y:
                    y,
                width:
                    contentWidth,
                height:
                    height
            )


        (
            text
            as NSString
        )
        .draw(
            with:
                rect,
            options: [
                .usesLineFragmentOrigin,
                .usesFontLeading
            ],
            attributes:
                attributes,
            context:
                nil
        )


        y +=
            height
            +
            3
    }


    private func measuredHeight(
        _ text:
            String,
        attributes:
            [NSAttributedString.Key:
                Any]
    ) -> CGFloat {

        let rect =
            (
                text
                as NSString
            )
            .boundingRect(
                with:
                    CGSize(
                        width:
                            contentWidth,
                        height:
                            .greatestFiniteMagnitude
                    ),
                options: [
                    .usesLineFragmentOrigin,
                    .usesFontLeading
                ],
                attributes:
                    attributes,
                context:
                    nil
            )


        return
            ceil(
                rect
                    .height
            )
            +
            1
    }


    private func ensureRoom(
        _ height:
            CGFloat
    ) {

        if y
            +
            height
            >
            bottomLimit {

            beginPage()
        }
    }


    private func drawFooter() {

        let footer =
            "AI Document & Bill Explainer • Page \(pageNumber)"


        (
            footer
            as NSString
        )
        .draw(
            in:
                CGRect(
                    x:
                        margin,
                    y:
                        pageRect
                            .height
                        -
                        31,
                    width:
                        contentWidth,
                    height:
                        13
                ),
            withAttributes: [
                .font:
                    UIFont
                        .systemFont(
                            ofSize:
                                7.5
                        ),
                .foregroundColor:
                    ProfessionalPDFPalette
                        .secondary
            ]
        )
    }


    private func clean(
        _ text:
            String
    ) -> String {

        PlainTextSanitizer
            .clean(
                text
            )
    }
}
