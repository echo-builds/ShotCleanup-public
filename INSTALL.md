# Install ShotCleanup with a coding agent

This runbook is for Codex, Claude Code, WorkBuddy, or another coding agent that can operate the user's Mac terminal.

The goal is to install ShotCleanup on the iPhone connected to this Mac. Do the work directly instead of only explaining the steps. Pause only for Apple security or account actions that require the user.

## What the user needs

- A Mac
- An iPhone running iOS 18 or later
- A normal Apple Account
- Full Xcode from Apple

A paid Apple Developer Program membership is **not** required for installation on the user's own iPhone. With a free Personal Team, Apple provisioning expires after 7 days; rerun the same installation request to reinstall the app.

## Safety boundaries

- Never ask for an Apple Account password, verification code, recovery key, or certificate private key.
- Do not install Xcode automatically. If it is missing, ask the user to install it from Apple and open it once, then continue.
- Do not delete or overwrite unrelated projects, certificates, provisioning profiles, devices, or Xcode settings.
- Do not reuse an unrelated directory named `ShotCleanup-public`.
- When several signing teams or iPhones are available, show the choices and ask the user which one to use.
- Give the user only the current action they need to complete. After they finish, continue the installation instead of restarting the instructions.

## 1. Get the repository

If the current directory is already this repository, use it. Otherwise clone it into a new user-writable directory:

```sh
git clone https://github.com/echo-builds/ShotCleanup-public.git
cd ShotCleanup-public
```

## 2. Run the installer

Run this single entry point:

```sh
./scripts/install.sh
```

The script checks macOS, Xcode, signing, and the connected iPhone. When there is exactly one signing team and one connected iPhone, it automatically:

1. chooses them;
2. generates a unique local Bundle ID;
3. builds with automatic provisioning;
4. installs the app;
5. attempts to launch it.

Do not replace this with a different build process unless the script itself is broken.

## 3. Handle only the reported blocker

### Full Xcode is missing or not selected

Ask the user to install Xcode from Apple and open it once. If Xcode is already installed but Command Line Tools are selected, select the full Xcode developer directory. Ask before running an administrator command.

Then rerun:

```sh
./scripts/install.sh
```

### No Apple Development identity is found

Open Xcode and ask the user to complete this one-time action:

1. Open `Xcode → Settings → Accounts`.
2. Sign in with their Apple Account.
3. Select their Personal Team.
4. Open `Manage Certificates` and create an `Apple Development` certificate if Xcode has not already created one.

A paid membership is not required. Never ask the user to send credentials to the agent.

Then rerun the installer.

### No iPhone is found

Ask the user to:

1. connect the iPhone to the Mac;
2. unlock it;
3. tap `Trust` if prompted;
4. enable Developer Mode if iPhone requests it, restart, and reconnect.

Then rerun the installer.

### Several teams or iPhones are found

Show the names and identifiers reported by the scripts, ask the user to choose, then rerun:

```sh
./scripts/install.sh --team-id TEAM_ID --device-id DEVICE_ID
```

A stable local Bundle ID can optionally be supplied:

```sh
./scripts/install.sh \
  --team-id TEAM_ID \
  --device-id DEVICE_ID \
  --bundle-id com.example.shotcleanup.local
```

## 4. Verify the Mac-side installation

Treat the installation as successful only after `devicectl device install app` succeeds. If automatic launch fails, ask the user to unlock the iPhone and open ShotCleanup manually.

Do not report the entire setup as complete yet. The remaining steps must be done on the iPhone.

## 5. Guide the user through the iPhone setup

Give these steps one at a time:

1. Open ShotCleanup and allow full photo access.
2. In Shortcuts, create a shortcut with `Take Screenshot`, followed by ShotCleanup's `识别刚发送的截图`; pass the screenshot result into the second action.
3. Open `Settings → Accessibility → Touch → Back Tap → Triple Tap` and choose that shortcut.
4. Test with unimportant screenshots first. Send them, remain on the page where at least one sent image is visible, triple-tap the back of the iPhone, and check the photo count and previews before confirming deletion.

The setup is complete only after the app is installed and the user knows the remaining iPhone steps.
