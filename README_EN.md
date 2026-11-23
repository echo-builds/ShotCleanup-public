<p align="right"><a href="./README.md">简体中文</a> · <strong>English</strong></p>

# ShotCleanup

> Send the screenshot. Then get it out of Photos while the moment is still fresh.

[![iOS 18+](https://img.shields.io/badge/iOS-18%2B-black?logo=apple)](https://www.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-orange?logo=swift&logoColor=white)](https://www.swift.org/)
[![On-device](https://img.shields.io/badge/Processing-On--device-2ea44f)](./docs/how-it-works.md)
[![MIT License](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)

<p align="center">
  <a href="./assets/shotcleanup-demo.mp4"><img src="./assets/shotcleanup-demo.gif" width="320" alt="ShotCleanup demo"></a>
</p>
<p align="center"><sub>After sending, triple-tap the back of your iPhone, review the batch, and confirm deletion. Click the GIF for the original video.</sub></p>

I am a product manager, so I take screenshots every day: a bug I need to share with the team, a product detail worth discussing, or an error message someone needs to see.

Most of those screenshots have done their job once they are sent. But I do not leave the conversation, reopen Photos, find the same images, and delete them. I do not have a weekly screenshot-cleaning habit either.

Eventually, Photos fills up with product screens, chat records, and error messages I only needed once.

<p align="center">
  <img src="./images/screenshot-library.jpg" width="300" alt="A photo library filled with screenshots">
</p>

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

ShotCleanup is currently a developer preview. It must be installed from a Mac onto an iPhone running iOS 18 or later.

### Easiest path: give the task to an agent

You need:

- a Mac;
- an iPhone running iOS 18 or later;
- a normal Apple Account;
- the full Xcode app.

**A paid developer membership is not required.** A normal Apple Account can install the app on the account owner's iPhone. Free Personal Team provisioning expires after 7 days; give the same task to the agent again to reinstall it. See [Apple's account overview](https://developer.apple.com/help/account/basics/about-your-developer-account/).

Give this entire prompt to Codex, Claude Code, WorkBuddy, or another coding agent with terminal access to the Mac:

```text
Install ShotCleanup directly on the iPhone currently connected to this Mac. Do the work instead of only explaining the steps.

Repository: https://github.com/echo-builds/ShotCleanup-public
Read and follow this runbook exactly:
https://raw.githubusercontent.com/echo-builds/ShotCleanup-public/main/INSTALL.md

Automatically clone the repository, inspect the environment, identify the signing team and iPhone, build, install, and launch the app. Pause only for Apple security steps that I must complete, such as installing or signing in to Xcode, trusting the device, enabling Developer Mode, and configuring Shortcuts and Back Tap.

When I need to act, give me only the current action. Continue after I finish instead of restarting the explanation. Never ask me for an Apple Account password, verification code, or recovery key.

After installation, verify that the app is on the iPhone and continue guiding me through the Shortcut and Triple Tap setup.
```

The agent will handle:

- cloning the correct public repository;
- checking Xcode, signing, and the connected iPhone;
- selecting the only available signing team and device;
- generating a device-specific local Bundle ID;
- building, installing, and attempting to launch ShotCleanup.

The user only needs to handle Apple-controlled steps:

- install the full Xcode app if it is missing;
- sign in to an Apple Account inside Xcode;
- unlock the iPhone, trust the Mac, or enable Developer Mode;
- allow photo access and configure the Shortcut on the iPhone.

### Configure the iPhone after installation

The agent should guide the user through these steps one at a time:

1. Open ShotCleanup and allow full photo access.
2. In Shortcuts, create a shortcut with `Take Screenshot`, followed by ShotCleanup's `识别刚发送的截图`; pass the screenshot result into the second action.
3. Open `Settings → Accessibility → Touch → Back Tap → Triple Tap` and choose that shortcut.
4. Test with unimportant screenshots first and verify the count and previews before confirming deletion.

<details>
<summary>Install manually with Xcode</summary>

1. Download the repository and open `ShotCleanup.xcodeproj` in Xcode.
2. Under `Signing & Capabilities`, select your Apple Account and Team, then use a unique Bundle Identifier.
3. Connect and unlock the iPhone, select it as the run destination, and click Run.
4. Complete the iPhone setup above.

</details>

If installation fails, the same entry point can be run from the repository:

```sh
./scripts/install.sh
```

It checks the environment first and reports the current blocker.

## Local checks

The checks for image matching and time-batch inference run without an iPhone:

```sh
swiftc -O ShotCleanup/ThumbnailMatcher.swift ShotCleanup/ScreenshotBatchInference.swift Checks/MatcherChecks.swift -o /tmp/shot-cleanup-checks
/tmp/shot-cleanup-checks
```

## License

[MIT](./LICENSE)
