# ShotCleanup Agent Installation Guide

This guide is written for coding agents with terminal access to the user's Mac. The goal is to install ShotCleanup on a connected iPhone while leaving Apple-account and iPhone security decisions to the user.

## Safety boundaries

- Do not delete or overwrite unrelated Xcode projects, certificates, provisioning profiles, or user settings.
- Do not install Xcode automatically. If full Xcode is missing, ask the user to install it from Apple, then continue.
- Do not ask for Apple Account passwords, verification codes, certificate private keys, or other secrets.
- Stop and hand control to the user when Xcode requires Apple Account sign-in, the iPhone asks to trust the Mac, or Developer Mode must be enabled.
- Use the repository scripts instead of inventing a different build process. Read their output before retrying.

## 1. Get the repository

If the current working directory is already this repository, use it. Otherwise clone it into a new, user-writable directory and enter it:

```sh
git clone https://github.com/echo-builds/ShotCleanup-public.git
cd ShotCleanup-public
```

Do not reuse or overwrite an unrelated directory named `ShotCleanup`.

## 2. Inspect the environment

Run:

```sh
./scripts/doctor.sh
```

Resolve only the reported blockers:

- Full Xcode must be installed and selected. Command Line Tools alone are not enough.
- Xcode must contain an Apple Account with an Apple Development signing identity.
- The target iPhone must be connected, unlocked, trusted, and visible to Xcode.
- If the iPhone requests Developer Mode, let the user enable it and reconnect after the restart.

When several signing teams or iPhones are available, ask the user which one to use. Never guess between different people or devices.

## 3. Build and install

The installer can detect a single signing team and a single connected iPhone:

```sh
./scripts/install.sh
```

If detection is ambiguous, rerun it with the values shown by `doctor.sh`:

```sh
./scripts/install.sh --team-id TEAM_ID --device-id DEVICE_ID
```

An optional stable bundle identifier can be supplied when needed:

```sh
./scripts/install.sh \
  --team-id TEAM_ID \
  --device-id DEVICE_ID \
  --bundle-id com.example.shotcleanup.local
```

The installer builds with automatic provisioning, installs the resulting app, and attempts to launch it. Treat a successful `devicectl device install app` result as the installation check.

## 4. Hand off the iPhone-only steps

After the app is installed, tell the user to:

1. Open ShotCleanup and allow photo access.
2. In Shortcuts, create a shortcut containing `Take Screenshot`, followed by ShotCleanup's `识别刚发送的截图`, passing the screenshot into that action.
3. Go to `Settings → Accessibility → Touch → Back Tap → Triple Tap` and choose the shortcut.
4. Test first with unimportant screenshots and verify the count and previews in the iOS deletion confirmation.

Do not report the setup as fully complete until the app installation has succeeded. Clearly distinguish the remaining iPhone-only configuration from the completed Mac-side installation.
