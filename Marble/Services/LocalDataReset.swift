import Foundation
import SwiftData

/// Wipes every piece of account-owned data on this device. Called when
/// a DIFFERENT account signs in than the one whose data is stored
/// locally (see AuthenticationService.performInitialSync's owner-UID
/// check) — the device's local store belongs to exactly one account,
/// and an account switch behaves like a fresh device: wipe, then
/// restore the new account's cloud.
///
/// Deletes are instance-wise, honoring the model cascade rules
/// (Workout → ExerciseLog → WorkoutSet are .cascade) — NOT the bulk
/// `context.delete(model:)` path, which once left set-less Workout
/// shells behind and corrupted the store.
enum LocalDataReset {
    /// UserDefaults keys that describe ACCOUNT data state (cleared on
    /// wipe). Device preferences (theme, icon, rest-timer settings,
    /// onboarding flag) deliberately survive.
    private static let accountDataKeys = [
        "Marble.hasSeededStarterTemplates.v1",
        "Marble.exerciseLibraryToppedUp.v2",
        "Marble.WorkoutSession.v1",
        "userName",
    ]

    @MainActor
    static func wipe(context: ModelContext) {
        // Workouts first — cascades ExerciseLogs and WorkoutSets.
        deleteAll(Workout.self, in: context)
        // Sweep any orphans that predate the cascade rules.
        deleteAll(ExerciseLog.self, in: context)
        deleteAll(WorkoutSet.self, in: context)
        deleteAll(WorkoutTemplate.self, in: context)
        deleteAll(TrackedLift.self, in: context)
        deleteAll(BodyweightEntry.self, in: context)
        deleteAll(ProgressPhoto.self, in: context)
        // Exercises too: custom movements are the old account's data.
        // The stock library is reseeded below.
        deleteAll(Exercise.self, in: context)
        try? context.save()

        // Cached pixels: progress photos + avatar.
        PhotoStorageService.shared.clearAllLocalPhotoFiles()

        // Account-scoped flags/state — clearing the seed flags lets the
        // incoming account seed starters if its cloud is empty, and
        // clearing the session snapshot keeps an in-flight workout from
        // crossing accounts.
        for key in accountDataKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }

        // Rebuild the stock exercise library immediately — the cloud
        // restore that follows resolves exercises by name and needs the
        // library present.
        ExerciseSeed.seedIfNeeded(context: context)
    }

    private static func deleteAll<T: PersistentModel>(_ type: T.Type, in context: ModelContext) {
        let all = (try? context.fetch(FetchDescriptor<T>())) ?? []
        for object in all {
            context.delete(object)
        }
    }
}
