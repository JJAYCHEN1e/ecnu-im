//
//  FlarumResponse.swift
//  ecnu-im
//
//  Created by 陈俊杰 on 2022/4/23.
//

import Foundation
import SwiftUI
import SwiftyJSON

struct FlarumResponse {
    struct FlarumResponseData {
        var allData: [FlarumData] = []
        var discussions: [FlarumDiscussion] = []
        var posts: [FlarumPost] = []
        var users: [FlarumUser] = []
        var tags: [FlarumTag] = []
        var postReactions: [FlarumPostReaction] = []
        var notifications: [FlarumNotification] = []
        var badges: [FlarumBadge] = []
        var badgeCategories: [FlarumBadgeCategory] = []
        var userBadges: [FlarumUserBadge] = []
        var profileAnswers: [FlarumProfileAnswer] = []

        init(_ i: FlarumResponseReference.FlarumResponseData) {
            allData = i.allData.map { .init($0) }
            discussions = i.discussions.map { .init($0) }
            posts = i.posts.map { .init($0) }
            users = i.users.map { .init($0) }
            tags = i.tags.map { .init($0) }
            postReactions = i.postReactions.map { .init($0) }
            notifications = i.notifications.map { .init($0) }
            badges = i.badges.map { .init($0) }
            badgeCategories = i.badgeCategories.map { .init($0) }
            userBadges = i.userBadges.map { .init($0) }
            profileAnswers = i.profileAnswers.map { .init($0) }
        }
    }

    var links: FlarumLinks?
    var data: FlarumResponseData
    var included: FlarumResponseData

    init(_ i: FlarumResponseReference) {
        links = i.links
        data = .init(i.data)
        included = .init(i.included)
    }
}

struct FlarumResponseReference {
    struct FlarumResponseData {
        var allData: [FlarumDataReference] = []
        var discussions: [FlarumDiscussionReference] = []
        var posts: [FlarumPostReference] = []
        var users: [FlarumUserReference] = []
        var tags: [FlarumTagReference] = []
        var postReactions: [FlarumPostReactionReference] = []
        var notifications: [FlarumNotificationReference] = []
        var badges: [FlarumBadgeReference] = []
        var badgeCategories: [FlarumBadgeCategoryReference] = []
        var userBadges: [FlarumUserBadgeReference] = []
        var profileAnswers: [FlarumProfileAnswerReference] = []
    }

    var links: FlarumLinks?
    var data: FlarumResponseData
    var included: FlarumResponseData

    init(json: JSON) {
        links = json["links"].decode(FlarumLinks.self)
        data = .init()
        included = .init()

        let includedFirst = parseData(json: json["included"])
        // Not all relationships are included in data section!
        // For example, when you request for discussions list, in the data section,
        //  a discussion only has relationship info between itself and tags, but no
        //  relationship info between tags. That means in the data section, it only
        //  contains first level relationships.
        // We can easily tackle this problem with one more time traverse. And in the second
        //  round, we use the data extracted from last round first.
        // TODO: It seems 2 round traversing is insufficient? We should use reference
        //  type for all root types.
        let included = parseData(json: json["included"], withRelationship: true, includedData: includedFirst)
        self.included = included
        data = parseData(json: json["data"], withRelationship: true, includedData: included, isData: true)
    }

