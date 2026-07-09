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

// MARK: - Marble type (widget-local)
//
// The extension ships its own copies of the Favorit files (registered
// in the widget target's Resources + its Info.plist UIAppFonts), so
// the banner and island match the app's editorial register. Light
// weight only, same as the app.
private enum WidgetFont {
    static func body(_ size: CGFloat) -> Font {
        .custom("ABC Favorit Variable Unlicensed Trial", size: size).weight(.light)
    }
    static func mono(_ size: CGFloat) -> Font {
        .custom("ABC Favorit Mono Variable Unlicensed Trial", size: size).weight(.light)
    }
}

// MARK: - Rest timer Live Activity
//
// Renders the rest countdown in the Dynamic Island and as a lock-screen
// banner. The countdown text AND the depleting ring are drawn by the
// SYSTEM (Text(timerInterval:) / ProgressView(timerInterval:)) — the
// app never pushes per-second updates, only starts the activity, moves
// endDate on ±10s, and ends it on skip / completion (see RestTimerState).
//
// Deliberately display-only: no buttons. The controls live one tap away
// in the app; the surface stays a quiet REST + countdown.
struct MarbleWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestActivityAttributes.self) { context in
            // Lock screen / banner — bone card. REST left in light
            // Favorit, countdown right in Favorit Mono, both centered
            // on the same axis.
            HStack(alignment: .center) {
                // Title-case wordmark treatment — ink, Favorit (not
                // mono), no tracking. Reads as a title, not a label.
                Text("Rest")
                    .font(WidgetFont.body(19))
                    .foregroundStyle(Palette.ink)

                Spacer()

                countdown(context, size: 40)
                    .foregroundStyle(Palette.ink)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .activityBackgroundTint(Palette.bone)
            .activitySystemActionForegroundColor(Palette.ink)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded — long-press on the island.
                DynamicIslandExpandedRegion(.leading) {
                    Text("Rest")
                        .font(WidgetFont.body(17))
                        .foregroundStyle(.white)
                        .frame(maxHeight: .infinity, alignment: .center)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdown(context, size: 32)
                        .foregroundStyle(.white)
                        .frame(maxHeight: .infinity, alignment: .center)
                }
            } compactLeading: {
                // Apple-Timer pairing: depleting ring left, digits right.
                ring(context)
            } compactTrailing: {
                countdown(context, size: 14)
                    .foregroundStyle(Palette.bone)
                    // timerInterval text is greedy — cap it so the
                    // island's compact trailing slot stays tight.
                    .frame(maxWidth: 44)
            } minimal: {
                // When another app (e.g. Spotify) owns the island,
                // Marble collapses to this single tiny slot — digits
                // can't fit, so show the system-animated depleting
                // ring, Apple-Timer style, and time stays readable.
                ring(context)
            }
            .keylineTint(Palette.bone)
        }
    }

    /// System-rendered live countdown ("1:23"), Favorit Mono light,
    /// digits monospaced so the layout doesn't wobble each second.
    private func countdown(
        _ context: ActivityViewContext<RestActivityAttributes>,
        size: CGFloat
    ) -> some View {
        Text(timerInterval: context.attributes.startDate...context.state.endDate, countsDown: true)
            .font(WidgetFont.mono(size))
            .monospacedDigit()
            .multilineTextAlignment(.trailing)
    }

    /// System-animated depleting ring for the island's smallest slots.
    private func ring(
        _ context: ActivityViewContext<RestActivityAttributes>
    ) -> some View {
        ProgressView(
            timerInterval: context.attributes.startDate...context.state.endDate,
            countsDown: true,
            label: { EmptyView() },
            currentValueLabel: { EmptyView() }
        )
        .progressViewStyle(.circular)
        .tint(Palette.bone)
    }
}
