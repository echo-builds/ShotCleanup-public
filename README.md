<p align="right"><strong>简体中文</strong> · <a href="./README_EN.md">English</a></p>

# ShotCleanup · 截图清理

> 截图发出去之后，顺手把它从相册里送走。

[![iOS 18+](https://img.shields.io/badge/iOS-18%2B-black?logo=apple)](https://www.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-orange?logo=swift&logoColor=white)](https://www.swift.org/)
[![On-device](https://img.shields.io/badge/Processing-On--device-2ea44f)](./docs/how-it-works.zh-CN.md)
[![MIT License](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)

<p align="center">
  <a href="./assets/shotcleanup-demo.mp4"><img src="./assets/shotcleanup-demo.gif" width="320" alt="ShotCleanup 使用演示"></a>
</p>

我是一名产品经理，每天都会截很多图：测试产品时发现问题，截图发到群里；看到不错的设计，截图发给同事。

这些图解决的都是当下的问题。发出去后，我会继续工作，不会特意退出聊天、打开相册，再把刚才的截图找出来删除；我也没有定期清理截图的习惯。

时间一长，相册里就堆满了只使用过一次的产品页面、聊天记录和报错信息。

<p align="center">
  <img src="./images/screenshot-library.jpg" width="300" alt="堆满截图的相册">
</p>

常见的相册清理工具，是等图片堆积后，再打开一个 App 批量筛选。但我的问题不是「清理得不够快」，而是我根本不会在以后专门回来清理。

**删除只有足够简单，才会真的发生。**

所以 ShotCleanup 不做定期相册整理，而是把删除接在截图刚用完的那一刻：

**发完截图，轻点 iPhone 背面三下。**

它会找到刚才发送的那批截图，并交给 iOS 显示数量和预览。你确认后，原截图才会从相册删除；聊天里的图片不受影响。

## 怎么使用

1. 像平时一样截图并发送；
2. 停留在发送完成、至少一张图片仍然可见的页面；
3. 轻点 iPhone 背面三下；
4. 核对 iOS 显示的照片数量和预览，确认删除。

## 它怎么工作

iOS 不会告诉第三方 App「刚刚发送了哪些照片」。因此，ShotCleanup 不会读取消息，也不会直接删除最近创建的所有截图。

触发后，它会在 iPhone 本地：

1. 将当前页面与最近 5 分钟内创建的截图进行匹配；
2. 以屏幕中可靠匹配的截图为锚点，推断同一段连续截图；
3. 交给 iOS 显示最终数量和预览，等待你确认。

即使一次发送了 10 张、屏幕里只露出 2～3 张，它也会尝试找回完整的一批。没有可靠匹配或批次存在歧义时，它宁可缩小范围，也不会贸然扩大删除范围。

所有图像处理都在 iPhone 本地完成。完整的匹配规则、批次参数和边界见[工作原理](./docs/how-it-works.zh-CN.md)。

> 由于 iOS 不提供真实发送记录，同一段连续截图中没有发送的图片也可能进入候选。删除前请核对系统显示的数量和预览。

## 适合什么使用习惯

ShotCleanup 适合 **刚刚截图 → 很快发送 → 停留在发送页面 → 立即清理**。它不是历史相册整理工具，几天前创建、现在重新发送的截图不会进入候选。

## 安装

ShotCleanup 目前是开发者预览版，需要通过 Mac 安装到 iPhone，最低支持 iOS 18。

### 最简单的方式：交给 Agent

你需要准备：

- 一台 Mac；
- 一台 iOS 18 或更高版本的 iPhone；
- 普通 Apple Account；
- 完整版 Xcode。

**不需要付费开发者账号。**普通 Apple Account 可以把 App 安装到自己的 iPhone，但免费签名 7 天后会失效；到时把同一段话再次交给 Agent 重新安装即可。详见 [Apple 官方说明](https://developer.apple.com/help/account/basics/about-your-developer-account/)。

把下面整段话交给 Codex、Claude Code、WorkBuddy，或其他能够操作 Mac 终端的 Agent：

```text
请直接把 ShotCleanup 安装到这台 Mac 当前连接的 iPhone 上，不要只告诉我步骤。

项目仓库：https://github.com/echo-builds/ShotCleanup-public
先读取并严格执行安装说明：
https://raw.githubusercontent.com/echo-builds/ShotCleanup-public/main/INSTALL.md

请自动完成克隆仓库、检查环境、识别签名 Team 和 iPhone、编译、安装及启动。只有在必须由我完成的 Apple 安全操作时再暂停，例如安装或登录 Xcode、信任设备、开启开发者模式、配置快捷指令和背面三击。

需要我操作时，每次只告诉我当前一个动作；我完成后继续，不要重新从头解释。不要向我索要 Apple Account 密码、验证码或恢复密钥。

完成后请验证 App 已经安装到 iPhone，并继续带我完成手机上的快捷指令和背面三击设置。
```

Agent 会自动完成：

- 下载正确的公开仓库；
- 检查 Xcode、签名和连接的 iPhone；
- 自动选择唯一的签名 Team 和设备；
- 生成本机专用 Bundle ID；
- 编译、安装并尝试启动 ShotCleanup。

你只需要在系统要求时完成：

- 安装完整版 Xcode；
- 在 Xcode 登录自己的 Apple Account；
- 解锁 iPhone、信任 Mac 或开启开发者模式；
- 在 iPhone 上允许照片访问并配置快捷指令。

### 安装后，在 iPhone 配置

Agent 会逐步提醒你完成以下操作：

1. 打开 ShotCleanup，允许完整照片访问；
2. 在「快捷指令」中新建指令，依次添加「截屏」和「识别刚发送的截图」，并将截屏结果传给后一个操作；
3. 前往「设置 → 辅助功能 → 触控 → 轻点背面 → 轻点三下」，选择这条快捷指令；
4. 先用不重要的测试截图验证数量和预览，再确认删除。

<details>
<summary>不用 Agent，手动使用 Xcode 安装</summary>

1. 下载仓库，使用 Xcode 打开 `ShotCleanup.xcodeproj`；
2. 在 `Signing & Capabilities` 中选择自己的 Apple Account 和 Team，并将 Bundle Identifier 改成唯一值；
3. 连接并解锁 iPhone，选择真机后点击 Run；
4. 回到上面的「安装后，在 iPhone 配置」。

</details>

安装失败时，也可以在仓库目录运行：

```sh
./scripts/install.sh
```

脚本会先检查环境，再给出当前阻塞项。

## 本地检查

仓库中的 `Checks` 提供不依赖 iPhone 的图像匹配与时间批次推断检查：

```sh
swiftc -O ShotCleanup/ThumbnailMatcher.swift ShotCleanup/ScreenshotBatchInference.swift Checks/MatcherChecks.swift -o /tmp/shot-cleanup-checks
/tmp/shot-cleanup-checks
```

## License

[MIT](./LICENSE)
