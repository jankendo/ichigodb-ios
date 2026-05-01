import SwiftUI

struct VarietyEditorView: View {
    @EnvironmentObject private var library: VarietyLibraryViewModel
    @ObservedObject var viewModel: VarietyEditorViewModel
    @State private var selectedEditID = ""
    @State private var showAdvanced = false

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

                Section("編集対象") {
                    Picker("品種", selection: $selectedEditID) {
                        Text("新規登録").tag("")
                        ForEach(library.varieties) { variety in
                            Text(variety.name).tag(variety.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedEditID) { id in
                        if id.isEmpty {
                            viewModel.reset()
                        } else if let variety = library.varieties.first(where: { $0.id == id }) {
                            viewModel.edit(variety, parentLinks: library.parentLinks)
                        }
                    }
                }

                Section("クイック登録") {
                    TextField("品種名（必須）", text: $viewModel.draft.name)
                        .textInputAutocapitalization(.never)
                        .font(.title3.weight(.semibold))

                    Picker("都道府県", selection: $viewModel.draft.originPrefecture) {
                        Text("未設定").tag("")
                        ForEach(Prefecture.all, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu)

                    Picker("親品種 1", selection: parentBinding(0)) {
                        Text("未設定").tag("")
                        ForEach(parentCandidates) { variety in
                            Text(variety.name).tag(variety.id)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("親品種 2", selection: parentBinding(1)) {
                        Text("未設定").tag("")
                        ForEach(parentCandidates) { variety in
                            Text(variety.name).tag(variety.id)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("画像") {
                    PhotoSelectionStrip(images: $viewModel.selectedImages, maxCount: 5)
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
            }
            .navigationTitle(viewModel.isEditing ? "品種編集" : "品種登録")
            .navigationBarTitleDisplayMode(.large)
            .scrollContentBackground(.hidden)
            .background(AppTheme.surface)
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
            .safeAreaInset(edge: .bottom) {
                Button {
                    Task {
                        if let saved = await viewModel.save() {
                            selectedEditID = saved.id
                            await library.reload()
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
        library.varieties.filter { $0.id != (viewModel.draft.id ?? "") }
    }

    private func parentBinding(_ index: Int) -> Binding<String> {
        Binding {
            guard viewModel.draft.parentIDs.indices.contains(index) else { return "" }
            return viewModel.draft.parentIDs[index]
        } set: { newValue in
            while viewModel.draft.parentIDs.count <= index {
                viewModel.draft.parentIDs.append("")
            }
            viewModel.draft.parentIDs[index] = newValue
        }
    }
}
