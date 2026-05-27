import Foundation
import FirebaseFirestore

struct UserProfile: Codable, Identifiable {
    @DocumentID var documentID: String?
    var id: String
    var name: String
    var email: String?
    var joinDate: Date

    enum CodingKeys: String, CodingKey {
        case documentID
        case id
        case name
        case email
        case joinDate
    }
}
