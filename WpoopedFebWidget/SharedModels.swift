//
//  SharedModels.swift
//  WpoopedFebWidget
//
//  Created by Widget Extension on 7/27/25.
//

import Foundation

// MARK: - WalkType (synchronized with main app)
enum WalkType: Int, Codable, CaseIterable {
    case walk
    case walkAndPoop
    
    var displayName: String {
        switch self {
        case .walk: return "Walk"
        case .walkAndPoop: return "Walk + Poop"
        }
    }
    
    var iconName: String {
        switch self {
        case .walk: return "figure.walk"
        case .walkAndPoop: return "figure.walk.motion"
        }
    }
}

// MARK: - Shared Data Models for Widget
struct WalkData: Codable {
    let id: String
    let dogID: String
    let date: Date
    let walkType: WalkType
    let ownerName: String?
    
    init(id: String, dogID: String, date: Date, walkType: WalkType, ownerName: String? = nil) {
        self.id = id
        self.dogID = dogID
        self.date = date
        self.walkType = walkType
        self.ownerName = ownerName
    }
}

struct DogData: Codable {
    let id: String
    let name: String
    let imageData: Data?
    let isShared: Bool
    let lastWalk: WalkData?
    
    init(id: String, name: String, imageData: Data? = nil, isShared: Bool = false, lastWalk: WalkData? = nil) {
        self.id = id
        self.name = name
        self.imageData = imageData
        self.isShared = isShared
        self.lastWalk = lastWalk
    }
    
    static let sample = DogData(
        id: "sample-dog-1",
        name: "Buddy",
        imageData: nil,
        isShared: false,
        lastWalk: WalkData(
            id: "sample-walk-1",
            dogID: "sample-dog-1",
            date: Calendar.current.date(byAdding: .hour, value: -2, to: Date()) ?? Date(),
            walkType: .walk,
            ownerName: "Sample User"
        )
    )
}