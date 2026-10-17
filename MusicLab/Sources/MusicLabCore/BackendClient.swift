import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum BackendClientError: Error, LocalizedError, Sendable {
    case invalidURL
    case unauthorized
    case httpError(statusCode: Int, message: String)
    case decodingError(String)
    case networkError(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid backend URL."
        case .unauthorized:
            return "Unauthorized: Bearer token is invalid or missing."
        case .httpError(let code, let msg):
            return "Backend error (\(code)): \(msg)"
        case .decodingError(let msg):
            return "Failed to parse response: \(msg)"
        case .networkError(let msg):
            return "Network connection error: \(msg)"
        }
    }
}

public actor BackendClient {
    private let session: URLSession
    
    public init(session: URLSession = .shared) {
        self.session = session
    }
    
    public func checkHealth(baseUrl: String) async throws -> BackendHealthResponse {
        let cleanBase = baseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(cleanBase)/health") else {
            throw BackendClientError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0
        
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw BackendClientError.networkError("Non-HTTP response")
        }
        
        guard http.statusCode == 200 else {
            throw BackendClientError.httpError(statusCode: http.statusCode, message: "Health check returned \(http.statusCode)")
        }
        
        do {
            return try JSONDecoder().decode(BackendHealthResponse.self, from: data)
        } catch {
            throw BackendClientError.decodingError(error.localizedDescription)
        }
    }
    
    public func fetchJobs(baseUrl: String, token: String, status: String? = nil) async throws -> [BackendJobSummary] {
        let cleanBase = baseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        var components = URLComponents(string: "\(cleanBase)/jobs")
        if let status = status {
            components?.queryItems = [URLQueryItem(name: "status", value: status)]
        }
        
        guard let url = components?.url else {
            throw BackendClientError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 8.0
        
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw BackendClientError.networkError("Non-HTTP response")
        }
        
        if http.statusCode == 401 {
            throw BackendClientError.unauthorized
        }
        
        guard http.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw BackendClientError.httpError(statusCode: http.statusCode, message: msg)
        }
        
        do {
            let list = try JSONDecoder().decode(JobsListResponse.self, from: data)
            return list.jobs
        } catch {
            throw BackendClientError.decodingError(error.localizedDescription)
        }
    }
    
    public func fetchJob(baseUrl: String, token: String, jobId: String) async throws -> BackendJobDetail {
        let cleanBase = baseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(cleanBase)/jobs/\(jobId)") else {
            throw BackendClientError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 8.0
        
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw BackendClientError.networkError("Non-HTTP response")
        }
        
        if http.statusCode == 401 {
            throw BackendClientError.unauthorized
        }
        
        guard http.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw BackendClientError.httpError(statusCode: http.statusCode, message: msg)
        }
        
        do {
            return try JSONDecoder().decode(BackendJobDetail.self, from: data)
        } catch {
            throw BackendClientError.decodingError(error.localizedDescription)
        }
    }
    
    public func submitJob(baseUrl: String, token: String, appleMusicUrl: String, name: String? = nil, destinationId: String? = nil) async throws -> BackendJobDetail {
        let cleanBase = baseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(cleanBase)/jobs") else {
            throw BackendClientError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10.0
        
        let body = JobSubmissionRequest(url: appleMusicUrl, name: name, destinationId: destinationId)
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw BackendClientError.networkError("Non-HTTP response")
        }
        
        if http.statusCode == 401 {
            throw BackendClientError.unauthorized
        }
        
        guard http.statusCode == 201 else {
            let msg = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw BackendClientError.httpError(statusCode: http.statusCode, message: msg)
        }
        
        do {
            return try JSONDecoder().decode(BackendJobDetail.self, from: data)
        } catch {
            throw BackendClientError.decodingError(error.localizedDescription)
        }
    }
    
    public func cancelJob(baseUrl: String, token: String, jobId: String) async throws -> JobCancelResponse {
        let cleanBase = baseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(cleanBase)/jobs/\(jobId)/cancel") else {
            throw BackendClientError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 8.0
        
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw BackendClientError.networkError("Non-HTTP response")
        }
        
        if http.statusCode == 401 {
            throw BackendClientError.unauthorized
        }
        
        guard http.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw BackendClientError.httpError(statusCode: http.statusCode, message: msg)
        }
        
        do {
            return try JSONDecoder().decode(JobCancelResponse.self, from: data)
        } catch {
            throw BackendClientError.decodingError(error.localizedDescription)
        }
    }
    
    /// Fetches the server's configured import destinations (id + default).
    public func fetchDestinations(baseUrl: String, token: String) async throws -> DestinationsResponse {
        let cleanBase = baseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(cleanBase)/destinations") else {
            throw BackendClientError.invalidURL
        }
        
        let (data, response) = try await session.data(for: authorizedRequest(url: url, token: token))
        guard let http = response as? HTTPURLResponse else {
            throw BackendClientError.networkError("Non-HTTP response")
        }
        if http.statusCode == 401 { throw BackendClientError.unauthorized }
        guard http.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw BackendClientError.httpError(statusCode: http.statusCode, message: msg)
        }
        do {
            return try JSONDecoder().decode(DestinationsResponse.self, from: data)
        } catch {
            throw BackendClientError.decodingError(error.localizedDescription)
        }
    }
    
    /// Fetches backend/job/wrapper logs. When `jobId` is supplied the server
    /// scopes the result to that job's captured amdl output.
    public func fetchLogs(
        baseUrl: String,
        token: String,
        jobId: String? = nil,
        source: String? = nil,
        limit: Int = 500
    ) async throws -> LogsResponse {
        let cleanBase = baseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        var components = URLComponents(string: "\(cleanBase)/logs")!
        var items: [URLQueryItem] = []
        if let jobId { items.append(URLQueryItem(name: "jobId", value: jobId)) }
        if let source { items.append(URLQueryItem(name: "source", value: source)) }
        items.append(URLQueryItem(name: "limit", value: String(limit)))
        components.queryItems = items
        guard let url = components.url else {
            throw BackendClientError.invalidURL
        }
        
        let (data, response) = try await session.data(for: authorizedRequest(url: url, token: token))
        guard let http = response as? HTTPURLResponse else {
            throw BackendClientError.networkError("Non-HTTP response")
        }
        if http.statusCode == 401 { throw BackendClientError.unauthorized }
        guard http.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw BackendClientError.httpError(statusCode: http.statusCode, message: msg)
        }
        do {
            return try JSONDecoder().decode(LogsResponse.self, from: data)
        } catch {
            throw BackendClientError.decodingError(error.localizedDescription)
        }
    }
    
    private func authorizedRequest(url: URL, token: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 8.0
        return request
    }
}
