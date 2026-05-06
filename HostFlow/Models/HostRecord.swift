import Foundation
import SwiftData

@Model
final class HostRecord {
    var id: UUID
    var ip: String
    var hostname: String
    var isEnabled: Bool
    var profile: Profile?

    init(ip: String, hostname: String, profile: Profile? = nil) {
        self.id = UUID()
        self.ip = ip
        self.hostname = hostname
        self.isEnabled = true
        self.profile = profile
    }
}