    private func parseData(json: JSON, withRelationship: Bool = false, includedData: FlarumResponseData? = nil, isData: Bool = false) -> FlarumResponseData {
        var responseData = FlarumResponseData()
        var jsonArray: [JSON] = []
        if let dataJSONArray = json.array {
            jsonArray.append(contentsOf: dataJSONArray)
        } else {
            jsonArray.append(json)
        }

        for dataJSON in jsonArray {
            // Different type's attributes
            if let dataType = FlarumDataType(rawValue: dataJSON["type"].string ?? "") {
                switch dataType {
                case .discussion:
                    if let id = dataJSON["id"].string {
                        let discussion: FlarumDiscussionReference
                        if !isData, let _discussion = includedData?.discussions.first(where: { $0.id == id }) {
                            discussion = _discussion
                        } else {
                            discussion = FlarumDiscussionReference(id: id)
                            discussion.attributes = dataJSON["attributes"].decode(FlarumDiscussionAttributes.self)
                            if isData, let _discussion = includedData?.discussions.first(where: { $0.id == id }) {
                                discussion.relationships = _discussion.relationships
                            }
                        }
                        if withRelationship, let includedData = includedData {
                            var relationships = FlarumDiscussionRelationshipsReference()
                            if let dic = dataJSON["relationships"].dictionary {
                                for relationship in FlarumDiscussionRelationships.Relationship.allCases {
                                    switch relationship {
                                    case .user:
                                        if let userId = dic["user"]?["data"]["id"].string {
                                            relationships.user = includedData.users.first(where: { $0.id == userId })
                                        }
                                    case .lastPostedUser:
                                        if let userId = dic["lastPostedUser"]?["data"]["id"].string {
                                            relationships.lastPostedUser = includedData.users.first(where: { $0.id == userId })
                                        }
                                    case .firstPost:
                                        if let postId = dic["firstPost"]?["data"]["id"].string {
                                            relationships.firstPost = includedData.posts.first(where: { $0.id == postId })
                                        }
                                    case .lastPost:
                                        if let postId = dic["lastPost"]?["data"]["id"].string {
                                            relationships.lastPost = includedData.posts.first(where: { $0.id == postId })
                                        }
                                    case .mostRelevantPost:
                                        if let postId = dic["mostRelevantPost"]?["data"]["id"].string {
                                            relationships.mostRelevantPost = includedData.posts.first(where: { $0.id == postId })
                                        }
                                    case .tags:
                                        if let tagIds = dic["tags"]?["data"].array?.compactMap({ $0["id"].string }) {
                                            relationships.tags = includedData.tags.filter { tagIds.contains($0.id) }
                                        }
                                    }
                                }
                            }
                            discussion.relationships = relationships
                        }
                        responseData.allData.append(.discussion(discussion))
                        responseData.discussions.append(discussion)
                    }
                case .post:
                    if let id = dataJSON["id"].string {
                        let post: FlarumPostReference
                        if !isData, let _post = includedData?.posts.first(where: { $0.id == id }) {
                            post = _post
                        } else {
                            post = FlarumPostReference(id: id)
                            var attributes = dataJSON["attributes"]
                            if attributes["content"].exists() {
                                if let contentType = FlarumPostAttributes.FlarumPostContentType(rawValue: attributes["contentType"].string ?? "") {
                                    switch contentType {
                                    case .comment:
                                        var json = JSON()
                                        json["_0"] = attributes["content"]
                                        attributes["content"] = JSON(dictionaryLiteral: ("comment", json))
                                    case .discussionRenamed:
                                        var json = JSON()
                                        json["_0"] = attributes["content"]
                                        attributes["content"] = JSON(dictionaryLiteral: ("discussionRenamed", json))
                                    case .discussionTagged:
                                        var json = JSON()
                                        json["_0"] = attributes["content"]
                                        attributes["content"] = JSON(dictionaryLiteral: ("discussionTagged", json))
                                    case .discussionLocked:
                                        var json = JSON()
                                        json["_0"] = attributes["content"]["locked"]
                                        attributes["content"] = JSON(dictionaryLiteral: ("discussionLocked", json))
                                    }
                                } else {
                                    debugExecution {
                                        let whitelist = ["discussionStickied", "discussionSuperStickied", "discussionMerged", "recipientsModified"]
                                        if let contentType = attributes["contentType"].string,
                                           !whitelist.contains(contentType) {
                                            fatalErrorDebug("\(contentType) is not in the whitelist.")
                                        }
                                    }
                                    attributes = attributes.removing(key: "content")
                                    attributes = attributes.removing(key: "contentType")
                                }
                            }
                            post.attributes = attributes.decode(FlarumPostAttributes.self)
                            if isData, let _post = includedData?.posts.first(where: { $0.id == id }) {
                                post.relationships = _post.relationships
                            }
                        }
                        if withRelationship, let includedData = includedData {
                            var relationships = FlarumPostRelationshipsReference()
                            for relationship in FlarumPostRelationshipsReference.Relationship.allCases {
                                switch relationship {
                                case .discussion:
                                    if let discussionId = dataJSON["relationships"]["discussion"]["data"]["id"].string {
                                        relationships.discussion = includedData.discussions.first(where: { $0.id == discussionId })
                                    }
                                case .user:
                                    if let userId = dataJSON["relationships"]["user"]["data"]["id"].string {
                                        relationships.user = includedData.users.first(where: { $0.id == userId })
                                    }
                                case .reactions:
                                    if let reactionIds = dataJSON["relationships"]["reactions"]["data"].array?.compactMap({ $0["post_reactions"].string }) {
                                        relationships.reactions = includedData.postReactions.filter { reactionIds.contains($0.id) }
                                    }
                                case .likes:
                                    if let likeIds = dataJSON["relationships"]["likes"]["data"].array?.compactMap({ $0["id"].string }) {
                                        relationships.likes = includedData.users.filter { likeIds.contains($0.id) }
                                    }
                                case .mentionedBy:
                                    if let mentionedByIds = dataJSON["relationships"]["mentionedBy"]["data"].array?.compactMap({ $0["id"].string }) {
                                        relationships.mentionedBy = includedData.posts.filter { mentionedByIds.contains($0.id) }
                                    }
                                }
                            }
                            post.relationships = relationships
                        }
                        responseData.allData.append(.post(post))
                        responseData.posts.append(post)
                    }
                case .user:
                    if let id = dataJSON["id"].string {
                        var user: FlarumUserReference?
                        if !isData, let _user = includedData?.users.first(where: { $0.id == id }) {
                            user = _user
                        } else {
                            if let attributes = dataJSON["attributes"].decode(FlarumUserAttributes.self) {
                                user = FlarumUserReference(id: id, attributes: attributes)
                                if isData, let _user = includedData?.users.first(where: { $0.id == id }) {
                                    user?.relationships = _user.relationships
                                }
                            }
                        }
                        if let user = user {
                            if withRelationship, let includedData = includedData {
                                var userBadges: [FlarumUserBadgeReference] = []
                                if let badgeIds = dataJSON["relationships"]["badges"]["data"].array?.compactMap({ $0["id"].string }) {
                                    userBadges = includedData.userBadges.filter { badgeIds.contains($0.id) }
                                }
                                var profileAnswers: [FlarumProfileAnswerReference] = []
                                if let profileAnswerIds = dataJSON["relationships"]["masqueradeAnswers"]["data"].array?.compactMap({ $0["id"].string }) {
                                    profileAnswers = includedData.profileAnswers.filter { profileAnswerIds.contains($0.id) }
                                }
                                var ignoredUsers: [FlarumUserReference] = []
                                if let ignoredUserIds = dataJSON["relationships"]["ignoredUsers"]["data"].array?.compactMap({ $0["id"].string }) {
                                    ignoredUsers = includedData.users.filter { ignoredUserIds.contains($0.id) }
                                }
                                user.relationships = FlarumUserRelationshipsReference(userBadges: userBadges, profileAnswers: profileAnswers, ignoredUsers: ignoredUsers)
                            }
                            responseData.allData.append(.user(user))
                            responseData.users.append(user)
                        }
                    }
                case .tag:
                    if let id = dataJSON["id"].string {
                        var tag: FlarumTagReference?
                        if !isData, let _tag = includedData?.tags.first(where: { $0.id == id }) {
                            tag = _tag
                        } else {
                            if let tagAttributes = dataJSON["attributes"].decode(FlarumTagAttributes.self) {
                                tag = FlarumTagReference(id: id, attributes: tagAttributes)
                                if isData, let _tag = includedData?.tags.first(where: { $0.id == id }) {
                                    tag?.relationships = _tag.relationships
                                }
                            }
                        }
                        if let tag = tag {
                            if withRelationship, let includedData = includedData {
                                var relationships = FlarumTagRelationshipsReference()
                                if let parentId = dataJSON["relationships"]["parent"]["data"]["id"].string {
                                    if let parentTag = includedData.tags.first(where: { $0.id == parentId }) {
                                        relationships.parent = parentTag
                                    }
                                    tag.relationships = relationships
                                }
                            }
                            responseData.allData.append(.tag(tag))
                            responseData.tags.append(tag)
                        }
                    }
                case .postReaction:
                    if let id = dataJSON["id"].string {
                        if let userId = dataJSON["attributes"]["userId"].string,
                           let postId = dataJSON["attributes"]["postId"].string,
                           let reactionId = dataJSON["attributes"]["reactionId"].string,
                           let user = includedData?.users.first(where: { userId == $0.id }),
                           let post = includedData?.posts.first(where: { postId == $0.id }),
                           let reaction = FlarumReactionsPublisher.shared.allReactions.first(where: { reactionId == $0.id }) {
                            let postReaction = FlarumPostReactionReference(id: id, attributes: .init(user: user, post: post, reaction: reaction))
                            responseData.allData.append(.postReaction(postReaction))
                            responseData.postReactions.append(postReaction)
                        }
                    }
                case .notification:
                    if let id = dataJSON["id"].string {
                        var notification: FlarumNotificationReference?
                        if !isData, let _notification = includedData?.notifications.first(where: { $0.id == id }) {
                            notification = _notification
                        } else {
                            var attributes = dataJSON["attributes"]
                            if attributes["content"].exists() {
                                if let contentType = FlarumNotificationAttributes.FlarumNotificationContentType(rawValue: attributes["contentType"].string ?? "") {
                                    switch contentType {
                                    case .postLiked:
                                        attributes["content"] = JSON([
                                            "postLiked": [:],
                                        ])
                                    case .postMentioned:
                                        attributes["content"] = JSON([
                                            "postMentioned": attributes["content"],
                                        ])
                                    case .userMentioned:
                                        attributes["content"] = JSON([
                                            "userMentioned": [:],
                                        ])
                                    case .postReacted:
                                        if let reactionString = attributes["content"].string {
                                            var json = JSON(parseJSON: reactionString)

                                            if json["enabled"] == 1 {
                                                json["enabled"] = true
                                            } else if json["enabled"] == 0 {
                                                json["enabled"] = false
                                            }

                                            if let id = json["id"].int,
                                               let reactionAtt = json.decode(FlarumReactionAttributes.self) {
                                                let reaction = FlarumReaction(id: "\(id)", attributes: reactionAtt)
                                                if let data = try? JSONEncoder().encode(FlarumNotificationAttributes.FlarumNotificationContent.postReacted(reaction: reaction)) {
                                                    let json = JSON(data)
                                                    attributes["content"] = json
                                                }
                                            }
                                        }
                                    case .badgeReceived:
                                        attributes["content"] = JSON([
                                            "badgeReceived": [:],
                                        ])
                                    case .newPost:
                                        attributes["content"] = JSON([
                                            "newPost": attributes["content"],
                                        ])
                                    case .privateDiscussionReplied:
                                        attributes["content"] = JSON([
                                            "privateDiscussionReplied": attributes["content"],
                                        ])
                                    case .privateDiscussionCreated:
                                        attributes["content"] = JSON([
                                            "privateDiscussionCreated": [:],
                                        ])
                                    case .privateDiscussionAdded:
                                        attributes["content"] = JSON([
                                            "privateDiscussionAdded": [:],
                                        ])
                                    }
                                } else {
                                    debugExecution {
                                        let whitelist: [String] = []
                                        if let contentType = attributes["contentType"].string,
                                           !whitelist.contains(contentType) {
                                            fatalErrorDebug("\(contentType) is not in the whitelist.")
                                        }
                                    }
                                    attributes = attributes.removing(key: "content")
                                    attributes = attributes.removing(key: "contentType")
                                }
                                if let attributes = attributes.decode(FlarumNotificationAttributes.self) {
                                    notification = FlarumNotificationReference(id: id, attributes: attributes)
                                    if isData, let _notification = includedData?.notifications.first(where: { $0.id == id }) {
                                        notification?.relationships = _notification.relationships
                                    }
                                }
                            }
                        }
                        if let notification = notification {
                            if withRelationship, let includedData = includedData {
                                if let subjectType = FlarumNotificationRelationshipsReference.SubjectType(rawValue:
                                    dataJSON["relationships"]["subject"]["data"]["type"].string ?? ""
                                ) {
                                    var fromUser: FlarumUserReference?
                                    if let userId = dataJSON["relationships"]["fromUser"]["data"]["id"].string,
                                       let user = includedData.users.first(where: { $0.id == userId }) {
                                        fromUser = user
                                    }
                                    switch subjectType {
                                    case .post:
                                        if let postId = dataJSON["relationships"]["subject"]["data"]["id"].string,
                                           let post = includedData.posts.first(where: { $0.id == postId }) {
                                            let relationships = FlarumNotificationRelationshipsReference(fromUser: fromUser, subject: .post(post: post))
                                            notification.relationships = relationships
                                        }
                                    case .discussion:
                                        if let discussionId = dataJSON["relationships"]["subject"]["data"]["id"].string,
                                           let discussion = includedData.discussions.first(where: { $0.id == discussionId }) {
                                            let relationships = FlarumNotificationRelationshipsReference(fromUser: fromUser, subject: .discussion(discussion: discussion))
                                            notification.relationships = relationships
                                        }
                                    case .userBadge:
                                        if let userBadgeId = dataJSON["relationships"]["subject"]["data"]["id"].string,
                                           let userBadgeId = Int(userBadgeId) {
                                            let relationships = FlarumNotificationRelationshipsReference(subject: .userBadge(userBadgeId: userBadgeId))
                                            notification.relationships = relationships
                                        }
                                    }
                                } else {
                                    debugExecution {
                                        let whitelist: [String] = []
                                        if let subjectType = dataJSON["relationships"]["subject"]["data"]["type"].string,
                                           !whitelist.contains(subjectType) {
                                            fatalErrorDebug("\(subjectType) is not in the whitelist.")
                                        }
                                    }
                                }
                            }
                            responseData.allData.append(.notification(notification))
                            responseData.notifications.append(notification)
                        }
                    }
                case .badge:
                    if let id = dataJSON["id"].string {
                        var badge: FlarumBadgeReference?
                        if !isData, let _badge = includedData?.badges.first(where: { $0.id == id }) {
                            badge = _badge
                        } else {
                            if let attributes = dataJSON["attributes"].decode(FlarumBadgeAttributes.self) {
                                badge = FlarumBadgeReference(id: id, attributes: attributes)
                                if isData, let _badge = includedData?.badges.first(where: { $0.id == id }) {
                                    badge?.relationships = _badge.relationships
                                }
                            }
                        }
                        if let badge = badge {
                            if withRelationship, let includedData = includedData {
                                if let categoryId = dataJSON["relationships"]["category"]["data"]["id"].string {
                                    if let category = includedData.badgeCategories.first(where: { $0.id == categoryId }) {
                                        let relationships = FlarumBadgeRelationshipsReference(category: category)
                                        badge.relationships = relationships
                                    }
                                }
                            }
                            responseData.allData.append(.badge(badge))
                            responseData.badges.append(badge)
                        }
                    }
                case .badgeCategory:
                    if let id = dataJSON["id"].string {
                        var badgeCategory: FlarumBadgeCategoryReference?
                        if !isData, let _badgeCategory = includedData?.badgeCategories.first(where: { $0.id == id }) {
                            badgeCategory = _badgeCategory
                        } else {
                            if let attributes = dataJSON["attributes"].decode(FlarumBadgeCategoryAttributes.self) {
                                badgeCategory = FlarumBadgeCategoryReference(id: id, attributes: attributes)
                                if isData, let _badgeCategory = includedData?.badgeCategories.first(where: { $0.id == id }) {
                                    badgeCategory?.relationships = _badgeCategory.relationships
                                }
                            }
                        }
                        if let badgeCategory = badgeCategory {
                            if withRelationship, let includedData = includedData {
                                if let badgeIds = dataJSON["relationships"]["badges"]["data"].array?.compactMap({ $0["id"].string }) {
                                    let badges = includedData.badges.filter { badgeIds.contains($0.id) }
                                    let relationships = FlarumBadgeCategoryRelationshipsReference(badges: badges)
                                    badgeCategory.relationships = relationships
                                }
                            }
                            responseData.allData.append(.badgeCategory(badgeCategory))
                            responseData.badgeCategories.append(badgeCategory)
                        }
                    }
                case .userBadge:
                    if let id = dataJSON["id"].string {
                        var userBadge: FlarumUserBadgeReference?
                        if !isData, let _userBadge = includedData?.userBadges.first(where: { $0.id == id }) {
                            userBadge = _userBadge
                        } else {
                            if let attributes = dataJSON["attributes"].decode(FlarumUserBadgeAttributes.self) {
                                userBadge = FlarumUserBadgeReference(id: id, attributes: attributes)
                                if isData, let _userBadge = includedData?.userBadges.first(where: { $0.id == id }) {
                                    userBadge?.relationships = _userBadge.relationships
                                }
                            }
                        }
                        if let userBadge = userBadge {
                            if withRelationship, let includedData = includedData {
                                if let badgeId = dataJSON["relationships"]["badge"]["data"]["id"].string {
                                    if let badge = includedData.badges.first(where: { $0.id == badgeId }) {
                                        let relationships = FlarumUserBadgeRelationshipsReference(badge: badge)
                                        userBadge.relationships = relationships
                                    }
                                }
                            }
                            responseData.allData.append(.userBadge(userBadge))
                            responseData.userBadges.append(userBadge)
                        }
                    }
                case .profileAnswer:
                    if let id = dataJSON["id"].string {
                        if let attributes = dataJSON["attributes"].decode(FlarumProfileAnswerAttributes.self) {
                            let profileAnswer = FlarumProfileAnswerReference(id: id, attributes: attributes)
                            responseData.allData.append(.profileAnswer(profileAnswer))
                            responseData.profileAnswers.append(profileAnswer)
                        }
                    }
                }
            }
        }

        return responseData
    }
}

