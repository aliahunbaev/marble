import Foundation
import UIKit
import SwiftData
import FirebaseAuth
import FirebaseStorage
import FirebaseFirestore

@MainActor
final class PhotoStorageService {
    static let shared = PhotoStorageService()

    private let storage = Storage.storage()
    private let db = Firestore.firestore()
    private var uid: String? { Auth.auth().currentUser?.uid }

    // MARK: - Local cache directory

    private var photosDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("photos", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    func localURL(for photo: ProgressPhoto) -> URL? {
        guard let name = photo.localFileName else { return nil }
        return photosDirectory.appendingPathComponent(name)
    }

    func image(for photo: ProgressPhoto) -> UIImage? {
        if let url = localURL(for: photo), let data = try? Data(contentsOf: url) {
            return UIImage(data: data)
        }
        return nil
    }

    // MARK: - Save new photo (locally first, then upload)

    /// Saves the image to disk, creates a ProgressPhoto record, and kicks off an upload.
    @discardableResult
    func savePhoto(_ image: UIImage,
                   workoutCloudID: String? = nil,
                   context: ModelContext) -> ProgressPhoto? {
        // Downscale to max 2048px on long edge, JPEG quality 0.85
        guard let processed = downscale(image, maxDimension: 2048),
              let data = processed.jpegData(compressionQuality: 0.85) else {
            return nil
        }

        let fileName = "\(UUID().uuidString).jpg"
        let url = photosDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            print("Photo save — local write failed: \(error)")
            return nil
        }

        let photo = ProgressPhoto(
            date: .now,
            localFileName: fileName,
            workoutCloudID: workoutCloudID
        )
        context.insert(photo)
        try? context.save()

        Task { await uploadPhoto(photo, data: data, context: context) }

        return photo
    }

    // MARK: - Upload

