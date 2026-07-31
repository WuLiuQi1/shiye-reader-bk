# 第三方软件与素材说明

拾页包含或依赖第三方开源软件。每个组件仍适用其自身许可证；本文件是导航说明，不替代
各组件的原始许可证文本。

## Flutter 与 Dart 依赖

直接依赖及其锁定版本记录在 [pubspec.yaml](pubspec.yaml) 与
[pubspec.lock](pubspec.lock)。Flutter 构建会收集 Dart/Flutter 包的许可证，并通过应用内
“开源许可”页面展示。发布前应使用与目标版本相同的 Flutter SDK 重新解析依赖，并确认
该页面能够打开且列出实际打包的组件。

主要直接依赖包括：

- Flutter、flutter_localizations、cupertino_icons
- file_picker、shared_preferences、package_info_plus
- sqflite、sqflite_common_ffi、sqflite_common_ffi_web
- path、path_provider、crypto、uuid、flutter_secure_storage
- epubx、pdfx、archive、kindle_unpack、html、gbk_codec
- url_launcher、provider、fl_chart、scrollable_positioned_list、intl
- flutter_tts、dio、audioplayers

准确、完整的传递依赖集合以 `pubspec.lock` 和最终构建生成的许可证清单为准。

## 字体

随应用提供或供应用下载的字体许可证文本位于
[`assets/fonts/licenses/`](assets/fonts/licenses/)。字体文件与软件代码可能适用不同许可，
再分发时必须同时遵守相应字体许可证。

## 上游代码

本项目基于 Open Reading，当前修改版按
[GNU AGPL-3.0-only](LICENSE) 分发。历史 MIT 许可边界见
[LICENSE-MIT-LEGACY](LICENSE-MIT-LEGACY) 与 [LICENSING.md](LICENSING.md)。

## 发布检查

发布者在每次发布前应：

1. 保留 `LICENSE`、`NOTICE.md`、`LICENSE-MIT-LEGACY` 和 `LICENSING.md`；
2. 保留依赖包及字体随附的版权与许可证文本；
3. 检查应用内“开源许可”页面与实际构建依赖一致；
4. 在二进制下载页链接至对应提交或版本标签的完整源代码；
5. 不打包无权分发的小说、书源集合、凭据或受限制素材。
