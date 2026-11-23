import AppIntents
import ImageIO
import Photos
import SwiftUI
import UniformTypeIdentifiers
import UIKit

@main
struct ShotCleanupApp: App {
    var body: some Scene {
        WindowGroup { CleanupView(model: ReviewModel.shared) }
    }
}

struct ReviewChatCapture: AppIntent {
    static let title: LocalizedStringResource = "识别刚发送的截图"
    static let description = IntentDescription("在本机比对聊天画面与最近的相册截图，有匹配时直接请求系统确认删除。")
    static let openAppWhenRun = false

    @Parameter(
        title: "聊天画面",
        supportedContentTypes: [.image],
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var capture: IntentFile

    static var parameterSummary: some ParameterSummary {
        Summary("识别 \(\.$capture) 中的相册截图")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        ReviewModel.shared.clearReview()
        await ReviewModel.shared.process(data: capture.data, requestDeletion: true)
        return .result()
    }
}

@MainActor
final class ReviewModel: ObservableObject {
    struct Candidate: Identifiable {
        let id: String
        let image: UIImage
        let bounds: CGRect?
        let matchedOnScreen: Bool
    }

    static let shared = ReviewModel()

    @Published private(set) var candidates: [Candidate] = []
    @Published private(set) var capture: CGImage?
    @Published private(set) var busy = false
    @Published private(set) var deleting = false
    @Published private(set) var status: String?
    @Published var excluded: Set<String> = []
    private var analysis: Task<Void, Never>?

    var selected: [Candidate] { candidates.filter { !excluded.contains($0.id) } }

    func start(data: Data, requestDeletion: Bool = false) {
        guard !deleting else { return }
        clearReview()
        analysis = Task { await process(data: data, requestDeletion: requestDeletion) }
    }

    func process(data: Data, requestDeletion: Bool = false) async {
        guard !deleting else { return }
        guard data.count < 25_000_000,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let screen = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 1_600
              ] as CFDictionary),
              screen.width < screen.height else {
            busy = false
            status = "没有收到竖屏聊天画面。请在发图后回到聊天里再触发。"
            return
        }

        busy = true
        var access = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if access == .notDetermined {
            access = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        }
        guard !Task.isCancelled else { return }
        guard access == .authorized || access == .limited else {
            busy = false
            status = "请在 iPhone 设置中允许「截图清理」读取相册截图，再试一次。"
            return
        }
        let result = Self.recentScreenshots(referenceDate: Date())
        var images: [String: UIImage] = [:]
        var samples: [ScreenshotSample] = []
        var recentItems: [ScreenshotBatchItem] = []
        for index in 0..<result.count {
            guard !Task.isCancelled else { return }
            let asset = result.object(at: index)
            guard asset.mediaSubtypes.contains(.photoScreenshot) else { continue }
            if let creationDate = asset.creationDate,
               let image = await Self.loadImage(asset), let pixels = image.cgImage {
                images[asset.localIdentifier] = image
                samples.append(ScreenshotSample(id: asset.localIdentifier, image: pixels))
                recentItems.append(ScreenshotBatchItem(
                    id: asset.localIdentifier,
                    creationDate: creationDate
                ))
            }
        }
        guard !Task.isCancelled else { return }

        let worker = Task.detached(priority: .userInitiated) {
            ThumbnailMatcher.find(screen: screen, samples: samples)
        }
        let hits = await withTaskCancellationHandler {
            await worker.value
        } onCancel: {
            worker.cancel()
        }
        guard !Task.isCancelled else { return }

        let hitsByID = Dictionary(uniqueKeysWithValues: hits.map { ($0.id, $0) })
        // ThumbnailMatcher returns reliable matches from the bottom of the screen upward.
        // Anchor on the bottom-most match so older visible messages cannot add another batch.
        let batch = ScreenshotBatchInference.infer(
            items: recentItems,
            orderedMatchedIDs: hits.map(\.id)
        )
        candidates = batch.ids.compactMap { id in
            images[id].map {
                Candidate(
                    id: id,
                    image: $0,
                    bounds: hitsByID[id]?.bounds,
                    matchedOnScreen: hitsByID[id] != nil
                )
            }
        }
        capture = candidates.isEmpty ? nil : screen
        busy = false
        if candidates.isEmpty {
            status = access == .limited
                ? "没找到可靠匹配。有限相册权限只允许比对你已授权的截图。"
                : "没找到可靠匹配，因此没有删除任何照片。"
            return
        }
        switch batch.decision {
        case .expanded:
            status = "已用屏幕中最下方匹配到的截图定位本次批次，共找到 \(candidates.count) 张连续截图。"
        case .batchTooLarge:
            status = "推断出的批次过大，只保留屏幕中最下方明确匹配的 1 张截图。"
        case .matchedOnly:
            status = nil
        }
        if requestDeletion { await removeSelected() }
    }

    func clearReview() {
        analysis?.cancel()
        capture = nil
        candidates = []
        excluded = []
        status = nil
        busy = false
    }

    func removeSelected() async {
        guard !busy, !deleting, !selected.isEmpty else { return }
        let ids = selected.map(\.id)
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        guard assets.count == ids.count,
              (0..<assets.count).allSatisfy({ assets.object(at: $0).mediaSubtypes.contains(.photoScreenshot) }) else {
            clearReview()
            status = "相册已有变化，请回到聊天再识别一次。"
            return
        }
        deleting = true
        defer { deleting = false }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assets)
            }
            clearReview()
            status = "已从相册删除 \(ids.count) 张截图。"
        } catch {
            status = "未删除截图。你可以检查候选、调整勾选后重试。"
        }
    }

    private static func recentScreenshots(referenceDate: Date) -> PHFetchResult<PHAsset> {
        let albums = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumScreenshots, options: nil)
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let earliest = referenceDate.addingTimeInterval(-5 * 60)
        let latest = referenceDate.addingTimeInterval(-1)
        options.predicate = NSPredicate(
            format: "creationDate >= %@ AND creationDate <= %@",
            earliest as NSDate, latest as NSDate
        )
        if let screenshots = albums.firstObject {
            return PHAsset.fetchAssets(in: screenshots, options: options)
        }
        options.predicate = NSPredicate(
            format: "creationDate >= %@ AND creationDate <= %@ AND (mediaSubtypes & %d) != 0",
            earliest as NSDate, latest as NSDate,
            Int(PHAssetMediaSubtype.photoScreenshot.rawValue)
        )
        return PHAsset.fetchAssets(with: .image, options: options)
    }

    private static func loadImage(_ asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .exact
            options.isNetworkAccessAllowed = false
            PHImageManager.default().requestImage(
                for: asset, targetSize: CGSize(width: 240, height: 520),
                contentMode: .aspectFit, options: options
            ) { image, information in
                if information?[PHImageResultIsDegradedKey] as? Bool == true { return }
                continuation.resume(returning: image)
            }
        }
    }
}

