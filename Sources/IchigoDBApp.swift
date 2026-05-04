import SwiftUI
import UIKit

enum AppTab: Hashable {
    case home
    case library
    case varietyEditor
    case reviewEditor
    case analysis
}

@main
struct IchigoDBApp: App {
    var body: some Scene {
        WindowGroup {
            switch SupabaseConfigState.current {
            case .ready(let config):
                ConfiguredRootView(config: config)
            case .missing:
                ConfigMissingView()
            }
        }
    }
}

private struct ConfiguredRootView: View {
    @StateObject private var libraryVM: VarietyLibraryViewModel
    @StateObject private var editorVM: VarietyEditorViewModel
    @StateObject private var reviewVM: ReviewEditorViewModel
    @StateObject private var uploadQueue: UploadQueue
    @State private var selectedTab: AppTab = .home

    init(config: SupabaseConfig) {
        let repository = IchigoRepository(client: SupabaseClient(config: config))
        let dataStore = IchigoDataStore(repository: repository)
        _libraryVM = StateObject(wrappedValue: VarietyLibraryViewModel(repository: repository, dataStore: dataStore))
        _editorVM = StateObject(wrappedValue: VarietyEditorViewModel(repository: repository))
        _reviewVM = StateObject(wrappedValue: ReviewEditorViewModel(repository: repository))
        _uploadQueue = StateObject(wrappedValue: UploadQueue(repository: repository))
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(editorVM: editorVM, reviewVM: reviewVM, selectedTab: $selectedTab)
                .tabItem { Label("ホーム", systemImage: "house") }
                .tag(AppTab.home)

            LibraryView(editorVM: editorVM, reviewVM: reviewVM, selectedTab: $selectedTab)
                .tabItem { Label("図鑑", systemImage: "book.pages") }
                .tag(AppTab.library)

            VarietyEditorView(viewModel: editorVM)
                .tabItem { Label("登録", systemImage: "plus.square") }
                .tag(AppTab.varietyEditor)

            ReviewEditorView(viewModel: reviewVM, editorVM: editorVM, selectedTab: $selectedTab)
                .tabItem { Label("評価", systemImage: "star.leadinghalf.filled") }
                .tag(AppTab.reviewEditor)

            AnalysisView(selectedTab: $selectedTab)
                .tabItem { Label("分析", systemImage: "chart.xyaxis.line") }
                .tag(AppTab.analysis)
        }
        .tint(AppTheme.strawberry)
        .toolbarBackground(.visible, for: .tabBar)
        .environmentObject(libraryVM)
        .environmentObject(uploadQueue)
        .onChange(of: selectedTab) {
            UIApplication.shared.dismissActiveKeyboard()
        }
        .task {
            if libraryVM.varieties.isEmpty {
                await libraryVM.reload()
            }
        }
    }
}

private struct ConfigMissingView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 42))
                .foregroundStyle(AppTheme.strawberry)
            Text("Supabase設定が未注入です")
                .font(.largeTitle.bold())
            Text("GitHub Actionsで `SUPABASE_URL` と `SUPABASE_ANON_KEY` から生成される設定が必要です。ローカル確認時は `Sources/Generated/SupabaseConfig.generated.swift` に一時値を入れてください。")
                .foregroundStyle(AppTheme.muted)
            Text("この画面が出るIPAはDBへ接続しません。")
                .font(.callout.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.surface)
    }
}
