import SwiftUI

public struct WidgetStudioView: View {
    @Bindable var config: NotchWidgetConfig
    let onPreviewWidget: (WidgetID) -> Void
    @State private var selectedCategory: WidgetCategory? = nil

    public init(
        config: NotchWidgetConfig,
        onPreviewWidget: @escaping (WidgetID) -> Void
    ) {
        self.config = config
        self.onPreviewWidget = onPreviewWidget
    }

    private var visibleWidgets: [WidgetID] {
        if let selectedCategory {
            return WidgetID.allCases.filter { $0.category == selectedCategory }
        }
        return WidgetID.allCases
    }

    public var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider().overlay(Color.white.opacity(0.08))

            ScrollView {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 14),
                        GridItem(.flexible(), spacing: 14),
                    ],
                    spacing: 14
                ) {
                    ForEach(visibleWidgets) { widget in
                        WidgetStudioCard(
                            widget: widget,
                            isEnabled: Binding(
                                get: { config.isEnabled(widget) },
                                set: { config.setEnabled(widget, $0) }
                            ),
                            onPreview: { onPreviewWidget(widget) }
                        )
                    }
                }
                .padding(20)

                freeformLayoutSection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                tunablesSection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 22)
            }
        }
        .frame(minWidth: 740, minHeight: 560)
        .background(Color(nsColor: .windowBackgroundColor))
        .preferredColorScheme(.dark)
    }

    private var freeformLayoutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Notch Overview Bento Layout (Freeform)")
                        .font(.system(size: 13, weight: .semibold))
                    Text("วางการ์ดเล็ก/ใหญ่ผสมกันได้อิสระ เพิ่ม แทนที่ ปรับขนาด และจัดลำดับใหม่ได้ทันที")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    ForEach(BentoTileKind.allCases) { kind in
                        Button {
                            config.addBentoTile(kind)
                        } label: {
                            Label(kind.title, systemImage: kind.symbol)
                        }
                    }
                } label: {
                    Label("Add Card", systemImage: "plus.circle.fill")
                        .font(.system(size: 11.5, weight: .semibold))
                }
            }

            ForEach(config.overviewLayout) { item in
                HStack(spacing: 10) {
                    Image(systemName: item.kind.symbol)
                        .frame(width: 18)
                        .foregroundStyle(.secondary)
                    Text(item.kind.title)
                        .font(.system(size: 12, weight: .medium))

                    Spacer()

                    Picker("", selection: Binding(
                        get: { item.kind },
                        set: { config.replaceBentoTile(id: item.id, with: $0) }
                    )) {
                        ForEach(BentoTileKind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .frame(width: 150)

                    Picker("", selection: Binding(
                        get: { item.size },
                        set: { config.resizeBentoTile(id: item.id, to: $0) }
                    )) {
                        ForEach(BentoTileSize.allCases) { size in
                            Text(size.shortLabel).tag(size)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)

                    Button { config.moveBentoTile(id: item.id, offset: -1) } label: {
                        Image(systemName: "arrow.up")
                    }
                    Button { config.moveBentoTile(id: item.id, offset: 1) } label: {
                        Image(systemName: "arrow.down")
                    }
                    Button { config.removeBentoTile(id: item.id) } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var headerBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Notch Widget Studio")
                    .font(.system(size: 16, weight: .semibold))
                Text("เลือกวิดเจ็ตที่จะแสดงใน Notch พร้อมตัวอย่างแอนิเมชันสด")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Picker("Category", selection: $selectedCategory) {
                Text("All").tag(WidgetCategory?.none)
                ForEach(WidgetCategory.allCases) { cat in
                    Text(cat.rawValue).tag(WidgetCategory?.some(cat))
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 380)

            Button("Reset") {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) {
                    config.resetToDefaults()
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var tunablesSection: some View {
        VStack(spacing: 14) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "wand.and.stars")
                            .foregroundStyle(.purple)
                        Text("Aurora Glow Intensity")
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                        Text("\(Int(config.auroraIntensity * 100))%")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $config.auroraIntensity, in: 0.2...1.0, step: 0.05)
                }
                .padding(14)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "person.crop.circle.badge.clock")
                            .foregroundStyle(.orange)
                        Text("Walk-Away Auto-Lock Delay")
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                        Text("\(config.walkAwayTimeoutSeconds)s")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    Picker("", selection: $config.walkAwayTimeoutSeconds) {
                        Text("15s").tag(15)
                        Text("30s").tag(30)
                        Text("60s").tag(60)
                        Text("120s").tag(120)
                    }
                    .pickerStyle(.segmented)
                }
                .padding(14)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "rectangle.topthird.inset.filled")
                            .foregroundStyle(.cyan)
                        Text("Ear Status Pills (ซ้าย / ขวา)")
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                        Picker("Mode", selection: $config.notchDisplayMode) {
                            ForEach(NotchDisplayMode.allCases) { m in
                                Text(m.rawValue).tag(m)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 170)
                    }
                    HStack(spacing: 12) {
                        Picker("Left", selection: $config.leftEarStat) {
                            ForEach(EarStatKind.allCases) { stat in
                                Text(stat.title).tag(stat)
                            }
                        }
                        Picker("Right", selection: $config.rightEarStat) {
                            ForEach(EarStatKind.allCases) { stat in
                                Text(stat.title).tag(stat)
                            }
                        }
                    }
                    .font(.system(size: 11))
                }
                .padding(14)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundStyle(.blue)
                        Text("Notch Opacity & Scroll")
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                        Text("\(Int(config.islandOpacity * 100))%")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $config.islandOpacity, in: 0.7...1.0, step: 0.05)
                    Toggle("Two-finger scroll to switch tabs", isOn: $config.scrollToSwitchTabs)
                        .font(.system(size: 11))
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                }
                .padding(14)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