struct CleanupView: View {
    @ObservedObject var model: ReviewModel
    @Environment(\.scenePhase) private var phase
    @State private var showCapture = false
    @State private var importCapture = false
    @State private var showImportError = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if model.busy {
                        ProgressView("正在比对相册截图…")
                            .accessibilityAddTraits(.updatesFrequently)
                    } else if model.candidates.isEmpty {
                        if let status = model.status {
                            Text(status).foregroundStyle(.secondary)
                        }
                        setup
                    } else {
                        review
                    }
                }
                .padding(20)
                .frame(maxWidth: 540, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("截图清理")
            .safeAreaInset(edge: .bottom) {
                if !model.candidates.isEmpty {
                    HStack {
                        Button("取消") { model.clearReview() }
                            .buttonStyle(.bordered)
                            .disabled(model.deleting)
                        Spacer()
                        Button("从相册删除 \(model.selected.count) 张", role: .destructive) {
                            Task { await model.removeSelected() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .disabled(model.selected.isEmpty || model.deleting)
                    }
                    .padding()
                    .background(.regularMaterial)
                }
            }
            .fileImporter(isPresented: $importCapture, allowedContentTypes: [.image]) { result in
                do {
                    let url = try result.get()
                    let accessed = url.startAccessingSecurityScopedResource()
                    defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                    model.start(data: try Data(contentsOf: url, options: .mappedIfSafe))
                } catch {
                    showImportError = true
                }
            }
            .alert("无法读取所选图片", isPresented: $showImportError) {
                Button("好", role: .cancel) {}
            }
            .onChange(of: phase) { _, next in
                if next == .background && !model.deleting {
                    showCapture = false
                    model.clearReview()
                }
            }
        }
    }

    private var setup: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("在聊天里照常发图").font(.title3.bold())
            Text("在「快捷指令」中依次添加「截屏」和「识别刚发送的截图」，将截屏结果传给第二步。然后到「设置 → 辅助功能 → 触控 → 轻点背面」绑定这条指令。")
                .foregroundStyle(.secondary)
            Button("导入聊天画面试用") { importCapture = true }
                .buttonStyle(.bordered)
        }
    }

    private var review: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("准备清理 \(model.candidates.count) 张截图").font(.title3.bold())
            Text("请确认这些是刚发的图。点缩略图可以取消勾选。")
                .foregroundStyle(.secondary)
            if let status = model.status { Text(status).foregroundStyle(.secondary) }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 10) {
                ForEach(model.candidates) { item in
                    let included = !model.excluded.contains(item.id)
                    Button {
                        if included { model.excluded.insert(item.id) } else { model.excluded.remove(item.id) }
                    } label: {
                        Image(uiImage: item.image)
                            .resizable().scaledToFit()
                            .frame(minWidth: 96, maxWidth: 156)
                            .frame(height: 132)
                            .background(.quaternary)
                            .overlay(alignment: .topTrailing) {
                                Image(systemName: included ? "checkmark.circle.fill" : "circle")
                                    .font(.title3).padding(7)
                                    .background(.regularMaterial, in: Circle())
                                    .padding(5)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(included ? "截图，已勾选" : "截图，未勾选")
                    .disabled(model.deleting)
                }
            }
            DisclosureGroup("查看聊天画面中的匹配位置", isExpanded: $showCapture) {
                if let capture = model.capture {
                    GeometryReader { proxy in
                        Image(decorative: capture, scale: 1)
                            .resizable()
                            .overlay {
                                ForEach(model.candidates) { item in
                                    if let rect = item.bounds {
                                        RoundedRectangle(cornerRadius: 4)
                                            .strokeBorder(.green, lineWidth: 2)
                                            .frame(width: rect.width * proxy.size.width,
                                                   height: rect.height * proxy.size.height)
                                            .position(x: rect.midX * proxy.size.width,
                                                      y: rect.midY * proxy.size.height)
                                    }
                                }
                            }
                    }
                    .aspectRatio(CGFloat(capture.width) / CGFloat(capture.height), contentMode: .fit)
                    .frame(maxWidth: 340)
                }
            }
        }
    }
}

