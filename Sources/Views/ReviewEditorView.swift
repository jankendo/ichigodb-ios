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
    @State private var showHistoryVarietyPicker = false
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("クリア") {
                        viewModel.reset()
                    }
                    .disabled(viewModel.isSaving || mode != .entry)
                }
            }
            .keyboardDoneToolbar()
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
            .sheet(isPresented: $showHistoryVarietyPicker) {
                VarietyPickerSheet(
                    varieties: library.activeVarieties,
                    selection: $viewModel.historyVarietyID,
                    emptyTitle: "すべて",
                    allowsRegistration: false,
                    onRegister: { _ in }
                )
            }
            .safeAreaInset(edge: .bottom) {
                bottomActionBar
            }
            .alert("同じ日の評価があります", isPresented: $viewModel.duplicatePending) {
                Button("上書き") {
                    Task {
                        let hadImages = !viewModel.selectedImages.isEmpty
                        if let saved = await viewModel.save(overwriteDuplicate: true) {
                            library.applySavedReview(saved)
                            if hadImages {
                                await library.reload()
                            }
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
            .onChange(of: viewModel.sessionDraft) { _ in
                viewModel.persistDraft()
            }
            .onChange(of: viewModel.entryRequestID) { _ in
                mode = .entry
            }
            .onChange(of: batchSelection) { ids in
                viewModel.updateTastingSessionSelection(
                    Array(ids),
                    baseDraft: viewModel.draft,
                    nameResolver: library.varietyName
                )
            }
            .onAppear {
                batchSelection = Set(viewModel.sessionDraft.selectedVarietyIDs)
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
                            Text("品種をタブで切り替えて、それぞれ別スコア・別メモを保存前にまとめて編集できます。")
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
                        viewModel.updateTastingSessionDate(viewModel.draft.tastedDate)
                        showBatchPicker = true
                    } label: {
                        Label("品種を複数選択", systemImage: "checklist")
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    DatePicker(
                        "共通試食日",
                        selection: Binding(
                            get: { viewModel.sessionDraft.tastedDate },
                            set: { viewModel.updateTastingSessionDate($0) }
                        ),
                        in: ...Date(),
                        displayedComponents: .date
                    )

                    TextField("共通メモ（任意）", text: $viewModel.sessionDraft.commonNote, axis: .vertical)
                        .lineLimit(2...4)

                    if !batchSelection.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(selectedBatchIDs, id: \.self) { id in
                                    CapsuleBadge(text: library.varietyName(id), tint: AppTheme.leaf)
                                }
                            }
                        }

                        Button {
                            viewModel.queueTastingSession(nameResolver: library.varietyName)
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
                if hasTastingSession {
                    tastingSessionEditor
                } else {
                    ScoreCapsuleControl(title: "甘味", value: $viewModel.draft.sweetness)
                    ScoreCapsuleControl(title: "酸味", value: $viewModel.draft.sourness)
                    ScoreCapsuleControl(title: "香り", value: $viewModel.draft.aroma)
                    ScoreCapsuleControl(title: "食感", value: $viewModel.draft.texture)
                    ScoreCapsuleControl(title: "見た目", value: $viewModel.draft.appearance)
                }
            }

            Section("3. 任意メモ") {
                if hasTastingSession {
                    Label("食べ比べ中の購入場所・価格・コメントは、上の品種タブごとに入力できます。画像付き評価は1品種ずつ正式登録してください。", systemImage: "square.stack.3d.up")
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                } else {
                    TextField("購入場所", text: $viewModel.draft.purchasePlace)
                    OptionalIntField(title: "価格（円）", value: $viewModel.draft.priceJPY)
                    TextField("コメント", text: $viewModel.draft.comment, axis: .vertical)
                        .lineLimit(3...8)
                    PhotoSelectionStrip(images: $viewModel.selectedImages, maxCount: 3)
                }
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
            Button {
                showHistoryVarietyPicker = true
            } label: {
                HStack {
                    Label(historyVarietyName, systemImage: "text.magnifyingglass")
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                }
            }
            .buttonStyle(.plain)

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

    private var hasTastingSession: Bool {
        !viewModel.sessionDraft.selectedVarietyIDs.isEmpty
    }

    @ViewBuilder
    private var tastingSessionEditor: some View {
        let ids = selectedBatchIDs
        if ids.isEmpty {
            EmptyView()
        } else {
            let activeID = activeSessionVarietyID ?? ids[0]
            VStack(alignment: .leading, spacing: 14) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ids, id: \.self) { id in
                            Button {
                                viewModel.setActiveTastingVariety(id)
                            } label: {
                                Label(library.varietyName(id), systemImage: activeID == id ? "checkmark.circle.fill" : "circle")
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .foregroundStyle(activeID == id ? Color.white : AppTheme.ink)
                                    .background(activeID == id ? AppTheme.strawberry : AppTheme.card, in: Capsule())
                                    .overlay(Capsule().stroke(activeID == id ? Color.clear : AppTheme.line))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                TastingVarietyDraftCard(
                    varietyName: library.varietyName(activeID),
                    draft: sessionDraftBinding(for: activeID)
                )
            }
            .padding(.vertical, 4)
        }
    }

    private var historyVarietyName: String {
        viewModel.historyVarietyID.isEmpty ? "履歴品種: すべて" : "履歴品種: \(library.varietyName(viewModel.historyVarietyID))"
    }

    private var selectedBatchIDs: [String] {
        batchSelection
            .sorted { library.varietyName($0).localizedStandardCompare(library.varietyName($1)) == .orderedAscending }
    }

    private var activeSessionVarietyID: String? {
        let selectedIDs = selectedBatchIDs
        if selectedIDs.contains(viewModel.sessionDraft.activeVarietyID) {
            return viewModel.sessionDraft.activeVarietyID
        }
        return selectedIDs.first
    }

    private func sessionDraftBinding(for varietyID: String) -> Binding<ReviewDraft> {
        Binding(
            get: { viewModel.tastingDraft(for: varietyID) },
            set: { viewModel.updateTastingDraft($0, for: varietyID) }
        )
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
                        let hadImages = !viewModel.selectedImages.isEmpty
                        if let saved = await viewModel.save() {
                            library.applySavedReview(saved)
                            if hadImages {
                                await library.reload()
                            }
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

private struct TastingVarietyDraftCard: View {
    var varietyName: String
    @Binding var draft: ReviewDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(varietyName)
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                    Text("総合 \(draft.overall)/10")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.strawberry)
                }
                Spacer()
                CapsuleBadge(text: "編集中", tint: AppTheme.gold)
            }

            ScoreCapsuleControl(title: "甘味", value: $draft.sweetness)
            ScoreCapsuleControl(title: "酸味", value: $draft.sourness)
            ScoreCapsuleControl(title: "香り", value: $draft.aroma)
            ScoreCapsuleControl(title: "食感", value: $draft.texture)
            ScoreCapsuleControl(title: "見た目", value: $draft.appearance)

            Divider()

            TextField("購入場所", text: $draft.purchasePlace)
            OptionalIntField(title: "価格（円）", value: $draft.priceJPY)
            TextField("この品種のコメント", text: $draft.comment, axis: .vertical)
                .lineLimit(2...6)
        }
        .padding(12)
        .background(AppTheme.elevated, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.line))
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
    private let entries: [VarietySearchIndexEntry]
    @Binding var selection: Set<String>
    var onRegister: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dismissSearch) private var dismissSearch
    @State private var searchText = ""

    init(varieties: [Variety], selection: Binding<Set<String>>, onRegister: @escaping (String) -> Void) {
        self.entries = VarietySearchIndexEntry.makeSorted(from: varieties)
        self._selection = selection
        self.onRegister = onRegister
    }

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
                        dismissSearch()
                        onRegister(cleanedSearchText)
                        dismiss()
                    } label: {
                        Label("「\(cleanedSearchText)」を品種登録する", systemImage: "plus.square")
                    }
                    .buttonStyle(.plain)
                } else {
                    ForEach(searchResult.rows) { entry in
                        let variety = entry.variety
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
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    SelectionResultFooter(hiddenCount: searchResult.hiddenCount, queryIsEmpty: cleanedSearchText.isEmpty)
                }
            }
            .listStyle(.plain)
            .searchable(text: $searchText, prompt: "品種名・別名で検索")
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("食べ比べ品種")
            .safeAreaInset(edge: .bottom) {
                Button {
                    dismissSearch()
                    dismiss()
                } label: {
                    Label(selection.isEmpty ? "品種を選択してください" : "\(selection.count)件で決定", systemImage: "checkmark.circle")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(selection.isEmpty)
                .padding()
                .background(.thinMaterial)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        dismissSearch()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("決定") {
                        dismissSearch()
                        dismiss()
                    }
                        .disabled(selection.isEmpty)
                }
            }
            .keyboardDoneToolbar()
        }
    }

    private var cleanedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var searchResult: VarietySelectionSearchResult {
        VarietySelectionSearch.result(
            entries: entries,
            query: searchText,
            selectedIDs: selection,
            emptyLimit: 70,
            searchLimit: 120
        )
    }

    private var filteredVarieties: [VarietySearchIndexEntry] {
        searchResult.rows
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
    private let entries: [VarietySearchIndexEntry]
    @Binding var selection: String
    var emptyTitle: String
    var allowsRegistration: Bool
    var onRegister: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dismissSearch) private var dismissSearch
    @State private var searchText = ""

    init(
        varieties: [Variety],
        selection: Binding<String>,
        emptyTitle: String = "未選択",
        allowsRegistration: Bool = true,
        onRegister: @escaping (String) -> Void
    ) {
        self.entries = VarietySearchIndexEntry.makeSorted(from: varieties)
        self._selection = selection
        self.emptyTitle = emptyTitle
        self.allowsRegistration = allowsRegistration
        self.onRegister = onRegister
    }

    var body: some View {
        NavigationStack {
            List {
                Button {
                    dismissSearch()
                    selection = ""
                    dismiss()
                } label: {
                    Label(emptyTitle, systemImage: selection.isEmpty ? "checkmark.circle.fill" : "circle")
                }
                .buttonStyle(.plain)
                if filteredVarieties.isEmpty && !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ContentUnavailableView(
                        "登録済み品種が見つかりません",
                        systemImage: "plus.magnifyingglass",
                        description: Text(allowsRegistration ? "このまま品種登録へ進めます。" : "検索語を変えてください。")
                    )
                    if allowsRegistration {
                        Button {
                            dismissSearch()
                            onRegister(cleanedSearchText)
                            dismiss()
                        } label: {
                            Label("「\(cleanedSearchText)」を品種登録する", systemImage: "plus.square")
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    ForEach(searchResult.rows) { entry in
                        let variety = entry.variety
                        Button {
                            dismissSearch()
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
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    SelectionResultFooter(hiddenCount: searchResult.hiddenCount, queryIsEmpty: cleanedSearchText.isEmpty)
                }
            }
            .listStyle(.plain)
            .searchable(text: $searchText, prompt: "品種名・別名で検索")
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("品種を選択")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        dismissSearch()
                        dismiss()
                    }
                }
                if allowsRegistration {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("登録") {
                            dismissSearch()
                            onRegister(cleanedSearchText)
                            dismiss()
                        }
                        .disabled(cleanedSearchText.isEmpty)
                    }
                }
            }
            .keyboardDoneToolbar()
        }
    }

    private var cleanedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var searchResult: VarietySelectionSearchResult {
        VarietySelectionSearch.result(
            entries: entries,
            query: searchText,
            selectedIDs: selection.isEmpty ? [] : [selection],
            emptyLimit: 70,
            searchLimit: 120
        )
    }

    private var filteredVarieties: [VarietySearchIndexEntry] {
        searchResult.rows
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
