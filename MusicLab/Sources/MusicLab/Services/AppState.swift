import SwiftUI
import Combine
import MusicLabCore

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
    private let keychain = KeychainService()
    
    // Search state
    @Published public var searchQuery: String = ""
    @Published public var selectedCatalogFilter: CatalogType? = nil
    @Published public var searchResults: [CatalogItem] = MockData.sampleAlbums + MockData.sampleSongs
    @Published public var isSearching: Bool = false
    @Published public var searchErrorMessage: String? = nil
    
    // Quick import sheet
    @Published public var isShowingQuickImport: Bool = false
    @Published public var quickImportUrl: String = ""
    @Published public var importFeedbackToast: String? = nil
    
    private let musicClient = AppleMusicClient()
    private let backendClient = BackendClient()
    
    public init() {
        // Load saved settings if any
        loadSavedConfig()
        testServerConnection()
    }
    
    public var activeJobsCount: Int {
        jobs.filter { $0.state.isActive }.count
    }
    
    public func submitImport(item: CatalogItem) {
        if isServerOnline && !serverConfig.bearerToken.isEmpty {
            Task {
                do {
                    _ = try await backendClient.submitJob(
                        baseUrl: serverConfig.backendUrl,
                        token: serverConfig.bearerToken,
                        appleMusicUrl: item.appleMusicUrl,
                        name: "\(item.artistName) — \(item.title)"
                    )
                    await self.refreshJobsFromBackend()
                    self.showToast("Submitted '\(item.title)' to server")
                } catch {
                    self.showToast("Submission failed: \(error.localizedDescription)")
                }
            }
        } else {
            let newJob = Job(
                id: "job-\(Int.random(in: 1000...9999))",
                type: item.type.rawValue,
                url: item.appleMusicUrl,
                name: "\(item.artistName) — \(item.title)",
                state: .queued,
                stage: .resolving,
                progressHint: "Enqueued (offline mode)",
                createdAt: Date(),
                updatedAt: Date()
            )
            jobs.insert(newJob, at: 0)
            showToast("Added '\(item.title)' to local queue")
        }
    }
    
    public func submitUrlImport(url: String) {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        do {
            let parsed = try AppleMusicURL.parse(trimmed)
            let typeName = parsed.effectiveResourceType.rawValue
            let label = parsed.slug?.replacingOccurrences(of: "-", with: " ").capitalized ?? "Item \(parsed.effectiveIdentifier)"
            let itemName = "\(typeName.capitalized): \(label)"
            
            if isServerOnline && !serverConfig.bearerToken.isEmpty {
                Task {
                    do {
                        _ = try await backendClient.submitJob(
                            baseUrl: serverConfig.backendUrl,
                            token: serverConfig.bearerToken,
                            appleMusicUrl: parsed.originalURL.absoluteString,
                            name: itemName
                        )
                        await self.refreshJobsFromBackend()
                        self.quickImportUrl = ""
                        self.isShowingQuickImport = false
                        self.showToast("Submitted \(typeName) to server")
                    } catch {
                        self.showToast("Server import failed: \(error.localizedDescription)")
                    }
                }
            } else {
                let newJob = Job(
                    id: "job-\(Int.random(in: 1000...9999))",
                    type: typeName,
                    url: parsed.originalURL.absoluteString,
                    name: itemName,
                    state: .queued,
                    stage: .resolving,
                    progressHint: "Enqueued via validated URL (\(parsed.storefront))",
                    createdAt: Date(),
                    updatedAt: Date()
                )
                jobs.insert(newJob, at: 0)
                quickImportUrl = ""
                isShowingQuickImport = false
                showToast("Added validated \(typeName) to local queue")
            }
        } catch let urlError as AppleMusicURLError {
            showToast("Error: \(urlError.localizedDescription)")
        } catch {
            showToast("Invalid Apple Music URL: \(error.localizedDescription)")
        }
    }
    
    public func performSearch(query: String, filter: CatalogType? = nil) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = MockData.sampleAlbums + MockData.sampleSongs
            searchErrorMessage = nil
            return
        }
        
        isSearching = true
        searchErrorMessage = nil
        
        Task {
            #if !os(Linux)
            do {
                let types: [AppleMusicResourceType]
                if let filter = filter {
                    switch filter {
                    case .song: types = [.song]
                    case .album: types = [.album]
                    case .playlist: types = [.playlist]
                    case .artist: types = [.artist]
                    }
                } else {
                    types = [.album, .song, .playlist]
                }
                
                let results = try await musicClient.search(query: trimmed, types: types)
                self.searchResults = results
                self.isSearching = false
            } catch {
                // If direct network fails, fallback to filtered mock dataset
                let allItems = MockData.sampleAlbums + MockData.sampleSongs
                let lower = trimmed.lowercased()
                let filtered = allItems.filter {
                    $0.title.lowercased().contains(lower) || $0.artistName.lowercased().contains(lower)
                }
                self.searchResults = filtered
                self.searchErrorMessage = "Live catalog lookup unavailable (\(error.localizedDescription)); showing local suggestions"
                self.isSearching = false
            }
            #else
            let allItems = MockData.sampleAlbums + MockData.sampleSongs
            let lower = trimmed.lowercased()
            let filtered = allItems.filter {
                $0.title.lowercased().contains(lower) || $0.artistName.lowercased().contains(lower)
            }
            self.searchResults = filtered
            self.isSearching = false
            #endif
        }
    }
    
    public func cancelJob(id: String) {
        if isServerOnline && !serverConfig.bearerToken.isEmpty {
            Task {
                do {
                    _ = try await backendClient.cancelJob(
                        baseUrl: serverConfig.backendUrl,
                        token: serverConfig.bearerToken,
                        jobId: id
                    )
                    await self.refreshJobsFromBackend()
                    self.showToast("Job cancelled on server")
                } catch {
                    self.showToast("Failed to cancel job: \(error.localizedDescription)")
                }
            }
        } else {
            if let index = jobs.firstIndex(where: { $0.id == id }) {
                jobs[index].state = .cancelled
                jobs[index].updatedAt = Date()
                showToast("Job cancelled")
            }
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
        
        Task {
            do {
                let health = try await backendClient.checkHealth(baseUrl: serverConfig.backendUrl)
                self.isServerOnline = true
                self.serverConfig.isConnected = true
                self.serverConfig.lastChecked = Date()
                let amdlStatus = health.services?.amdl?.available == true ? "amdl ready" : "amdl unavailable"
                self.serverStatusMessage = "Online (v\(health.version), \(amdlStatus))"
                await self.refreshJobsFromBackend()
            } catch {
                self.isServerOnline = false
                self.serverConfig.isConnected = false
                self.serverStatusMessage = "Unreachable: \(error.localizedDescription)"
            }
            self.isCheckingServer = false
        }
    }
    
    public func refreshJobsFromBackend() async {
        guard isServerOnline, !serverConfig.bearerToken.isEmpty else { return }
        do {
            let summaries = try await backendClient.fetchJobs(
                baseUrl: serverConfig.backendUrl,
                token: serverConfig.bearerToken
            )
            
            // Map summaries to Job models
            let serverJobs = summaries.map { s in
                Job(
                    id: s.id,
                    type: s.type,
                    url: s.url,
                    name: s.name,
                    state: JobState(rawValue: s.state) ?? .queued,
                    stage: s.stage.flatMap { JobStage(rawValue: $0) },
                    progressHint: s.progressHint,
                    createdAt: ISO8601DateFormatter().date(from: s.createdAt) ?? Date(),
                    updatedAt: ISO8601DateFormatter().date(from: s.updatedAt) ?? Date(),
                    addedTracks: [],
                    navidrome: s.navidrome.map { JobNavidromeStatus(verified: $0.verified, matches: $0.matches) }
                )
            }
            if !serverJobs.isEmpty {
                self.jobs = serverJobs
            }
        } catch {
            print("[AppState] Error fetching jobs: \(error.localizedDescription)")
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
            var loaded = config
            if let token = keychain.load() {
                loaded.bearerToken = token
            }
            self.serverConfig = loaded
        } else if let token = keychain.load() {
            self.serverConfig.bearerToken = token
        }
    }
    
    public func saveConfig() {
        if !serverConfig.bearerToken.isEmpty {
            keychain.save(serverConfig.bearerToken)
        }
        var toSave = serverConfig
        toSave.bearerToken = ""
        if let data = try? JSONEncoder().encode(toSave) {
            UserDefaults.standard.set(data, forKey: "MusicLab.ServerConfig")
        }
        showToast("Settings saved")
    }
}
