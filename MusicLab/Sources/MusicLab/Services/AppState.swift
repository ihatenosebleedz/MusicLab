import SwiftUI
import Combine
import MusicLabCore
#if canImport(UserNotifications)
import UserNotifications
#endif

public struct ArtistPromptData: Identifiable, Sendable {
    public let id: String
    public let name: String
    
    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

public enum AppTab: Int, CaseIterable, Identifiable {
    case search = 0
    case queue = 1
    case library = 2
    case settings = 3
    
    public var id: Int { rawValue }
    
    public var title: String {
        switch self {
        
        case .search: return "Download"
        case .queue: return "Queue"
        case .library: return "Library"
        case .settings: return "Settings"
        }
    }
    
    public var iconName: String {
        switch self {
        
        case .search: return "arrow.down.circle"
        case .queue: return "list.bullet"
        case .library: return "music.note.list"
        case .settings: return "gearshape"
        }
    }
}

@MainActor
public final class AppState: ObservableObject {
    @Published public var selectedTab: AppTab = .search
    @Published public var jobs: [Job] = []
    @Published public var isLoadingJobs: Bool = false
    @Published public var serverConfig: ServerConfig = .default
    @Published public var isServerOnline: Bool = false
    @Published public var isCheckingServer: Bool = false
    @Published public var serverStatusMessage: String = "Not connected"
    @Published public var isSubmitting: Bool = false
    /// Import destinations advertised by the server (`GET /destinations`).
    @Published public var destinations: [BackendDestination] = []
    /// The destination id imports should use. `nil` => server default.
    @Published public var selectedDestinationId: String? = nil
    private let keychain = KeychainService()
    private var pollTimer: Timer?
    private var dismissedJobIds: Set<String> = []
    
    // Notifications & Artist sheet
    @Published public var notifyOnCompletion: Bool = false
    @Published public var artistPromptItem: ArtistPromptData? = nil
    private var notifiedJobIds: Set<String> = []
    private var previousJobStates: [String: JobState] = [:]
    
    // Search state
    @Published public var searchQuery: String = ""
    @Published public var selectedCatalogFilter: CatalogType? = nil
    @Published public var searchResults: [CatalogItem] = []
    @Published public var isSearching: Bool = false
    @Published public var searchErrorMessage: String? = nil
    private let searchDebouncer = SearchDebouncer()
    
    public enum ToastKind: Sendable {
        case success, error, info
    }
    @Published public var importFeedbackToast: String? = nil
    @Published public var importFeedbackKind: ToastKind = .success
    
    // Onboarding
    @Published public var hasCompletedOnboarding: Bool = false
    
    /// User-selected accent theme (drives `Theme.accent` app-wide).
    @Published public var accentOption: AccentOption = .musicRed
    
    private enum DefaultsKey {
        static let serverConfig = "MusicLab.ServerConfig"
        static let onboardingComplete = "MusicLab.OnboardingComplete"
        static let accent = "MusicLab.Accent"
        static let destination = "MusicLab.Destination"
        static let notifyOnCompletion = "MusicLab.NotifyOnCompletion"
    }
    
    public let authService = AppleMusicAuthService.shared
    internal let musicClient = AppleMusicClient()
    private let backendClient = BackendClient()
    
    public init() {
        // Load saved settings if any
        loadAccent()
        loadDestination()
        loadNotificationPreference()
        loadSavedConfig()
        testServerConnection()
        startPolling()
    }
    
    /// Applies the persisted accent so `Theme.accent` is correct before first render.
    private func loadAccent() {
        if let raw = UserDefaults.standard.string(forKey: DefaultsKey.accent),
           let option = AccentOption(rawValue: raw) {
            accentOption = option
        } else {
            accentOption = .musicRed
        }
        Theme.currentAccent = accentOption
    }
    
    /// Selects an accent, applies it app-wide, and persists the choice.
    public func setAccent(_ option: AccentOption) {
        guard option != accentOption else { return }
        accentOption = option
        Theme.currentAccent = option
        UserDefaults.standard.set(option.rawValue, forKey: DefaultsKey.accent)
    }
    
    /// The human-readable label for the current destination choice.
    public var selectedDestinationLabel: String {
        guard let id = selectedDestinationId else {
            return destinations.first(where: { $0.isDefault })?.id ?? "Server default"
        }
        return id
    }
    