enum FlarumDataType: String, RawRepresentable {
    case discussion = "discussions"
    case post = "posts"
    case user = "users"
    case tag = "tags"
    case postReaction = "post_reactions"
    case notification = "notifications"
    case badge = "badges"
    case badgeCategory = "badgeCategories"
    case userBadge = "userBadges"
    case profileAnswer = "masquerade-answer"
}

enum FlarumDataReference {
    case discussion(FlarumDiscussionReference)
    case post(FlarumPostReference)
    case user(FlarumUserReference)
    case tag(FlarumTagReference)
    case postReaction(FlarumPostReactionReference)
    case notification(FlarumNotificationReference)
    case badge(FlarumBadgeReference)
    case badgeCategory(FlarumBadgeCategoryReference)
    case userBadge(FlarumUserBadgeReference)
    case profileAnswer(FlarumProfileAnswerReference)
}

enum FlarumData {
    case discussion(FlarumDiscussion)
    case post(FlarumPost)
    case user(FlarumUser)
    case tag(FlarumTag)
    case postReaction(FlarumPostReaction)
    case notification(FlarumNotification)
    case badge(FlarumBadge)
    case badgeCategory(FlarumBadgeCategory)
    case userBadge(FlarumUserBadge)
    case profileAnswer(FlarumProfileAnswer)

