//
//  FlarumBadgeCategory.swift
//  ecnu-im
//
//  Created by 陈俊杰 on 2022/5/16.
//

import Foundation

struct FlarumBadgeCategoryAttributes: Codable {
    var name: String
    var description: String?
    var order: Int
    var isEnabled: Bool
    var isTable: Bool
    var createdAt: String
}

struct FlarumBadgeCategoryRelationships: Codable {
    var badges: [FlarumBadge]
}

class FlarumBadgeCategory: Codable {
    init(id: String, attributes: FlarumBadgeCategoryAttributes, relationships: FlarumBadgeCategoryRelationships? = nil) {
        self.id = id
        self.attributes = attributes
        self.relationships = relationships
    }

    var id: String
    var attributes: FlarumBadgeCategoryAttributes
    var relationships: FlarumBadgeCategoryRelationships?
}

extension FlarumBadgeCategory: Hashable {
    static func == (lhs: FlarumBadgeCategory, rhs: FlarumBadgeCategory) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