    /// Loads the persisted destination choice (`nil` = server default).
    private func loadDestination() {
        selectedDestinationId = UserDefaults.standard.string(forKey: DefaultsKey.destination)
    }
    
    /// Persists the destination choice. Pass `nil` to use the server default.
    public func setDestination(_ id: String?) {
        selectedDestinationId = id
        if let id {
            UserDefaults.standard.set(id, forKey: DefaultsKey.destination)
        } else {
            UserDefaults.standard.removeObject(forKey: DefaultsKey.destination)
        }
    }
    
    /// Loads the persisted notification preference.
    private func loadNotificationPreference() {
        notifyOnCompletion = UserDefaults.standard.bool(forKey: DefaultsKey.notifyOnCompletion)
    }
    
    /// Toggles download completion notifications, requesting iOS permission if needed.
    public func setNotifyOnCompletion(_ enabled: Bool) {
        if enabled {
            #if canImport(UserNotifications)
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
                Task { @MainActor in
                    self?.notifyOnCompletion = granted
                    UserDefaults.standard.set(granted, forKey: DefaultsKey.notifyOnCompletion)
                    if !granted {
                        self?.showToast("Notifications not permitted in iOS Settings", kind: .info)
                    }
                }
            }
            #else
            notifyOnCompletion = enabled
            UserDefaults.standard.set(enabled, forKey: DefaultsKey.notifyOnCompletion)
            #endif
        } else {
            notifyOnCompletion = false
            UserDefaults.standard.set(false, forKey: DefaultsKey.notifyOnCompletion)
        }
    }
    
    /// Fetches the server's destinations so Settings/imports can offer them.
    public func loadDestinations() async {
        guard isServerOnline, !serverConfig.bearerToken.isEmpty else { return }
        do {
            let response = try await backendClient.fetchDestinations(
                baseUrl: serverConfig.backendUrl,
                token: serverConfig.bearerToken
            )
            self.destinations = response.destinations
            // Drop a stale persisted choice that the server no longer knows.
            if let current = selectedDestinationId,
               !response.destinations.contains(where: { $0.id == current }) {
                setDestination(nil)
            }
        } catch {
            print("[AppState] Error fetching destinations: \(error.localizedDescription)")
        }
    }
    
    private func startPolling() {
        Task { [weak self] in
            while true {
                // Poll faster while downloads are active so progress/ETA feel live.
                let seconds = (self?.activeJobsCount ?? 0) > 0 ? 1 : 3
                try? await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
                if let self = self, self.isServerOnline {
                    await self.refreshJobsFromBackend()
                }
            }
        }
    }

    public var activeJobsCount: Int {
        jobs.filter { $0.state.isActive }.count
    }
    
    public func submitImport(item: CatalogItem) {
        guard !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        guard isServerOnline, !serverConfig.bearerToken.isEmpty else {
            showToast("Server offline — connect in Settings to import", kind: .info)
            return
        }
        Task {
            do {
                _ = try await backendClient.submitJob(
                    baseUrl: serverConfig.backendUrl,
                    token: serverConfig.bearerToken,
                    appleMusicUrl: item.appleMusicUrl,
                    name: "\(item.artistName) — \(item.title)",
                    destinationId: selectedDestinationId
                )
                await self.refreshJobsFromBackend()
                self.showToast("Submitted '\(item.title)' to server")
            } catch {
                self.showToast("Submission failed: \(error.localizedDescription)", kind: .error)
            }
        }
    }
    
    /// Queues multiple albums/items in batch (e.g. for downloading all of an artist's discography).
    public func submitBatchImports(items: [CatalogItem]) {
        guard !items.isEmpty else { return }
        guard isServerOnline, !serverConfig.bearerToken.isEmpty else {
            showToast("Server offline — connect in Settings to import", kind: .info)
            return
        }
        Task {
            var queuedCount = 0
            for item in items {
                do {
                    _ = try await backendClient.submitJob(
                        baseUrl: serverConfig.backendUrl,
                        token: serverConfig.bearerToken,
                        appleMusicUrl: item.appleMusicUrl,
                        name: "\(item.artistName) — \(item.title)",
                        destinationId: selectedDestinationId
                    )
                    queuedCount += 1
                } catch {
                    print("[AppState] Failed to queue '\(item.title)': \(error.localizedDescription)")
                }
            }
            await self.refreshJobsFromBackend()
            self.showToast("Queued \(queuedCount) albums for download")
        }
    }
    
