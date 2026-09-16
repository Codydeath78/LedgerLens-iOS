import Foundation

// Text Chunk

struct TextChunk: Identifiable, Hashable {
    let id: UUID
    let text: String

    init(id: UUID = UUID(), text: String) {
        self.id = id
        self.text = text
    }
}

// Normalized Financial Model

enum TransactionStatus: String, Codable {
    case pending
    case posted
    case unknown
}

enum MoneyFlow: String, Codable {
    case outflow
    case inflow
    case neutral
    case unknown
}

enum FinancialRecordRole: String, Codable {
    case transaction
    case purchase
    case withdrawal
    case deposit
    case payment
    case credit
    case fee
    case billCharge
    case refund
    case unknown
}

struct TransactionRecord: Identifiable, Hashable {
    let id: UUID
    let chunkID: UUID
    let date: Date?
    let postedDate: Date?
    let amount: Decimal
    let currency: String
    let status: TransactionStatus
    let flow: MoneyFlow
    let role: FinancialRecordRole
    let description: String
    let vendor: String?
    let category: String?
    let sourceText: String

    init(
        id: UUID = UUID(),
        chunkID: UUID,
        date: Date?,
        postedDate: Date? = nil,
        amount: Decimal,
        currency: String = "USD",
        status: TransactionStatus = .unknown,
        flow: MoneyFlow = .unknown,
        role: FinancialRecordRole = .transaction,
        description: String,
        vendor: String? = nil,
        category: String? = nil,
        sourceText: String
    ) {
        self.id = id
        self.chunkID = chunkID
        self.date = date
        self.postedDate = postedDate
        self.amount = amount < 0 ? -amount : amount
        self.currency = currency
        self.status = status
        self.flow = flow
        self.role = role
        self.description = description
        self.vendor = vendor
        self.category = category
        self.sourceText = sourceText
    }

    var signedAmount: Decimal {
        switch flow {
        case .outflow:
            return -amount
        case .inflow:
            return amount
        case .neutral, .unknown:
            return amount
        }
    }

    var searchableText: String {
        [
            description,
            vendor,
            category,
            status == .unknown ? nil : status.rawValue,
            role.rawValue,
            sourceText
        ]
        .compactMap { $0 }
        .joined(separator: " ")
        .lowercased()
    }
}

struct FinancialDocument {
    let veryfiDocumentID: Int?
    let documentType: String
    let displayText: String
    let chunks: [TextChunk]
    let records: [TransactionRecord]
}

// Embeddings

struct EmbeddingVector {
    let vector: [Float]
}

protocol EmbeddingProvider {
    func embeddings(for texts: [String]) async throws -> [EmbeddingVector]
}

extension EmbeddingProvider {
    func embedding(for text: String) async throws -> EmbeddingVector {
        let result = try await embeddings(for: [text])
        guard let first = result.first else {
            throw OpenAIError.missingEmbedding
        }
        return first
    }
}

struct StubEmbeddingProvider: EmbeddingProvider {
    func embeddings(for texts: [String]) async throws -> [EmbeddingVector] {
        texts.map { _ in
            EmbeddingVector(
                vector: (0..<384).map { _ in Float.random(in: -1...1) }
            )
        }
    }
}

// Structured Filtering

enum AmountComparison: Equatable {
    case greaterThan(Decimal)
    case greaterThanOrEqual(Decimal)
    case lessThan(Decimal)
    case lessThanOrEqual(Decimal)
    case equal(Decimal)
    case between(Decimal, Decimal)
}

struct TransactionDateCriterion: Equatable {
    let month: Int
    let day: Int?
    let year: Int?
}

struct TransactionFilter: Equatable {
    var date: TransactionDateCriterion?
    var amount: AmountComparison?
    var status: TransactionStatus?
    var categoryTerms: [String] = []
    var textTerms: [String] = []

    var hasStructuredCriteria: Bool {
        date != nil ||
        amount != nil ||
        status != nil ||
        !categoryTerms.isEmpty
    }

