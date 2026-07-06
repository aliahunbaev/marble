import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Marble palette (code-defined)
//
// The widget target doesn't share the app's asset catalog, so the
// brand colors are defined here directly. Values mirror the app's
// colorsets: bone #F4EEE4, warm ink #0E0A07, taupe #6B6358.
private enum Palette {
    static let bone = Color(red: 0.957, green: 0.933, blue: 0.894)
    static let ink = Color(red: 0.055, green: 0.039, blue: 0.027)
    static let taupe = Color(red: 0.420, green: 0.388, blue: 0.345)
}

// MARK: - Rest timer Live Activity
//
// Renders the rest countdown in the Dynamic Island and as a lock-screen
// banner. The countdown itself is drawn by the SYSTEM via
// Text(timerInterval:) — the app never pushes per-second updates, only
// starts the activity, moves endDate on ±10s, and ends it on skip /
// completion (see RestTimerState).
struct MarbleWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestActivityAttributes.self) { context in
            // Lock screen / banner — bone card, editorial REST label,
            // light countdown. Matches the app's register.
            HStack(alignment: .firstTextBaseline) {
                Text("REST")
                    .font(.system(size: 12, weight: .medium))
                    .tracking(2)
                    .foregroundStyle(Palette.taupe)

                Spacer()

                countdown(context, size: 36)
                    .foregroundStyle(Palette.ink)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .activityBackgroundTint(Palette.bone)
            .activitySystemActionForegroundColor(Palette.ink)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded — long-press on the island.
                DynamicIslandExpandedRegion(.leading) {
                    Text("REST")
                        .font(.system(size: 12, weight: .medium))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(maxHeight: .infinity, alignment: .center)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdown(context, size: 32)
                        .foregroundStyle(.white)
                        .frame(maxHeight: .infinity, alignment: .center)
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.bone)
            } compactTrailing: {
                countdown(context, size: 13)
                    .foregroundStyle(Palette.bone)
                    // timerInterval text is greedy — cap it so the
                    // island's compact trailing slot stays tight.
                    .frame(maxWidth: 42)
            } minimal: {
                Image(systemName: "timer")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Palette.bone)
            }
            .keylineTint(Palette.bone)
        }
    }

    /// System-rendered live countdown ("1:23"), light weight, digits
    /// monospaced so the layout doesn't wobble each second.
    private func countdown(
        _ context: ActivityViewContext<RestActivityAttributes>,
        size: CGFloat
    ) -> some View {
        Text(timerInterval: context.attributes.startDate...context.state.endDate, countsDown: true)
            .font(.system(size: size, weight: .light))
            .monospacedDigit()
            .multilineTextAlignment(.trailing)
    }
}
