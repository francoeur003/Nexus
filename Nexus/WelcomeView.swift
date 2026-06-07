import SwiftUI

// MARK: - Welcome window (shown on first launch)

struct WelcomeView: View {
    @State private var step = 0
    @AppStorage("enableMenuBar") var enableMenuBar = true
    @AppStorage("enableWidget")  var enableWidget  = false
    @AppStorage("hasLaunched")   var hasLaunched   = false

    var body: some View {
        ZStack {
            Color(hex: "0E0E12").ignoresSafeArea()

            VStack(spacing: 0) {
                // Step indicator
                HStack(spacing: 6) {
                    ForEach(0..<3) { i in
                        Capsule()
                            .fill(i == step ? Color(hex:"0A84FF") : Color.white.opacity(0.12))
                            .frame(width: i == step ? 20 : 6, height: 6)
                            .animation(.easeInOut(duration: 0.3), value: step)
                    }
                }
                .padding(.top, 28)

                Spacer()

                // Content
                Group {
                    if step == 0 { StepWelcome() }
                    if step == 1 { StepMode(menuBar: $enableMenuBar, widget: $enableWidget) }
                    if step == 2 { StepPermission() }
                }
                .transition(.asymmetric(
                    insertion:  .move(edge: .trailing).combined(with: .opacity),
                    removal:    .move(edge: .leading).combined(with: .opacity)
                ))

                Spacer()

                // Navigation
                HStack(spacing: 12) {
                    if step > 0 {
                        Button("返回") { withAnimation { step -= 1 } }
                            .buttonStyle(.bordered)
                    }
                    Spacer()
                    Button(step < 2 ? "继续" : "开始使用") {
                        if step < 2 {
                            withAnimation { step += 1 }
                        } else {
                            hasLaunched = true
                            NSApp.keyWindow?.close()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(hex: "0A84FF"))
                    .font(.system(size: 13, weight: .semibold))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 28)
            }
        }
        .frame(width: 480, height: 420)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Step 1: Welcome

private struct StepWelcome: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "gauge.with.dots.needle.67percent")
                .font(.system(size: 64, weight: .thin))
                .foregroundStyle(
                    LinearGradient(colors: [Color(hex:"0A84FF"), Color(hex:"BF5AF2")],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )

            VStack(spacing: 8) {
                Text("欢迎使用 Nexus")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                Text("为 Apple Silicon 打造的实时处理器、图形处理器、内存、电池和功耗监测。")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "ABABC0"))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            HStack(spacing: 24) {
                Feature(icon: "cpu",              label: "逐核心处理器")
                Feature(icon: "rectangle.3.group",label: "图形处理器与温度")
                Feature(icon: "battery.75percent",label: "完整电池信息")
                Feature(icon: "bolt.fill",        label: "功耗监测")
            }
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - Step 2: Mode

private struct StepMode: View {
    @Binding var menuBar: Bool
    @Binding var widget:  Bool

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 6) {
                Text("选择显示方式")
                    .font(.system(size: 20, weight: .bold)).foregroundColor(.white)
                Text("之后可以随时在设置里修改。")
                    .font(.system(size: 12)).foregroundColor(Color(hex:"666680"))
            }

            VStack(spacing: 12) {
                ModeCard(
                    icon: "menubar.rectangle",
                    title: "菜单栏",
                    desc: "在菜单栏显示实时状态，点击可打开完整面板。",
                    selected: $menuBar
                )
                ModeCard(
                    icon: "square.grid.2x2",
                    title: "桌面小组件",
                    desc: "在桌面或通知中心显示小号或中号小组件。",
                    selected: $widget
                )
            }
            .padding(.horizontal, 32)
        }
    }
}

// MARK: - Step 3: Permissions

private struct StepPermission: View {
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 6) {
                Text("一次性权限")
                    .font(.system(size: 20, weight: .bold)).foregroundColor(.white)
                Text("Nexus 需要一次管理员授权，用于读取图形处理器、温度和功耗数据。")
                    .font(.system(size: 12)).foregroundColor(Color(hex:"666680"))
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 10) {
                PermRow(icon: "cpu",              color: "0A84FF",
                        title: "处理器与内存",    desc: "直接从 macOS 读取，无需密码。")
                PermRow(icon: "rectangle.3.group",color: "BF5AF2",
                        title: "图形处理器与温度",     desc: "使用原生 SMC 与 IOReport 传感器，无第三方依赖。")
                PermRow(icon: "bolt.fill",        color: "FFD60A",
                        title: "功耗通道",     desc: "监测 ANE、DRAM、GPU SRAM 和系统总功耗。")
                PermRow(icon: "battery.75percent",color: "30D158",
                        title: "电池",         desc: "循环次数、健康度、充电功率和适配器功率。")
            }
            .padding(.horizontal, 36)

            Text("管理员密码由 macOS 缓存，Nexus 不会保存。")
                .font(.system(size: 10))
                .foregroundColor(Color(hex:"444455"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

// MARK: - Sub-components

private struct Feature: View {
    let icon: String; let label: String
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(Color(hex:"0A84FF"))
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(Color(hex:"888899"))
                .multilineTextAlignment(.center)
        }
        .frame(width: 72)
    }
}

private struct ModeCard: View {
    let icon: String; let title: String; let desc: String
    @Binding var selected: Bool

    var body: some View {
        Button { selected.toggle() } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(selected ? Color(hex:"0A84FF") : Color(hex:"666680"))
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(selected ? .white : Color(hex:"888899"))
                    Text(desc)
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex:"666680"))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selected ? Color(hex:"0A84FF") : Color(hex:"333344"))
                    .font(.system(size: 18))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(selected ? Color(hex:"0A84FF").opacity(0.08) : Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(selected ? Color(hex:"0A84FF").opacity(0.4) : Color.white.opacity(0.06))
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: selected)
    }
}

private struct PermRow: View {
    let icon: String; let color: String
    let title: String; let desc: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: color))
                .frame(width: 20)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex:"666680"))
            }
        }
    }
}