    func matches(_ transaction: TransactionRecord) -> Bool {
        if let status, transaction.status != status {
            return false
        }

        if let amount {
            switch amount {
            case .greaterThan(let value):
                guard transaction.amount > value else { return false }
            case .greaterThanOrEqual(let value):
                guard transaction.amount >= value else { return false }
            case .lessThan(let value):
                guard transaction.amount < value else { return false }
            case .lessThanOrEqual(let value):
                guard transaction.amount <= value else { return false }
            case .equal(let value):
                guard transaction.amount == value else { return false }
            case .between(let low, let high):
                guard transaction.amount >= low, transaction.amount <= high else {
                    return false
                }
            }
        }

        if let date {
            guard let transactionDate = transaction.date else {
                return false
            }

            let components = Calendar.current.dateComponents(
                [.year, .month, .day],
                from: transactionDate
            )

            guard components.month == date.month else {
                return false
            }

            if let day = date.day, components.day != day {
                return false
            }

            if let year = date.year, components.year != year {
                return false
            }
        }

        let searchable = transaction.searchableText

        for term in textTerms where !searchable.contains(term.lowercased()) {
            return false
        }

        if !categoryTerms.isEmpty {
            let category = transaction.category?.lowercased() ?? ""
            for term in categoryTerms where !category.contains(term.lowercased()) {
                return false
            }
        }

        return true
    }
}

// Mode 4 Aggregation

enum AggregationOperation: String, Equatable {
    case maximum
    case minimum
    case sum
    case count
    case average
}

enum AggregationScope: String, Equatable {
    case spending
    case inflows
    case allActivity
}

struct AggregationQuery: Equatable {
    let operation: AggregationOperation
    let scope: AggregationScope
    let filter: TransactionFilter
}

struct AggregationResult {
    let operation: AggregationOperation
    let scope: AggregationScope
    let matchingRecords: [TransactionRecord]
    let selectedRecords: [TransactionRecord]
    let decimalValue: Decimal?
    let countValue: Int
}

struct AggregationEngine {
    static func execute(
        query: AggregationQuery,
        records: [TransactionRecord]
    ) -> AggregationResult {
        let matching = records.filter { record in
            scopeMatches(query.scope, record: record) && query.filter.matches(record)
        }

        switch query.operation {
        case .count:
            return AggregationResult(
                operation: .count,
                scope: query.scope,
                matchingRecords: matching,
                selectedRecords: [],
                decimalValue: nil,
                countValue: matching.count
            )

        case .sum:
            let values = matching.map(\.amount)
            let total = values.reduce(Decimal.zero, +)
            return AggregationResult(
                operation: .sum,
                scope: query.scope,
                matchingRecords: matching,
                selectedRecords: [],
                decimalValue: total,
                countValue: values.count
            )

        case .average:
            let values = matching.map(\.amount)
            guard !values.isEmpty else {
                return AggregationResult(
                    operation: .average,
                    scope: query.scope,
                    matchingRecords: matching,
                    selectedRecords: [],
                    decimalValue: nil,
                    countValue: 0
                )
            }
            let total = values.reduce(Decimal.zero, +)
            return AggregationResult(
                operation: .average,
                scope: query.scope,
                matchingRecords: matching,
                selectedRecords: [],
                decimalValue: total / Decimal(values.count),
                countValue: values.count
            )

        case .maximum:
            guard let maximum = matching.map(\.amount).max() else {
                return AggregationResult(
                    operation: .maximum,
                    scope: query.scope,
                    matchingRecords: matching,
                    selectedRecords: [],
                    decimalValue: nil,
                    countValue: 0
                )
            }
            let selected = matching.filter { $0.amount == maximum }
            return AggregationResult(
                operation: .maximum,
                scope: query.scope,
                matchingRecords: matching,
                selectedRecords: selected,
                decimalValue: maximum,
                countValue: selected.count
            )

        case .minimum:
            guard let minimum = matching.map(\.amount).min() else {
                return AggregationResult(
                    operation: .minimum,
                    scope: query.scope,
                    matchingRecords: matching,
                    selectedRecords: [],
                    decimalValue: nil,
                    countValue: 0
                )
            }
            let selected = matching.filter { $0.amount == minimum }
            return AggregationResult(
                operation: .minimum,
                scope: query.scope,
                matchingRecords: matching,
                selectedRecords: selected,
                decimalValue: minimum,
                countValue: selected.count
            )
        }
    }

