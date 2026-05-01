import SwiftUI

private enum ReviewScreenMode: String, CaseIterable, Identifiable {
    case entry = "記録"
    case history = "履歴"
    case deleted = "復元"

    var id: String { rawValue }
}

struct ReviewEditorView: View {
    @EnvironmentObject private var library: VarietyLibraryViewModel
    @ObservedObject var viewModel: ReviewEditorViewModel
    @State private var mode: ReviewScreenMode = .entry
    @State private var showVarietyPicker = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("表示", selection: $mode) {
                    ForEach(ReviewScreenMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding([.horizontal, .top])

                content
            }
            .navigationTitle("品種評価")
            .navigationBarTitleDisplayMode(.large)
            .background(AppTheme.surface)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("クリア") {
                        viewModel.reset()
                    }
                    .disabled(viewModel.isSaving || mode != .entry)
                }
            }
            .sheet(isPresented: $showVarietyPicker) {
                VarietyPickerSheet(
                    varieties: library.activeVarieties,
                    selection: $viewModel.draft.varietyID
                )
            }
            .safeAreaInset(edge: .bottom) {
                if mode == .entry {
                    Button {
                        Task {
                            if await viewModel.save() != nil {
                                await library.reload()
                            }
                        }
                    } label: {
                        Label(viewModel.isSaving ? "保存中" : "評価を保存", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(viewModel.isSaving || viewModel.draft.varietyID.isEmpty)
                    .padding()
                    .background(.thinMaterial)
                }
            }
            .alert("同じ日の評価があります", isPresented: $viewModel.duplicatePending) {
                Button("上書き") {
                    Task {
                        if await viewModel.save(overwriteDuplicate: true) != nil {
                            await library.reload()
                        }
                    }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text(duplicateMessage)
            }
            .onChange(of: viewModel.draft) { _ in
                viewModel.persistDraft()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .entry:
            entryForm
        case .history:
            historyList
        case .deleted:
            deletedList
        }
    }

    private var entryForm: some View {
        Form {
            Section {
                AppScreenHeader(
                    title: "品種評価",
                    subtitle: "品種を選び、5項目をタップしてすぐ記録できます。",
                    systemImage: "star.leadinghalf.filled"
                )
                HStack(spacing: 10) {
                    MetricPill(title: "総合", value: "\(viewModel.draft.overall)/10")
                    MetricPill(title: "画像", value: "\(viewModel.selectedImages.count)/3")
                }
            }
            .listRowBackground(Color.clear)

            Section("1. 品種と日付") {
                Button {
                    showVarietyPicker = true
                } label: {
                    HStack {
                        Label(selectedVarietyName, systemImage: "magnifyingglass")
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundStyle(AppTheme.muted)
                    }
                }
                .buttonStyle(.plain)

                DatePicker("試食日", selection: $viewModel.draft.tastedDate, in: ...Date(), displayedComponents: .date)
            }

            Section("2. スコア") {
                ScoreCapsuleControl(title: "甘味", value: $viewModel.draft.sweetness)
                ScoreCapsuleControl(title: "酸味", value: $viewModel.draft.sourness)
                ScoreCapsuleControl(title: "香り", value: $viewModel.draft.aroma)
                ScoreCapsuleControl(title: "食感", value: $viewModel.draft.texture)
                ScoreCapsuleControl(title: "見た目", value: $viewModel.draft.appearance)
            }

            Section("3. 任意メモ") {
                TextField("購入場所", text: $viewModel.draft.purchasePlace)
                OptionalIntField(title: "価格（円）", value: $viewModel.draft.priceJPY)
                TextField("コメント", text: $viewModel.draft.comment, axis: .vertical)
                    .lineLimit(3...8)
                PhotoSelectionStrip(images: $viewModel.selectedImages, maxCount: 3)
            }

            Section {
                MessageBanner(message: viewModel.message)
                ErrorBanner(message: viewModel.errorMessage)
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.surface)
    }

    private var historyList: some View {
        List {
            Section {
                historyFilters
            }
            .listRowBackground(AppTheme.card)

            if filteredHistoryRows.isEmpty {
                ContentUnavailableView(
                    "評価履歴がありません",
                    systemImage: "tray",
                    description: Text("条件を変えるか、記録タブから評価を追加してください。")
                )
                .listRowSeparator(.hidden)
            } else {
                ForEach(filteredHistoryRows) { review in
                    ReviewHistoryCard(review: review, allowRestore: false) {
                        Task {
                            if await viewModel.deleteReview(id: review.id) {
                                await library.reload()
                            }
                        }
                    }
                    .listRowSeparator(.hidden)
                }
            }
        }
        .listStyle(.plain)
        .refreshable { await library.reload() }
    }

    private var deletedList: some View {
        List {
            if library.deletedReviews.isEmpty {
                ContentUnavailableView(
                    "削除済み評価はありません",
                    systemImage: "arrow.uturn.backward",
                    description: Text("削除した評価だけがここに表示されます。")
                )
                .listRowSeparator(.hidden)
            } else {
                ForEach(library.deletedReviews.sorted { $0.tastedDate > $1.tastedDate }) { review in
                    ReviewHistoryCard(review: review, allowRestore: true) {
                        Task {
                            if await viewModel.restoreReview(id: review.id) {
                                await library.reload()
                            }
                        }
                    }
                    .listRowSeparator(.hidden)
                }
            }
        }
        .listStyle(.plain)
        .refreshable { await library.reload() }
    }

    private var historyFilters: some View {
        VStack(spacing: 12) {
            Picker("履歴品種", selection: $viewModel.historyVarietyID) {
                Text("すべて").tag("")
                ForEach(library.activeVarieties) { variety in
                    Text(variety.name).tag(variety.id)
                }
            }
            .pickerStyle(.menu)

            DatePicker("開始日", selection: $viewModel.historyDateFrom, displayedComponents: .date)
            DatePicker("終了日", selection: $viewModel.historyDateTo, in: ...Date(), displayedComponents: .date)
            Stepper("総合 \(viewModel.historyMinimumOverall) 以上", value: $viewModel.historyMinimumOverall, in: 1...10)
        }
    }

    private var filteredHistoryRows: [Review] {
        let from = Validation.isoDate(viewModel.historyDateFrom)
        let to = Validation.isoDate(viewModel.historyDateTo)
        return library.activeReviews
            .filter { review in
                if !viewModel.historyVarietyID.isEmpty && review.varietyID != viewModel.historyVarietyID {
                    return false
                }
                return review.tastedDate >= min(from, to)
                    && review.tastedDate <= max(from, to)
                    && review.overall >= viewModel.historyMinimumOverall
            }
            .sorted { $0.tastedDate > $1.tastedDate }
    }

    private var selectedVarietyName: String {
        viewModel.draft.varietyID.isEmpty ? "品種を選択" : library.varietyName(viewModel.draft.varietyID)
    }

    private var duplicateMessage: String {
        guard let id = viewModel.duplicateReviewID,
              let review = library.reviews.first(where: { $0.id == id }) else {
            return "同じ品種・試食日の評価を更新しますか？"
        }
        return "\(library.varietyName(review.varietyID)) / \(review.tastedDate) / 総合 \(review.overall)/10 を上書きします。"
    }
}

private struct ReviewHistoryCard: View {
    @EnvironmentObject private var library: VarietyLibraryViewModel
    var review: Review
    var allowRestore: Bool
    var action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(library.varietyName(review.varietyID))
                        .font(.headline)
                    Text(review.tastedDate)
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                }
                Spacer()
                CapsuleBadge(text: "\(review.overall)/10", tint: AppTheme.strawberry)
            }
            HStack(spacing: 6) {
                score("甘", review.sweetness)
                score("酸", review.sourness)
                score("香", review.aroma)
                score("食", review.texture)
                score("見", review.appearance)
            }
            if let place = review.purchasePlace, !place.isEmpty {
                Label(place, systemImage: "bag")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
            }
            if let comment = review.comment, !comment.isEmpty {
                Text(comment)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.ink)
            }
            if !images.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(images) { image in
                            AsyncVarietyImage(
                                image: library.loadedImage(bucket: "review-images", path: image.storagePath),
                                url: library.imageURL(bucket: "review-images", path: image.storagePath),
                                height: 72
                            )
                            .frame(width: 72)
                            .task {
                                await library.ensureImage(bucket: "review-images", path: image.storagePath)
                            }
                        }
                    }
                }
            }
            Button(action: action) {
                Label(allowRestore ? "復元" : "削除", systemImage: allowRestore ? "arrow.uturn.backward" : "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .cardSurface()
    }

    private var images: [ReviewImage] {
        library.reviewImages(for: review.id)
    }

    private func score(_ label: String, _ value: Int) -> some View {
        Text("\(label)\(value)")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AppTheme.elevated, in: Capsule())
    }
}

