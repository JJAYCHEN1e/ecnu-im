//
//  AppGlobalState.swift
//  ecnu-im
//
//  Created by 陈俊杰 on 2022/5/14.
//

import Combine
import Foundation
import SwiftUI

struct Account: Codable {
    var account: String
    var password: String
    var userId: Int

    var userIdString: String {
        "\(userId)"
    }
}

enum LoginError: Error {
    case networkError
}

enum LoginState {
    case notStart
    case noAccount
    case trying
    case requestFailed
    case loginFailed
    case loginSuccess
}

/// https://stackoverflow.com/a/68795484
extension Optional: RawRepresentable where Wrapped: Codable {
    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
              let json = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        return json
    }

    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let value = try? JSONDecoder().decode(Self.self, from: data)
        else {
            return nil
        }
        self = value
    }
}

class AppGlobalState: ObservableObject {
    @AppStorage("account") private(set) var account: Account? = nil

    public var blockCompletely: CurrentValueSubject<Bool, Never>
    public var themeStyleOption: CurrentValueSubject<ThemeStyleOption, Never>
    public var showRecentActiveUsers: CurrentValueSubject<Bool, Never>
    public var showRecentOnlineUsers: CurrentValueSubject<Bool, Never>
    public var showRecentRegisteredUsers: CurrentValueSubject<Bool, Never>
    public var autoClearUnreadNotification: CurrentValueSubject<Bool, Never>
    public var discussionBrowseCategory: CurrentValueSubject<BrowseCategory, Never>

    @Published var unreadNotificationCount = 0
    @Published var userInfo: FlarumUser?
    @Published var ignoredUserIds: Set<String> = []
    @Published var hasTriedToLogin = false
    @Published var token: String? = nil
    @Published var tokenPrepared = false
    @Published var loginState = LoginState.notStart

    var emailVerificationEvent = PassthroughSubject<Void, Never>()
    var clearNotificationEvent = PassthroughSubject<Void, Never>()

    private var subscriptions: Set<AnyCancellable> = []

    var userIdInt: Int? {
        if let account = account {
            return account.userId
        }
        return nil
    }

    var flarumCookie: HTTPCookie? {
        if let token = token, let flarumTokenCookie = HTTPCookie(properties: [
            HTTPCookiePropertyKey.domain: "ecnu.im",
            HTTPCookiePropertyKey.path: "/",
            HTTPCookiePropertyKey.name: "flarum_remember",
            HTTPCookiePropertyKey.value: token,
        ]) {
            return flarumTokenCookie
        }
        return nil
    }

    static let shared = AppGlobalState()

    init() {
        UserDefaults.standard.setDefaultValuesForKeys([
            "blockCompletely": false,
            "themeStyleOption": ThemeStyleOption.auto.rawValue,
            "showRecentActiveUsers": true,
            "showRecentOnlineUsers": false,
            "showRecentRegisteredUsers": false,
            "autoClearUnreadNotification": false,
            "discussionBrowseCategory": BrowseCategory.cards.rawValue,
        ])

        blockCompletely = CurrentValueSubject<Bool, Never>(UserDefaults.standard.bool(forKey: "blockCompletely"))
        themeStyleOption = {
            if let rawString = UserDefaults.standard.string(forKey: "themeStyleOption"),
               let themeStyleOption = ThemeStyleOption(rawValue: rawString) {
                return CurrentValueSubject<ThemeStyleOption, Never>(themeStyleOption)
            } else {
                return CurrentValueSubject<ThemeStyleOption, Never>(.auto)
            }
        }()
        showRecentActiveUsers = CurrentValueSubject<Bool, Never>(UserDefaults.standard.bool(forKey: "showRecentActiveUsers"))
        showRecentOnlineUsers = CurrentValueSubject<Bool, Never>(UserDefaults.standard.bool(forKey: "showRecentOnlineUsers"))
        showRecentRegisteredUsers = CurrentValueSubject<Bool, Never>(UserDefaults.standard.bool(forKey: "showRecentRegisteredUsers"))
        autoClearUnreadNotification = CurrentValueSubject<Bool, Never>(UserDefaults.standard.bool(forKey: "autoClearUnreadNotification"))
        discussionBrowseCategory = {
            if let rawString = UserDefaults.standard.string(forKey: "discussionBrowseCategory"),
               let browseCategory = BrowseCategory(rawValue: rawString) {
                return CurrentValueSubject<BrowseCategory, Never>(browseCategory)
            } else {
                return CurrentValueSubject<BrowseCategory, Never>(.cards)
            }
        }()

        blockCompletely.removeDuplicates().sink { value in
            UserDefaults.standard.set(value, forKey: "blockCompletely")
            self.objectWillChange.send()
        }
        .store(in: &subscriptions)
        themeStyleOption.removeDuplicates().sink { value in
            switch value {
            case .auto:
                UIApplication.shared.sceneWindows.forEach { window in
                    window.overrideUserInterfaceStyle = .unspecified
                }
            case .light:
                UIApplication.shared.sceneWindows.forEach { window in
                    window.overrideUserInterfaceStyle = .light
                }
            case .dark:
                UIApplication.shared.sceneWindows.forEach { window in
                    window.overrideUserInterfaceStyle = .dark
                }
            }
            UserDefaults.standard.set(value.rawValue, forKey: "themeStyleOption")
            self.objectWillChange.send()
        }
        .store(in: &subscriptions)

        showRecentActiveUsers.removeDuplicates().sink { value in
            UserDefaults.standard.set(value, forKey: "showRecentActiveUsers")
            self.objectWillChange.send()
        }
        .store(in: &subscriptions)

        showRecentOnlineUsers.removeDuplicates().sink { value in
            UserDefaults.standard.set(value, forKey: "showRecentOnlineUsers")
            self.objectWillChange.send()
        }
        .store(in: &subscriptions)

        showRecentRegisteredUsers.removeDuplicates().sink { value in
            UserDefaults.standard.set(value, forKey: "showRecentRegisteredUsers")
            self.objectWillChange.send()
        }
        .store(in: &subscriptions)

        autoClearUnreadNotification.removeDuplicates().sink { value in
            UserDefaults.standard.set(value, forKey: "autoClearUnreadNotification")
            self.objectWillChange.send()
        }
        .store(in: &subscriptions)

        discussionBrowseCategory.removeDuplicates().sink { value in
            UserDefaults.standard.set(value.rawValue, forKey: "discussionBrowseCategory")
            self.objectWillChange.send()
        }
        .store(in: &subscriptions)

        emailVerificationEvent.sink { _ in
            Task {
                await self.tryToLoginWithStoredAccount()
            }
        }
        .store(in: &subscriptions)
    }

