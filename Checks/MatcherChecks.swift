import CoreGraphics
import Foundation
import ImageIO

@main
struct MatcherChecks {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if arguments.count >= 2 {
            let screen = try readImage(arguments[0])
            let samples = try arguments.dropFirst().map { ScreenshotSample(id: $0, image: try readImage($0)) }
            for hit in ThumbnailMatcher.find(screen: screen, samples: samples) {
                print("\(hit.id) \(hit.bounds) distance=\(hit.distance)")
            }
            return
        }
        precondition(arguments.isEmpty, "Pass a screen capture and at least one original.")

        let first = pattern(seed: 851)
        let second = pattern(seed: 3231)
        let unrelated = pattern(seed: 5723)
        let chat = draw(width: 144, height: 312) { context in
            context.setFillColor(gray: 0.9, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: 144, height: 312))
            context.draw(first, in: CGRect(x: 87, y: 170, width: 51, height: 81))
            context.draw(second, in: CGRect(x: 96, y: 97, width: 42, height: 66))
        }
        let firstSample = ScreenshotSample(id: "first", image: first)
        let secondSample = ScreenshotSample(id: "second", image: second)
        let distractor = ScreenshotSample(id: "unrelated", image: unrelated)
        let hits = ThumbnailMatcher.find(screen: chat, samples: [firstSample, secondSample, distractor])
        precondition(Set(hits.map(\.id)) == ["first", "second"], "Unexpected matches: \(hits)")
        precondition(hits.first?.id == "second", "Expected bottom-most image first.")
        let ambiguous = ThumbnailMatcher.find(screen: chat, samples: [
            firstSample, secondSample, ScreenshotSample(id: "copy", image: first)
        ])
        precondition(ambiguous.map(\.id) == ["second"], "Indistinguishable originals must both be skipped.")

        let blank = draw(width: 144, height: 312) { _ in }
        precondition(ThumbnailMatcher.find(screen: blank, samples: [firstSample]).isEmpty)
        checkBatchInference()
        print("Passed image matching and screenshot batch inference checks.")
    }

    static func checkBatchInference() {
        let base = Date(timeIntervalSince1970: 1_000)
        let continuous = (0..<10).map {
            ScreenshotBatchItem(id: "shot-\($0)", creationDate: base.addingTimeInterval(Double($0 * 5)))
        }
        let expanded = ScreenshotBatchInference.infer(
            items: continuous,
            orderedMatchedIDs: ["shot-9", "shot-8"]
        )
        precondition(expanded.ids == continuous.map(\.id))
        precondition(expanded.decision == .expanded)

        let separated = [
            ScreenshotBatchItem(id: "early-1", creationDate: base),
            ScreenshotBatchItem(id: "early-2", creationDate: base.addingTimeInterval(5)),
            ScreenshotBatchItem(id: "late-1", creationDate: base.addingTimeInterval(90)),
            ScreenshotBatchItem(id: "late-2", creationDate: base.addingTimeInterval(95))
        ]
        // The matcher orders hits from the bottom of the screen upward. When old and
        // new messages are both visible, only the bottom-most hit anchors a batch.
        let bottomMostWins = ScreenshotBatchInference.infer(
            items: separated,
            orderedMatchedIDs: ["late-2", "early-2"]
        )
        precondition(bottomMostWins.ids == ["late-1", "late-2"])
        precondition(bottomMostWins.decision == .expanded)

        let reversedOrder = ScreenshotBatchInference.infer(
            items: separated,
            orderedMatchedIDs: ["early-2", "late-2"]
        )
        precondition(reversedOrder.ids == ["early-1", "early-2"])
        precondition(reversedOrder.decision == .expanded)

        let tooLarge = (0..<21).map {
            ScreenshotBatchItem(id: "many-\($0)", creationDate: base.addingTimeInterval(Double($0)))
        }
        let capped = ScreenshotBatchInference.infer(items: tooLarge, orderedMatchedIDs: ["many-20"])
        precondition(capped.ids == ["many-20"])
        precondition(capped.decision == .batchTooLarge)

        let missing = ScreenshotBatchInference.infer(items: continuous, orderedMatchedIDs: ["missing"])
        precondition(missing.ids.isEmpty)
        precondition(missing.decision == .matchedOnly)
    }

    static func pattern(seed: UInt64) -> CGImage {
        draw(width: 96, height: 150) { context in
            var state = seed
            for row in 0..<5 {
                for column in 0..<4 {
                    state = state &* 6_364_136_223_846_793_005 &+ 1
                    let gray = CGFloat((state >> 32) & 255) / 255
                    context.setFillColor(gray: gray, alpha: 1)
                    context.fill(CGRect(x: column * 24, y: row * 30, width: 24, height: 30))
                }
            }
        }
    }

    static func draw(width: Int, height: Int, content: (CGContext) -> Void) -> CGImage {
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                                bitmapInfo: CGImageAlphaInfo.none.rawValue)!
        content(context)
        return context.makeImage()!
    }

    static func readImage(_ path: String) throws -> CGImage {
        let url = URL(fileURLWithPath: path)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 1_600
              ] as CFDictionary) else { throw CocoaError(.fileReadCorruptFile) }
        return image
    }
}

