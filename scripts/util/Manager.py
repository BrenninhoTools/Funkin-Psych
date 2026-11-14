import argparse
import json
import os
import platform
import shutil
import subprocess
import sys
import time
from pathlib import Path


class BuildManager:
    def __init__(self):
        self.root = Path(__file__).resolve().parents[2]
        self.system = platform.system().lower()
        self.targets = [
            "windows",
            "linux",
            "mac",
            "android",
            "ios",
            "html5"
        ]

        self.project = self.detect_project()

    def log(self, message, level="INFO"):
        colors = {
            "INFO": "\033[96m",
            "SUCCESS": "\033[92m",
            "WARNING": "\033[93m",
            "ERROR": "\033[91m"
        }

        color = colors.get(level, "")
        reset = "\033[0m"

        print(f"{color}[{level}] {message}{reset}")

    def detect_project(self):
        files = [
            "project.hxp",
            "Project.xml",
            "project.xml"
        ]

        for name in files:
            path = self.root / name

            if path.is_file():
                return path

        return None

    def command_exists(self, name):
        return shutil.which(name) is not None

    def execute(self, command, check=True):
        self.log("Running: " + " ".join(command))

        try:
            result = subprocess.run(
                command,
                cwd=self.root,
                check=False
            )

            if check and result.returncode != 0:
                raise RuntimeError(
                    f"Command failed with code {result.returncode}"
                )

            return result.returncode

        except FileNotFoundError:
            self.log(
                f"Executable not found: {command[0]}",
                "ERROR"
            )
            return 127

    def check_environment(self):
        self.log("Checking build environment...")

        required = ["haxe", "haxelib"]

        missing = [
            tool for tool in required
            if not self.command_exists(tool)
        ]

        if missing:
            self.log(
                "Missing tools: " + ", ".join(missing),
                "ERROR"
            )
            return False

        if self.project is None:
            self.log(
                "Project.xml or project.hxp not found.",
                "ERROR"
            )
            return False

        self.log(
            f"Project: {self.project.name}",
            "SUCCESS"
        )

        return True

    def lime(self, action, target, debug=False, extra=None):
        command = [
            "haxelib",
            "run",
            "lime",
            action,
            target
        ]

        if debug:
            command.append("-debug")

        if extra:
            command.extend(extra)

        return self.execute(command)

    def build(self, target, debug=False, extra=None):
        if not self.check_environment():
            return 1

        if target not in self.targets:
            self.log(
                f"Unsupported target: {target}",
                "ERROR"
            )
            return 1

        self.log(
            f"Building {target} "
            f"({'debug' if debug else 'release'})"
        )

        start = time.perf_counter()

        result = self.lime(
            "build",
            target,
            debug,
            extra
        )

        elapsed = time.perf_counter() - start

        if result == 0:
            self.log(
                f"Build completed in {elapsed:.2f}s",
                "SUCCESS"
            )
        else:
            self.log("Build failed.", "ERROR")

        return result

    def run(self, target, debug=False, extra=None):
        if not self.check_environment():
            return 1

        return self.lime(
            "run",
            target,
            debug,
            extra
        )

    def test(self, target, debug=False, extra=None):
        if not self.check_environment():
            return 1

        return self.lime(
            "test",
            target,
            debug,
            extra
        )

    def clean(self, target):
        if not self.check_environment():
            return 1

        self.log(f"Cleaning {target}...")

        result = self.lime(
            "clean",
            target
        )

        if result == 0:
            self.log(
                "Clean completed.",
                "SUCCESS"
            )

        return result

    def install_dependencies(self):
        if not self.command_exists("haxelib"):
            self.log(
                "Haxelib is not installed.",
                "ERROR"
            )
            return 1

        hmm_file = self.root / "hmm.json"

        if not hmm_file.exists():
            self.log(
                "hmm.json not found.",
                "ERROR"
            )
            return 1

        self.log("Installing HMM dependencies...")

        if not self.command_exists("hmm"):
            result = self.execute([
                "haxelib",
                "install",
                "hmm",
                "--quiet"
            ])

            if result != 0:
                return result

        result = self.execute([
            "haxelib",
            "run",
            "hmm",
            "install"
        ])

        if result == 0:
            self.log(
                "Dependencies installed.",
                "SUCCESS"
            )

        return result

    def get_version(self, command):
        try:
            result = subprocess.run(
                command,
                cwd=self.root,
                capture_output=True,
                text=True,
                check=False
            )

            output = (
                result.stdout.strip()
                or result.stderr.strip()
            )

            return output if output else "Unknown"

        except OSError:
            return "Not installed"

    def info(self):
        data = {
            "project": (
                self.project.name
                if self.project
                else None
            ),
            "root": str(self.root),
            "system": platform.system(),
            "architecture": platform.machine(),
            "python": platform.python_version(),
            "haxe": self.get_version([
                "haxe",
                "--version"
            ]),
            "haxelib": self.get_version([
                "haxelib",
                "version"
            ]),
            "lime": self.get_version([
                "haxelib",
                "run",
                "lime",
                "--version"
            ])
        }

        print(json.dumps(
            data,
            indent=4,
            ensure_ascii=False
        ))

    def menu(self):
        while True:
            print()
            print("=" * 45)
            print("       FUNKIN-PSYCH BUILD MANAGER")
            print("=" * 45)
            print()
            print("1. Build Release")
            print("2. Build Debug")
            print("3. Build and Run")
            print("4. Clean")
            print("5. Install Dependencies")
            print("6. Environment Information")
            print("0. Exit")
            print()

            choice = input("Select: ").strip()

            if choice == "0":
                break

            if choice == "6":
                self.info()
                continue

            if choice == "5":
                self.install_dependencies()
                continue

            if choice not in ["1", "2", "3", "4"]:
                self.log(
                    "Invalid option.",
                    "WARNING"
                )
                continue

            target = input(
                "Target [windows/linux/mac/android/ios/html5]: "
            ).strip().lower()

            if target not in self.targets:
                self.log(
                    "Invalid target.",
                    "ERROR"
                )
                continue

            if choice == "1":
                self.build(target)

            elif choice == "2":
                self.build(target, debug=True)

            elif choice == "3":
                self.test(target)

            elif choice == "4":
                self.clean(target)


def main():
    parser = argparse.ArgumentParser(
        description="Funkin-Psych Build Manager"
    )

    parser.add_argument(
        "action",
        nargs="?",
        default="menu",
        choices=[
            "menu",
            "build",
            "run",
            "test",
            "clean",
            "install",
            "info"
        ]
    )

    parser.add_argument(
        "--target",
        default="windows"
    )

    parser.add_argument(
        "--debug",
        action="store_true"
    )

    parser.add_argument(
        "extra",
        nargs=argparse.REMAINDER
    )

    args = parser.parse_args()
    manager = BuildManager()

    if args.action == "menu":
        manager.menu()
        return 0

    if args.action == "info":
        manager.info()
        return 0

    if args.action == "install":
        return manager.install_dependencies()

    if args.target not in manager.targets:
        manager.log(
            "Unsupported target.",
            "ERROR"
        )
        return 1

    if args.action == "build":
        return manager.build(
            args.target,
            args.debug,
            args.extra
        )

    if args.action == "run":
        return manager.run(
            args.target,
            args.debug,
            args.extra
        )

    if args.action == "test":
        return manager.test(
            args.target,
            args.debug,
            args.extra
        )

    if args.action == "clean":
        return manager.clean(args.target)

    return 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\nBuild cancelled.")
        sys.exit(130)
    except RuntimeError as error:
        print(f"[ERROR] {error}")
        sys.exit(1)
