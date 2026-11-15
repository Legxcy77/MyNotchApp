import Foundation

public struct PullRequestPulse: Equatable, Sendable, Identifiable {
    public enum ChecksState: String, Equatable, Sendable {
        case passing
        case failing
        case pending
        case unknown
    }

    public let id: String
    public let repo: String
    public let number: Int
    public let title: String
    public let url: URL
    public let isReviewRequest: Bool
    public var checksState: ChecksState

    public init(
        repo: String,
        number: Int,
        title: String,
        url: URL,
        isReviewRequest: Bool,
        checksState: ChecksState = .unknown
    ) {
        self.id = url.absoluteString
        self.repo = repo
        self.number = number
        self.title = title
        self.url = url
        self.isReviewRequest = isReviewRequest
        self.checksState = checksState
    }
}

public enum GitHubPulseParser {
    private struct SearchResponse: Decodable {
        struct Item: Decodable {
            let number: Int
            let title: String
            let html_url: String
            let repository_url: String?
        }
        let items: [Item]
    }

    public static func parseSearchItems(_ data: Data, isReviewRequest: Bool) -> [PullRequestPulse] {
        guard let decoded = try? JSONDecoder().decode(SearchResponse.self, from: data) else {
            return []
        }
        return decoded.items.compactMap { item in
            guard let url = URL(string: item.html_url) else { return nil }
            let repo = extractRepo(from: item.repository_url) ?? ""
            return PullRequestPulse(
                repo: repo,
                number: item.number,
                title: item.title,
                url: url,
                isReviewRequest: isReviewRequest
            )
        }
    }

    public static func diffTransitions(previous: [PullRequestPulse], current: [PullRequestPulse]) -> [PullRequestPulse] {
        let prevByID = Dictionary(uniqueKeysWithValues: previous.map { ($0.id, $0) })
        return current.filter { pr in
            guard let old = prevByID[pr.id] else {
                return pr.isReviewRequest
            }
            return old.checksState != pr.checksState
        }
    }

    private static func extractRepo(from repositoryURL: String?) -> String? {
        guard let repositoryURL else { return nil }
        let parts = repositoryURL.split(separator: "/")
        guard parts.count >= 2 else { return nil }
        return "\(parts[parts.count - 2])/\(parts[parts.count - 1])"
    }
}