    init(_ i: FlarumDataReference) {
        switch i {
        case let .discussion(flarumDiscussion):
            self = .discussion(.init(flarumDiscussion))
            return
        case let .post(flarumPost):
            self = .post(.init(flarumPost))
            return
        case let .user(flarumUser):
            self = .user(.init(flarumUser))
            return
        case let .tag(flarumTag):
            self = .tag(.init(flarumTag))
            return
        case let .postReaction(flarumPostReaction):
            self = .postReaction(.init(flarumPostReaction))
            return
        case let .notification(flarumNotification):
            self = .notification(.init(flarumNotification))
            return
        case let .badge(flarumBadge):
            self = .badge(.init(flarumBadge))
            return
        case let .badgeCategory(flarumBadgeCategory):
            self = .badgeCategory(.init(flarumBadgeCategory))
            return
        case let .userBadge(flarumUserBadge):
            self = .userBadge(.init(flarumUserBadge))
            return
        case let .profileAnswer(flarumProfileAnswer):
            self = .profileAnswer(.init(flarumProfileAnswer))
            return
        }
    }
}

extension Response {
    func flarumResponse() -> FlarumResponse {
        let json = JSON(data)
        let flarumResponseReference = FlarumResponseReference(json: json)
        return .init(flarumResponseReference)
    }
}
