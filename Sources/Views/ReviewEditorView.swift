import SwiftUI

struct ReviewEditorView: View {
    @EnvironmentObject private var library: VarietyLibraryViewModel
    @ObservedObject var viewModel: ReviewEditorViewModel

    var body: some View {
        NavigationStack {
            Form {
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
                    scoreStepper("甘味", value: $viewModel.draft.sweetness)
                    scoreStepper("酸味", value: $viewModel.draft.sourness)
                    scoreStepper("香り", value: $viewModel.draft.aroma)
                    scoreStepper("食感", value: $viewModel.draft.texture)
                    scoreStepper("見た目", value: $viewModel.draft.appearance)
                    HStack {
                        Text("総合")
                        Spacer()
                        Text("\(viewModel.draft.overall)/10")
                            .font(.title2.bold())
                            .foregroundStyle(AppTheme.strawberry)
                    }
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

    private func scoreStepper(_ title: String, value: Binding<Int>) -> some View {
        Stepper(value: value, in: 1...5) {
            HStack {
                Text(title)
                Spacer()
                Text("\(value.wrappedValue)")
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)
            }
        }
    }
}