    func clearCookieStorage() {
        flarumProvider.session.session.reset(completionHandler: {})
    }

    @MainActor func logout() {
        clearCookieStorage()
        account = nil
        unreadNotificationCount = 0
        userInfo = nil
        ignoredUserIds = []
        token = nil
        tokenPrepared = false
    }

    @discardableResult
    func login(account: String, password: String) async -> Result<Bool, LoginError> {
        if let result = try? await flarumProvider.request(.token(username: account, password: password)) {
            if let token = try? result.map(Token.self) {
                let flarumTokenCookie = HTTPCookie(properties: [
                    HTTPCookiePropertyKey.domain: "ecnu.im",
                    HTTPCookiePropertyKey.path: "/",
                    HTTPCookiePropertyKey.name: "flarum_remember",
                    HTTPCookiePropertyKey.value: token.token,
                ])!
                flarumProvider.session.sessionConfiguration.httpCookieStorage?.setCookie(flarumTokenCookie)
                DispatchQueue.main.async {
                    self.account = Account(account: account, password: password, userId: token.userId)
                    self.hasTriedToLogin = true
                    self.token = token.token
                    self.tokenPrepared = true
                }
                if let response = try? await flarumProvider.request(.user(id: token.userId)).flarumResponse() {
                    if AppGlobalState.shared.userInfo == nil {
                        DispatchQueue.main.async {
                            AppGlobalState.shared.userInfo = response.data.users.first
                        }
                    }
                    FlarumBadgeStorage.shared.store(userBadges: response.included.userBadges)
                    DispatchQueue.main.async {
                        AppGlobalState.shared.ignoredUserIds = Set(response.data.users.first?.relationships?.ignoredUsers.compactMap { $0.id } ?? [])
                    }
                }
                return .success(true)
            } else if let error = try? result.map(FlarumAPIErrorModel.self) {
                debugPrint(error)
            } else {
                debugExecution {
                    print(String(data: result.data, encoding: .utf8) ?? "failed")
                    fatalErrorDebug()
                }
            }
            return .success(false)
        } else {
            // Network request error, maybe app is in background.
            return .failure(.networkError)
        }
    }

    @MainActor func tryToLoginWithStoredAccount() async {
        if let account = account {
            loginState = .trying
            let loginResult = await login(account: account.account, password: account.password)
            switch loginResult {
            case let .success(result):
                if !result {
                    // Maybe password has been modified
                    UIApplication.shared.topController()?.presentSignView()
                    logout()
                    loginState = .loginFailed
                    Toast.default(icon: .emoji("🤔"), title: "登录失败", subtitle: "密码可能被修改，请重新登录").show()
                } else {
                    loginState = .loginSuccess
                    Toast.default(icon: .emoji("🎉"), title: "登录成功").show()
                }
            case .failure:
                // Network error
                loginState = .requestFailed
                Toast.default(icon: .emoji("📶"), title: "登录失败", subtitle: "网络请求出错，正在重试").show()
                await tryToLoginWithStoredAccount()
            }
        } else {
            loginState = .noAccount
        }
    }
}
