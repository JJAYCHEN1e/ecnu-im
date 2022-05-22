//
//  AllDiscussionsView.swift
//  ecnu-im
//
//  Created by 陈俊杰 on 2022/3/25.
//

import Combine
import SwiftUI
import SwiftUIPullToRefresh

enum BrowseCategory: String, CaseIterable, Identifiable, Hashable {
    case twitter
    case cards
    var id: String { rawValue }
}

// TODO: Navigation header should be extracted as a general component later.
struct AllDiscussionsViewNavigationHeader: View {
    @EnvironmentObject var uiKitEnvironment: UIKitEnvironment
    @Binding var selectedMode: BrowseCategory

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                Button {
                    uiKitEnvironment.splitVC?.pop(from: uiKitEnvironment.nvc)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .regular, design: .rounded))
                        .foregroundColor(.primary.opacity(0.8))
                }

                Spacer(minLength: 0)
                Text("最新话题")
                    .font(.system(size: 19, weight: .bold))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .overlay(
                Picker("模式", selection: $selectedMode) {
                    Text("推文")
                        .tag(BrowseCategory.twitter)
                    Text("卡片")
                        .tag(BrowseCategory.cards)
                }
                .pickerStyle(SegmentedPickerStyle())
                .fixedSize()
                .padding(.trailing, 8),
                alignment: .trailing
            )
        }
        .background(Color(uiColor: .secondarySystemBackground))
        .overlay(
            Rectangle()
                .foregroundColor(.primary.opacity(0.2))
                .frame(height: 0.5),
            alignment: .bottomTrailing
        )
    }
}

struct AllDiscussionsView: View {
    struct ViewModelWithMode: Hashable {
        static func == (lhs: AllDiscussionsView.ViewModelWithMode, rhs: AllDiscussionsView.ViewModelWithMode) -> Bool {
            lhs.mode == rhs.mode && lhs.viewModel.discussion.id == rhs.viewModel.discussion.id
        }

        var mode: BrowseCategory
        var viewModel: DiscussionListCellViewModel

        func hash(into hasher: inout Hasher) {
            hasher.combine(mode)
            hasher.combine(viewModel.discussion.id)
        }
    }

    struct ModeWithID: Hashable {
        var mode: BrowseCategory
        var id: Int
    }

    private let pageItemLimit = 20
    @State private var discussionList: [DiscussionListCellViewModel] = []
    @State private var pageOffset = 0
    @State private var loadInfo = AllDiscussionLoadInfo()

    @State private var subscriptions: Set<AnyCancellable> = []

    @State private var selectedMode: BrowseCategory = .cards

    @ObservedObject var appGlobalState = AppGlobalState.shared

    private var bottomSeparator: some View {
        Rectangle()
            .foregroundColor(.primary.opacity(0.2))
            .frame(height: 0.5)
    }

    var body: some View {
        ScrollViewReader { proxy in
            List {
                if discussionList.count > 0 {
                    switch selectedMode {
                    case .twitter:
                        let viewModelWithModeList = discussionList.map { ViewModelWithMode(mode: .twitter, viewModel: $0) }
                        ForEach(Array(zip(viewModelWithModeList.indices, viewModelWithModeList)), id: \.1) { index, viewModelWithMode in
                            let viewModel = viewModelWithMode.viewModel
                            let discussion = viewModel.discussion
                            let isHidden = discussion.isHidden
                            let ignored = appGlobalState.ignoredUserIds.contains(viewModel.discussion.starter?.id ?? "")
                            DiscussionListCell(viewModel: viewModel)
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                                .dimmedOverlay(ignored: .constant(ignored), isHidden: .constant(isHidden))
                                .id(ModeWithID(mode: .twitter, id: index))
                                .onAppear {
                                    checkLoadMore(index)
                                }
                        }
                    case .cards:
                        let viewModelWithModeList = discussionList.map { ViewModelWithMode(mode: .cards, viewModel: $0) }
                        ForEach(Array(zip(viewModelWithModeList.indices, viewModelWithModeList)), id: \.1) { index, viewModelWithMode in
                            let viewModel = viewModelWithMode.viewModel
                            let discussion = viewModel.discussion
                            let isHidden = discussion.isHidden
                            let ignored = appGlobalState.ignoredUserIds.contains(viewModel.discussion.starter?.id ?? "")
                            DiscussionListCardCell(viewModel: viewModel)
                                .listRowSeparatorTint(.clear, edges: .all)
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                                .dimmedOverlay(ignored: .constant(ignored), isHidden: .constant(isHidden))
                                .id(ModeWithID(mode: .cards, id: index))
                                .onAppear {
                                    checkLoadMore(index)
                                }
                        }
                    }
                } else {
                    ForEach(0 ..< 10) { _ in
                        DiscussionListCellPlaceholder()
                            .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
                            .listRowBackground(Color.clear)
                    }
                }
            }
            .listStyle(.plain)
            .background(ThemeManager.shared.theme.backgroundColor1)
            .safeAreaInset(edge: .top, content: {
                AllDiscussionsViewNavigationHeader(selectedMode: $selectedMode)
            })
            .refreshable(action: {
                await loadMore(isRefresh: true)
            })
            .onLoad {
                AppGlobalState.shared.$tokenPrepared.sink { change in
                    Task {
                        await loadMore(isRefresh: true)
                    }
                }.store(in: &subscriptions)
            }
            .onChange(of: selectedMode) { newValue in
                proxy.scrollTo(ModeWithID(mode: newValue, id: 0), anchor: .top)
            }
        }
    }
}

