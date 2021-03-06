//
//  NotificationCenterView.swift
//  ecnu-im
//
//  Created by 陈俊杰 on 2022/5/11.
//

import Combine
import SwiftUI

private class NotificationCenterViewLoadInfo {
    var task: Task<Void, Never>?
    let limit: Int = 30
    var loadingOffset: Int = 0
    var isLoading = false
}

class NotificationCenterViewModel: ObservableObject {
    @Published var notifications: [FlarumNotification] = []
}

struct NotificationCenterView: View {
    @ObservedObject private var viewModel = NotificationCenterViewModel()
    @State private var subscriptions: Set<AnyCancellable> = []
    @State private var hasScrolled = false
    @State private var loadInfo = NotificationCenterViewLoadInfo()
    @ObservedObject var appGlobalState = AppGlobalState.shared

    @State private var appeared = false
    @State private var task: Task<Void, Error>?

    @State private var sequenceQueue = DispatchQueue(label: "NotificationCenterViewLoadQueue")

    var body: some View {
        Group {
            if viewModel.notifications.count > 0 {
                List {
                    ForEach(Array(zip(viewModel.notifications.indices, viewModel.notifications)), id: \.1) { index, notification in
                        let ignored: Bool = {
                            if let user = notification.relationships?.fromUser {
                                if appGlobalState.ignoredUserIds.contains(user.id) {
                                    return true
                                }
                            }
                            return false
                        }()
                        NotificationView(notification: .constant(notification))
                            .listRowInsets(EdgeInsets())
                            .background(
                                Group {
                                    if index == 0 {
                                        scrollDetector
                                    }
                                },
                                alignment: .topLeading
                            )
                            .dimmedOverlay(ignored: .constant(ignored), isHidden: .constant(false))
                            .onAppear {
                                checkLoadMore(index)
                            }
                    }
                }
                .listStyle(.plain)
                .coordinateSpace(name: "scroll")
                .refreshable {
                    load(isRefresh: true)
                }
            } else {
                Color.clear
            }
        }
        .safeAreaInset(edge: .top) {
            header
        }
        .onLoad {
            AppGlobalState.shared.$tokenPrepared.sink { change in
                load(isRefresh: true)
            }.store(in: &subscriptions)
        }
        .onAppear {
            appeared = true
            tryToStartReadNotificationTask()
        }
        .onDisappear {
            appeared = false
            task?.cancel()
            task = nil
        }
    }

    private func tryToStartReadNotificationTask() {
        if appGlobalState.autoClearUnreadNotification.value, viewModel.notifications.contains(where: { $0.attributes.isRead == false }) {
            task?.cancel()
            task = nil
            task = Task {
                try await Task.sleep(nanoseconds: 3_000_000_000)
                guard !Task.isCancelled else { return }
                if let _ = try? await flarumProvider.request(.readNotifications) {
                    guard !Task.isCancelled else { return }
                    DispatchQueue.main.async {
                        appGlobalState.unreadNotificationCount = 0
                        appGlobalState.clearNotificationEvent.send()
                        viewModel.notifications.indices.forEach { index in
                            withAnimation {
                                viewModel.notifications[index].attributes.isRead = true
                            }
                        }
                        Toast.default(icon: .emoji("✔️"), title: "已自动已读通知").show()
                    }
                }
            }
        }
    }

    private func checkLoadMore(_ i: Int) {
        if i == viewModel.notifications.count - 10 || i == viewModel.notifications.count - 1 {
            load()
        }
    }

    func load(isRefresh: Bool = false) {
        sequenceQueue.async {
            if isRefresh {
                loadInfo.task?.cancel()
                loadInfo.task = nil
                loadInfo.loadingOffset = 0
                loadInfo.isLoading = true
                withAnimation {
                    DispatchQueue.main.sync {
                        viewModel.notifications = []
                    }
                }
            } else {
                if loadInfo.isLoading {
                    return
                } else {
                    loadInfo.isLoading = true
                }
            }

            let loadInfo = self.loadInfo
            loadInfo.task = Task {
                if let response = try? await flarumProvider.request(.notification(offset: loadInfo.loadingOffset, limit: loadInfo.limit)).flarumResponse() {
                    guard !Task.isCancelled else { return }
                    withAnimation {
                        let isFirstTimeLoad = self.viewModel.notifications.count == 0
                        self.viewModel.notifications.append(contentsOf: response.data.notifications)
                        if isFirstTimeLoad, response.data.notifications.count != 0 {
                            tryToStartReadNotificationTask()
                        }
                    }
                    guard !Task.isCancelled else { return }
                    sequenceQueue.async {
                        guard !Task.isCancelled else { return }
                        loadInfo.loadingOffset += loadInfo.limit
                        loadInfo.isLoading = false
                    }
                }
            }
        }
    }

    var scrollDetector: some View {
        GeometryReader { proxy in
            Color.clear.preference(key: ScrollPreferenceKey.self, value: proxy.frame(in: .named("scroll")).minY)
        }
        .onPreferenceChange(ScrollPreferenceKey.self) { value in
            withAnimation(.easeInOut(duration: 0.3)) {
                if value < 70 {
                    hasScrolled = true
                } else {
                    hasScrolled = false
                }
            }
        }
        .frame(height: 0)
    }

    var header: some View {
        ZStack {
            Text("通知中心")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(.teal)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading)
                .padding(.top, 20)

            Button {
                Task {
                    if let _ = try? await flarumProvider.request(.readNotifications) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            appGlobalState.unreadNotificationCount = 0
                            appGlobalState.clearNotificationEvent.send()
                            load(isRefresh: true)
                        }
                    }
                }
            } label: {
                HStack(spacing: 16) {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.bold))
                        .frame(width: 36, height: 36)
                        .foregroundColor(.secondary)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .modifier(OutlineOverlay(cornerRadius: 14))
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 20)
                .padding(.top, 20)
            }
        }
        .background(
            Color.clear
                .background(.ultraThinMaterial)
                .blur(radius: 10)
                .opacity(hasScrolled ? 1 : 0)
        )
        .frame(alignment: .top)
    }
}

struct NotificationCenterView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationCenterView()
    }
}
