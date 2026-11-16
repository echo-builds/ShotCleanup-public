<p align="right"><a href="./README.md">简体中文</a> · <strong>English</strong></p>

# ShotCleanup

> Send the screenshot. Then get it out of Photos while the moment is still fresh.

[![iOS 18+](https://img.shields.io/badge/iOS-18%2B-black?logo=apple)](https://www.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-orange?logo=swift&logoColor=white)](https://www.swift.org/)
[![On-device](https://img.shields.io/badge/Processing-On--device-2ea44f)](./docs/how-it-works.md)
[![MIT License](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)

<p align="center">
  <video src="./assets/shotcleanup-demo.mp4" width="320" controls muted playsinline></video>
</p>
<p align="center"><sub>After sending, triple-tap the back of your iPhone, review the batch, and confirm deletion.</sub></p>

I am a product manager, so I take screenshots every day: a bug I need to share with the team, a product detail worth discussing, or an error message someone needs to see.

Most of those screenshots have done their job once they are sent. But I do not leave the conversation, reopen Photos, find the same images, and delete them. I do not have a weekly screenshot-cleaning habit either.

Eventually, Photos fills up with product screens, chat records, and error messages I only needed once.

![A photo library filled with screenshots](./images/screenshot-library.jpg)

Most photo-cleanup tools help after the clutter has accumulated: open another app, review a backlog, and clean it in batches. My problem is not that batch cleanup is too slow. It is that I never come back to do it.

**Deletion only happens when it is easy enough.**

ShotCleanup is therefore not a periodic photo organizer. It puts deletion at the moment a screenshot has finished its job:

**After sending screenshots, triple-tap the back of your iPhone.**

ShotCleanup finds the batch you just sent and asks iOS to show the final count and previews. Nothing is removed until you confirm, and the copies already sent in chat are not affected.

## How to use it

1. Take and send screenshots as usual.
2. Stay on the sent-message screen with at least one image still visible.
3. Triple-tap the back of your iPhone.
4. Check the photo count and previews shown by iOS, then confirm.

## How it works

iOS does not tell third-party apps which photos were just sent. ShotCleanup therefore does not read your messages or blindly delete every recent screenshot.

When triggered, it works locally on your iPhone to:

1. match the current screen against screenshots created in the previous five minutes;
2. use reliable on-screen matches as anchors to infer the continuous capture batch;
3. hand the final set to iOS for count, preview, and confirmation.

If you send ten screenshots while only two or three remain visible, ShotCleanup can still try to recover the full batch. If no reliable match exists or the batch is ambiguous, it narrows the result instead of expanding the deletion.

All image processing stays on the iPhone. See [How ShotCleanup works](./docs/how-it-works.md) for the matching rules, batch limits, and known boundaries.

> iOS does not expose the actual send record. An unsent screenshot from the same continuous capture session may therefore appear as a candidate. Always check the count and previews before confirming.

## Best-fit workflow

ShotCleanup is designed for **take screenshots → send them soon → stay on the sent screen → clean them up immediately**. It is not a historical photo-library organizer, and an old screenshot resent days later will not be considered.

## Installation

ShotCleanup is currently a developer preview. It requires a Mac with Xcode, an iPhone running iOS 18 or later, and local code signing.

### Agent-assisted install (experimental)

Give the following prompt to Codex, Claude Code, WorkBuddy, or another coding agent with terminal access to your Mac:

```text
Install ShotCleanup on the iPhone currently connected to this Mac.
Follow this guide exactly: https://raw.githubusercontent.com/echo-builds/ShotCleanup/main/INSTALL.md
Complete every step that can be automated. Hand control back only when Apple Account sign-in, device trust, or an iPhone setting requires me.
Afterward, verify that the app was installed and tell me which iPhone-only setup steps remain.
```

The first install may still require you to sign in to an Apple Account, unlock and trust the iPhone, or enable Developer Mode. Apple does not allow those security steps to be bypassed.

### Configure the iPhone after installation

1. Open ShotCleanup and allow photo access.
2. In Shortcuts, create a shortcut with `Take Screenshot`, followed by ShotCleanup's `识别刚发送的截图`, passing the screenshot into the second action.
3. Go to `Settings → Accessibility → Touch → Back Tap → Triple Tap` and select that shortcut.

<details>
<summary>Install manually with Xcode</summary>

1. Download the repository and open `ShotCleanup.xcodeproj` in Xcode.
2. Under `Signing & Capabilities`, select your Apple Account and Team, then use a unique Bundle Identifier.
3. Connect and unlock the iPhone, select it as the run destination, and click Run.
4. Complete the iPhone setup above.

</details>

If installation fails, start with:

```sh
./scripts/doctor.sh
```

## Local checks

The checks for image matching and time-batch inference run without an iPhone:

```sh
swiftc -O ShotCleanup/ThumbnailMatcher.swift ShotCleanup/ScreenshotBatchInference.swift Checks/MatcherChecks.swift -o /tmp/shot-cleanup-checks
/tmp/shot-cleanup-checks
```

## License

[MIT](./LICENSE)
