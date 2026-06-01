import Foundation
import SwiftData
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class CloudSyncService {
    static let shared = CloudSyncService()
    private let db = Firestore.firestore()

    private var uid: String? { Auth.auth().currentUser?.uid }
    private var isSignedIn: Bool { uid != nil }

    // MARK: - Push

    func uploadWorkout(_ workout: Workout) {
        guard let uid else { return }
        let dto = WorkoutDTO(from: workout)
        do {
            try db.collection("users").document(uid)
                .collection("workouts").document(workout.cloudID)
                .setData(from: dto, merge: false)
        } catch {
            print("Cloud sync — upload workout failed: \(error)")
        }
    }

    func uploadTemplate(_ template: WorkoutTemplate) {
        guard let uid else { return }
        let dto = TemplateDTO(from: template)
        do {
            try db.collection("users").document(uid)
                .collection("templates").document(template.cloudID)
                .setData(from: dto, merge: false)
        } catch {
            print("Cloud sync — upload template failed: \(error)")
        }
    }

    func uploadTrackedLift(_ lift: TrackedLift) {
        guard let uid else { return }
        let dto = TrackedLiftDTO(from: lift)
        do {
            try db.collection("users").document(uid)
                .collection("trackedLifts").document(lift.cloudID)
                .setData(from: dto, merge: false)
        } catch {
            print("Cloud sync — upload tracked lift failed: \(error)")
        }
    }

    func uploadBodyweightEntry(_ entry: BodyweightEntry) {
        guard let uid else { return }
        let dto = BodyweightEntryDTO(from: entry)
        do {
            try db.collection("users").document(uid)
                .collection("bodyweightEntries").document(entry.cloudID)
                .setData(from: dto, merge: false)
        } catch {
            print("Cloud sync — upload bodyweight failed: \(error)")
        }
    }

    // MARK: - Delete
    //
    // These were previously fire-and-forget (`db.collection(...).delete()`
    // without awaiting). If the app backgrounded before the request
    // flushed, the cloud delete never landed — local state had removed
    // the doc, but Firestore still held the row. On reinstall, restore
    // pulled the stale doc back. Now async/await with explicit error
    // logging so failures are visible during dev.
    //
    // We also skip the cloud call when cloudID is empty (the row was
    // never uploaded, so there's no cloud doc to remove).

    func deleteWorkout(cloudID: String) async {
        guard let uid, !cloudID.isEmpty else { return }
        do {
            try await db.collection("users").document(uid)
                .collection("workouts").document(cloudID).delete()
        } catch {
            print("Cloud sync — delete workout failed: \(error)")
        }
    }

    func deleteTemplate(cloudID: String) async {
        guard let uid, !cloudID.isEmpty else { return }
        do {
            try await db.collection("users").document(uid)
                .collection("templates").document(cloudID).delete()
        } catch {
            print("Cloud sync — delete template failed: \(error)")
        }
    }

    func deleteTrackedLift(cloudID: String) async {
        guard let uid, !cloudID.isEmpty else { return }
        do {
            try await db.collection("users").document(uid)
                .collection("trackedLifts").document(cloudID).delete()
        } catch {
            print("Cloud sync — delete tracked lift failed: \(error)")
        }
    }

    func deleteBodyweightEntry(cloudID: String) async {
        guard let uid, !cloudID.isEmpty else { return }
        do {
            try await db.collection("users").document(uid)
                .collection("bodyweightEntries").document(cloudID).delete()
        } catch {
            print("Cloud sync — delete bodyweight failed: \(error)")
        }
    }

    // MARK: - Restore (on sign-in)

    func restoreFromCloud(into context: ModelContext) async {
        guard let uid else { return }

        // Fetch existing local cloudIDs to avoid duplicates
        let existingWorkoutIDs = Set((try? context.fetch(FetchDescriptor<Workout>()).map(\.cloudID)) ?? [])
        let existingTemplateIDs = Set((try? context.fetch(FetchDescriptor<WorkoutTemplate>()).map(\.cloudID)) ?? [])
        let existingLiftIDs = Set((try? context.fetch(FetchDescriptor<TrackedLift>()).map(\.cloudID)) ?? [])

        // Local exercises (universal seeded set) for name lookup
        let allExercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        let exerciseByName = Dictionary(uniqueKeysWithValues: allExercises.map { ($0.name, $0) })

        // Workouts
        do {
            let workoutSnap = try await db.collection("users").document(uid)
                .collection("workouts").getDocuments()
            for doc in workoutSnap.documents {
                guard let dto = try? doc.data(as: WorkoutDTO.self),
                      !existingWorkoutIDs.contains(dto.cloudID) else { continue }
                let workout = Workout(name: dto.name, date: dto.date, duration: dto.duration, notes: dto.notes)
                workout.cloudID = dto.cloudID
                workout.exerciseLogs = dto.exerciseLogs.map { logDTO in
                    let log = ExerciseLog(exercise: exerciseByName[logDTO.exerciseName])
                    log.sets = logDTO.sets.map {
                        WorkoutSet(weight: $0.weight, reps: $0.reps, isCompleted: $0.isCompleted)
                    }
                    return log
                }
                context.insert(workout)
            }
        } catch {
            print("Cloud sync — restore workouts failed: \(error)")
        }

        // Templates
        do {
            let templateSnap = try await db.collection("users").document(uid)
                .collection("templates").getDocuments()
            for doc in templateSnap.documents {
                guard let dto = try? doc.data(as: TemplateDTO.self),
                      !existingTemplateIDs.contains(dto.cloudID) else { continue }
                let template = WorkoutTemplate(name: dto.name)
                template.cloudID = dto.cloudID
                template.exercises = dto.exerciseNames.compactMap { exerciseByName[$0] }
                context.insert(template)
            }
        } catch {
            print("Cloud sync — restore templates failed: \(error)")
        }

        // Tracked Lifts
        do {
            let liftSnap = try await db.collection("users").document(uid)
                .collection("trackedLifts").getDocuments()
            for doc in liftSnap.documents {
                guard let dto = try? doc.data(as: TrackedLiftDTO.self),
                      !existingLiftIDs.contains(dto.cloudID) else { continue }
                let lift = TrackedLift(
                    exercise: exerciseByName[dto.exerciseName],
                    metricType: dto.metricType,
                    displayOrder: dto.displayOrder
                )
                lift.cloudID = dto.cloudID
                lift.manualBestWeight = dto.manualBestWeight
                lift.manualBestWeightReps = dto.manualBestWeightReps
                lift.manualOneRepMax = dto.manualOneRepMax
                lift.manualMaxVolume = dto.manualMaxVolume
                context.insert(lift)
            }
        } catch {
            print("Cloud sync — restore tracked lifts failed: \(error)")
        }

        // Bodyweight Entries
        let existingBodyweightIDs = Set((try? context.fetch(FetchDescriptor<BodyweightEntry>()).map(\.cloudID)) ?? [])
        do {
            let bwSnap = try await db.collection("users").document(uid)
                .collection("bodyweightEntries").getDocuments()
            for doc in bwSnap.documents {
                guard let dto = try? doc.data(as: BodyweightEntryDTO.self),
                      !existingBodyweightIDs.contains(dto.cloudID) else { continue }
                let entry = BodyweightEntry(weight: dto.weight, date: dto.date)
                entry.cloudID = dto.cloudID
                entry.createdAt = dto.createdAt
                context.insert(entry)
            }
        } catch {
            print("Cloud sync — restore bodyweight entries failed: \(error)")
        }

        try? context.save()
    }

    // MARK: - Cleanup utilities
    //
    // For removing orphan / sparse data that accumulated before the
    // await-deletes fix landed. Sweep covers both the local model
    // context and the user's Firestore docs.

    /// Deletes templates that are "empty" — no name OR no exercises.
    /// Sweeps the local store first, then the cloud (to catch stale
    /// cloud docs whose local row was already removed but never
    /// propagated). Returns total deleted count for confirmation.
    func cleanupEmptyTemplates(context: ModelContext) async -> Int {
        var localDeleted = 0
        var cloudDeleted = 0
        let cloudIDsToDelete: Set<String>

        // --- Local sweep
        let localTemplates = (try? context.fetch(FetchDescriptor<WorkoutTemplate>())) ?? []
        var collectedCloudIDs = Set<String>()
        for template in localTemplates {
            let nameEmpty = template.name.trimmingCharacters(in: .whitespaces).isEmpty
            let exercisesEmpty = template.exercises.isEmpty
            if nameEmpty || exercisesEmpty {
                if !template.cloudID.isEmpty { collectedCloudIDs.insert(template.cloudID) }
                context.delete(template)
                localDeleted += 1
            }
        }
        try? context.save()
        cloudIDsToDelete = collectedCloudIDs

        // --- Cloud sweep (await every delete so the function only
        // returns when the network has actually flushed every request)
        guard let uid else { return localDeleted }

        // First: the ones we just removed locally
        for cloudID in cloudIDsToDelete {
            do {
                try await db.collection("users").document(uid)
                    .collection("templates").document(cloudID).delete()
                cloudDeleted += 1
            } catch {
                print("Cleanup — delete \(cloudID) failed: \(error)")
            }
        }

        // Then: orphans that exist in cloud but not in local store —
        // empty-exercises docs that survived a previous bad delete.
        do {
            let snap = try await db.collection("users").document(uid)
                .collection("templates").getDocuments()
            for doc in snap.documents {
                guard let dto = try? doc.data(as: TemplateDTO.self) else { continue }
                let nameEmpty = dto.name.trimmingCharacters(in: .whitespaces).isEmpty
                let exercisesEmpty = dto.exerciseNames.isEmpty
                if nameEmpty || exercisesEmpty {
                    try? await doc.reference.delete()
                    cloudDeleted += 1
                }
            }
        } catch {
            print("Cleanup — scan cloud templates failed: \(error)")
        }

        return max(localDeleted, cloudDeleted)
    }

    // MARK: - Clear all cloud data

    func clearAllCloudData() async {
        guard let uid else { return }
        for collection in ["workouts", "templates", "trackedLifts", "bodyweightEntries"] {
            do {
                let snap = try await db.collection("users").document(uid)
                    .collection(collection).getDocuments()
                for doc in snap.documents {
                    try await doc.reference.delete()
                }
            } catch {
                print("Cloud sync — clear \(collection) failed: \(error)")
            }
        }
    }

    // MARK: - Full Push (after sign-in, for existing local data)

    func pushAllLocalToCloud(from context: ModelContext) {
        guard isSignedIn else { return }
        let workouts = (try? context.fetch(FetchDescriptor<Workout>())) ?? []
        let templates = (try? context.fetch(FetchDescriptor<WorkoutTemplate>())) ?? []
        let lifts = (try? context.fetch(FetchDescriptor<TrackedLift>())) ?? []
        let bodyweights = (try? context.fetch(FetchDescriptor<BodyweightEntry>())) ?? []
        workouts.forEach { uploadWorkout($0) }
        templates.forEach { uploadTemplate($0) }
        lifts.forEach { uploadTrackedLift($0) }
        bodyweights.forEach { uploadBodyweightEntry($0) }
    }
}

