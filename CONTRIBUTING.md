# Contributing to MacMonitor

Thanks for taking the time to contribute. MacMonitor is a small, focused tool — contributions that keep it fast, native, and dependency-light are most welcome.

---

## Table of contents

- [Development environment](#development-environment)
- [Architecture overview](#architecture-overview)
- [Code style](#code-style)
- [Opening an issue](#opening-an-issue)
- [Submitting a pull request](#submitting-a-pull-request)
- [Good first issues](#good-first-issues)
- [What we won't merge](#what-we-wont-merge)

---

## Development environment

**Required:**

| Tool | Version | Notes |
|------|---------|-------|
| Xcode | 15.0+ | Download from the Mac App Store |
| macOS | 13 Ventura+ | Apple Silicon only |
| mactop | latest | `brew install mactop` |
| Git | any | Pre-installed on macOS |

**Recommended:**

- SwiftLint — `brew install swiftlint` (run before submitting PRs)
- GitHub CLI — `brew install gh` (for creating releases)

**Setup:**

```bash
# 1. Fork the repo on GitHub, then clone your fork
git clone https://github.com/ryyansafar/MacMonitor.git
cd MacMonitor

# 2. Install mactop
brew install mactop

# 3. Configure passwordless sudo (needed for GPU + power data)
MACTOP=$(which mactop)
echo "$(whoami) ALL=(ALL) NOPASSWD: $MACTOP" | sudo tee /etc/sudoers.d/macmonitor
sudo chmod 440 /etc/sudoers.d/macmonitor

# 4. Open in Xcode
open Macmonitor.xcodeproj
```

In Xcode:
- Select the `Macmonitor` target → **Signing & Capabilities** → set **Team** to your Apple ID
- Do the same for `MacMonitorWidget`
- Press `Cmd+R` to build and run

The app will appear in your menu bar with no Dock icon.

---

## Architecture overview

```
SystemStatsModel        ← single ObservableObject shared by all SwiftUI views
    │
    ├── CPU             host_processor_info (two-sample delta, no sudo)
    ├── Memory          vm_statistics64 (no sudo)
    ├── Network         netstat -ib delta (no sudo)
    ├── Battery         pmset + ioreg (no sudo)
    └── GPU / Power     sudo mactop --headless --count 1 --format json
```

**Key design decisions:**

- **No App Sandbox.** Required to access Mach kernel APIs and run mactop. This means MacMonitor cannot be submitted to the Mac App Store.
- **No App Groups.** The widget collects its own data using Mach kernel APIs directly, avoiding the need for a paid Apple Developer account.
- **mactop for Apple Silicon metrics.** GPU, cluster temperatures, ANE power, and DRAM power aren't exposed through public macOS APIs. mactop uses private Apple performance counters. MacMonitor shells out to mactop rather than replicating its approach.
- **Two-sample CPU delta.** CPU usage is calculated by sampling tick counters, sleeping briefly, sampling again, then computing the delta. The widget does this on a background queue to avoid blocking the UI thread.

---

## Code style

MacMonitor uses SwiftUI and follows a few conventions:

**Naming:**
- `@Published` properties use camelCase and are named after what they represent, not how they're collected (`gpuUsage`, not `mactopGPUPercent`)
- Views are named after what they display (`PopoverView`, `BatterySection`) not how they're structured (`VerticalStack`)
- Private helpers in model files use `// MARK: - Section` comments to group related code

**Layout:**
- Indent with 4 spaces (Xcode default)
- Opening braces on the same line
- One blank line between `@Published` declarations and method definitions

**UI:**
- All colours are defined using the `Color(hex:)` extension — no hard-coded `Color(.systemBlue)` calls
- Dark-mode only (the app sets `.preferredColorScheme(.dark)` at the top level)
- Use the existing colour palette: `#0A84FF` (blue), `#30D158` (green), `#BF5AF2` (purple), `#FF9F0A` (orange), `#FF453A` (red), `#FFD60A` (yellow), `#0E0E12` (background)

**Data collection:**
- Heavy work (mactop, ioreg, pmset) runs on a background `DispatchQueue`, never on the main thread
- Results are published back to the main thread via `DispatchQueue.main.async`
- Shell helpers use the `shell(_ path: String, _ args: [String]) -> String` function in `SystemStatsModel` — avoid `Process` duplication

---

## Opening an issue

Before opening an issue, please:

1. Search existing issues to avoid duplicates
2. Run MacMonitor and check the Console app (Filter: `Macmonitor`) for any error messages

**Bug report — include:**
- macOS version (`sw_vers -productVersion`)
- Chip (`system_profiler SPHardwareDataType | grep "Chip"`)
- mactop version (`mactop --version`)
- What you expected to happen
- What actually happened
- Steps to reproduce

**Feature request — include:**
- What metric or capability you'd like to add
- What data source would provide it (or your best guess)
- Why it belongs in MacMonitor rather than a separate tool

---

## Submitting a pull request

1. **Open an issue first** for anything beyond a trivial fix. It saves everyone time if we discuss approach before implementation.

2. **Fork and branch:**
   ```bash
   git checkout -b feat/descriptive-name
   # or
   git checkout -b fix/what-was-broken
   ```

3. **Keep PRs focused.** One feature or fix per PR. If you're cleaning up unrelated code at the same time, separate commits are fine; separate PRs are better.

4. **Test on device.** The simulator does not support Mach kernel CPU sampling or mactop. All testing must be done on a physical Apple Silicon Mac.

5. **Check these before submitting:**
   - [ ] App builds with no warnings for both `Macmonitor` and `MacMonitorWidget` targets
   - [ ] mactop data still appears (GPU, temps, power rails)
   - [ ] Battery section shows correct values (`pmset -g batt` output matches)
   - [ ] Widget renders correctly in both Small and Medium sizes (use the Widget Simulator in Xcode)
   - [ ] First-launch welcome window appears after `defaults delete rybo.Macmonitor hasLaunched`
   - [ ] Memory usage of the app itself stays below ~30 MB at idle

6. **PR description — include:**
   - What changed and why
   - Any trade-offs or alternatives you considered
   - Screenshots if the change affects the UI

---

## Good first issues

If you're new to the project, these are good starting points:

- **Display thermal state as text** — `ProcessInfo.thermalState` returns `.nominal`, `.fair`, `.serious`, `.critical`. The header shows a coloured dot but not the text label.
- **Add disk space section** — available/total for the main volume, using `FileManager.default.volumeAvailableCapacityForImportantUsage`
- **Configurable refresh interval** — let users set the menu bar label refresh from 1s to 10s via Settings
- **Keyboard shortcut to open/close popover** — a global hotkey using `NSEvent.addGlobalMonitorForEvents`
- **Memory pressure label** — `HOST_VM_INFO64` includes a memory pressure value; surface it alongside the memory bar
- **Improve DMG background** — the current DMG uses a plain white background; a custom dark background image would be more consistent with the app's aesthetic

---

## What we won't merge

- **Anything that requires a paid Apple Developer account** to build from source (App Groups, entitlements that need distribution provisioning)
- **Additional third-party dependencies** — the goal is to stay as close to zero external Swift packages as possible
- **Mac App Store compatibility changes** — the app's core features require disabling the sandbox
- **UI changes that add visual noise** — the dashboard is already information-dense; new metrics need to fit cleanly or replace something
- **Intel Mac support** — mactop, per-core Apple Silicon cluster data, and ANE/DRAM power rails are Apple Silicon-specific

---

## Release process (for maintainers)

Releases are fully automated. No manual DMG building or formula editing required.

```bash
# 1. Bump CFBundleShortVersionString in Xcode to match the new tag
# 2. Commit + tag
git commit -am "chore: bump version to 1.x.0"
git tag v1.x.0
git push origin main --tags
```

GitHub Actions takes it from there:

| Workflow | Trigger | Does |
|----------|---------|------|
| `release.yml` | `v*` tag pushed | Builds DMG on macOS runner, creates GitHub Release, attaches `.dmg` |
| `update-brew.yml` | Release published | Downloads DMG, computes SHA256, commits updated `Casks/macmonitor.rb` |

Users running `brew upgrade --cask macmonitor` get the new version automatically within ~5 minutes of the release being published.

---

## Support the project

If you'd like to support development:

- [buymeacoffee.com/ryyansafar](https://buymeacoffee.com/ryyansafar)
- [paypal.me/ryyansafar](https://www.paypal.com/paypalme/ryyansafar)
- [razorpay.me/@ryyansafar](https://razorpay.me/@ryyansafar)

---

## Questions?

Open a [GitHub Discussion](../../discussions) for anything that's not a bug or feature request — architecture questions, ideas, or just "would this be welcome?".
