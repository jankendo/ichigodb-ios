import SwiftUI

struct VarietyEditorView: View {
    @EnvironmentObject private var library: VarietyLibraryViewModel
    @ObservedObject var viewModel: VarietyEditorViewModel
    @State private var selectedEditID = ""
    @State private var showAdvanced = false
    @State private var showParentSelector = false
    @State private var showEditPicker = false
    @State private var selectedRestoreID = ""
    @State private var deleteConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    AppScreenHeader(
                        title: viewModel.isEditing ? "品種編集" : "品種登録",
                        subtitle: "品種名だけで保存できます。必要な情報はあとから追記できます。",
                        systemImage: "plus.square.on.square"
                    )
                    HStack(spacing: 10) {
                        MetricPill(title: viewModel.isEditing ? "編集中" : "モード", value: viewModel.isEditing ? "更新" : "新規")
                        MetricPill(title: "画像", value: "\(viewModel.selectedImages.count)/5")
                    }
                }
                .listRowBackground(Color.clear)

                Section("登録済み確認") {
                    Button {
                        showEditPicker = true
                    } label: {
                        HStack {
                            Label(viewModel.isEditing ? library.varietyName(viewModel.draft.id ?? "") : "登録済み品種を検索", systemImage: "magnifyingglass")
                            Spacer()
                            Text("\(library.activeVarieties.count)件")
                                .font(.caption)
                                .foregroundStyle(AppTheme.muted)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption)
                                .foregroundStyle(AppTheme.muted)
                        }
                    }
                    .buttonStyle(.plain)
                    Text("品種名を入力すると、既存候補も下に表示します。登録済みならそのまま編集に切り替えられます。")
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                }

                Section("クイック登録") {
                    TextField("品種名（必須）", text: $viewModel.draft.name)
                        .textInputAutocapitalization(.never)
                        .font(.title3.weight(.semibold))

                    TextField("別名（カンマ区切り）", text: $viewModel.draft.aliasNamesText)

                    existingCandidatePanel

                    Picker("都道府県", selection: $viewModel.draft.originPrefecture) {
                        Text("未設定").tag("")
                        ForEach(Prefecture.all, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu)

                    parentSummary
                }

                Section("画像") {
                    PhotoSelectionStrip(images: $viewModel.selectedImages, maxCount: 5)
                    if viewModel.isEditing, let id = viewModel.draft.id {
                        ExistingVarietyImages(varietyID: id, viewModel: viewModel)
                    }
                }

                Section {
                    DisclosureGroup(isExpanded: $showAdvanced) {
                        VStack(alignment: .leading, spacing: 18) {
                            advancedBasicFields
                            Divider()
                            advancedTasteFields
                            Divider()
                            advancedMemoFields
                        }
                        .padding(.vertical, 8)
                    } label: {
                        Label("詳しく設定", systemImage: "slider.horizontal.3")
                    }
                }

                Section {
                    MessageBanner(message: viewModel.message)
                    ErrorBanner(message: viewModel.errorMessage)
                }

                if viewModel.isEditing {
                    Section("管理") {
                        Button(role: .destructive) {
                            deleteConfirmation = true
                        } label: {
                            Label("この品種を削除", systemImage: "trash")
                        }
                    }
                }

                if !library.deletedVarieties.isEmpty {
                    Section("削除済みを復元") {
                        Picker("復元対象", selection: $selectedRestoreID) {
                            Text("選択してください").tag("")
                            ForEach(library.deletedVarieties) { variety in
                                Text(variety.name).tag(variety.id)
                            }
                        }
                        .pickerStyle(.menu)
                        Button {
                            Task {
                                if await viewModel.restore(id: selectedRestoreID) {
                                    selectedRestoreID = ""
                                    await library.reload()
                                }
                            }
                        } label: {
                            Label("復元", systemImage: "arrow.uturn.backward")
                        }
                        .disabled(selectedRestoreID.isEmpty)
                    }
                }
            }
            .navigationTitle(viewModel.isEditing ? "品種編集" : "品種登録")
            .navigationBarTitleDisplayMode(.large)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(AppTheme.surface)
            .keyboardDoneToolbar()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("新規") {
                        selectedEditID = ""
                        viewModel.reset()
                    }
                    .disabled(viewModel.isSaving)
                }
            }
            .onAppear {
                selectedEditID = viewModel.draft.id ?? ""
            }
            .sheet(isPresented: $showParentSelector) {
                ParentSelectionSheet(
                    candidates: parentCandidates,
                    selectedIDs: $viewModel.draft.parentIDs
                )
            }
            .sheet(isPresented: $showEditPicker) {
                VarietyEditPickerSheet(
                    varieties: library.activeVarieties,
                    selectedID: $selectedEditID
                ) { id in
                    if id.isEmpty {
                        viewModel.reset()
                    } else if let variety = library.varieties.first(where: { $0.id == id }) {
                        viewModel.edit(variety, parentLinks: library.parentLinks)
                    }
                }
            }
            .confirmationDialog("この品種を削除しますか？", isPresented: $deleteConfirmation, titleVisibility: .visible) {
                Button("削除", role: .destructive) {
                    Task {
                        if await viewModel.softDeleteCurrent() {
                            selectedEditID = ""
                            await library.reload()
                        }
                    }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("削除後も復元できます。")
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    Task {
                        let hadImages = !viewModel.selectedImages.isEmpty
                        let hadParents = !viewModel.draft.parentIDs.filter { !$0.isEmpty }.isEmpty
                        if let saved = await viewModel.save() {
                            selectedEditID = saved.id
                            library.applySavedVariety(saved)
                            if hadImages || hadParents {
                                await library.reload()
                            }
                        }
                    }
                } label: {
                    Label(viewModel.isSaving ? "保存中" : viewModel.draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "品種名を入力" : "この品種を保存", systemImage: "checkmark")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(viewModel.isSaving || viewModel.draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding()
                .background(.thinMaterial)
            }
        }
    }

    private var advancedBasicFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("登録情報")
                .font(.headline)
            TextField("育成者・開発者", text: $viewModel.draft.developer)
            OptionalIntField(title: "登録年", value: $viewModel.draft.registeredYear)
            TextField("登録番号", text: $viewModel.draft.registrationNumber)
            TextField("出願番号", text: $viewModel.draft.applicationNumber)
        }
    }

    private var advancedTasteFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("味と栽培")
                .font(.headline)
            HStack {
                OptionalDoubleField(title: "糖度下限", value: $viewModel.draft.brixMin)
                OptionalDoubleField(title: "糖度上限", value: $viewModel.draft.brixMax)
            }
            Picker("酸味", selection: $viewModel.draft.acidityLevel) {
                ForEach(AcidityLevel.allCases) { level in
                    Text(level.label).tag(level)
                }
            }
            .pickerStyle(.segmented)
            OptionalIntField(title: "収穫開始月", value: $viewModel.draft.harvestStartMonth)
            OptionalIntField(title: "収穫終了月", value: $viewModel.draft.harvestEndMonth)
            TextField("果皮色", text: $viewModel.draft.skinColor)
            TextField("果肉色", text: $viewModel.draft.fleshColor)
        }
    }

    private var advancedMemoFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("メモ")
                .font(.headline)
            TextField("特性の概要", text: $viewModel.draft.characteristicsSummary, axis: .vertical)
                .lineLimit(2...5)
            TextField("説明", text: $viewModel.draft.description, axis: .vertical)
                .lineLimit(3...8)
            TextField("タグ（カンマ区切り）", text: $viewModel.draft.tagsText)
        }
    }

    private var parentCandidates: [Variety] {
        library.activeVarieties.filter { $0.id != (viewModel.draft.id ?? "") }
    }

    @ViewBuilder
    private var existingCandidatePanel: some View {
        let rows = existingCandidates
        if viewModel.draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Label("ひらがな・カタカナ違い、別名、登録番号でも探します。", systemImage: "text.magnifyingglass")
                .font(.caption)
                .foregroundStyle(AppTheme.muted)
        } else if rows.isEmpty {
            Label("近い登録済み品種は見つかりません。新規登録できそうです。", systemImage: "checkmark.seal")
                .font(.caption)
                .foregroundStyle(AppTheme.leaf)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Label(exactDuplicate == nil ? "似ている登録済み品種" : "既に登録済みの可能性があります", systemImage: exactDuplicate == nil ? "sparkle.magnifyingglass" : "exclamationmark.triangle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(exactDuplicate == nil ? AppTheme.ink : AppTheme.strawberry)
                ForEach(Array(rows.prefix(5))) { candidate in
                    Button {
                        let variety = candidate.variety
                        selectedEditID = variety.id
                        viewModel.edit(variety, parentLinks: library.parentLinks)
                    } label: {
                        let variety = candidate.variety
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(variety.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.ink)
                                    CapsuleBadge(text: candidate.kind.rawValue, tint: candidate.kind == .exact ? AppTheme.strawberry : AppTheme.gold)
                                }
                                Text(candidateSubtitle(for: candidate))
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.muted)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "pencil")
                                .foregroundStyle(AppTheme.strawberry)
                        }
                        .padding(10)
                        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(candidate.kind == .exact ? AppTheme.strawberry : AppTheme.line))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var existingCandidates: [VarietyMatchCandidate] {
        let query = viewModel.draft.name
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        return library.duplicateCandidates(for: query, limit: 8)
            .filter { $0.variety.id != (viewModel.draft.id ?? "") }
    }

    private var exactDuplicate: VarietyMatchCandidate? {
        existingCandidates.first { $0.kind == .exact }
    }

    private func candidateSubtitle(for candidate: VarietyMatchCandidate) -> String {
        let variety = candidate.variety
        var parts = [String]()
        if let prefecture = variety.originPrefecture { parts.append(prefecture) }
        if let number = variety.registrationNumber { parts.append("登録 \(number)") }
        if !variety.aliasNames.isEmpty { parts.append("別名 \(variety.aliasNames.prefix(2).joined(separator: ", "))") }
        parts.append(candidate.kind.rawValue)
        return parts.isEmpty ? "登録済み" : parts.joined(separator: " / ")
    }

    private var parentSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                showParentSelector = true
            } label: {
                Label("親品種を選ぶ", systemImage: "leaf")
            }
            .buttonStyle(SecondaryButtonStyle())

            if viewModel.draft.parentIDs.filter({ !$0.isEmpty }).isEmpty {
                Text("親品種は未設定です。")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(viewModel.draft.parentIDs.filter { !$0.isEmpty }, id: \.self) { id in
                        CapsuleBadge(text: library.varietyName(id), tint: AppTheme.leaf)
                    }
                }
            }
        }
    }
}

