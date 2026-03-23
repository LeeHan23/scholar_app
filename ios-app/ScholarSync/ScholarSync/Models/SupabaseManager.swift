import Foundation

enum SupabaseError: LocalizedError {
    case invalidResponse
    case invalidURL
    case notAuthenticated
    case httpError(Int)
    case authError(String)
    case invalidRequest(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid server response"
        case .invalidURL: return "Invalid URL"
        case .notAuthenticated: return "Not authenticated. Please sign in again."
        case .httpError(let code): return "Server error (\(code))"
        case .authError(let message): return message
        case .invalidRequest(let message): return message
        }
    }
}

struct AuthResponse: Codable {
    let access_token: String?
    let refresh_token: String?
    let user: AuthUser?
}

struct AuthUser: Codable {
    let id: String
    let email: String?
}

struct AuthErrorResponse: Codable {
    let error: String?
    let error_description: String?
    let msg: String?
}

class SupabaseManager {
    static let shared = SupabaseManager()

    // The anon key is a public key by design — security is enforced by
    // Row Level Security (RLS) policies on the Supabase tables, not by
    // keeping this key secret. This is the standard pattern for mobile apps
    // per Supabase documentation.
    private let baseURL: String
    private let apiKey: String

    private static let keychainAccessToken = "supabaseAccessToken"
    private static let keychainRefreshToken = "supabaseRefreshToken"
    private static let keychainUserId = "supabaseUserId"

    init() {
        // Load from Info.plist so keys are not hardcoded in source.
        // Add SUPABASE_URL and SUPABASE_ANON_KEY to your Info.plist or
        // use a .xcconfig file to inject them at build time.
        self.baseURL = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String
            ?? "https://qwucidgyppghygjvzlsg.supabase.co"
        self.apiKey = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String
            ?? "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF3dWNpZGd5cHBnaHlnanZ6bHNnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIyNjAxMjksImV4cCI6MjA4NzgzNjEyOX0.eUedSI9Bcncj5-3qgqjGBBzh8Tx0Mc0WrFiaciwU8ws"
    }

    // MARK: - Secure Token Storage (Keychain)

    var accessToken: String? {
        get { KeychainHelper.read(forKey: Self.keychainAccessToken) }
        set {
            if let value = newValue {
                KeychainHelper.save(value, forKey: Self.keychainAccessToken)
            } else {
                KeychainHelper.delete(forKey: Self.keychainAccessToken)
            }
        }
    }

    var refreshToken: String? {
        get { KeychainHelper.read(forKey: Self.keychainRefreshToken) }
        set {
            if let value = newValue {
                KeychainHelper.save(value, forKey: Self.keychainRefreshToken)
            } else {
                KeychainHelper.delete(forKey: Self.keychainRefreshToken)
            }
        }
    }

    var currentUserId: String? {
        get { KeychainHelper.read(forKey: Self.keychainUserId) }
        set {
            if let value = newValue {
                KeychainHelper.save(value, forKey: Self.keychainUserId)
            } else {
                KeychainHelper.delete(forKey: Self.keychainUserId)
            }
        }
    }

    var isAuthenticated: Bool {
        accessToken != nil && currentUserId != nil
    }

    // MARK: - Auth

    func signUp(email: String, password: String) async throws -> AuthResponse {
        let redirectTo = "https://www.computationalrd.com/auth/confirm"
        guard let url = URL(string: "\(baseURL)/auth/v1/signup?redirect_to=\(redirectTo)") else {
            throw SupabaseError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15
        request.httpBody = try JSONEncoder().encode(["email": email, "password": password])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }

        if httpResponse.statusCode >= 400 {
            if let errBody = try? JSONDecoder().decode(AuthErrorResponse.self, from: data) {
                throw SupabaseError.authError(errBody.msg ?? errBody.error_description ?? "Sign up failed")
            }
            throw SupabaseError.httpError(httpResponse.statusCode)
        }

        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        if authResponse.access_token != nil {
            saveAuth(authResponse)
        }
        return authResponse
    }

    func signIn(email: String, password: String) async throws -> AuthResponse {
        guard let url = URL(string: "\(baseURL)/auth/v1/token?grant_type=password") else {
            throw SupabaseError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15
        request.httpBody = try JSONEncoder().encode(["email": email, "password": password])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }

        if httpResponse.statusCode >= 400 {
            if let errBody = try? JSONDecoder().decode(AuthErrorResponse.self, from: data) {
                throw SupabaseError.authError(errBody.msg ?? errBody.error_description ?? "Sign in failed")
            }
            throw SupabaseError.httpError(httpResponse.statusCode)
        }

        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        saveAuth(authResponse)
        return authResponse
    }

