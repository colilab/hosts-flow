# 🌐 Host Flow

A native macOS app for developers and sysadmins who want to manage virtual hosts quickly and cleanly. Inspired by iHosts, it lets you create host profiles that can be activated or deactivated individually or in combination, writing the result directly to `/etc/hosts`.

![Swift](https://img.shields.io/badge/Swift-5.9-F54A2A?logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-blue?logo=apple&logoColor=white)
![macOS](https://img.shields.io/badge/macOS-14.0%2B-000000?logo=apple&logoColor=white)
![Xcode](https://img.shields.io/badge/Xcode-15%2B-147EFB?logo=xcode&logoColor=white)
![XcodeGen](https://img.shields.io/badge/XcodeGen-project.yml-blueviolet?logo=yaml&logoColor=white)
![License](https://img.shields.io/badge/license-Proprietary-lightgrey)

---

## ✨ Features

- 🗂 **Profiles** — create, rename, and delete named groups of host records (e.g. "Default", "Staging", "Production"). Multiple profiles can be active at the same time.
- 📋 **Host Records** — each profile holds a list of IP + hostname entries with inline editing and per-record enable/disable toggles.
- 🔔 **Menu Bar** — quick profile toggle from the macOS status bar without opening the main window.
- ⚙️ **Settings** — launch at login, appearance (System / Light / Dark), and `/etc/hosts` write permission management.

---

## 🛠 Tech Stack

| Layer | Technology |
| ------------------ | --------------------------------- |
| Language | ![Swift](https://img.shields.io/badge/Swift-5.9-F54A2A?logo=swift&logoColor=white) |
| UI | ![SwiftUI](https://img.shields.io/badge/SwiftUI-Native_macOS-blue?logo=apple&logoColor=white) |
| Persistence | ![SwiftData](https://img.shields.io/badge/SwiftData-purple?logo=apple&logoColor=white) |
| Architecture | MVVM with `@Observable` |
| Project generation | ![XcodeGen](https://img.shields.io/badge/XcodeGen-project.yml-blueviolet?logo=yaml&logoColor=white) |
| Minimum target | ![macOS](https://img.shields.io/badge/macOS-14.0%2B-000000?logo=apple&logoColor=white) |

The app writes to `/etc/hosts` using a sandboxed temporary exception entitlement. Only the block delimited by `# --- Host Flow Start ---` / `# --- Host Flow End ---` is modified; everything else in the file is left untouched.

---

## 📋 Requirements

- 🍎 macOS 14.0 or later
- 🔨 Xcode 15 or later
- ⚡️ [XcodeGen](https://github.com/yonaskolb/XcodeGen) (only needed to regenerate `HostFlow.xcodeproj` after editing `project.yml`)

---

## 🚀 Running Locally

```bash
# 1. Clone the repository
git clone git@github.com:colilab/hosts-flow.git
cd hosts-flow

# 2. (Optional) Regenerate the Xcode project if you modified project.yml
brew install xcodegen   # skip if already installed
cd HostFlow
xcodegen generate

# 3. Open the project in Xcode
open HostFlow.xcodeproj
```

Then press **⌘R** in Xcode to build and run.

> ⚠️ **Note:** on first run macOS will ask for administrator permission to write to `/etc/hosts`. This is required for the app to apply any profile changes.

---

## 📁 Project Structure

```
HostFlow/
├── App/            # 🚀 App entry point and root ContentView
├── Models/         # 🗃 SwiftData models (Profile, HostRecord)
├── Stores/         # 📦 Observable state (ProfileStore, AppSettings)
├── Views/
│   ├── Sidebar/         # 📂 Profile list
│   ├── ProfileDetail/   # 📋 Host records table
│   ├── MenuBar/         # 🔔 Status bar popover
│   └── Settings/        # ⚙️ Settings scene
└── Helpers/        # 🔧 HostsFileManager, parser, validator
```

---

## 📄 License

Copyright © 2026 Colilab. All rights reserved.
