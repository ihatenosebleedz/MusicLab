import SwiftUI
import Combine

public enum AppTab: Int, CaseIterable, Identifiable {
    case discover = 0
    case search = 1
    case queue = 2
    case library = 3
    case settings = 4
    
    public var id: Int { rawValue }
    
    public var title: String {
        switch self {
        case .discover: return "Discover"
        case .search: return "Search"
        case .queue: return "Queue"
        case .library: return "Library"
        case .settings: return "Settings"
        }
    }
    
    public var iconName: String {
        switch self {
        case .discover: return "sparkles"
        case .search: return "magnifyingglass"
        case .queue: return "arrow.down.circle"
        case .library: return "music.note.list"
        case .settings: return "gearshape"
        }
    }
}

@MainActor
public final class AppState: ObservableObject {
    @Published public var selectedTab: AppTab = .discover
    @Published public var jobs: [Job] = MockData.sampleJobs
    @Published public var serverConfig: ServerConfig = .default
    @Published public var isServerOnline: Bool = false
    @Published public var isCheckingServer: Bool = false
    @Published public var serverStatusMessage: String = "Not connected"
    
    // Search state
    @Published public var searchQuery: String = ""
    @Published public var selectedCatalogFilter: CatalogType? = nil
    @Published public var searchResults: [CatalogItem] = MockData.sampleAlbums + MockData.sampleSongs
    @Published public var isSearching: Bool = false
    
    // Quick import sheet
    @Published public var isShowingQuickImport: Bool = false
    @Published public var quickImportUrl: String = ""
    @Published public var importFeedbackToast: String? = nil
    
    public init() {
        // Load saved settings if any
        loadSavedConfig()
    }
    
    public var activeJobsCount: Int {
        jobs.filter { $0.state.isActive }.count
    }
    
    public func submitImport(item: CatalogItem) {
        let newJob = Job(
            id: "job-\(Int.random(in: 1000...9999))",
            type: item.type.rawValue,
            url: item.appleMusicUrl,
            name: "\(item.artistName) — \(item.title)",
            state: .queued,
            stage: .resolving,
            progressHint: "Enqueued for amdl processing",
            createdAt: Date(),
            updatedAt: Date()
        )
        jobs.insert(newJob, at: 0)
        showToast("Added '\(item.title)' to queue")
    }
    
    public func submitUrlImport(url: String) {
        guard !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let cleanUrl = url.trimmingCharacters(in: .whitespacesAndNewlines)
        let newJob = Job(
            id: "job-\(Int.random(in: 1000...9999))",
            type: cleanUrl.contains("/album/") ? "album" : "song",
            url: cleanUrl,
            name: "Direct Import: \(cleanUrl.split(separator: "/").last ?? "item")",
            state: .queued,
            stage: .resolving,
            progressHint: "Enqueued from direct URL",
            createdAt: Date(),
            updatedAt: Date()
        )
        jobs.insert(newJob, at: 0)
        quickImportUrl = ""
        isShowingQuickImport = false
        showToast("URL submitted to queue")
    }
    
    public func cancelJob(id: String) {
        if let index = jobs.firstIndex(where: { $0.id == id }) {
            jobs[index].state = .cancelled
            jobs[index].updatedAt = Date()
            showToast("Job cancelled")
        }
    }
    
    public func retryJob(id: String) {
        if let index = jobs.firstIndex(where: { $0.id == id }) {
            jobs[index].state = .queued
            jobs[index].stage = .resolving
            jobs[index].error = nil
            jobs[index].updatedAt = Date()
            showToast("Job retried")
        }
    }
    
    public func clearCompletedJobs() {
        jobs.removeAll { $0.state == .completed || $0.state == .cancelled }
        showToast("Cleared finished jobs")
    }
    
    public func testServerConnection() {
        isCheckingServer = true
        serverStatusMessage = "Checking \(serverConfig.backendUrl)..."
        
        guard let url = URL(string: "\(serverConfig.backendUrl)/health") else {
            isCheckingServer = false
            isServerOnline = false
            serverStatusMessage = "Invalid backend URL"
            return
        }
        
        Task {
            var request = URLRequest(url: url)
            request.timeoutInterval = 4.0
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    self.isServerOnline = true
                    self.serverConfig.isConnected = true
                    self.serverConfig.lastChecked = Date()
                    self.serverStatusMessage = "Online (200 OK)"
                } else {
                    self.isServerOnline = false
                    self.serverConfig.isConnected = false
                    self.serverStatusMessage = "Unexpected status: \((response as? HTTPURLResponse)?.statusCode ?? 0)"
                }
            } catch {
                self.isServerOnline = false
                self.serverConfig.isConnected = false
                self.serverStatusMessage = "Unreachable: \(error.localizedDescription)"
            }
            self.isCheckingServer = false
        }
    }
    
    public func showToast(_ message: String) {
        withAnimation {
            self.importFeedbackToast = message
        }
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            withAnimation {
                if self.importFeedbackToast == message {
                    self.importFeedbackToast = nil
                }
            }
        }
    }
    
    private func loadSavedConfig() {
        if let data = UserDefaults.standard.data(forKey: "MusicLab.ServerConfig"),
           let config = try? JSONDecoder().decode(ServerConfig.self, from: data) {
            self.serverConfig = config
        }
    }
    
    public func saveConfig() {
        if let data = try? JSONEncoder().encode(serverConfig) {
            UserDefaults.standard.set(data, forKey: "MusicLab.ServerConfig")
        }
        showToast("Settings saved")
    }
}