// MARK: - DTOs

struct WorkoutDTO: Codable {
    var cloudID: String
    var name: String
    var date: Date
    var duration: TimeInterval
    var notes: String?
    var exerciseLogs: [ExerciseLogDTO]

    init(from workout: Workout) {
        self.cloudID = workout.cloudID
        self.name = workout.name
        self.date = workout.date
        self.duration = workout.duration
        self.notes = workout.notes
        self.exerciseLogs = workout.exerciseLogs.map { ExerciseLogDTO(from: $0) }
    }
}

struct ExerciseLogDTO: Codable {
    var exerciseName: String
    var exerciseMuscleGroup: String
    var sets: [SetDTO]

    init(from log: ExerciseLog) {
        self.exerciseName = log.exercise?.name ?? ""
        self.exerciseMuscleGroup = log.exercise?.muscleGroup ?? ""
        self.sets = log.sets.map { SetDTO(weight: $0.weight, reps: $0.reps, isCompleted: $0.isCompleted) }
    }
}

struct SetDTO: Codable {
    var weight: Double
    var reps: Int
    var isCompleted: Bool
}

struct TemplateDTO: Codable {
    var cloudID: String
    var name: String
    var exerciseNames: [String]

    init(from template: WorkoutTemplate) {
        self.cloudID = template.cloudID
        self.name = template.name
        self.exerciseNames = template.exercises.map(\.name)
    }
}

struct TrackedLiftDTO: Codable {
    var cloudID: String
    var exerciseName: String
    var metricType: String
    var displayOrder: Int
    var manualBestWeight: Double?
    var manualBestWeightReps: Int?
    var manualOneRepMax: Double?
    var manualMaxVolume: Double?

    init(from lift: TrackedLift) {
        self.cloudID = lift.cloudID
        self.exerciseName = lift.exercise?.name ?? ""
        self.metricType = lift.metricType
        self.displayOrder = lift.displayOrder
        self.manualBestWeight = lift.manualBestWeight
        self.manualBestWeightReps = lift.manualBestWeightReps
        self.manualOneRepMax = lift.manualOneRepMax
        self.manualMaxVolume = lift.manualMaxVolume
    }
}

struct BodyweightEntryDTO: Codable {
    var cloudID: String
    var weight: Double
    var date: Date
    var createdAt: Date

    init(from entry: BodyweightEntry) {
        self.cloudID = entry.cloudID
        self.weight = entry.weight
        self.date = entry.date
        self.createdAt = entry.createdAt
    }
}
