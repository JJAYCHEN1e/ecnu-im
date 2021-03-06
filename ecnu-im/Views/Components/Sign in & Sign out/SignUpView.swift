import ReCaptcha
import Regex
import RxSwift
import SafariServices
import SwiftUI

private struct RegisterSuccessData: Decodable {
    let id: String
}

private struct RegisterSuccessModel: Decodable {
    let data: RegisterSuccessData
}

class SignUpViewModel: ObservableObject {
    @Published var email = ""
    @Published var account = ""
    @Published var nickname = ""
    @Published var password = ""
    @Published var confirmedPassword = ""
}

struct SignUpView: View {
    @EnvironmentObject var model: SignViewModel
    @ObservedObject var signUpViewModel: SignUpViewModel
    @FocusState var isEmailFocused: Bool
    @FocusState var isAccountFocused: Bool
    @FocusState var isNicknameFocused: Bool
    @FocusState var isPasswordFocused: Bool
    @FocusState var isConfirmedPasswordFocused: Bool
    @State var appear = [false, false, false]
    @State private var registering = false
    var dismissModal: () -> Void
    @AppStorage("isLogged") var isLogged = false
    @AppStorage("account") var account: String = ""
    @AppStorage("password") var password: String = ""

    @State private var disposeBag = DisposeBag()
    @State private var recaptcha: ReCaptcha!

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("注册")
                .font(.largeTitle).bold()
                .blendMode(.overlay)
                .slideFadeIn(show: appear[0], offset: 30)

            Text("使用校内邮箱注册以访问论坛的全部内容")
                .font(.headline)
                .foregroundColor(.primary.opacity(0.7))
                .slideFadeIn(show: appear[1], offset: 20)

