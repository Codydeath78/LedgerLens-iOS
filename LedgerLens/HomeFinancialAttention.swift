
// Home Intelligence / Financial Attention Feed

import Foundation


struct HomeFinancialAttentionFeed:
    Sendable,
    Equatable {

    let items:
        [HomeFinancialAttentionItem]

    let urgentCount:
        Int

    let reviewCount:
        Int

    let informationCount:
        Int

    let deepAnalyzedDocumentCount:
        Int

    let totalDocumentCount:
        Int

    let failedDeepAnalysisCount:
        Int


    var hasPartialDeepCoverage:
        Bool {

        deepAnalyzedDocumentCount
        <
        totalDocumentCount
    }
}


struct HomeFinancialAttentionItem:
    Identifiable,
    Sendable,
    Equatable {

    enum Kind:
        String,
        Sendable {

        case billDue
        case repeatedCharge
        case unusualCharge
        case balanceMovement
        case recentDocument
    }


    enum Priority:
        Int,
        Sendable {

        case urgent = 0
        case review = 1
        case information = 2
    }


    let id:
        String

    let kind:
        Kind

    let priority:
        Priority

    let document:
        HistoryDocument

    let title:
        String

    let detail:
        String

    let createdAt:
        Date
}
