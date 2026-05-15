import Foundation
import CoreTransferable
import UniformTypeIdentifiers

extension UTType {
    static let hostFlowRecord = UTType(exportedAs: "com.colilab.hostflow.hostrecord")
}

struct HostRecordTransfer: Codable, Transferable {
    let id: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .hostFlowRecord)
    }
}
