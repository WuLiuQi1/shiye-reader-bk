# Windows 云端编译 IPA 并安装到 iPhone

此流程适用于只有 Windows 电脑和 iPhone、仅供自己使用、不发布 App Store 的情况。
不需要付费 Apple Developer Program。免费 Apple ID 签名通常需要每 7 天刷新。

## 一、上传项目到 GitHub

1. 在 GitHub 新建一个 **Private（私有）** 仓库。
2. 解压本项目包。
3. 将解压目录中的全部文件上传到仓库根目录。
4. 确认仓库根目录能看到 `pubspec.yaml`、`ios` 和 `.github`。

注意：Windows 默认可能隐藏 `.github` 文件夹，但上传时必须保留它。

## 二、一键生成 IPA

1. 打开 GitHub 仓库的 **Actions** 页面。
2. 左侧选择 **Build AltStore IPA**。
3. 点击 **Run workflow**，再点击绿色的 **Run workflow**。
4. 等待构建完成并显示绿色勾号。
5. 打开该次构建，在页面底部的 **Artifacts** 下载
   `OpenReading-AltStore-IPA`。
6. 解压下载的 ZIP，得到 `OpenReading-AltStore-unsigned.ipa`。

这个 IPA 没有预先绑定任何人的苹果证书。AltStore 安装时会使用你的免费 Apple ID
为它签名。

## 三、Windows 安装 AltStore

1. 从 Apple 官网安装 Windows 版 iTunes 和 iCloud。
   不要使用 Microsoft Store 版本。
2. 从 AltStore 官网下载并安装 AltServer。
3. 用数据线连接 iPhone，解锁并选择“信任此电脑”。
4. 打开 iTunes，启用“通过 Wi-Fi 与此 iPhone 同步”。
5. 在 Windows 任务栏托盘中点击 AltServer：
   **Install AltStore → 你的 iPhone**。
6. 输入用于免费签名的 Apple ID。建议专门注册一个 Apple ID。

如果启用了双重认证而登录失败，请在 Apple ID 网站生成“App 专用密码”后重试。

## 四、安装 IPA

1. 在 iPhone 打开 AltStore。
2. 进入 **My Apps**，点击左上角 `+`。
3. 从“文件”中选择 `OpenReading-AltStore-unsigned.ipa`。
4. 等待签名和安装完成。

首次运行前可能还需要：

- `设置 → 隐私与安全性 → 开发者模式`：开启并重启手机。
- `设置 → 通用 → VPN 与设备管理`：信任你的 Apple ID。

## 五、每 7 天刷新

保持 Windows 上 AltServer 正在运行，并让电脑和 iPhone 位于同一 Wi-Fi。
在 AltStore 的 **My Apps** 页面点击 **Refresh All**。建议在到期前刷新。

## 常见问题

- GitHub 没显示工作流：确认 `.github/workflows/build-altstore-ipa.yml` 已上传。
- 构建失败：打开失败步骤，复制红色错误日志。
- IPA 无法选择：先将 IPA 保存到 iPhone 的“文件”App。
- 安装提示已达 App 上限：免费账号通常最多同时安装 3 个侧载 App。
- App 过期：重新运行 AltServer 并在 AltStore 中刷新或重新安装。