    private func uploadPhoto(_ photo: ProgressPhoto, data: Data, context: ModelContext) async {
        guard let uid else { return }
        let path = "users/\(uid)/photos/\(photo.cloudID).jpg"
        let ref = storage.reference(withPath: path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        do {
            _ = try await ref.putDataAsync(data, metadata: metadata)
            let downloadURL = try await ref.downloadURL()

            photo.remoteURL = downloadURL.absoluteString
            photo.uploadPending = false
            try? context.save()

            // Mirror metadata to Firestore for restore-on-other-device
            try await db.collection("users").document(uid)
                .collection("photos").document(photo.cloudID)
                .setData([
                    "cloudID": photo.cloudID,
                    "date": Timestamp(date: photo.date),
                    "remoteURL": photo.remoteURL ?? "",
                    "workoutCloudID": photo.workoutCloudID ?? "",
                    "caption": photo.caption ?? ""
                ], merge: false)
        } catch {
            print("Photo upload failed: \(error)")
        }
    }

    /// Retry pending uploads — call after sign-in or when network restored
    func retryPendingUploads(context: ModelContext) async {
        guard isSignedIn else { return }
        let pending = (try? context.fetch(FetchDescriptor<ProgressPhoto>(
            predicate: #Predicate { $0.uploadPending == true }
        ))) ?? []
        for photo in pending {
            guard let url = localURL(for: photo),
                  let data = try? Data(contentsOf: url) else { continue }
            await uploadPhoto(photo, data: data, context: context)
        }
    }

    // MARK: - Delete

    /// Cascade-delete every photo linked to the given workout. Used
    /// when a workout is removed (via WorkoutDetailView delete or
    /// ActiveWorkoutView.undoFinish) so we don't leave orphan photo
    /// records and storage files pointing at a workout that no
    /// longer exists. Each photo goes through the regular `delete`
    /// path so local file, model record, Firestore mirror, and
    /// Firebase Storage object all get cleaned up.
    func deletePhotosLinkedToWorkout(cloudID: String, context: ModelContext) {
        guard !cloudID.isEmpty else { return }
        let allPhotos = (try? context.fetch(FetchDescriptor<ProgressPhoto>())) ?? []
        for photo in allPhotos where photo.workoutCloudID == cloudID {
            delete(photo, context: context)
        }
    }

    func delete(_ photo: ProgressPhoto, context: ModelContext) {
        // Local file
        if let url = localURL(for: photo) {
            try? FileManager.default.removeItem(at: url)
        }
        let cloudID = photo.cloudID
        context.delete(photo)
        try? context.save()

        // Remote
        guard let uid else { return }
        let ref = storage.reference(withPath: "users/\(uid)/photos/\(cloudID).jpg")
        ref.delete { error in
            if let error { print("Photo delete (storage) failed: \(error)") }
        }
        db.collection("users").document(uid)
            .collection("photos").document(cloudID).delete()
    }

    // MARK: - Restore from cloud

    func restoreFromCloud(into context: ModelContext) async {
        guard let uid else { return }

        let existingIDs = Set((try? context.fetch(FetchDescriptor<ProgressPhoto>()).map(\.cloudID)) ?? [])

        do {
            let snap = try await db.collection("users").document(uid)
                .collection("photos").getDocuments()

            for doc in snap.documents {
                let data = doc.data()
                guard let cloudID = data["cloudID"] as? String,
                      !existingIDs.contains(cloudID) else { continue }

                let date = (data["date"] as? Timestamp)?.dateValue() ?? Date()
                let remoteURL = data["remoteURL"] as? String
                let workoutCloudID = (data["workoutCloudID"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                let caption = (data["caption"] as? String).flatMap { $0.isEmpty ? nil : $0 }

                let photo = ProgressPhoto(
                    date: date,
                    workoutCloudID: workoutCloudID,
                    caption: caption
                )
                photo.cloudID = cloudID
                photo.remoteURL = remoteURL
                photo.uploadPending = false
                context.insert(photo)

                // Download bytes for local cache
                if let urlStr = remoteURL, let url = URL(string: urlStr) {
                    Task {
                        if let (downloaded, _) = try? await URLSession.shared.data(from: url) {
                            let fileName = "\(cloudID).jpg"
                            let localURL = photosDirectory.appendingPathComponent(fileName)
                            try? downloaded.write(to: localURL, options: .atomic)
                            photo.localFileName = fileName
                            try? context.save()
                        }
                    }
                }
            }
            try? context.save()
        } catch {
            print("Photo restore failed: \(error)")
        }
    }

    // MARK: - Avatar (single-image, profile-scoped)
    //
    // The avatar is one image per user. Stored locally as `avatar.jpg`
    // in the photos cache and mirrored to `users/uid/avatar.jpg` in
    // Firebase Storage so it follows the user across devices /
    // reinstalls. Separate code path from ProgressPhoto since it's a
    // singleton-per-user, not a record in a model.

    private var avatarLocalURL: URL {
        photosDirectory.appendingPathComponent("avatar.jpg")
    }

    /// Reads the cached avatar image off disk. Returns nil if the user
    /// hasn't set one yet (or hasn't synced from cloud on this device).
    func avatarImage() -> UIImage? {
        guard let data = try? Data(contentsOf: avatarLocalURL) else { return nil }
        return UIImage(data: data)
    }

    /// Persist a new avatar image. Downscales to a circle-friendly max
    /// dimension, writes locally for immediate render, then uploads to
    /// Firebase Storage in the background.
    @discardableResult
    func saveAvatar(_ image: UIImage) -> Bool {
        guard let processed = downscale(image, maxDimension: 512),
              let data = processed.jpegData(compressionQuality: 0.9) else {
            return false
        }
        do {
            try data.write(to: avatarLocalURL, options: .atomic)
        } catch {
            print("Avatar save — local write failed: \(error)")
            return false
        }
        Task { await uploadAvatar(data: data) }
        return true
    }

    private func uploadAvatar(data: Data) async {
        guard let uid else { return }
        let ref = storage.reference(withPath: "users/\(uid)/avatar.jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        do {
            _ = try await ref.putDataAsync(data, metadata: metadata)
        } catch {
            print("Avatar upload failed: \(error)")
        }
    }

    /// Pull the cloud avatar into the local cache. Call on sign-in so
    /// the user sees their photo on a fresh device after restoring.
    func restoreAvatarFromCloud() async {
        guard let uid else { return }
        let ref = storage.reference(withPath: "users/\(uid)/avatar.jpg")
        do {
            let data = try await ref.data(maxSize: 4 * 1024 * 1024)
            try data.write(to: avatarLocalURL, options: .atomic)
        } catch {
            // "object-not-found" is normal when the user hasn't set
            // an avatar; suppress the noisy log for that case.
            if (error as NSError).domain != StorageErrorDomain {
                print("Avatar restore failed: \(error)")
            }
        }
    }

    // MARK: - Helpers

    private var isSignedIn: Bool { uid != nil }

    private func downscale(_ image: UIImage, maxDimension: CGFloat) -> UIImage? {
        let w = image.size.width
        let h = image.size.height
        let scale = min(maxDimension / max(w, h), 1.0)
        if scale >= 1.0 { return image }
        let newSize = CGSize(width: w * scale, height: h * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
