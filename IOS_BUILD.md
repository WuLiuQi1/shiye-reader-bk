# iOS 构建说明

本项目已包含 iOS 15+ 的 Xcode 工程，并包含 Legado／阅读 v3 书源导入与阅读页换源功能。

只有 Windows 电脑、准备使用 AltStore 免费安装时，请直接阅读
[`WINDOWS_ALTSTORE_BUILD.md`](WINDOWS_ALTSTORE_BUILD.md)。项目已包含可手动运行的
GitHub Actions 工作流 `.github/workflows/build-altstore-ipa.yml`。

## 环境

- macOS
- Xcode 16 或更新版本
- Flutter 3.35 或更新版本
- CocoaPods
- Apple Developer 账号（安装到真机或导出 IPA 时需要）

## 编译

```bash
flutter pub get
cd ios
pod install
cd ..
open ios/Runner.xcworkspace
```

在 Xcode 中：

1. 选择 `Runner` target。
2. 在 **Signing & Capabilities** 中选择你的 Team。
3. 将 Bundle Identifier 从 `com.niki.xxread` 改成你账号下唯一的标识。
4. 选择 iPhone 真机后运行，或使用 **Product → Archive**。
5. 在 Organizer 中选择 **Distribute App** 导出 IPA 或上传 TestFlight。

也可以在签名配置完成后执行：

```bash
flutter build ios --release
```

## iOS 书源兼容说明

iOS 默认会拦截 HTTP 请求，而部分 Legado／阅读书源仍使用 HTTP。项目的
`ios/Runner/Info.plist` 已加入相应网络兼容设置，让用户主动导入的这类书源可以访问。

书源中包含 JavaScript、XPath、复杂登录或验证码的规则仍不执行；支持范围与项目根目录
README 中的 Legado 兼容说明一致。
