import CoreGraphics

struct ScreenshotSample: Sendable {
    let id: String
    let image: CGImage
}

struct ThumbnailMatch: Sendable {
    let id: String
    /// Bounds in the captured screen, measured from its top-left corner.
    let bounds: CGRect
    let distance: Double
}

enum ThumbnailMatcher {
    private static let cells = 8
    private static let verificationCells = 12
    private static let maximumDistance = 0.050
    private static let ambiguityMargin = 0.018
    private static let maximumColorDistance = 0.135

    static func find(screen: CGImage, samples: [ScreenshotSample]) -> [ThumbnailMatch] {
        guard !samples.isEmpty, screen.height > screen.width,
              let frame = LuminanceImage(screen, width: 144),
              let colorFrame = ColorImage(screen, width: 288) else { return [] }
        let candidates: [(id: String, luminance: LuminanceImage, color: ColorImage)] = samples.compactMap { sample in
            guard let luminance = LuminanceImage(sample.image, width: 96),
                  let color = ColorImage(sample.image, width: 192) else { return nil }
            return (sample.id, luminance, color)
        }
        var matches: [String: ThumbnailMatch] = [:]
        var observed = [Double](repeating: 0, count: cells * cells)

        // Different apps place sent images differently: right-aligned, centered,
        // or in a full-width publishing card. Search the whole content width.
        for ratio in [0.45, 0.50, 0.56, 0.64, 0.72, 0.80, 0.90, 1.0, 1.15, 1.33, 1.50] {
            if Task.isCancelled { return [] }
            let templates = candidates.compactMap { id, image, _ -> (String, [Double])? in
                let square = image.centerCrop(aspect: ratio)
                var features = [Double](repeating: 0, count: cells * cells)
                return image.describe(square, into: &features) ? (id, features) : nil
            }
            for width in stride(from: 21, through: 87, by: 3) {
                let height = Int((Double(width) / ratio).rounded())
                let lastY = Int(Double(frame.height) * 0.94) - height
                let firstY = Int(Double(frame.height) * 0.15)
                guard lastY >= firstY else { continue }

                let lastX = frame.width - width - 4
                guard lastX >= 4 else { continue }
                for left in stride(from: 4, through: lastX, by: 3) {
                    for top in stride(from: firstY, through: lastY, by: 3) {
                        let region = Region(x: left, y: top, width: width, height: height)
                        guard frame.describe(region, into: &observed) else { continue }
                        let match = bestTemplate(for: observed, in: templates)
                        guard let match,
                              match.distance < (matches[match.id]?.distance ?? .infinity) else { continue }
                        matches[match.id] = ThumbnailMatch(
                            id: match.id,
                            bounds: CGRect(
                                x: Double(region.x) / Double(frame.width),
                                y: Double(region.y) / Double(frame.height),
                                width: Double(width) / Double(frame.width),
                                height: Double(height) / Double(frame.height)
                            ),
                            distance: match.distance
                        )
                    }
                }
            }
        }

        // Different windows on one visible thumbnail must not add two candidates.
        var unique: [ThumbnailMatch] = []
        for match in matches.values.sorted(by: { $0.distance < $1.distance }) {
            guard let sample = candidates.first(where: { $0.0 == match.id }),
                  let colorDistance = colorFrame.distance(
                    in: match.bounds,
                    to: sample.2,
                    cells: verificationCells
                  ),
                  colorDistance <= maximumColorDistance else { continue }
            let overlapping = matches.values.contains { other in
                other.id != match.id && intersectionFraction(match.bounds, other.bounds) > 0.60
                    && abs(other.distance - match.distance) < ambiguityMargin
            }
            if !overlapping && !unique.contains(where: { intersectionFraction($0.bounds, match.bounds) > 0.60 }) {
                unique.append(match)
            }
        }
        return unique.sorted { $0.bounds.midY > $1.bounds.midY }
    }

    private static func bestTemplate(
        for observed: [Double], in templates: [(String, [Double])]
    ) -> (id: String, distance: Double)? {
        var first: (id: String, distance: Double)?
        var second = maximumDistance + ambiguityMargin
        for (id, features) in templates {
            var error = 0.0
            for index in observed.indices {
                error += abs(observed[index] - features[index])
                if error >= second * Double(observed.count) { break }
            }
            let distance = error / Double(observed.count)
            if distance < (first?.distance ?? second) {
                second = first?.distance ?? second
                first = (id, distance)
            } else {
                second = min(second, distance)
            }
        }
        guard let first, first.distance <= maximumDistance,
              second - first.distance >= ambiguityMargin else { return nil }
        return first
    }

    private static func intersectionFraction(_ first: CGRect, _ second: CGRect) -> Double {
        let overlap = first.intersection(second)
        guard !overlap.isNull else { return 0 }
        return overlap.width * overlap.height / min(first.width * first.height, second.width * second.height)
    }

    private struct Region {
        let x: Int
        let y: Int
        let width: Int
        let height: Int
    }

    private struct LuminanceImage {
        let width: Int
        let height: Int
        let sums: [Int]

