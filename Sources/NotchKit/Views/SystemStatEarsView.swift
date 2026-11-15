import IOKit.ps
import SwiftUI

public enum EarStatFormatter {
    public static func format(
        kind: EarStatKind,
        pulse: SystemPulseSample?,
        batteryPercent: Int? = nil,
        date: Date = Date()
    ) -> (symbol: String, text: String)? {
        switch kind {
        case .none:
            return nil
        case .cpu:
            let pct = Int((pulse?.cpuPercent ?? 0).rounded())
            return ("cpu", "\(pct)%")
        case .ram:
            let total = max(1.0, pulse?.ramTotalGB ?? 1.0)
            let pct = Int(((pulse?.ramUsedGB ?? 0) / total * 100.0).rounded())
            return ("memorychip", "\(pct)%")
        case .battery:
            let pct = batteryPercent ?? currentBatteryPercent() ?? 100
            return ("battery.75percent", "\(pct)%")
        case .time:
            let f = DateFormatter()
            f.dateFormat = "HH:mm"
            return ("clock", f.string(from: date))
        }
    }

    private static func currentBatteryPercent() -> Int? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef],
              let first = list.first,
              let desc = IOPSGetPowerSourceDescription(info, first)?.takeUnretainedValue() as? [String: Any] else {
            return nil
        }
        let current = desc[kIOPSCurrentCapacityKey] as? Int ?? 0
        let maxCap = max(1, desc[kIOPSMaxCapacityKey] as? Int ?? 100)
        return min(100, max(0, Int((Double(current) / Double(maxCap) * 100.0).rounded())))
    }
}

public struct SystemStatEarsView: View {
    let notchWidth: CGFloat
    let leftStat: EarStatKind
    let rightStat: EarStatKind
    let pulse: SystemPulseSample?

    public init(
        notchWidth: CGFloat,
        leftStat: EarStatKind,
        rightStat: EarStatKind,
        pulse: SystemPulseSample?
    ) {
        self.notchWidth = notchWidth
        self.leftStat = leftStat
        self.rightStat = rightStat
        self.pulse = pulse
    }

    public var body: some View {
        HStack(spacing: 0) {
            earPill(kind: leftStat)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 4)

            Spacer()
                .frame(width: notchWidth)

            earPill(kind: rightStat)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 4)
        }
        .frame(height: 32)
    }

    @ViewBuilder
    private func earPill(kind: EarStatKind) -> some View {
        if let item = EarStatFormatter.format(kind: kind, pulse: pulse) {
            HStack(spacing: 2) {
                Image(systemName: item.symbol)
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.72))
                Text(item.text)
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
    }
}