private struct VarietyPickerSheet: View {
    var varieties: [Variety]
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            List {
                Button {
                    selection = ""
                    dismiss()
                } label: {
                    Label("未選択", systemImage: selection.isEmpty ? "checkmark.circle.fill" : "circle")
                }
                ForEach(filteredVarieties) { variety in
                    Button {
                        selection = variety.id
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(variety.name)
                                    .foregroundStyle(AppTheme.ink)
                                Text(variety.originPrefecture ?? "産地未設定")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.muted)
                            }
                            Spacer()
                            if selection == variety.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(AppTheme.strawberry)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "品種名・別名で検索")
            .navigationTitle("品種を選択")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private var filteredVarieties: [Variety] {
        let normalized = searchText.normalizedSearchText
        guard !normalized.isEmpty else { return varieties }
        return varieties.filter { variety in
            ([variety.name, variety.japaneseName, variety.originPrefecture].compactMap { $0 } + variety.aliasNames)
                .joined(separator: " ")
                .normalizedSearchText
                .contains(normalized)
        }
    }
}

private struct ScoreCapsuleControl: View {
    var title: String
    @Binding var value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text("\(value)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(AppTheme.strawberry)
            }

            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { score in
                    Button {
                        value = score
                    } label: {
                        Text("\(score)")
                            .font(.headline.monospacedDigit())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .foregroundStyle(value == score ? .white : AppTheme.ink)
                            .background(value == score ? AppTheme.strawberry : AppTheme.card, in: Capsule())
                            .overlay(Capsule().stroke(value == score ? AppTheme.strawberry : AppTheme.line))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(title) \(score)")
                }
            }
        }
        .padding(.vertical, 6)
    }
}
