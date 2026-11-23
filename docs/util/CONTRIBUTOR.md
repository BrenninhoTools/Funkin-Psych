# Contributing Guide — Funkin-Psych

Thank you for your interest in contributing to **Funkin-Psych** (`BrenninhoTools/Funkin-Psych`)! This project is a fork and continuation of **Psych Engine** focused on cross-platform support (Desktop and Mobile — Android/iOS), stability, and extended modding capabilities.

This document outlines the guidelines for setting up your environment, proposing improvements, and submitting Pull Requests.

---

## 📋 Table of Contents

1. [Code of Conduct](#-code-of-conduct)
2. [Development Environment Setup](#-development-environment-setup)
3. [How to Contribute](#-how-to-contribute)
4. [Code & Cross-Platform Guidelines](#-code--cross-platform-guidelines)
5. [Pull Request Process](#-pull-request-process)

---

## 🤝 Code of Conduct

* Be respectful and constructive in Issues, code reviews, and discussions.
* Stay focused on technical improvements, stability, and engine compatibility.
* When reporting bugs, always provide as much context as possible (target platform, crash logs, steps to reproduce).

---

## 🛠️ Development Environment Setup

**Funkin-Psych** is built with **Haxe** and **C++**, manages its dependencies via **HxPKG** (`.hxpkg`), and stores its assets in a Git submodule (`funkin-psych.assets`).

### 1. Cloning the Repository

Because the assets live in a separate submodule, clone the repository using the `--recursive` flag:

```bash
git clone --recursive https://github.com/BrenninhoTools/Funkin-Psych.git
cd Funkin-Psych
```

If you have already cloned the repository without the submodule, initialize it manually:

```bash
git submodule update --init --recursive
```

### 2. Installing Dependencies

Run the scripts inside the `setup/` directory matching your operating system to install the pinned versions of `lime`, `openfl`, `flixel`, `hxcpp`, and other libraries defined in `.hxpkg`.

### 3. Feature Flags (`project.hxp`)

Before compiling or testing specific features, check the `setupFeatures()` function in `project.hxp`, where flags such as `LUA_ALLOWED` and `VIDEOS_ALLOWED` can be toggled depending on your build target.

---

## 🚀 How to Contribute

### Reporting Bugs
Before opening a new Issue, check whether the problem has already been reported. When creating a report, please include:
* **Platform & Architecture:** (e.g., Windows x64, Linux, Android ARM64, iOS).
* **Version / Commit:** Release tag or commit hash you are running.
* **Steps to Reproduce:** Clear instructions on how to trigger the issue.
* **Logs:** Native crash reports or terminal output.

### Suggesting Enhancements
Open an Issue describing:
* The current limitation or problem.
* Your proposed solution and how it benefits players or modders.
* Expected impact across both Desktop and Mobile platforms.

---

## 💻 Code & Cross-Platform Guidelines

Because this engine emphasizes **Android and iOS** alongside Desktop, keep the following points in mind when writing code:

1. **Mobile Compatibility & Touch Controls:**
   * New screens, menus, or editors must work properly with touch controls (4-lane hitbox, swipe/tap gestures, and virtual buttons such as the `KEYS` shortcut overlay in editors).
   * Avoid relying exclusively on physical keyboard shortcuts without providing a touch alternative when `#if mobile` is active.
2. **Filesystem & Case-Sensitivity:**
   * Mobile OSes (Android/iOS) and Linux are case-sensitive. Always use the engine's internal file-lookup helpers for mod assets and configured storage paths (`Storage Type` on Android and the `Documents` folder on iOS).
3. **Scripting (Lua & HScript):**
   * On mobile, the engine uses a bundled **Lua 5.1** interpreter (with the `bit` library) instead of LuaJIT to prevent ARM64 crashes. Ensure any newly exposed Lua functions are compatible with standard Lua 5.1.
4. **Shaders (OpenGL / OpenGL ES):**
   * Custom shaders should be tested or adapted for **OpenGL ES** to prevent shader compilation errors on mobile devices.
5. **Code Style:**
   * Follow the indentation, naming conventions, and structure already used in existing Haxe (`.hx`) files across the repository.
   * Keep commits focused and avoid bundling unrelated changes together.

---

## 🔄 Pull Request Process

1. **Fork** this repository.
2. Create a descriptive branch from `main`:
   ```bash
   git checkout -b fix/mobile-shader-loading
   ```
   *(Use prefixes such as `feat/`, `fix/`, `refactor/`, or `docs/`).*
3. Test your changes across as many targets as possible (Desktop and, when available, Mobile builds locally or via GitHub Actions).
4. Ensure the project compiles cleanly without new critical warnings or breaking compatibility with existing mods.
5. Submit your **Pull Request** clearly explaining what was changed, why it was needed, and how to test it.

---

Thank you again for helping improve **Funkin-Psych**! 🎮✨
