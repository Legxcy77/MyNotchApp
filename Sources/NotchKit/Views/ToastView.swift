import SwiftUI

struct ToastView: View {
    let toast: Toast
    let clearance: CGFloat

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(toast.tint.color.opacity(0.18))
                Image(systemName: toast.symbol)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(toast.tint.color)
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 1) {
                Text(toast.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                if let subtitle = toast.subtitle {
                    Text(subtitle)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .lineLimit(1)
            .truncationMode(.middle)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.top, clearance)
        .frame(maxHeight: .infinity)
    }
}

struct ExpandedView: View {
    let clearance: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TimelineView(.everyMinute) { context in
                HStack(alignment: .firstTextBaseline) {
                    Text(context.date, format: .dateTime.hour().minute())
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text(context.date, format: .dateTime.weekday(.wide).day().month(.wide))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                    Spacer()
                }
                .foregroundStyle(.white)
            }

            Text("All quiet. Builds, agents and servers will show up here.")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.4))

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .padding(.top, clearance + 12)
        .padding(.bottom, 16)
    }
}

