import Foundation
import SwiftData

@Model
final class Dog {
    var name: String
    var breed: String?
    var birthDate: Date?
    var createdAt: Date
    var ownerId: String
    
    init(name: String, breed: String? = nil, birthDate: Date? = nil, ownerId: String) {
        self.name = name
        self.breed = breed
        self.birthDate = birthDate
        self.createdAt = Date()
        self.ownerId = ownerId
    }
}
