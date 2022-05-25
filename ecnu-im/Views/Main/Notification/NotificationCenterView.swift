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

struct NotificationCenterView: View {
    @State private var notifications: [FlarumNotification] = []
    @State private var subscriptions: Set<AnyCancellable> = []
    @State private var hasScrolled = false
    @State private var loadInfo = NotificationCenterViewLoadInfo()
    @ObservedObject var appGlobalState = AppGlobalState.shared

    @State private var sequenceQueue = DispatchQueue(label: "NotificationCenterViewLoadQueue")

    var body: some View {
        Group {
            if notifications.count > 0 {
                List {
                    ForEach(0 ..< notifications.count, id: \.self) { index in
                        let notification = notifications[index]
                        let ignored: Bool = {
                            if let user = notification.relationships?.fromUser {
                                if appGlobalState.ignoredUserIds.contains(user.id) {
                                    return true
                                }
                            }
                            return false
                        }()
                        NotificationView(notification: notification)
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
                load()
            }.store(in: &subscriptions)
        }
    }

    private func checkLoadMore(_ i: Int) {
        if i == notifications.count - 10 || i == notifications.count - 1 {
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
                    notifications = []
                }
            } else {
                if loadInfo.isLoading {
                    return
                }
            }

            let loadInfo = self.loadInfo
            loadInfo.task = Task {
                if let response = try? await flarumProvider.request(.notification(offset: loadInfo.loadingOffset, limit: loadInfo.limit)).flarumResponse() {
                    guard !Task.isCancelled else { return }
                    withAnimation {
                        self.notifications.append(contentsOf: response.data.notifications)
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
                        appGlobalState.unreadNotificationCount = 0
                        appGlobalState.clearNotificationEvent.send()
                        load(isRefresh: true)
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
