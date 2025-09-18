//
//  WalkTypeExtension.swift
//  WpoopedFebWidget
//
//  Created by Widget Extension on 7/27/25.
//

import Foundation
import AppIntents

// MARK: - AppEnum conformance for WalkType
extension WalkType: AppEnum, @unchecked Sendable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Walk Type")
    }
    
    static var caseDisplayRepresentations: [WalkType: DisplayRepresentation] {
        [
            .walk: DisplayRepresentation(title: "Walk"),
            .walkAndPoop: DisplayRepresentation(title: "Walk + Poop")
        ]
    }
}