    private static func scopeMatches(
        _ scope: AggregationScope,
        record: TransactionRecord
    ) -> Bool {
        switch scope {
        case .spending:
            return record.flow == .outflow
        case .inflows:
            return record.flow == .inflow
        case .allActivity:
            return true
        }
    }
}

// Query Analysis / Router

struct RAGQueryAnalyzer {
    enum RetrievalMode: Equatable {
        case aggregation
        case structured
        case exhaustive
        case semantic
    }

    private static let stopWords: Set<String> = [
        "a", "an", "the", "my", "me", "i", "what", "was", "were",
        "is", "are", "do", "did", "does", "how", "much", "many",
        "when", "where", "which", "all", "every", "list", "show",
        "give", "tell", "transaction", "transactions", "purchase",
        "purchases", "payment", "payments", "spent", "spend", "still",
        "from", "on", "for", "in", "of", "to", "with", "and", "or",
        "than", "over", "under", "above", "below", "more", "less",
        "most", "largest", "biggest", "highest", "maximum", "max",
        "smallest", "lowest", "minimum", "min", "recent", "category",
        "categorized", "status", "amount", "date", "pending", "posted",
        "processing", "exactly", "around", "total", "sum", "average",
        "avg", "mean", "count", "number", "overall", "expensive", "least"
    ]

    static func retrievalMode(for question: String) -> RetrievalMode {
        if aggregationOperation(from: question) != nil {
            return .aggregation
        }

        let filter = structuredFilter(from: question)
        if filter.hasStructuredCriteria {
            return .structured
        }

        if isExhaustiveQuestion(question) {
            return .exhaustive
        }

        return .semantic
    }

    static func isExhaustiveQuestion(_ question: String) -> Bool {
        let q = question.lowercased()
        return q.contains("list") ||
            q.contains("all") ||
            q.contains("every") ||
            q.contains("show me") ||
            q.contains("which transactions")
    }

    static func meaningfulTerms(from question: String) -> [String] {
        let normalized = question
            .lowercased()
            .replacingOccurrences(
                of: #"[^a-z0-9\s]"#,
                with: " ",
                options: .regularExpression
            )

        var result: [String] = []
        for token in normalized.split(separator: " ").map(String.init) {
            guard token.count >= 2,
                  !stopWords.contains(token),
                  Int(token) == nil,
                  !isMonthName(token) else {
                continue
            }
            if !result.contains(token) {
                result.append(token)
            }
        }
        return result
    }

    static func structuredFilter(from question: String) -> TransactionFilter {
        var filter = TransactionFilter()
        let lower = question.lowercased()

        if lower.contains("pending") || lower.contains("processing") {
            filter.status = .pending
        } else if lower.contains("posted") {
            filter.status = .posted
        }

        filter.amount = parseAmountCriterion(from: question)
        filter.date = parseDateCriterion(from: question)
        filter.categoryTerms = parseCategoryTerms(from: question)
        filter.textTerms = meaningfulTerms(from: question)

        return filter
    }

    static func structuredMatches(
        question: String,
        transactions: [TransactionRecord]
    ) -> [TransactionRecord] {
        let filter = structuredFilter(from: question)
        return transactions.filter { filter.matches($0) }
    }

    static func aggregationQuery(
        from question: String
    ) -> AggregationQuery? {
        guard let operation = aggregationOperation(from: question) else {
            return nil
        }

        return AggregationQuery(
            operation: operation,
            scope: aggregationScope(from: question),
            filter: structuredFilter(from: question)
        )
    }

