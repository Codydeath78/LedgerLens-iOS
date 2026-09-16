import SwiftUI
internal import Combine

@MainActor
final class DocumentWorkspace:
    ObservableObject {

    enum Tab:
        Hashable {

        case home
        case analyze
        case insights
        case history
    }


    enum AnalyzeLaunchAction:
        String,
        Sendable {

        case upload
        case scan
    }


    struct PendingAnalyzeAction:
        Identifiable,
        Sendable {

        let id =
            UUID()

        let action:
            AnalyzeLaunchAction
    }


    struct PendingDocument:
        Identifiable {

        let id =
            UUID()

        let financialDocument:
            FinancialDocument

        let historyDocumentID:
            UUID

        let displayName:
            String

        let summary:
            HistoryDocumentSummary?

        let conversations:
            [DocumentConversation]
    }


    @Published
    var selectedTab:
        Tab = .home

    @Published private(set)
    var pendingAnalyzeAction:
        PendingAnalyzeAction?

    @Published private(set)
    var pendingDocument:
        PendingDocument?


    // Navigation

    func showHome() {

        selectedTab =
            .home
    }


    func showHistory() {

        selectedTab =
            .history
    }


    func showInsights() {

        selectedTab =
            .insights
    }


    func requestAnalyze(
        _ action:
            AnalyzeLaunchAction
    ) {

        pendingAnalyzeAction =
            PendingAnalyzeAction(
                action:
                    action
            )

        selectedTab =
            .analyze
    }


    func consumeAnalyzeAction()
        -> PendingAnalyzeAction? {

        let value =
            pendingAnalyzeAction

        pendingAnalyzeAction =
            nil

        return value
    }


    // Document Continuity

    func openFromHistory(
        financialDocument:
            FinancialDocument,
        historyDocumentID:
            UUID,
        displayName:
            String,
        summary:
            HistoryDocumentSummary?,
        conversations:
            [DocumentConversation]
    ) {

        pendingDocument =
            PendingDocument(
                financialDocument:
                    financialDocument,
                historyDocumentID:
                    historyDocumentID,
                displayName:
                    displayName,
                summary:
                    summary,
                conversations:
                    conversations
            )

        selectedTab =
            .analyze
    }


    func consumePendingDocument()
        -> PendingDocument? {

        let value =
            pendingDocument

        pendingDocument =
            nil

        return value
    }
}