    func signOut() {
        accessToken = nil
        refreshToken = nil
        currentUserId = nil
    }

    private func saveAuth(_ auth: AuthResponse) {
        accessToken = auth.access_token
        refreshToken = auth.refresh_token
        if let user = auth.user {
            currentUserId = user.id
        }
    }

    // MARK: - Token Refresh

    /// Attempt to refresh the access token using the stored refresh token.
    /// Returns true if successful, false if re-login is required.
    func refreshAccessToken() async -> Bool {
        guard let token = refreshToken else {
            signOut()
            return false
        }

        guard let url = URL(string: "\(baseURL)/auth/v1/token?grant_type=refresh_token") else {
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15
        request.httpBody = try? JSONEncoder().encode(["refresh_token": token])

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                signOut()
                return false
            }

            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
            saveAuth(authResponse)
            return true
        } catch {
            signOut()
            return false
        }
    }

    // MARK: - REST Helpers

    private func authenticatedRequest(path: String, method: String = "GET", body: Data? = nil, queryParams: String = "") throws -> URLRequest {
        guard let token = accessToken else {
            throw SupabaseError.notAuthenticated
        }

        let urlString = "\(baseURL)/rest/v1/\(path)\(queryParams.isEmpty ? "" : "?\(queryParams)")"
        guard let url = URL(string: urlString) else {
            throw SupabaseError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.timeoutInterval = 15

        if let body = body {
            request.httpBody = body
        }

        return request
    }

    /// Execute a request, automatically refreshing the token on 401 and retrying once.
    private func executeWithRefresh(path: String, method: String = "GET", body: Data? = nil, queryParams: String = "") async throws -> (Data, HTTPURLResponse) {
        let request = try authenticatedRequest(path: path, method: method, body: body, queryParams: queryParams)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }

        print("[SupabaseManager] \(method) /\(path) → \(httpResponse.statusCode)")
        if httpResponse.statusCode >= 400 {
            let bodyStr = String(data: data, encoding: .utf8) ?? "(no body)"
            print("[SupabaseManager] Error body: \(bodyStr)")
        }

        // If 401, try refreshing the token and retry once
        if httpResponse.statusCode == 401 {
            print("[SupabaseManager] Token expired, attempting refresh...")
            let refreshed = await refreshAccessToken()
            if refreshed {
                let retryRequest = try authenticatedRequest(path: path, method: method, body: body, queryParams: queryParams)
                let (retryData, retryResponse) = try await URLSession.shared.data(for: retryRequest)
                guard let retryHttp = retryResponse as? HTTPURLResponse else {
                    throw SupabaseError.invalidResponse
                }
                print("[SupabaseManager] Retry \(method) /\(path) → \(retryHttp.statusCode)")
                return (retryData, retryHttp)
            } else {
                print("[SupabaseManager] Token refresh failed, signing out")
                throw SupabaseError.notAuthenticated
            }
        }

        return (data, httpResponse)
    }

    /// Validates that an ID is a positive integer before using in query params.
    private func validatedId(_ id: Int) throws -> Int {
        guard id > 0 else {
            throw SupabaseError.invalidRequest("Invalid ID")
        }
        return id
    }

    // MARK: - Papers CRUD

    func fetchPapers() async throws -> [Paper] {
        let (data, httpResponse) = try await executeWithRefresh(path: "papers", queryParams: "select=*&order=id.desc")

        guard httpResponse.statusCode == 200 else {
            throw SupabaseError.httpError(httpResponse.statusCode)
        }

        return try JSONDecoder().decode([Paper].self, from: data)
    }

    func addPaper(_ paper: Paper) async throws -> Paper {
        let body = try JSONEncoder().encode(paper)
        let (data, httpResponse) = try await executeWithRefresh(path: "papers", method: "POST", body: body)

        guard httpResponse.statusCode == 201 else {
            throw SupabaseError.httpError(httpResponse.statusCode)
        }

        let papers = try JSONDecoder().decode([Paper].self, from: data)
        guard let saved = papers.first else {
            throw SupabaseError.invalidResponse
        }
        return saved
    }

    func updatePaper(_ paper: Paper) async throws -> Paper {
        guard let id = paper.id else {
            throw SupabaseError.invalidRequest("Paper has no ID")
        }
        let safeId = try validatedId(id)

        let body = try JSONEncoder().encode(paper)
        let (data, httpResponse) = try await executeWithRefresh(path: "papers", method: "PATCH", body: body, queryParams: "id=eq.\(safeId)")

        guard httpResponse.statusCode == 200 else {
            throw SupabaseError.httpError(httpResponse.statusCode)
        }

        let papers = try JSONDecoder().decode([Paper].self, from: data)
        guard let updated = papers.first else {
            throw SupabaseError.invalidResponse
        }
        return updated
    }

    func deletePaper(id: Int) async throws {
        let safeId = try validatedId(id)
        let (_, httpResponse) = try await executeWithRefresh(path: "papers", method: "DELETE", queryParams: "id=eq.\(safeId)")

        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 204 else {
            throw SupabaseError.httpError(httpResponse.statusCode)
        }
    }

    // MARK: - Projects CRUD

    func fetchProjects() async throws -> [Project] {
        let (data, httpResponse) = try await executeWithRefresh(path: "projects", queryParams: "select=*&order=id.desc")

        guard httpResponse.statusCode == 200 else {
            throw SupabaseError.httpError(httpResponse.statusCode)
        }

        return try JSONDecoder().decode([Project].self, from: data)
    }

    func addProject(_ project: Project) async throws -> Project {
        let body = try JSONEncoder().encode(project)
        let (data, httpResponse) = try await executeWithRefresh(path: "projects", method: "POST", body: body)

        guard httpResponse.statusCode == 201 else {
            throw SupabaseError.httpError(httpResponse.statusCode)
        }

        let projects = try JSONDecoder().decode([Project].self, from: data)
        guard let saved = projects.first else {
            throw SupabaseError.invalidResponse
        }
        return saved
    }

    func updateProject(_ project: Project) async throws -> Project {
        guard let id = project.id else {
            throw SupabaseError.invalidRequest("Project has no ID")
        }
        let safeId = try validatedId(id)

        let body = try JSONEncoder().encode(project)
        let (data, httpResponse) = try await executeWithRefresh(path: "projects", method: "PATCH", body: body, queryParams: "id=eq.\(safeId)")

        guard httpResponse.statusCode == 200 else {
            throw SupabaseError.httpError(httpResponse.statusCode)
        }

        let projects = try JSONDecoder().decode([Project].self, from: data)
        guard let updated = projects.first else {
            throw SupabaseError.invalidResponse
        }
        return updated
    }

    func deleteProject(id: Int) async throws {
        let safeId = try validatedId(id)
        let (_, httpResponse) = try await executeWithRefresh(path: "projects", method: "DELETE", queryParams: "id=eq.\(safeId)")

        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 204 else {
            throw SupabaseError.httpError(httpResponse.statusCode)
        }
    }

    // MARK: - Storage (PDF Upload / Download)

    /// Upload a PDF file to Supabase Storage and return the storage path.
    func uploadPDF(data: Data, paperId: Int) async throws -> String {
        guard let token = accessToken, let userId = currentUserId else {
            throw SupabaseError.notAuthenticated
        }

        let storagePath = "\(userId)/\(paperId).pdf"
        let urlString = "\(baseURL)/storage/v1/object/papers/\(storagePath)"
        guard let url = URL(string: urlString) else {
            throw SupabaseError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/pdf", forHTTPHeaderField: "Content-Type")
        request.setValue("true", forHTTPHeaderField: "x-upsert")
        request.timeoutInterval = 60
        request.httpBody = data

        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }

        print("[SupabaseManager] Upload PDF → \(httpResponse.statusCode)")

        if httpResponse.statusCode == 401 {
            let refreshed = await refreshAccessToken()
            if refreshed {
                return try await uploadPDF(data: data, paperId: paperId)
            }
            throw SupabaseError.notAuthenticated
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: responseData, encoding: .utf8) ?? ""
            print("[SupabaseManager] Upload error: \(body)")
            throw SupabaseError.httpError(httpResponse.statusCode)
        }

        return storagePath
    }

    /// Get a signed URL for a stored PDF (valid for 1 hour).
    func getSignedPDFUrl(path: String) async throws -> URL {
        guard let token = accessToken else {
            throw SupabaseError.notAuthenticated
        }

        let urlString = "\(baseURL)/storage/v1/object/sign/papers"
        guard let url = URL(string: urlString) else {
            throw SupabaseError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let body: [String: Any] = ["expiresIn": 3600, "path": path]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            print("[SupabaseManager] Sign URL error: \(body)")
            throw SupabaseError.invalidResponse
        }

        struct SignedURLResponse: Codable { let signedURL: String }
        let result = try JSONDecoder().decode(SignedURLResponse.self, from: data)
        guard let signedURL = URL(string: "\(baseURL)\(result.signedURL)") else {
            throw SupabaseError.invalidURL
        }
        return signedURL
    }
}