    static func aggregationOperation(
        from question: String
    ) -> AggregationOperation? {
        let q = question.lowercased()

        if q.contains("how many") || q.contains("number of") || q.contains("count") {
            return .count
        }

        if q.contains("average") || q.contains("mean") {
            return .average
        }

        if q.contains("largest") || q.contains("biggest") ||
            q.contains("highest") || q.contains("maximum") ||
            q.contains("most expensive") {
            return .maximum
        }

        if q.contains("smallest") || q.contains("lowest") ||
            q.contains("minimum") || q.contains("least expensive") {
            return .minimum
        }

        if q.contains("total") || q.contains("sum") ||
            (q.contains("how much") && (q.contains("spent") || q.contains("spend"))) {
            return .sum
        }

        return nil
    }

    static func aggregationScope(from question: String) -> AggregationScope {
        let q = question.lowercased()

        if q.contains("received") || q.contains("deposit") ||
            q.contains("deposits") || q.contains("credit") ||
            q.contains("credits") || q.contains("income") {
            return .inflows
        }

        if q.contains("spent") || q.contains("spend") ||
            q.contains("purchase") || q.contains("purchases") ||
            q.contains("charge") || q.contains("charges") ||
            q.contains("withdrawal") || q.contains("withdrawals") {
            return .spending
        }

        return .allActivity
    }

    // Amount parsing