        init?(_ image: CGImage, width: Int) {
            let height = max(1, Int((Double(image.height) * Double(width) / Double(image.width)).rounded()))
            guard height <= 1_024 else { return nil }
            var bytes = [UInt8](repeating: 0, count: width * height)
            let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
                guard let context = CGContext(
                    data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                    bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                    bitmapInfo: CGImageAlphaInfo.none.rawValue
                ) else { return false }
                let rectangle = CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))
                context.setFillColor(gray: 1, alpha: 1)
                context.fill(rectangle)
                context.interpolationQuality = .high
                context.draw(image, in: rectangle)
                return true
            }
            guard drawn else { return nil }
            let stride = width + 1
            var sums = [Int](repeating: 0, count: stride * (height + 1))
            for y in 0..<height {
                var row = 0
                for x in 0..<width {
                    row += Int(bytes[y * width + x])
                    sums[(y + 1) * stride + x + 1] = sums[y * stride + x + 1] + row
                }
            }
            self.width = width
            self.height = height
            self.sums = sums
        }

        func centerCrop(aspect: Double) -> Region {
            let cropWidth = min(width, Int((Double(height) * aspect).rounded()))
            let cropHeight = min(height, Int((Double(width) / aspect).rounded()))
            return Region(x: (width - cropWidth) / 2, y: (height - cropHeight) / 2,
                          width: cropWidth, height: cropHeight)
        }

        func describe(_ region: Region, into values: inout [Double]) -> Bool {
            let insetX = region.width / 16
            let insetY = region.height / 16
            let usableWidth = region.width - 2 * insetX
            let usableHeight = region.height - 2 * insetY
            guard usableWidth >= cells, usableHeight >= cells else { return false }

            var low = 1.0
            var high = 0.0
            let stride = width + 1
            for row in 0..<cells {
                let y0 = region.y + insetY + row * usableHeight / cells
                let y1 = region.y + insetY + (row + 1) * usableHeight / cells
                for col in 0..<cells {
                    let x0 = region.x + insetX + col * usableWidth / cells
                    let x1 = region.x + insetX + (col + 1) * usableWidth / cells
                    let sum = sums[y1 * stride + x1] - sums[y0 * stride + x1]
                        - sums[y1 * stride + x0] + sums[y0 * stride + x0]
                    let mean = Double(sum) / Double(255 * (y1 - y0) * (x1 - x0))
                    values[row * cells + col] = mean
                    low = min(low, mean)
                    high = max(high, mean)
                }
            }
            return high - low >= 0.18
        }
    }

    private struct ColorImage {
        let width: Int
        let height: Int
        let bytes: [UInt8]

        init?(_ image: CGImage, width: Int) {
            let height = max(1, Int((Double(image.height) * Double(width) / Double(image.width)).rounded()))
            guard height <= 2_048 else { return nil }
            var bytes = [UInt8](repeating: 0, count: width * height * 4)
            let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
                guard let context = CGContext(
                    data: buffer.baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: width * 4,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                ) else { return false }
                let rectangle = CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))
                context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
                context.fill(rectangle)
                context.interpolationQuality = .high
                context.draw(image, in: rectangle)
                return true
            }
            guard drawn else { return nil }
            self.width = width
            self.height = height
            self.bytes = bytes
        }

        func distance(in normalizedRegion: CGRect, to sample: ColorImage,
                      cells: Int) -> Double? {
            let observed = Region(
                x: Int((normalizedRegion.minX * Double(width)).rounded()),
                y: Int((normalizedRegion.minY * Double(height)).rounded()),
                width: Int((normalizedRegion.width * Double(width)).rounded()),
                height: Int((normalizedRegion.height * Double(height)).rounded())
            )
            let aspect = Double(observed.width) / Double(observed.height)
            let cropWidth = min(sample.width, Int((Double(sample.height) * aspect).rounded()))
            let cropHeight = min(sample.height, Int((Double(sample.width) / aspect).rounded()))
            let source = Region(
                x: (sample.width - cropWidth) / 2,
                y: (sample.height - cropHeight) / 2,
                width: cropWidth,
                height: cropHeight
            )
            guard let first = descriptor(observed, cells: cells),
                  let second = sample.descriptor(source, cells: cells),
                  first.count == second.count else { return nil }
            var error = 0.0
            for index in first.indices { error += abs(first[index] - second[index]) }
            return error / Double(first.count)
        }

        private func descriptor(_ region: Region, cells: Int) -> [Double]? {
            let insetX = max(1, region.width / 16)
            let insetY = max(1, region.height / 16)
            let x0 = max(0, region.x + insetX)
            let y0 = max(0, region.y + insetY)
            let x1 = min(width, region.x + region.width - insetX)
            let y1 = min(height, region.y + region.height - insetY)
            guard x1 - x0 >= cells, y1 - y0 >= cells else { return nil }

            var values = [Double](repeating: 0, count: cells * cells * 3)
            for row in 0..<cells {
                let top = y0 + row * (y1 - y0) / cells
                let bottom = y0 + (row + 1) * (y1 - y0) / cells
                for column in 0..<cells {
                    let left = x0 + column * (x1 - x0) / cells
                    let right = x0 + (column + 1) * (x1 - x0) / cells
                    var red = 0
                    var green = 0
                    var blue = 0
                    for y in top..<bottom {
                        for x in left..<right {
                            let offset = (y * width + x) * 4
                            red += Int(bytes[offset])
                            green += Int(bytes[offset + 1])
                            blue += Int(bytes[offset + 2])
                        }
                    }
                    let count = max(1, (right - left) * (bottom - top))
                    let base = (row * cells + column) * 3
                    values[base] = Double(red) / Double(255 * count)
                    values[base + 1] = Double(green) / Double(255 * count)
                    values[base + 2] = Double(blue) / Double(255 * count)
                }
            }
            return values
        }
    }
}
