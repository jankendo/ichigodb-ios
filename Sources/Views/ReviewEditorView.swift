import SwiftUI

struct ReviewEditorView: View {
    @EnvironmentObject private var library: VarietyLibraryViewModel
    @ObservedObject var viewModel: ReviewEditorViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    AppScreenHeader(
                        title: "品種評価",
                        subtitle: "5項目をタップして、試食メモをすばやく残します。",
                        systemImage: "star.leadinghalf.filled"
                    )
                    HStack(spacing: 10) {
                        MetricPill(title: "総合", value: "\(viewModel.draft.overall)/10")
                        MetricPill(title: "画像", value: "\(viewModel.selectedImages.count)/3")
                    }
                }
                .listRowBackground(Color.clear)

                Section("対象品種") {
                    Picker("品種", selection: $viewModel.draft.varietyID) {
                        Text("選択してください").tag("")
                        ForEach(library.varieties) { variety in
                            Text(variety.name).tag(variety.id)
                        }
                    }
                    DatePicker("試食日", selection: $viewModel.draft.tastedDate, in: ...Date(), displayedComponents: .date)
                }

                Section("スコア") {
                    ScoreCapsuleControl(title: "甘味", value: $viewModel.draft.sweetness)
                    ScoreCapsuleControl(title: "酸味", value: $viewModel.draft.sourness)
                    ScoreCapsuleControl(title: "香り", value: $viewModel.draft.aroma)
                    ScoreCapsuleControl(title: "食感", value: $viewModel.draft.texture)
                    ScoreCapsuleControl(title: "見た目", value: $viewModel.draft.appearance)
                }

                Section("購入メモ") {
                    TextField("購入場所", text: $viewModel.draft.purchasePlace)
                    OptionalIntField(title: "価格（円）", value: $viewModel.draft.priceJPY)
                    TextField("コメント", text: $viewModel.draft.comment, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section("画像") {
                    PhotoSelectionStrip(images: $viewModel.selectedImages, maxCount: 3)
                }

                Section {
                    MessageBanner(message: viewModel.message)
                    ErrorBanner(message: viewModel.errorMessage)
                }
            }
            .navigationTitle("品種評価")
            .navigationBarTitleDisplayMode(.large)
            .scrollContentBackground(.hidden)
            .background(AppTheme.surface)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("クリア") {
                        viewModel.reset()
                    }
                    .disabled(viewModel.isSaving)
                }
            }
            .safeAreaInset(edge: .bottom) {
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
                Text("同じ品種・試食日の評価を更新しますか？")
            }
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
