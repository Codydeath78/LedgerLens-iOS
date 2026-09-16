// Deterministic, local document-intelligence models.
// No AI is used to decide financial facts.

import Foundation


// Intelligence Model

struct DocumentIntelligence: Sendable {

    let institution:
        DocumentInstitutionInsight?

    let suggestedName:
        String?

    let shouldAutoApplySuggestedName:
        Bool

    let importantDates:
        [DocumentImportantDate]

    let largestCharges:
        [DocumentChargeInsight]

    let duplicateCandidates:
        [DocumentDuplicateChargeCandidate]

    let unusualChargeSignals:
        [DocumentUnusualChargeSignal]

    let balanceMovement:
        DocumentBalanceMovement?

    let attentionItems:
        [DocumentAttentionItem]

    let spendingBasis:
        String?

    let analyzedSpendingRecordCount:
        Int
}


// Institution

struct DocumentInstitutionInsight: Sendable {

    enum Confidence:
        String,
        Sendable {

        case high =
            "High confidence"

        case medium =
            "Likely"
    }


    let name:
        String

    let confidence:
        Confidence

    let source:
        String
}



// Important Dates

struct DocumentImportantDate:
    Identifiable,
    Sendable {

    let id:
        String

    let label:
        String

    let value:
        String

    let systemImage:
        String

    let date:
        Date?
}



// Charge Insights

struct DocumentChargeInsight:
    Identifiable,
    Sendable {

    let id:
        String

    let merchant:
        String

    let amount:
        Decimal

    let currency:
        String

    let date:
        Date?

    let category:
        String?
}


struct DocumentDuplicateChargeCandidate:
    Identifiable,
    Sendable {

    let id:
        String

    let merchant:
        String

    let amount:
        Decimal

    let currency:
        String

    let firstDate:
        Date

    let secondDate:
        Date

    let daysApart:
        Int
}


struct DocumentUnusualChargeSignal:
    Identifiable,
    Sendable {

    let id:
        String

    let charge:
        DocumentChargeInsight

    let typicalAmount:
        Decimal

    let multipleOfTypical:
        Double
}


// Balance Movement

struct DocumentBalanceMovement: Sendable {

    let beginning:
        Decimal

    let ending:
        Decimal

    let delta:
        Decimal

    let currency:
        String


    var directionText:
        String {

        let value =
            NSDecimalNumber(
                decimal:
                    delta
            )
            .doubleValue


        if value > 0 {

            return
                "Balance increased"
        }


        if value < 0 {

            return
                "Balance decreased"
        }


        return
            "Balance was unchanged"
    }
}


// Attention Summary

struct DocumentAttentionItem:
    Identifiable,
    Sendable {

    enum Level:
        String,
        Sendable {

        case action
        case review
        case information
    }


    let id:
        String

    let level:
        Level

    let title:
        String

    let detail:
        String

    let systemImage:
        String
}