private struct ParentSelectionSheet: View {
    var candidates: [Variety]
    @Binding var selectedIDs: [String]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dismissSearch) private var dismissSearch
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredCandidates) { variety in
                    Button {
                        toggle(variety.id)
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(variety.name)
                                    .foregroundStyle(AppTheme.ink)
                                if let prefecture = variety.originPrefecture {
                                    Text(prefecture)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.muted)
                                }
                            }
                            Spacer()
                            if selectedIDs.contains(variety.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(AppTheme.strawberry)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .searchable(text: $searchText, prompt: "親品種を検索")
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("親品種")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        dismissSearch()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("クリア") {
                        dismissSearch()
                        selectedIDs = []
                    }
                }
            }
            .keyboardDoneToolbar()
        }
    }

    private var filteredCandidates: [Variety] {
        candidates.filter { $0.matchesSearch(searchText) }
    }

    private func toggle(_ id: String) {
        if selectedIDs.contains(id) {
            selectedIDs.removeAll { $0 == id }
        } else {
            selectedIDs.append(id)
        }
    }
}

private struct VarietyEditPickerSheet: View {
    var varieties: [Variety]
    @Binding var selectedID: String
    var onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dismissSearch) private var dismissSearch
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            List {
                Button {
                    dismissSearch()
                    selectedID = ""
                    onSelect("")
                    dismiss()
                } label: {
                    Label("新規登録", systemImage: selectedID.isEmpty ? "checkmark.circle.fill" : "plus.circle")
                }
                .buttonStyle(.plain)

                if filteredVarieties.isEmpty {
                    ContentUnavailableView(
                        "一致する登録済み品種がありません",
                        systemImage: "magnifyingglass",
                        description: Text("表記を変えるか、このまま新規登録してください。")
                    )
                } else {
                    ForEach(filteredVarieties) { variety in
                        Button {
                            dismissSearch()
                            selectedID = variety.id
                            onSelect(variety.id)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(variety.name)
                                        .font(.headline)
                                        .foregroundStyle(AppTheme.ink)
                                    Text(subtitle(for: variety))
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.muted)
                                        .lineLimit(1)
                                }
                                Spacer()
                                if selectedID == variety.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(AppTheme.strawberry)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "品種名・別名・登録番号")
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("登録済み品種")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        dismissSearch()
                        dismiss()
                    }
                }
            }
            .keyboardDoneToolbar()
        }
    }

    private var filteredVarieties: [Variety] {
        varieties.filter { $0.matchesSearch(searchText) }
            .sorted {
                if $0.isExactMatch(for: searchText) != $1.isExactMatch(for: searchText) {
                    return $0.isExactMatch(for: searchText)
                }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
    }

    private func subtitle(for variety: Variety) -> String {
        var parts = [String]()
        if let prefecture = variety.originPrefecture { parts.append(prefecture) }
        if let number = variety.registrationNumber { parts.append("登録 \(number)") }
        if !variety.aliasNames.isEmpty { parts.append("別名 \(variety.aliasNames.prefix(2).joined(separator: ", "))") }
        return parts.isEmpty ? "登録済み" : parts.joined(separator: " / ")
    }
}

