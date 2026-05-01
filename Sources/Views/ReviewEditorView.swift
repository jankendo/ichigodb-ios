import SwiftUI

private enum ReviewScreenMode: String, CaseIterable, Identifiable {
    case entry = "記録"
    case queue = "メモ"
    case history = "履歴"
    case deleted = "復元"

    var id: String { rawValue }
}

struct ReviewEditorView: View {
    @EnvironmentObject private var library: VarietyLibraryViewModel
    @ObservedObject var viewModel: ReviewEditorViewModel
    @ObservedObject var editorVM: VarietyEditorViewModel
    @Binding var selectedTab: AppTab
    @State private var mode: ReviewScreenMode = .entry
    @State private var showVarietyPicker = false
    @State private var showBatchPicker = false
    @State private var batchSelection = Set<String>()

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
            .dismissKeyboardOnTap()
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
                    selection: $viewModel.draft.varietyID,
                    onRegister: { name in
                        editorVM.reset()
                        editorVM.draft.name = name
                        selectedTab = .varietyEditor
                    }
                )
            }
            .sheet(isPresented: $showBatchPicker) {
                MultiVarietyPickerSheet(
                    varieties: library.activeVarieties,
                    selection: $batchSelection,
                    onRegister: { name in
                        editorVM.reset()
                        editorVM.draft.name = name
                        selectedTab = .varietyEditor
                    }
                )
            }
            .safeAreaInset(edge: .bottom) {
                bottomActionBar
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
        case .queue:
            queueList
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
                    subtitle: "食べ比べ中はメモに貯めて、最後にまとめて正式登録できます。",
                    systemImage: "star.leadinghalf.filled"
                )
                HStack(spacing: 10) {
                    MetricPill(title: "総合", value: "\(viewModel.draft.overall)/10")
                    MetricPill(title: "メモ", value: "\(viewModel.queuedDrafts.count)")
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

            Section("食べ比べセット") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("複数品種を同時メモ")
                                .font(.headline)
                            Text("同じ日・同じスコア・同じメモで複数品種を一気に評価メモへ追加できます。")
                                .font(.caption)
                                .foregroundStyle(AppTheme.muted)
                        }
                        Spacer()
                        CapsuleBadge(text: "\(batchSelection.count)件", tint: AppTheme.gold)
                    }

                    Button {
                        if !viewModel.draft.varietyID.isEmpty {
                            batchSelection.insert(viewModel.draft.varietyID)
                        }
                        showBatchPicker = true
                    } label: {
                        Label("品種を複数選択", systemImage: "checklist")
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    if !batchSelection.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(selectedBatchIDs, id: \.self) { id in
                                    CapsuleBadge(text: library.varietyName(id), tint: AppTheme.leaf)
                                }
                            }
                        }

                        Button {
                            viewModel.addBatchToQueue(
                                varietyIDs: Array(batchSelection),
                                nameResolver: library.varietyName
                            )
                            batchSelection.removeAll()
                            mode = .queue
                        } label: {
                            Label("\(batchSelection.count)件をメモに追加", systemImage: "tray.and.arrow.down")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!viewModel.selectedImages.isEmpty)
                    }

                    if !viewModel.selectedImages.isEmpty {
                        Text("画像付きの評価は、画像の取り違えを防ぐため1件ずつ正式登録してください。")
                            .font(.caption)
                            .foregroundStyle(AppTheme.muted)
                    }
                }
                .padding(.vertical, 4)
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

            if !viewModel.queuedDrafts.isEmpty {
                Section("評価メモ") {
                    Button {
                        mode = .queue
                    } label: {
                        Label("\(viewModel.queuedDrafts.count)件を確認して正式登録", systemImage: "tray.full")
                    }
                }
            }

            Section {
                MessageBanner(message: viewModel.message)
                ErrorBanner(message: viewModel.errorMessage)
            }
        }
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(AppTheme.surface)
    }

    private var queueList: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("食べ比べメモ", systemImage: "tray.full")
                        .font(.headline)
                    Text("同じ日に複数品種を試すときは、ここで見比べてからまとめて登録できます。重複する同日評価は正式登録時に上書きします。")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.muted)
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(AppTheme.card)

            if viewModel.queuedDrafts.isEmpty {
                ContentUnavailableView(
                    "評価メモは空です",
                    systemImage: "tray",
                    description: Text("記録タブで品種を選び、「メモに追加」を押してください。")
                )
                .listRowSeparator(.hidden)
            } else {
                ForEach(viewModel.queuedDrafts) { item in
                    QueuedReviewCard(item: item) {
                        viewModel.loadQueuedDraft(item)
                        mode = .entry
                    } onDelete: {
                        viewModel.removeQueuedDraft(item.id)
                    }
                    .listRowSeparator(.hidden)
                }
            }

            Section {
                MessageBanner(message: viewModel.message)
                ErrorBanner(message: viewModel.errorMessage)
            }
        }
        .listStyle(.plain)
        .scrollDismissesKeyboard(.interactively)
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
                    ReviewHistoryCard(review: review, allowRestore: false, editAction: {
                        viewModel.edit(review)
                        mode = .entry
                    }) {
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
        .scrollDismissesKeyboard(.interactively)
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
                    ReviewHistoryCard(review: review, allowRestore: true, editAction: nil) {
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
        .scrollDismissesKeyboard(.interactively)
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

    private var selectedBatchIDs: [String] {
        batchSelection
            .sorted { library.varietyName($0).localizedStandardCompare(library.varietyName($1)) == .orderedAscending }
    }

    @ViewBuilder
    private var bottomActionBar: some View {
        if mode == .entry {
            HStack(spacing: 10) {
                Button {
                    viewModel.addCurrentDraftToQueue(varietyName: selectedVarietyName)
                } label: {
                    Label("メモに追加", systemImage: "tray.and.arrow.down")
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(viewModel.isSaving || viewModel.draft.varietyID.isEmpty)

                Button {
                    Task {
                        if await viewModel.save() != nil {
                            await library.reload()
                        }
                    }
                } label: {
                    Label(viewModel.isSaving ? "保存中" : viewModel.draft.id == nil ? "正式登録" : "更新", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(viewModel.isSaving || viewModel.draft.varietyID.isEmpty)
            }
            .padding()
            .background(.thinMaterial)
        } else if mode == .queue {
            Button {
                Task {
                    if await viewModel.saveQueuedDrafts() > 0 {
                        await library.reload()
                    }
                }
            } label: {
                Label(viewModel.isSaving ? "登録中" : "\(viewModel.queuedDrafts.count)件を正式登録", systemImage: "checkmark.seal")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(viewModel.isSaving || viewModel.queuedDrafts.isEmpty)
            .padding()
            .background(.thinMaterial)
        }
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
    var editAction: (() -> Void)?
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
                                height: 72,
                                contentMode: .fit
                            )
                            .frame(width: 72)
                            .task(id: image.storagePath) {
                                await library.ensureImage(bucket: "review-images", path: image.storagePath)
                            }
                        }
                    }
                }
            }
            HStack(spacing: 10) {
                if let editAction {
                    Button(action: editAction) {
                        Label("編集", systemImage: "pencil")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                Button(action: action) {
                    Label(allowRestore ? "復元" : "削除", systemImage: allowRestore ? "arrow.uturn.backward" : "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())
            }
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

private struct QueuedReviewCard: View {
    var item: QueuedReviewDraft
    var onEdit: () -> Void
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.varietyName)
                        .font(.headline)
                    Text(Validation.isoDate(item.draft.tastedDate))
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                }
                Spacer()
                CapsuleBadge(text: "\(item.draft.overall)/10", tint: AppTheme.gold)
            }

            HStack(spacing: 6) {
                score("甘", item.draft.sweetness)
                score("酸", item.draft.sourness)
                score("香", item.draft.aroma)
                score("食", item.draft.texture)
                score("見", item.draft.appearance)
            }

            if !item.draft.comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(item.draft.comment)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.ink)
            }

            HStack(spacing: 10) {
                Button(action: onEdit) {
                    Label("編集", systemImage: "pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())

                Button(role: .destructive, action: onDelete) {
                    Label("削除", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .cardSurface()
    }

    private func score(_ label: String, _ value: Int) -> some View {
        Text("\(label)\(value)")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AppTheme.elevated, in: Capsule())
    }
}

private struct MultiVarietyPickerSheet: View {
    var varieties: [Variety]
    @Binding var selection: Set<String>
    var onRegister: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Label("\(selection.count)件選択中", systemImage: "checklist")
                            .font(.headline)
                        Spacer()
                        if !selection.isEmpty {
                            Button("全解除") {
                                selection.removeAll()
                            }
                            .font(.subheadline.weight(.semibold))
                        }
                    }
                }
                .listRowBackground(AppTheme.card)

                if filteredVarieties.isEmpty && !cleanedSearchText.isEmpty {
                    ContentUnavailableView(
                        "登録済み品種が見つかりません",
                        systemImage: "plus.magnifyingglass",
                        description: Text("品種登録してから評価へ戻れます。")
                    )
                    Button {
                        onRegister(cleanedSearchText)
                        dismiss()
                    } label: {
                        Label("「\(cleanedSearchText)」を品種登録する", systemImage: "plus.square")
                    }
                } else {
                    ForEach(filteredVarieties) { variety in
                        Button {
                            toggle(variety.id)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: selection.contains(variety.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selection.contains(variety.id) ? AppTheme.strawberry : AppTheme.muted)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(variety.name)
                                        .font(.headline)
                                        .foregroundStyle(AppTheme.ink)
                                    Text(variety.originPrefecture ?? "産地未設定")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.muted)
                                }
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.plain)
            .searchable(text: $searchText, prompt: "品種名・別名で検索")
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTap()
            .navigationTitle("食べ比べ品種")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("決定") { dismiss() }
                        .disabled(selection.isEmpty)
                }
            }
        }
    }

    private var cleanedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredVarieties: [Variety] {
        varieties
            .filter { $0.matchesSearch(searchText) }
            .sorted {
                if $0.isExactMatch(for: searchText) != $1.isExactMatch(for: searchText) {
                    return $0.isExactMatch(for: searchText)
                }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
    }

    private func toggle(_ id: String) {
        if selection.contains(id) {
            selection.remove(id)
        } else {
            selection.insert(id)
        }
    }
}

private struct VarietyPickerSheet: View {
    var varieties: [Variety]
    @Binding var selection: String
    var onRegister: (String) -> Void
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
                if filteredVarieties.isEmpty && !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ContentUnavailableView(
                        "登録済み品種が見つかりません",
                        systemImage: "plus.magnifyingglass",
                        description: Text("このまま品種登録へ進めます。")
                    )
                    Button {
                        onRegister(searchText.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    } label: {
                        Label("「\(searchText)」を品種登録する", systemImage: "plus.square")
                    }
                } else {
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
            }
            .listStyle(.plain)
            .searchable(text: $searchText, prompt: "品種名・別名で検索")
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTap()
            .navigationTitle("品種を選択")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("登録") {
                        onRegister(searchText.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .disabled(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var filteredVarieties: [Variety] {
        varieties.filter { $0.matchesSearch(searchText) }
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
