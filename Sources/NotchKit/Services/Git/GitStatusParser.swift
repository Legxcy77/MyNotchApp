import Foundation

public struct GitStatus: Equatable, Sendable {
    public var repoRoot: String
    public var repoName: String
    public var branch: String
    public var dirtyCount: Int
    public var ahead: Int
    public var behind: Int

    public init(repoRoot: String, repoName: String, branch: String, dirtyCount: Int, ahead: Int, behind: Int) {
        self.repoRoot = repoRoot
        self.repoName = repoName
        self.branch = branch
        self.dirtyCount = dirtyCount
        self.ahead = ahead
        self.behind = behind
    }
}

public enum GitStatusParser {
    public static func parsePorcelainV2(_ output: String, repoRoot: String) -> GitStatus? {
        var branch = "(detached)"
        var ahead = 0
        var behind = 0
        var dirty = 0

        for line in output.split(whereSeparator: \.isNewline) {
            if line.hasPrefix("# branch.head ") {
                branch = String(line.dropFirst("# branch.head ".count))
            } else if line.hasPrefix("# branch.ab ") {
                let parts = line.dropFirst("# branch.ab ".count).split(separator: " ")
                for part in parts {
                    if part.hasPrefix("+"), let n = Int(part.dropFirst()) { ahead = n }
                    if part.hasPrefix("-"), let n = Int(part.dropFirst()) { behind = n }
                }
            } else if !line.hasPrefix("#") {
                dirty += 1
            }
        }

        let name = (repoRoot as NSString).lastPathComponent
        return GitStatus(
            repoRoot: repoRoot,
            repoName: name.isEmpty ? repoRoot : name,
            branch: branch,
            dirtyCount: dirty,
            ahead: ahead,
            behind: behind
        )
    }
}
