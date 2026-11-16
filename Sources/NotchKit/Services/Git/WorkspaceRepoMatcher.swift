import Foundation

public enum WorkspaceRepoMatcher {
    public static let defaultSearchRoots: [URL] = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            home,
            home.appendingPathComponent("Projects", isDirectory: true),
            home.appendingPathComponent("Developer", isDirectory: true),
            home.appendingPathComponent("Documents", isDirectory: true),
            home.appendingPathComponent("Desktop", isDirectory: true),
            home.appendingPathComponent("Code", isDirectory: true),
            home.appendingPathComponent("Workspace", isDirectory: true),
            home.appendingPathComponent("src", isDirectory: true)
        ]
    }()

    /// Extracts workspace folder name from IDE window titles like `"keystay — HousekeepingPortalPage.tsx"`.
    public static func workspaceName(fromWindowTitle title: String) -> String? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let separators = [" — ", " - "]
        for sep in separators {
            if let range = trimmed.range(of: sep) {
                let candidate = String(trimmed[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !candidate.isEmpty, !candidate.contains("/") {
                    return candidate
                }
            }
        }
        return nil
    }

    /// Finds a git repository matching `workspaceName` inside `searchRoots`.
    public static func findGitRepo(named workspaceName: String, in searchRoots: [URL] = defaultSearchRoots) -> String? {
        let fm = FileManager.default
        for root in searchRoots {
            let candidate = root.appendingPathComponent(workspaceName, isDirectory: true)
            let gitDir = candidate.appendingPathComponent(".git")
            if fm.fileExists(atPath: gitDir.path) {
                return candidate.path
            }
        }
        return nil
    }
}
