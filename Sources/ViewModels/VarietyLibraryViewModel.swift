import Foundation
import SwiftUI

enum DiscoveryFilter: String, CaseIterable, Identifiable {
    case all = "すべて"
    case discovered = "発見済み"
    case undiscovered = "未発見"

    var id: String { rawValue }
}

@MainActor
final class VarietyLibraryViewModel: ObservableObject {
    @Published var varieties: [Variety] = []
    @Published var reviews: [Review] = []
    @Published var parentLinks: [VarietyParentLink] = []
    @Published var varietyImages: [VarietyImage] = []
    @Published var reviewImages: [ReviewImage] = []
    @Published var signedImageURLs: [String: URL] = [:]
    @Published var searchText = ""
    @Published var discoveryFilter: DiscoveryFilter = .all
    @Published var prefectureFilter = ""
    @Published var selectedVarietyID: String?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let repository: IchigoRepository

    init(repository: IchigoRepository) {
        self.repository = repository
        self.varieties = repository.cachedVarieties()
        self.reviews = repository.cachedReviews()
    }

    var discoveredIDs: Set<String> {
        Set(reviews.filter { $0.deletedAt == nil }.map(\.varietyID))
    }

    var progressText: String {
        let total = max(varieties.count, 1)
        let count = discoveredIDs.count
        return "\(count)/\(total)"
    }

    var filteredVarieties: [Variety] {
        let normalized = searchText.normalizedSearchText
        return varieties.filter { variety in
            guard variety.deletedAt == nil else { return false }
            if !prefectureFilter.isEmpty && variety.originPrefecture != prefectureFilter {
                return false
            }
            switch discoveryFilter {
            case .all:
                break
            case .discovered:
                guard discoveredIDs.contains(variety.id) else { return false }
            case .undiscovered:
                guard !discoveredIDs.contains(variety.id) else { return false }
            }
            guard !normalized.isEmpty else { return true }
            return variety.searchBlob.contains(normalized)
        }
    }

    func reload() async {
        isLoading = true
        errorMessage = nil
        do {
            async let varietiesTask = repository.fetchVarieties()
            async let reviewsTask = repository.fetchReviews()
            async let linksTask = repository.fetchParentLinks()
            async let varietyImagesTask = repository.fetchVarietyImages()
            async let reviewImagesTask = repository.fetchReviewImages()
            varieties = try await varietiesTask
            reviews = try await reviewsTask
            parentLinks = try await linksTask
            varietyImages = try await varietyImagesTask
            reviewImages = try await reviewImagesTask
            await preloadPrimaryImageURLs()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func reviewCount(for varietyID: String) -> Int {
        reviews.filter { $0.varietyID == varietyID && $0.deletedAt == nil }.count
    }

    func latestReview(for varietyID: String) -> Review? {
        reviews
            .filter { $0.varietyID == varietyID && $0.deletedAt == nil }
            .sorted { $0.tastedDate > $1.tastedDate }
            .first
    }

    func primaryImage(for varietyID: String) -> VarietyImage? {
        let images = varietyImages.filter { $0.varietyID == varietyID }
        return images.first(where: \.isPrimary) ?? images.first
    }

    func images(for varietyID: String) -> [VarietyImage] {
        varietyImages.filter { $0.varietyID == varietyID }
    }

    func varietyName(_ id: String) -> String {
        varieties.first(where: { $0.id == id })?.name ?? "未選択"
    }

    func imageURL(for image: VarietyImage?) -> URL? {
        guard let image else { return nil }
        return signedImageURLs[image.storagePath]
    }

    func ensureSignedURL(for image: VarietyImage) async {
        guard signedImageURLs[image.storagePath] == nil else { return }
        do {
            signedImageURLs[image.storagePath] = try await repository.signedURL(bucket: "variety-images", path: image.storagePath)
        } catch {
            // Missing image URLs should not block the app.
        }
    }

    func deleteVariety(_ id: String) async {
        do {
            try await repository.softDeleteVariety(id: id)
            await reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func preloadPrimaryImageURLs() async {
        let firstImages = varieties.compactMap { primaryImage(for: $0.id) }.prefix(40)
        for image in firstImages {
            await ensureSignedURL(for: image)
        }
    }
}

private extension Variety {
    var searchBlob: String {
        ([name, japaneseName, registrationNumber, applicationNumber, developer, originPrefecture, description, characteristicsSummary]
            .compactMap { $0 } + aliasNames + tags)
            .joined(separator: " ")
            .normalizedSearchText
    }
}

extension String {
    var normalizedSearchText: String {
        let folded = folding(options: [.caseInsensitive, .widthInsensitive, .diacriticInsensitive], locale: Locale(identifier: "ja_JP"))
        return folded.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
