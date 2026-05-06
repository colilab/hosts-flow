import Foundation
import SwiftData

@Model
final class Profile {
    var id: UUID
    var name: String
    var isActive: Bool
    var order: Int

    @Relationship(deleteRule: .cascade, inverse: \HostRecord.profile)
    var records: [HostRecord]

    init(name: String, order: Int = 0) {
        self.id = UUID()
        self.name = name
        self.isActive = false
        self.order = order
        self.records = []
    }
}
