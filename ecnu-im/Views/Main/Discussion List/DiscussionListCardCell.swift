//
//  DiscussionListCardCell.swift
//  ecnu-im
//
//  Created by 陈俊杰 on 2022/5/18.
//

import SwiftUI

struct DiscussionListCardCell: View {
    @ObservedObject private var viewModel: DiscussionListCellViewModel
    @EnvironmentObject var uiKitEnvironment: UIKitEnvironment

    init(viewModel: DiscussionListCellViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        Button {
            let near = viewModel.discussion.attributes?.lastPostNumber ?? 1
            uiKitEnvironment.splitVC?.push(viewController: DiscussionViewController(discussion: viewModel.discussion, nearNumber: near),
                                           column: .secondary,
                                           toRoot: true)
        } label: {
            Group {
                VStack(spacing: 4) {
                    HStack(alignment: .top) {
                        PostAuthorAvatarView(name: viewModel.discussion.starterName, url: viewModel.discussion.starterAvatarURL, size: 40)
                            .mask(Circle())
                            .overlay(Circle().stroke(Color.white, lineWidth: 1))
                            .overlay(
                                Group {
                                    if viewModel.discussion.firstPost?.id != viewModel.discussion.lastPost?.id {
                                        PostAuthorAvatarView(name: viewModel.discussion.lastPostedUserName, url: viewModel.discussion.lastPostedUserAvatarURL, size: 25)
                                            .mask(Circle())
                                            .overlay(Circle().stroke(Color.white, lineWidth: 1))
                                            .overlay(
                                                Color.primary.opacity(0.001)
                                                    .offset(x: 10, y: 10)
                                                    .onTapGesture {
                                                        if let targetId = viewModel.discussion.lastPostedUser?.id {
                                                            if let account = AppGlobalState.shared.account,
                                                               targetId != account.userIdString {
                                                                UIApplication.shared.presentOnTop(ProfileCenterViewController(userId: targetId), animated: true)
                                                            } else {
                                                                let number = viewModel.discussion.attributes?.lastPostNumber ?? 1
                                                                uiKitEnvironment.splitVC?.push(viewController: DiscussionViewController(discussion: viewModel.discussion, nearNumber: number),
                                                                                               column: .secondary,
                                                                                               toRoot: true)
                                                            }
                                                        }
                                                    }
                                            )
                                            .offset(x: 5, y: 0)
                                    }
                                },
                                alignment: .bottomTrailing
                            )
                            .onTapGesture {
                                if let account = AppGlobalState.shared.account,
                                   let targetId = viewModel.discussion.starter?.id,
                                   targetId != account.userIdString {
                                    UIApplication.shared.presentOnTop(ProfileCenterViewController(userId: targetId), animated: true)
                                }
                            }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(viewModel.discussion.discussionTitle)
                                .lineLimit(1)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(Asset.SpecialColors.cardTitleColor.swiftUIColor)
                            HStack(alignment: .top, spacing: 2) {
                                HStack(alignment: .center, spacing: 2) {
                                    Text(viewModel.discussion.lastPostedUserName)
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    Text(viewModel.discussion.lastPostDateDescription)
                                        .font(.system(size: 10, weight: .regular, design: .rounded))
                                }
                                Spacer(minLength: 0)
                                DiscussionTagsView(tags: .constant(viewModel.discussion.tagViewModels))
                                    .fixedSize()
                            }
                        }
                    }
                    if let completedLastPost = viewModel.completedLastPost {
                        let configuration = ContentParser.ContentExcerpt.ContentExcerptConfiguration(textLengthMax: 500, textLineMax: 5, imageCountMax: 0)
                        if let excerptText = completedLastPost.excerptText(configuration: configuration) {
                            Text(excerptText)
                                .animation(nil)
                                .multilineTextAlignment(.leading)
                                .lineLimit(4)
                                .truncationMode(.tail)
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                    }

                    HStack(spacing: 4) {
                        likeHint
                        Spacer(minLength: 0)
                        HStack(spacing: -3) {
                            ForEach(0 ..< viewModel.relatedUsers.count, id: \.self) { index in
                                let user = viewModel.relatedUsers[index]
                                PostAuthorAvatarView(name: user.attributes.displayName, url: user.avatarURL, size: 18)
                                    .mask(Circle())
                                    .overlay(Circle().stroke(Color.white, lineWidth: 0.5))
                            }
                        }
                        HStack(spacing: 1) {
                            HStack(spacing: 1) {
                                Image(systemName: "eye")
                                    .font(.system(size: 10))
                                    .frame(width: 16, height: 16)
                                Text("\(viewModel.discussion.viewCount)")
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                            }
                            HStack(spacing: 1) {
                                Image(systemName: "message")
                                    .font(.system(size: 10))
                                    .frame(width: 16, height: 16)
                                Text("\(viewModel.discussion.commentCount)")
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                            }
                        }
                    }
                    .frame(height: 18)
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 6)
                .background(.ultraThinMaterial)
                .backgroundStyle(cornerRadius: 15, opacity: 0.3)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    var likeHint: some View {
        Group {
            if let likesUsers = viewModel.completedLastPost?.relationships?.likes,
               likesUsers.count > 0 {
                let threshold = 3
                let likesUserName = likesUsers.prefix(threshold).map { $0.attributes.displayName }.joined(separator: ", ")
                    + "\(likesUsers.count > 3 ? "等\(likesUsers.count)人" : "")"
                Group {
                    (Text(Image(systemName: "heart.fill")) + Text(" \(likesUserName)觉得很赞"))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.primary.opacity(0.8))
                }
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.primary.opacity(0.8))
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.1))
                .cornerRadius(4)
                .onTapGesture {
                    UIApplication.shared.presentOnTop(LikeListViewController(users: likesUsers))
                }
            }
        }
    }
}
