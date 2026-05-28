import Foundation
import SwiftData

@Model
final class ProgressPhoto {
    var cloudID: String = UUID().uuidString
    var date: Date = Date()
    var localFileName: String?         // file name in the app's Documents/photos/
    var remoteURL: String?             // Firebase Storage download URL
    var workoutCloudID: String?        // optional link to a Workout
    var caption: String?
    var uploadPending: Bool = true     // true until uploaded to Firebase Storage

    init(date: Date = .now,
         localFileName: String? = nil,
         remoteURL: String? = nil,
         workoutCloudID: String? = nil,
         caption: String? = nil) {
        self.cloudID = UUID().uuidString
        self.date = date
        self.localFileName = localFileName
        self.remoteURL = remoteURL
        self.workoutCloudID = workoutCloudID
        self.caption = caption
        self.uploadPending = remoteURL == nil
    }
}