private struct WidgetStudioCard: View {
    let widget: WidgetID
    @Binding var isEnabled: Bool
    let onPreview: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: widget.symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isEnabled ? Color.accentColor : .secondary)
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 7))

                VStack(alignment: .leading, spacing: 1) {
                    Text(widget.title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .lineLimit(1)
                    Text(widget.category.rawValue)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: $isEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .controlSize(.small)
            }

            LiveWidgetMiniPreview(widget: widget, active: isEnabled)
                .frame(height: 62)

            HStack {
                Text(widget.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Spacer(minLength: 8)

                Button {
                    NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                    onPreview()
                } label: {
                    Label("Test", systemImage: "play.fill")
                        .font(.system(size: 10.5, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(isEnabled ? 0.065 : 0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(isEnabled ? 0.14 : 0.06), lineWidth: 1)
        )
        .opacity(isEnabled ? 1.0 : 0.65)
    }
}

private struct LiveWidgetMiniPreview: View {
    let widget: WidgetID
    let active: Bool
    @State private var pulse = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.black)

            switch widget {
            case .earsNowPlaying:
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 24, height: 24)
                    Text("Now Playing")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                    Spacer()
                    HStack(spacing: 2) {
                        ForEach(0..<4, id: \.self) { idx in
                            Capsule()
                                .fill(Color.green)
                                .frame(width: 2.5, height: pulse ? CGFloat(8 + (idx % 3) * 5) : 5)
                        }
                    }
                }
                .padding(.horizontal, 12)

            case .earsSystemStats:
                HStack(spacing: 10) {
                    Label(pulse ? "CPU 12%" : "CPU 18%", systemImage: "cpu")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.cyan)
                    Spacer()
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.14))
                        .frame(width: 44, height: 14)
                    Spacer()
                    Label("84%", systemImage: "battery.75percent")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.green)
                }
                .padding(.horizontal, 12)

            case .bentoCommandCenter:
                HStack(spacing: 8) {
                    Image(systemName: "hand.draw.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.blue)
                        .offset(x: pulse ? 6 : -6)
                    Text("Scroll ↔ Switch · Smart Hover")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.88))
                    Spacer()
                }
                .padding(.horizontal, 12)

            case .earsDevTicker, .bentoMissionControl:
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 7, height: 7)
                        .scaleEffect(pulse ? 1.25 : 0.85)
                    Text(widget == .earsDevTicker ? "swift test · 00:04" : "[PASS] 102 tests in 33 suites")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.9))
                    Spacer()
                }
                .padding(.horizontal, 12)

            case .edgeGlow, .lockScreenAurora:
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: pulse ? [.purple.opacity(0.55), .blue.opacity(0.4), .pink.opacity(0.45)] : [.blue.opacity(0.45), .teal.opacity(0.35), .purple.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        Text(widget == .edgeGlow ? "Edge Glow Pulse" : "Liquid Aurora GPU")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white)
                    }

            case .hudVolumeBrightness:
                VStack(spacing: 5) {
                    HStack {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 10))
                        Text("Volume")
                            .font(.system(size: 10, weight: .medium))
                        Spacer()
                        Text(pulse ? "75%" : "45%")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.16))
                            Capsule().fill(Color.white).frame(width: geo.size.width * (pulse ? 0.75 : 0.45))
                        }
                    }
                    .frame(height: 4)
                }
                .padding(.horizontal, 12)

            case .hudAirPodsPopup, .bentoSpatial3D:
                HStack(spacing: 10) {
                    Image(systemName: widget == .hudAirPodsPopup ? "airpodspro" : "cube.transparent.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.cyan)
                        .rotation3DEffect(.degrees(pulse ? 18 : -18), axis: (x: 0, y: 1, z: 0))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(widget == .hudAirPodsPopup ? "AirPods Pro" : "3D Spatial View")
                            .font(.system(size: 10.5, weight: .semibold))
                        Text("L 95% · R 95% · Case 80%")
                            .font(.system(size: 9.5, design: .monospaced))
                            .foregroundStyle(.green)
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)

            case .hudMagSafePopup:
                HStack(spacing: 10) {
                    Image(systemName: "bolt.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.green)
                        .scaleEffect(pulse ? 1.12 : 0.94)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("MagSafe Charging")
                            .font(.system(size: 10.5, weight: .semibold))
                        Text("84% · 67W Fast Charge")
                            .font(.system(size: 9.5, design: .monospaced))
                            .foregroundStyle(.green)
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)

            case .voiceAI:
                HStack(spacing: 10) {
                    Image(systemName: "waveform")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.blue)
                        .scaleEffect(y: pulse ? 1.3 : 0.7)
                    Text("“ดู error บนหน้าจอนี้ให้หน่อย”")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                    Spacer()
                }
                .padding(.horizontal, 12)

            case .walkAwayAutoLock:
                HStack(spacing: 10) {
                    Image(systemName: "lock.rotation")
                        .font(.system(size: 14))
                        .foregroundStyle(.orange)
                    Text("ไม่พบใบหน้า · ล็อกใน 3s")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.orange)
                    Spacer()
                }
                .padding(.horizontal, 12)

            default:
                HStack(spacing: 8) {
                    Image(systemName: widget.symbol)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.85))
                    Text(widget.title)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                    Spacer()
                }
                .padding(.horizontal, 12)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.75)
        )
        .onAppear {
            guard active else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