    private static func parseAmountCriterion(
        from question: String
    ) -> AmountComparison? {
        let q = question.lowercased()

        let betweenPattern = #"between\s+\$?\s*([\d,]+(?:\.\d{1,2})?)\s+(?:and|to)\s+\$?\s*([\d,]+(?:\.\d{1,2})?)"#
        if let match = firstMatch(pattern: betweenPattern, in: q),
           let low = decimal(match.group(1)),
           let high = decimal(match.group(2)) {
            return .between(low, high)
        }

        let patterns: [(String, (Decimal) -> AmountComparison)] = [
            (#"(?:(?:greater|more)\s+than|over|above)\s+\$?\s*([\d,]+(?:\.\d{1,2})?)"#, { .greaterThan($0) }),
            (#"at\s+least\s+\$?\s*([\d,]+(?:\.\d{1,2})?)"#, { .greaterThanOrEqual($0) }),
            (#"(?:less\s+than|under|below)\s+\$?\s*([\d,]+(?:\.\d{1,2})?)"#, { .lessThan($0) }),
            (#"at\s+most\s+\$?\s*([\d,]+(?:\.\d{1,2})?)"#, { .lessThanOrEqual($0) }),
            (#"(?:exactly|equal\s+to)\s+\$?\s*([\d,]+(?:\.\d{1,2})?)"#, { .equal($0) })
        ]

        for (pattern, builder) in patterns {
            if let match = firstMatch(pattern: pattern, in: q),
               let value = decimal(match.group(1)) {
                return builder(value)
            }
        }

        if let match = firstMatch(
            pattern: #"\$\s*([\d,]+(?:\.\d{1,2})?)"#,
            in: q
        ), let value = decimal(match.group(1)) {
            return .equal(value)
        }

        return nil
    }

    // Date parsing

    private static func parseDateCriterion(
        from question: String
    ) -> TransactionDateCriterion? {
        let q = question.lowercased()

        if let match = firstMatch(
            pattern: #"\b(\d{1,2})/(\d{1,2})/(\d{2,4})\b"#,
            in: q
        ),
        let month = Int(match.group(1)),
        let day = Int(match.group(2)),
        let rawYear = Int(match.group(3)),
        (1...12).contains(month),
        (1...31).contains(day) {
            let year = rawYear < 100 ? 2000 + rawYear : rawYear
            return TransactionDateCriterion(month: month, day: day, year: year)
        }

        let months: [(names: [String], month: Int)] = [
            (["january", "jan"], 1),
            (["february", "feb"], 2),
            (["march", "mar"], 3),
            (["april", "apr"], 4),
            (["may"], 5),
            (["june", "jun"], 6),
            (["july", "jul"], 7),
            (["august", "aug"], 8),
            (["september", "sept", "sep"], 9),
            (["october", "oct"], 10),
            (["november", "nov"], 11),
            (["december", "dec"], 12)
        ]

        for item in months {
            for name in item.names {
                let escaped = NSRegularExpression.escapedPattern(for: name)
                let pattern = "\\b\(escaped)\\s+(\\d{1,2})(?:st|nd|rd|th)?(?:,\\s*(\\d{4}))?\\b"

                if let match = firstMatch(pattern: pattern, in: q),
                   let day = Int(match.group(1)),
                   (1...31).contains(day) {
                    let year = match.group(2).isEmpty ? nil : Int(match.group(2))
                    return TransactionDateCriterion(
                        month: item.month,
                        day: day,
                        year: year
                    )
                }
            }
        }

        for item in months {
            for name in item.names {
                let escaped = NSRegularExpression.escapedPattern(for: name)
                let pattern = "\\b\(escaped)\\b(?:\\s+(\\d{4}))?"
                if let match = firstMatch(pattern: pattern, in: q) {
                    let year = match.group(1).isEmpty ? nil : Int(match.group(1))
                    return TransactionDateCriterion(
                        month: item.month,
                        day: nil,
                        year: year
                    )
                }
            }
        }

        return nil
    }

    // Category parsing

    private static func parseCategoryTerms(
        from question: String
    ) -> [String] {
        let q = question.lowercased()
        let patterns = [
            #"in\s+the\s+([a-z][a-z\s&'-]+?)\s+category"#,
            #"in\s+([a-z][a-z\s&'-]+?)\s+category"#,
            #"categorized\s+as\s+([a-z][a-z\s&'-]+)"#
        ]

        for pattern in patterns {
            if let match = firstMatch(pattern: pattern, in: q) {
                return meaningfulTerms(from: match.group(1))
            }
        }

        return []
    }

    // MARK: Helpers

    private static func decimal(_ string: String) -> Decimal? {
        Decimal(string: string.replacingOccurrences(of: ",", with: ""))
    }

    private static func isMonthName(_ term: String) -> Bool {
        [
            "january", "february", "march", "april", "may", "june",
            "july", "august", "september", "october", "november", "december",
            "jan", "feb", "mar", "apr", "jun", "jul", "aug", "sep", "sept",
            "oct", "nov", "dec"
        ].contains(term)
    }

    private struct RegexMatch {
        let groups: [String]

        func group(_ captureIndex: Int) -> String {
            guard captureIndex >= 1, captureIndex <= groups.count else {
                return ""
            }
            return groups[captureIndex - 1]
        }
    }

    private static func firstMatch(
        pattern: String,
        in text: String
    ) -> RegexMatch? {
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive]
        ) else {
            return nil
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range) else {
            return nil
        }

        var groups: [String] = []
        for index in 1..<match.numberOfRanges {
            let groupRange = match.range(at: index)
            if groupRange.location == NSNotFound {
                groups.append("")
            } else {
                groups.append((text as NSString).substring(with: groupRange))
            }
        }

        return RegexMatch(groups: groups)
    }
}

// RAG Document

struct RAGDocument {
    let chunks: [TextChunk]
    let embeddings: [UUID: EmbeddingVector]

    func retrieveRelevantChunks(
        for queryEmbedding: EmbeddingVector,
        topK: Int = 8
    ) -> [TextChunk] {
        chunks
            .compactMap { chunk -> (TextChunk, Float)? in
                guard let embedding = embeddings[chunk.id] else {
                    return nil
                }
                return (
                    chunk,
                    Self.cosineSimilarity(queryEmbedding.vector, embedding.vector)
                )
            }
            .sorted { $0.1 > $1.1 }
            .prefix(topK)
            .map(\.0)
    }

    private static func cosineSimilarity(
        _ a: [Float],
        _ b: [Float]
    ) -> Float {
        guard a.count == b.count, !a.isEmpty else {
            return -1
        }

        var dot: Float = 0
        var magA: Float = 0
        var magB: Float = 0

        for index in 0..<a.count {
            dot += a[index] * b[index]
            magA += a[index] * a[index]
            magB += b[index] * b[index]
        }

        let denominator = magA.squareRoot() * magB.squareRoot()
        return denominator > 0 ? dot / denominator : -1
    }
}

struct CitationAnswer {
    let answer: String
    let citedChunkIDs: [UUID]
}