    public func submitUrlImport(url: String) {
        guard !isSubmitting else { return }
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        
        do {
            let parsed = try AppleMusicURL.parse(trimmed)
            let typeName = parsed.effectiveResourceType.rawValue
            
            if parsed.effectiveResourceType == .artist {
                let rawName = parsed.slug?.replacingOccurrences(of: "-", with: " ").capitalized ?? "Artist \(parsed.effectiveIdentifier)"
                self.artistPromptItem = ArtistPromptData(id: parsed.effectiveIdentifier, name: rawName)
                return
            }
            
            let label = parsed.slug?.replacingOccurrences(of: "-", with: " ").capitalized ?? "Item \(parsed.effectiveIdentifier)"
            let itemName = "\(typeName.capitalized): \(label)"
            
            guard isServerOnline, !serverConfig.bearerToken.isEmpty else {
                showToast("Server offline — connect in Settings to import this \(typeName)", kind: .info)
                return
            }
            
            Task {
                do {
                    _ = try await backendClient.submitJob(
                        baseUrl: serverConfig.backendUrl,
                        token: serverConfig.bearerToken,
                        appleMusicUrl: parsed.originalURL.absoluteString,
                        name: itemName,
                        destinationId: selectedDestinationId
                    )
                    await self.refreshJobsFromBackend()
                    self.showToast("Submitted \(typeName) to server")
                } catch {
                    self.showToast("Server import failed: \(error.localizedDescription)", kind: .error)
                }
            }
        } catch let urlError as AppleMusicURLError {
            showToast("Error: \(urlError.localizedDescription)", kind: .error)
        } catch {
            showToast("Invalid Apple Music URL: \(error.localizedDescription)", kind: .error)
        }
    }
    
    /// Handles incoming deep links (e.g. musiclab://import?url=...) from Shortcuts or the Share Sheet.
    public func handleIncomingURL(_ url: URL) {
        guard let deepLink = MusicLabDeepLink.parse(url) else {
            showToast("Unrecognized deep link", kind: .error)
            return
        }
        
        switch deepLink {
        case .importURL(let appleMusicUrl):
            Task { @MainActor in
                if !self.isServerOnline && !self.serverConfig.backendUrl.isEmpty && !self.serverConfig.bearerToken.isEmpty {
                    _ = await self.checkServerConnection()
                }
                if let parsed = try? AppleMusicURL.parse(appleMusicUrl), parsed.effectiveResourceType == .artist {
                    self.submitUrlImport(url: appleMusicUrl)
                } else {
                    self.selectedTab = .queue
                    self.submitUrlImport(url: appleMusicUrl)
                }
            }
        }
    }
    
    /// Immediate search (submit, filter change, explicit action).
    public func performSearch(query: String, filter: CatalogType? = nil) {
        startSearch(query: query, filter: filter, delaySeconds: 0)
    }

    /// Debounced search for keystroke-driven live results.
    public func performSearchDebounced(query: String, filter: CatalogType? = nil) {
        startSearch(query: query, filter: filter, delaySeconds: 0.3)
    }

    private func startSearch(query: String, filter: CatalogType?, delaySeconds: Double) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        // Cancel any in-flight search; this one supersedes it.
        searchDebouncer.cancel()

        guard !trimmed.isEmpty else {
            searchResults = []
            searchErrorMessage = nil
            isSearching = false
            return
        }

        isSearching = true
        searchErrorMessage = nil

