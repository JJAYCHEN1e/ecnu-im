//
//  FlarumUserBadge.swift
//  ecnu-im
//
//  Created by 陈俊杰 on 2022/5/16.
//

import Foundation

struct FlarumUserBadgeAttributes: Codable {
    var isPrimary: Int
    var description: String?
    var assignedAt: String

    var assignedAtDate: Date? {
        // date format, example: 2022-03-23T13:37:49+00:00
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        let dateString = assignedAt.prefix(25)
        return dateFormatter.date(from: String(dateString))
    }
}

struct FlarumUserBadgeRelationshipsNew: Codable {
    var badge: FlarumBadgeNew

    init(_ i: FlarumUserBadgeRelationships) {
        badge = .init(i.badge)
    }
}

struct FlarumUserBadgeRelationships: Codable {
    var badge: FlarumBadge
}

struct FlarumUserBadgeNew: Codable {
    init(id: String, attributes: FlarumUserBadgeAttributes, relationships: FlarumUserBadgeRelationshipsNew? = nil) {
        self.id = id
        self.attributes = attributes
        self.relationships = relationships
    }

    var id: String
    var attributes: FlarumUserBadgeAttributes
    var relationships: FlarumUserBadgeRelationshipsNew?

    var assignedAtDateDescription: String {
        if let date = attributes.assignedAtDate {
            return date.localeDescription
        } else {
            return "Unknown"
        }
    }

    init(_ i: FlarumUserBadge) {
        id = i.id
        attributes = i.attributes
        relationships = i.relationships != nil ? .init(i.relationships!) : nil
    }
}

class FlarumUserBadge: Codable {
    init(id: String, attributes: FlarumUserBadgeAttributes, relationships: FlarumUserBadgeRelationships? = nil) {
        self.id = id
        self.attributes = attributes
        self.relationships = relationships
    }

    var id: String
    var attributes: FlarumUserBadgeAttributes
    var relationships: FlarumUserBadgeRelationships?

    var assignedAtDateDescription: String {
        if let date = attributes.assignedAtDate {
            return date.localeDescription
        } else {
            return "Unknown"
        }
    }
}

extension FlarumUserBadge: Hashable {
    static func == (lhs: FlarumUserBadge, rhs: FlarumUserBadge) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
