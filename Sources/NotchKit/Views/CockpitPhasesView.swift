import SwiftUI

enum CockpitPhaseSection: String, CaseIterable, Identifiable {
    case release = "Release"
    case impact = "Impact"
    case docker = "Docker"
    case ci = "CI"
    case database = "DB"
    case securityEnv = "Sec/Env"

    var id: String { rawValue }
}

struct CockpitPhasesInspectorView: View {
    let releaseReadiness: ReleaseReadinessReport?
    let changeImpact: ChangeImpactReport?
    let dockerContainers: [DockerContainer]
    let ciRuns: [CIRunRecord]
    let databaseReport: DatabaseHealthReport?
    let dependencyFindings: [DependencyFinding]
    let envGuardReport: EnvGuardReport?

    @State private var selectedSection: CockpitPhaseSection = .release

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(CockpitPhaseSection.allCases) { section in
                        Button {
                            selectedSection = section
                        } label: {
                            Text(section.rawValue)
                                .font(.system(size: 10, weight: selectedSection == section ? .semibold : .medium))
                                .foregroundStyle(.white.opacity(selectedSection == section ? 0.95 : 0.55))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    selectedSection == section ? .white.opacity(0.16) : .white.opacity(0.06),
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 6) {
                    switch selectedSection {
                    case .release:
                        releaseSection
                    case .impact:
                        impactSection
                    case .docker:
                        dockerSection
                    case .ci:
                        ciSection
                    case .database:
                        databaseSection
                    case .securityEnv:
                        securityEnvSection
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    @ViewBuilder
    private var releaseSection: some View {
        if let report = releaseReadiness {
            ForEach(report.checks) { item in
                let tint: Color = switch item.state {
                case .passed: Toast.Tint.success.color
                case .warning: Toast.Tint.waiting.color
                case .blocked: Toast.Tint.failure.color
                case .unknown: .white.opacity(0.45)
                }
                HStack(spacing: 6) {
                    Circle().fill(tint).frame(width: 6, height: 6)
                    Text(item.title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                    Spacer(minLength: 4)
                    Text(item.detail)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
            }
        } else {
            emptyState("No release gates evaluated yet. Open a git repo or run a build.")
        }
    }

    @ViewBuilder
    private var impactSection: some View {
        if let impact = changeImpact, !impact.changedFiles.isEmpty {
            HStack(spacing: 6) {
                Text("RISK: \(impact.riskLevel.rawValue.uppercased())")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(impact.riskLevel >= .high ? Toast.Tint.failure.color : Toast.Tint.waiting.color)
                Text("· \(impact.changedFiles.count) changed")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.white.opacity(0.6))
            }
            ForEach(impact.impacts.prefix(5)) { item in
                let isDirect = item.kind == .direct
                let kindColor: Color = isDirect ? Toast.Tint.info.color : .white.opacity(0.5)
                HStack(spacing: 6) {
                    Text(isDirect ? "DIRECT" : "INFER")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(kindColor)
                    Text(item.path)
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(item.reason)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.white.opacity(0.45))
                        .lineLimit(1)
                }
            }
            if !impact.suggestedTests.isEmpty {
                Text("Suggested: \(impact.suggestedTests.map(\.name).joined(separator: ", "))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Toast.Tint.success.color.opacity(0.9))
                    .lineLimit(2)
            }
        } else {
            emptyState("Working tree is clean. No changed files detected.")
        }
    }

    @ViewBuilder
    private var dockerSection: some View {
        let engine: DockerEngineAvailability = dockerContainers.isEmpty ? .unknown : .available
        let summary = ServiceHealthInspector.evaluate(containers: dockerContainers, engineAvailability: engine)
        if summary.services.isEmpty {
            emptyState("No running or inspected Docker containers.")
        } else {
            ForEach(summary.services) { svc in
                let tint: Color = switch svc.state {
                case .running: Toast.Tint.success.color
                case .stopped: .white.opacity(0.45)
                case .crashed, .unhealthy: Toast.Tint.failure.color
                case .restarting, .unknown: Toast.Tint.waiting.color
                }
                HStack(spacing: 6) {
                    Circle().fill(tint).frame(width: 6, height: 6)
                    Text(svc.name)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                    Text(svc.state.rawValue)
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(tint)
                    Spacer(minLength: 4)
                    if let dep = svc.affectedDependency {
                        Text("dep: \(dep)")
                            .font(.system(size: 9.5, design: .monospaced))
                            .foregroundStyle(Toast.Tint.waiting.color)
                    } else if let port = svc.exposedPorts.first {
                        Text(port)
                            .font(.system(size: 9.5, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.45))
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var ciSection: some View {
        if ciRuns.isEmpty {
            emptyState("No CI runs synced. Push updates via Event Bus POST /ci.")
        } else {
            ForEach(ciRuns.prefix(5)) { run in
                let tint: Color = switch run.status {
                case .success: Toast.Tint.success.color
                case .failure, .connectionError: Toast.Tint.failure.color
                case .queued, .inProgress, .cancelled: Toast.Tint.waiting.color
                case .unknown: .white.opacity(0.45)
                }
                HStack(spacing: 6) {
                    Circle().fill(tint).frame(width: 6, height: 6)
                    Text(run.workflow)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                    Text(run.branch)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                    Spacer(minLength: 4)
                    Text(run.commitSHA)
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
                    Text(run.isLive ? "LIVE" : "CACHED")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(run.isLive ? Toast.Tint.success.color : .white.opacity(0.4))
                }
            }
        }
    }

    @ViewBuilder
    private var databaseSection: some View {
        if let db = databaseReport {
            HStack(spacing: 6) {
                Text(db.engine)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Text("(\(db.environment))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                switch db.migrationStatus {
                case .upToDate:
                    Text("Up to date")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Toast.Tint.success.color)
                case .pending(let count, let files):
                    Text("\(count) pending: \(files.prefix(2).joined(separator: ", "))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Toast.Tint.waiting.color)
                        .lineLimit(1)
                case .failed(let reason):
                    Text("Failed: \(reason)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Toast.Tint.failure.color)
                        .lineLimit(1)
                case .schemaDrift(let detail):
                    Text("Drift: \(detail)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Toast.Tint.waiting.color)
                        .lineLimit(1)
                case .unknown:
                    Text("Migration status unknown")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
        } else {
            emptyState("No local database migration directory detected.")
        }
    }

    @ViewBuilder
    private var securityEnvSection: some View {
        if let env = envGuardReport {
            HStack(spacing: 6) {
                Image(systemName: env.isHealthy ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                    .font(.system(size: 10.5))
                    .foregroundStyle(env.isHealthy ? Toast.Tint.success.color : Toast.Tint.waiting.color)
                Text(env.isHealthy ? ".env keys in sync" : "Missing keys: \(env.missingKeys.joined(separator: ", "))")
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(2)
            }
        } else {
            emptyState("No .env.example found in active repo.")
        }

        if !dependencyFindings.isEmpty {
            ForEach(dependencyFindings.prefix(4)) { finding in
                HStack(spacing: 6) {
                    Text(finding.severity.rawValue.uppercased())
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(finding.severity >= .high ? Toast.Tint.failure.color : Toast.Tint.waiting.color)
                    Text("\(finding.packageName) (\(finding.version))")
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                    Spacer()
                    Text(finding.advisorySource)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
        }
    }

    private func emptyState(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(.white.opacity(0.45))
    }
}
