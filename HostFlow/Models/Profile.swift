import Foundation
import SwiftData

@Model
final class Profile {
    var id: UUID
    var name: String
    var isActive: Bool
    var order: Int
    var isReadOnly: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \HostRecord.profile)
    var records: [HostRecord]

    var isEditable: Bool { !isReadOnly }

    init(name: String, order: Int = 0, isReadOnly: Bool = false) {
        self.id = UUID()
        self.name = name
        self.isActive = false
        self.order = order
        self.isReadOnly = isReadOnly
        self.records = []
    }
}
