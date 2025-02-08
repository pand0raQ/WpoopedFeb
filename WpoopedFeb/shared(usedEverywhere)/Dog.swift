import Foundation
import SwiftData
import UIKit

@Model
final class Dog {
    var name: String
    var imageData: Data?
    var createdAt: Date
    
    init(name: String) {
        self.name = name
        self.createdAt = Date()
    }
    
    var image: UIImage? {
        guard let imageData else { return nil }
        return UIImage(data: imageData)
    }
}
