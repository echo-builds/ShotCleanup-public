import Foundation

struct ScreenshotBatchItem: Sendable, Equatable {
    let id: String
    let creationDate: Date
}

struct ScreenshotBatchInferenceResult: Sendable, Equatable {
    enum Decision: Sendable, Equatable {
        case matchedOnly
        case expanded
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

    /// Screen matches must be ordered from bottom to top. Only the first reliable
    /// match is used as the anchor, so older visible messages cannot add another batch.
    static func infer(
        items: [ScreenshotBatchItem],
        orderedMatchedIDs: [String],
        maximumAdjacentGap: TimeInterval = ScreenshotBatchInference.maximumAdjacentGap,
        maximumBatchSize: Int = ScreenshotBatchInference.maximumBatchSize
    ) -> ScreenshotBatchInferenceResult {
        let availableIDs = Set(items.map(\.id))
        guard let primaryMatchedID = orderedMatchedIDs.first(where: availableIDs.contains) else {
            return ScreenshotBatchInferenceResult(ids: [], decision: .matchedOnly)
        }

        let sorted = items.sorted {
            if $0.creationDate == $1.creationDate { return $0.id < $1.id }
            return $0.creationDate < $1.creationDate
        }
        let matchedOnly = [primaryMatchedID]

        var batches: [[ScreenshotBatchItem]] = []
        for item in sorted {
            if let previous = batches.last?.last,
               item.creationDate.timeIntervalSince(previous.creationDate) <= maximumAdjacentGap {
                batches[batches.count - 1].append(item)
            } else {
                batches.append([item])
            }
        }

        guard let batch = batches.first(where: { batch in
            batch.contains { $0.id == primaryMatchedID }
        }) else {
            return ScreenshotBatchInferenceResult(ids: matchedOnly, decision: .matchedOnly)
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
