import Foundation

struct ScreenshotBatchItem: Sendable, Equatable {
    let id: String
    let creationDate: Date
}

struct ScreenshotBatchInferenceResult: Sendable, Equatable {
    enum Decision: Sendable, Equatable {
        case matchedOnly
        case expanded
        case multipleBatches
        case batchTooLarge
    }

    let ids: [String]
    let decision: Decision
}

enum ScreenshotBatchInference {
    /// Screenshots separated by a longer pause are treated as different capture sessions.
    static let maximumAdjacentGap: TimeInterval = 45
    /// A safety cap: never expand one screen match into an unexpectedly large deletion.
    static let maximumBatchSize = 20

    static func infer(
        items: [ScreenshotBatchItem],
        matchedIDs: Set<String>,
        maximumAdjacentGap: TimeInterval = ScreenshotBatchInference.maximumAdjacentGap,
        maximumBatchSize: Int = ScreenshotBatchInference.maximumBatchSize
    ) -> ScreenshotBatchInferenceResult {
        let availableMatches = matchedIDs.intersection(items.map(\.id))
        guard !availableMatches.isEmpty else {
            return ScreenshotBatchInferenceResult(ids: [], decision: .matchedOnly)
        }

        let sorted = items.sorted {
            if $0.creationDate == $1.creationDate { return $0.id < $1.id }
            return $0.creationDate < $1.creationDate
        }
        let matchedOnly = sorted.filter { availableMatches.contains($0.id) }.map(\.id)

        var batches: [[ScreenshotBatchItem]] = []
        for item in sorted {
            if let previous = batches.last?.last,
               item.creationDate.timeIntervalSince(previous.creationDate) <= maximumAdjacentGap {
                batches[batches.count - 1].append(item)
            } else {
                batches.append([item])
            }
        }

        let anchoredBatches = batches.filter { batch in
            batch.contains { availableMatches.contains($0.id) }
        }
        guard anchoredBatches.count == 1, let batch = anchoredBatches.first else {
            return ScreenshotBatchInferenceResult(ids: matchedOnly, decision: .multipleBatches)
        }
        guard batch.count <= maximumBatchSize else {
            return ScreenshotBatchInferenceResult(ids: matchedOnly, decision: .batchTooLarge)
        }

        let ids = batch.map(\.id)
        return ScreenshotBatchInferenceResult(
            ids: ids,
            decision: ids.count > matchedOnly.count ? .expanded : .matchedOnly
        )
    }
}