private actor AllDiscussionLoadInfo {
    var isLoading = false
    func shouldLoad() -> Bool {
        let should = !isLoading
        if should {
            isLoading = true
        }
        return should
    }

    func finishLoad() {
        isLoading = false
    }
}

extension AllDiscussionsView {
    func checkLoadMore(_ i: Int) {
        if i == discussionList.count - 10 || i == discussionList.count - 1 {
            Task {
                await loadMore()
            }
        }
    }

    func loadMore(isRefresh: Bool = false) async {
        guard await loadInfo.shouldLoad() else { return }

        if isRefresh {
            pageOffset = 0
            discussionList.removeAll()
        }

        if let response = try? await flarumProvider.request(.allDiscussions(pageOffset: pageOffset, pageItemLimit: pageItemLimit)).flarumResponse() {
            let newDiscussions = response.data.discussions.sorted { d1, d2 in
                if let id1 = d1.lastPost?.id, let id2 = d2.lastPost?.id {
                    return id1 > id2
                }
                return false
            }.map { DiscussionListCellViewModel(discussion: $0) }
            for newDiscussion in newDiscussions {
                Task {
                    if let users = DiscussionUserStorage.shared.discussionUsers(for: newDiscussion.discussion.id),
                       users.count >= 5 || users.count == newDiscussion.discussion.attributes?.participantCount {
                        withAnimation {
                            newDiscussion.relatedUsers = Array(users)
                        }
                    } else {
                        if let id = Int(newDiscussion.discussion.id),
                           let response = try? await flarumProvider.request(.posts(discussionID: id, offset: 0, limit: 15)).flarumResponse() {
                            let users = response.data.posts.compactMap { $0.author }
                            let filteredUsers = Array(users.unique { $0.id }.prefix(5))
                            DiscussionUserStorage.shared.store(discussionUsers: filteredUsers, id: newDiscussion.discussion.id)
                            withAnimation {
                                newDiscussion.relatedUsers = filteredUsers
                            }
                        }
                    }
                }
                Task {
                    let ids = [newDiscussion.discussion.lastPost?.id, newDiscussion.discussion.firstPost?.id].compactMap { $0 }.compactMap { Int($0) }
                    if ids.count > 0,
                       let response = try? await flarumProvider.request(.postsByIds(ids: ids, includes: [.user, .likes, .mentionedBy_User])).flarumResponse() {
                        for post in response.data.posts {
                            if post.id == newDiscussion.discussion.lastPost?.id {
                                DispatchQueue.main.async {
                                    newDiscussion.completedLastPost = post
                                }
                            } else if post.id == newDiscussion.discussion.firstPost?.id {
                                DispatchQueue.main.async {
                                    newDiscussion.completedFirstPost = post
                                }
                            }
                        }
                    }
                }
            }
            discussionList.append(contentsOf: newDiscussions)
            pageOffset += pageItemLimit
        }
        await loadInfo.finishLoad()
    }
}