            form.slideFadeIn(show: appear[2], offset: 10)
        }
        .coordinateSpace(name: "stack")
        .padding(20)
        .padding(.vertical, 20)
        .background(.ultraThinMaterial)
        .backgroundColor(opacity: 0.4)
        .cornerRadius(30)
        .modifier(OutlineModifier(cornerRadius: 30))
        .onLoad { animate() }
    }

    var form: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("", text: $signUpViewModel.email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .placeholder(when: signUpViewModel.email.isEmpty) {
                    Text("校园邮箱")
                        .foregroundColor(.primary)
                        .blendMode(.overlay)
                }
                .customField(icon: "envelope.open.fill")
                .focused($isEmailFocused)

            TextField("", text: $signUpViewModel.account)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .placeholder(when: signUpViewModel.account.isEmpty) {
                    Text("账号")
                        .foregroundColor(.primary)
                        .blendMode(.overlay)
                }
                .customField(icon: "person.crop.circle.fill")
                .focused($isAccountFocused)

            TextField("", text: $signUpViewModel.nickname)
                .textContentType(.username)
                .keyboardType(.default)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .placeholder(when: signUpViewModel.nickname.isEmpty) {
                    Text("昵称（省略则和账号一致）")
                        .foregroundColor(.primary)
                        .blendMode(.overlay)
                }
                .customField(icon: "person.fill")
                .focused($isNicknameFocused)

            SecureField("", text: $signUpViewModel.password)
                .textContentType(.password)
                .placeholder(when: signUpViewModel.password.isEmpty) {
                    Text("密码")
                        .foregroundColor(.primary)
                        .blendMode(.overlay)
                }
                .customField(icon: "key.fill")
                .focused($isPasswordFocused)

            Button {
                register()
            } label: {
                AngularButton(title: "注册")
            }
            .disabled(registering)
            .overlay(
                Group {
                    if registering {
                        ProgressView()
                    }
                },
                alignment: .center
            )

            (Text("注册即代表同意我们的") + Text("**[论坛守则](https://ecnu.im/d/287)**") + Text("及") + Text("**[隐私协议](https://ecnu.im/p/4-privacy)**。"))
                .font(.footnote)
                .foregroundColor(.primary.opacity(0.7))
                .accentColor(.primary.opacity(0.7))
                .padding(.top, 8)

            Divider()

            Text("已经有账号了? **点击登录**")
                .font(.footnote)
                .foregroundColor(.primary.opacity(0.7))
                .accentColor(.primary.opacity(0.7))
                .onTapGesture {
                    withAnimation {
                        model.selectedPanel = .signIn
                    }
                }
            Text("注册遇到问题? **点击此处从浏览器注册**")
                .font(.footnote)
                .foregroundColor(.primary.opacity(0.7))
                .accentColor(.primary.opacity(0.7))
                .onTapGesture {
                    let selectSignUpButtonJS = """
                    document.querySelector('ul li.item-signUp > button').click();
                    """
                    if let url = URL(string: URLService.link(href: "https://ecnu.im/", jsAction: selectSignUpButtonJS).url) {
                        UIApplication.shared.open(url)
                    }
                }
            
            Text("**点击此处打开腾讯企业邮箱**")
                .font(.footnote)
                .foregroundColor(.primary.opacity(0.7))
                .accentColor(.primary.opacity(0.7))
                .onTapGesture {
                    if let url = URL(string: URLService.link(href: "https://exmail.qq.com/").url) {
                        UIApplication.shared.open(url)
                    }
                }
        }
    }

    func animate() {
        withAnimation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.8).delay(0.2)) {
            appear[0] = true
        }
        withAnimation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.8).delay(0.4)) {
            appear[1] = true
        }
        withAnimation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.8).delay(0.6)) {
            appear[2] = true
        }
    }

    func checkRegisterInfo() -> Bool {
        if signUpViewModel.email == "" {
            Toast.default(
                icon: .emoji("‼️"),
                title: "邮箱为空"
            ).show()
            return false
        }
        let regex = Regex("^(.+\\@\\w+\\.ecnu\\.edu\\.cn)$")
        if !regex.matches(signUpViewModel.email) {
            Toast.default(
                icon: .emoji("‼️"),
                title: "邮箱有误",
                subtitle: "请使用校内邮箱注册"
            ).show()
            return false
        }
        if signUpViewModel.account.count < 3 {
            Toast.default(
                icon: .emoji("‼️"),
                title: "帐户长度至少为3个字符"
            ).show()
            return false
        }
        if signUpViewModel.password.count < 8 {
            Toast.default(
                icon: .emoji("‼️"),
                title: "密码长度至少为8个字符"
            ).show()
            return false
        }

        return true
    }

    func register() {
        guard checkRegisterInfo() else { return }
        registering = true

        let nickname = signUpViewModel.nickname != "" ? signUpViewModel.nickname : signUpViewModel.account

        recaptcha = try! ReCaptcha(endpoint: .default, locale: .current)
        disposeBag = DisposeBag()
        let topView = UIApplication.shared.topController()!.view!
        let webViewTag = 123
        recaptcha.configureWebView { webView in
            webView.frame = topView.bounds
            webView.tag = webViewTag
        }
        recaptcha.rx.didFinishLoading
            .debug("did finish loading")
            .subscribe()
            .disposed(by: disposeBag)

        _ = recaptcha.rx.validate(on: topView, resetOnError: false)
            .subscribe(onNext: { next in
                print(next)
                topView.viewWithTag(webViewTag)?.removeFromSuperview()
                Task {
                    if let result = try? await flarumProvider.request(.register(email: signUpViewModel.email,
                                                                                username: signUpViewModel.account,
                                                                                nickname: nickname,
                                                                                password: signUpViewModel.password,
                                                                                recaptcha: next)) {
                        if let error = try? result.map(FlarumAPIErrorModel.self) {
                            let errorDetail = error.errors.compactMap { $0.detail }.joined(separator: "")
                                .replacingOccurrences(of: "username ", with: "帐号")
                                .replacingOccurrences(of: "email ", with: "邮箱")
                                .replacingOccurrences(of: "nickname ", with: "昵称")
                                .replacingOccurrences(of: "password ", with: "密码")
                            let toast = Toast.default(
                                icon: .emoji("‼️"),
                                title: "注册失败",
                                subtitle: errorDetail
                            )
                            toast.show()
                            registering = false
                        } else if let _ = try? result.map(RegisterSuccessModel.self) {
                            Task {
                                await AppGlobalState.shared.login(account: signUpViewModel.account, password: signUpViewModel.password)
                            }
                            registering = false
                            model.dismissModal.toggle()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                let toast = Toast.default(
                                    icon: .emoji("🎉"),
                                    title: "注册成功"
                                )
                                toast.show()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                    let alertController = UIAlertController(title: "注意", message: "恭喜您注册成功，请登录校园邮箱以激活账号。您想要现在打开腾讯企业邮箱吗？", preferredStyle: .alert)
                                    alertController.addAction(UIAlertAction(title: "确定", style: .destructive, handler: { action in
                                        EmailVerificationViewController.show()
                                    }))
                                    alertController.addAction(UIAlertAction(title: "取消", style: .cancel, handler: { action in
                                    }))
                                    UIApplication.shared.presentOnTop(alertController, animated: true)
                                }
                            }
                        } else {
                            registering = false
                        }
                    }
                }
            }, onError: { error in
                print(error)
                registering = false
            })
    }
}

struct SignUpView_Previews: PreviewProvider {
    static var previews: some View {
        SignUpView(signUpViewModel: SignUpViewModel(), dismissModal: {})
            .environmentObject(SignViewModel())
    }
}

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}