        searchDebouncer.schedule(delay: delaySeconds) { [self] in
            await self.runCatalogSearch(trimmed: trimmed, filter: filter)
        }
    }

    /// Runs the actual catalog search on the MainActor. `Task.isCancelled`
    /// reflects the debouncer's task, so a superseded search bails out before
    /// assigning results (preventing stale overwrites).
    private func runCatalogSearch(trimmed: String, filter: CatalogType?) async {
        #if !os(Linux)
        // If filtering by playlist, request Apple Music library access and merge library playlists
        let isPlaylistFilter = (filter == .playlist)
        if isPlaylistFilter {
            let authStatus = await authService.requestAccess()
            if Task.isCancelled { return }
            if authStatus != .authorized {
                searchErrorMessage = "Apple Music access denied. Enable access in Settings > Privacy & Security > Apple Music."
            }
        }

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
                types = [.album, .song, .playlist, .artist]
            }

            let catalogResults = try await musicClient.search(query: trimmed, types: types)
            if Task.isCancelled { return } // a newer search superseded this one

            var merged = catalogResults

            // Merge library playlists if authorized and playlist filter is active
            if isPlaylistFilter, authService.isAuthorized {
                let libraryPlaylists = await authService.searchLibraryPlaylists(term: trimmed)
                if Task.isCancelled { return }
                merged.append(contentsOf: libraryPlaylists)
            }

            searchResults = merged
            isSearching = false
        } catch is CancellationError {
            return // superseded; the newer search owns isSearching
        } catch {
            if Task.isCancelled { return }
            searchResults = []
            searchErrorMessage = "Live catalog lookup unavailable: \(error.localizedDescription)"
            isSearching = false
        }
        #else
        searchResults = []
        searchErrorMessage = "Apple Music catalog search is not available in this build environment."
        isSearching = false
        #endif
    }
    
    public func cancelJob(id: String) {
        guard isServerOnline, !serverConfig.bearerToken.isEmpty else {
            showToast("Server offline — cannot cancel right now", kind: .info)
            return
        }
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
                self.showToast("Failed to cancel job: \(error.localizedDescription)", kind: .error)
            }
        }
    }
    
    public func retryJob(id: String) {
        guard let job = jobs.first(where: { $0.id == id }) else { return }
        guard isServerOnline, !serverConfig.bearerToken.isEmpty else {
            showToast("Server offline — cannot retry right now", kind: .info)
            return
        }
        Task {
            do {
                _ = try await backendClient.submitJob(
                    baseUrl: serverConfig.backendUrl,
                    token: serverConfig.bearerToken,
                    appleMusicUrl: job.url,
                    name: job.name,
                    destinationId: selectedDestinationId
                )
                await self.refreshJobsFromBackend()
                self.showToast("Retry queued as a new job")
            } catch {
                self.showToast("Retry failed: \(error.localizedDescription)", kind: .error)
            }
        }
    }
    
    public func clearCompletedJobs() {
        let toDismiss = jobs.filter { $0.state == .completed || $0.state == .cancelled }
        for j in toDismiss {
            dismissedJobIds.insert(j.id)
        }
        jobs.removeAll { $0.state == .completed || $0.state == .cancelled }
        showToast("Cleared finished jobs")
    }
    
    public func testServerConnection() {
        Task { await self.checkServerConnection() }
    }
    
    /// Checks backend health, updates published status, and persists the config
    /// so anything the user typed is retained. Returns whether the server is
    /// reachable. Runs on the MainActor (inherited).
    @discardableResult
    public func checkServerConnection() async -> Bool {
        isCheckingServer = true
        serverStatusMessage = "Checking \(serverConfig.backendUrl)..."
        
        defer {
            isCheckingServer = false
            persistConfig()
        }
        
        do {
            let health = try await backendClient.checkHealth(baseUrl: serverConfig.backendUrl)
            self.isServerOnline = true
            self.serverConfig.isConnected = true
            self.serverConfig.lastChecked = Date()
            let amdlStatus = health.services?.amdl?.available == true ? "amdl ready" : "amdl unavailable"
            self.serverStatusMessage = "Online (v\(health.version), \(amdlStatus))"
            await self.loadDestinations()
            await self.refreshJobsFromBackend()
            return true
        } catch {
            self.isServerOnline = false
            self.serverConfig.isConnected = false
            self.serverStatusMessage = "Unreachable: \(error.localizedDescription)"
            return false
        }
    }
    
    /// Onboarding action: verify the entered configuration, and only advance
    /// past setup if the backend is actually reachable.
    public func testAndCompleteOnboarding() {
        Task {
            if await self.checkServerConnection() {
                self.completeOnboarding()
            }
        }
    }
    
    public func refreshJobsFromBackend() async {
        guard isServerOnline, !serverConfig.bearerToken.isEmpty else { return }
        if jobs.isEmpty { isLoadingJobs = true }
        defer { isLoadingJobs = false }
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
                    progressPercent: s.progressPercent,
                    progressCompleted: s.progressCompleted,
                    progressTotal: s.progressTotal,
                    etaSeconds: s.etaSeconds,
                    speedText: s.speedText,
                    createdAt: ISO8601DateFormatter().date(from: s.createdAt) ?? Date(),
                    updatedAt: ISO8601DateFormatter().date(from: s.updatedAt) ?? Date(),
                    exitCode: s.exitCode,
                    stdoutTail: s.stdoutTail,
                    stderrTail: s.stderrTail,
                    addedTracks: s.addedTracks?.map { JobAddedTrack(title: $0.title, artist: $0.artist, album: $0.album, path: $0.path) } ?? [],
                    navidrome: s.navidrome.map { JobNavidromeStatus(verified: $0.verified, matches: $0.matches) }
                )
            }
            self.jobs = serverJobs.filter { !self.dismissedJobIds.contains($0.id) }
            
            // Dispatch notification when a download finishes
            if self.notifyOnCompletion {
                for job in serverJobs {
                    let prevState = self.previousJobStates[job.id]
                    if job.state == .completed && prevState != nil && prevState != .completed && !self.notifiedJobIds.contains(job.id) {
                        self.notifiedJobIds.insert(job.id)
                        self.postCompletionNotification(for: job)
                    }
                    self.previousJobStates[job.id] = job.state
                }
            } else {
                for job in serverJobs {
                    self.previousJobStates[job.id] = job.state
                }
            }
        } catch {
            print("[AppState] Error fetching jobs: \(error.localizedDescription)")
        }
    }
    
    private func postCompletionNotification(for job: Job) {
        #if canImport(UserNotifications)
        let content = UNMutableNotificationContent()
        content.title = "Download Complete"
        content.body = "\(job.name) is ready in your library."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: "musiclab-job-\(job.id)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("[AppState] Error scheduling notification: \(error.localizedDescription)")
            }
        }
        #endif
    }
    
    /// Fetches a job's captured amdl output from `GET /logs?jobId=`.
    public func fetchJobLogs(jobId: String, limit: Int = 500) async -> [BackendLogEntry] {
        guard isServerOnline, !serverConfig.bearerToken.isEmpty else { return [] }
        do {
            let response = try await backendClient.fetchLogs(
                baseUrl: serverConfig.backendUrl,
                token: serverConfig.bearerToken,
                jobId: jobId,
                limit: limit
            )
            return response.logs
        } catch {
            print("[AppState] Error fetching logs: \(error.localizedDescription)")
            return []
        }
    }
    
    public func showToast(_ message: String, kind: ToastKind = .success) {
        withAnimation {
            self.importFeedbackToast = message
            self.importFeedbackKind = kind
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
        if let data = UserDefaults.standard.data(forKey: DefaultsKey.serverConfig),
           let config = try? JSONDecoder().decode(ServerConfig.self, from: data) {
            var loaded = config
            if let token = keychain.load() {
                loaded.bearerToken = token
            }
            self.serverConfig = loaded
        } else if let token = keychain.load() {
            self.serverConfig.bearerToken = token
        }
        // Migrate existing configured users straight past onboarding, and honor
        // an explicit completion flag otherwise.
        hasCompletedOnboarding =
            UserDefaults.standard.bool(forKey: DefaultsKey.onboardingComplete)
            || (!serverConfig.backendUrl.isEmpty && !serverConfig.bearerToken.isEmpty)
    }
    
    /// Persists the current config: token to the keychain, the rest to
    /// UserDefaults (never the token). Safe to call repeatedly; no toast.
    private func persistConfig() {
        if !serverConfig.bearerToken.isEmpty {
            keychain.save(serverConfig.bearerToken)
        }
        var toSave = serverConfig
        toSave.bearerToken = ""
        if let data = try? JSONEncoder().encode(toSave) {
            UserDefaults.standard.set(data, forKey: DefaultsKey.serverConfig)
        }
    }
    
    public func saveConfig() {
        persistConfig()
        showToast("Settings saved")
    }
    
    /// Marks first-run setup complete and persists the entered config.
    public func completeOnboarding() {
        persistConfig()
        UserDefaults.standard.set(true, forKey: DefaultsKey.onboardingComplete)
        hasCompletedOnboarding = true
    }
    
    /// Defers setup: jumps to Settings so the user can configure manually.
    public func skipOnboarding() {
        UserDefaults.standard.set(true, forKey: DefaultsKey.onboardingComplete)
        hasCompletedOnboarding = true
        selectedTab = .settings
    }
}
