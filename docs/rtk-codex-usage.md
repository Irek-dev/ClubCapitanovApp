# RTK + Codex usage

RTK is used in this project to compress noisy shell output before it reaches Codex context.

## Check installation

rtk --version
rtk telemetry status

## Common commands

rtk ls .
rtk read README.md
rtk grep "pattern" .
rtk git status
rtk git diff
rtk deps

## iOS project exploration

rtk ls .
rtk read Package.swift
rtk read Podfile
rtk grep "App" .
rtk grep "ViewModel" .
rtk grep "Coordinator" .
rtk grep "ObservableObject" .
rtk grep "NavigationStack" .
rtk grep "URLSession" .

## When not to use RTK

Do not use RTK when exact raw output is required, or for commands involving secrets, signing, certificates, provisioning profiles, deployment, TestFlight, App Store upload, destructive actions, or infrastructure changes.

Do not run heavy iOS commands without explicit approval:

xcodebuild
xcrun simctl
fastlane
pod install
pod update

## Recommended Codex behavior

During project analysis, Codex should:
1. Use RTK to inspect structure.
2. Identify architecture, entry points, navigation, state management, networking, persistence, and tests.
3. Propose a plan before changing code.
4. Ask before running heavy iOS builds or tests.

## Rollback

Restore project AGENTS.md from backup if one was created:

ls AGENTS.md.backup.*
cp AGENTS.md.backup.YYYYMMDD-HHMMSS AGENTS.md

Remove RTK project instructions manually from `AGENTS.md` if needed.

Uninstall RTK if installed via Homebrew:

brew uninstall rtk

Review changed files:

git status --short
git diff -- AGENTS.md docs/rtk-codex-usage.md