private struct ExistingVarietyImages: View {
    @EnvironmentObject private var library: VarietyLibraryViewModel
    var varietyID: String
    @ObservedObject var viewModel: VarietyEditorViewModel

    var body: some View {
        if !images.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("登録済み画像")
                    .font(.headline)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(images) { image in
                            VStack(spacing: 8) {
                                AsyncVarietyImage(
                                    image: library.loadedImage(bucket: "variety-images", path: image.storagePath),
                                    url: library.imageURL(bucket: "variety-images", path: image.storagePath),
                                    height: 96,
                                    contentMode: .fit
                                )
                                .frame(width: 116)
                                .task(id: image.storagePath) {
                                    await library.ensureImage(bucket: "variety-images", path: image.storagePath)
                                }
                                if image.isPrimary {
                                    CapsuleBadge(text: "メイン", tint: AppTheme.strawberry)
                                } else {
                                    Button("メイン") {
                                        Task {
                                            if await viewModel.setPrimaryImage(varietyID: varietyID, imageID: image.id) {
                                                await library.reload()
                                            }
                                        }
                                    }
                                    .font(.caption.weight(.semibold))
                                }
                                Button(role: .destructive) {
                                    Task {
                                        if await viewModel.deleteImage(image) {
                                            library.clearCachedImage(bucket: "variety-images", path: image.storagePath)
                                            await library.reload()
                                        }
                                    }
                                } label: {
                                    Label("削除", systemImage: "trash")
                                        .font(.caption)
                                }
                            }
                            .frame(width: 116)
                        }
                    }
                }
            }
        }
    }

    private var images: [VarietyImage] {
        library.images(for: varietyID)
    }
}
