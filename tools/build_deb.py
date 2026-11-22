"""Package an exported One More Try! Linux executable for Debian and Ubuntu."""
import argparse
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = "onemoretry"
ARCH = "amd64"
DEPENDENCIES = (
    "libc6 (>= 2.34), libstdc++6, libgcc-s1, libx11-6, libxcursor1, libxi6, "
    "libxinerama1, libxrandr2, libxrender1, libgl1, libasound2t64 | libasound2"
)


def install(source: Path, destination: Path, mode: int = 0o644) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, destination)
    destination.chmod(mode)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", required=True, type=Path, help="Linux Godot export with embedded PCK")
    parser.add_argument("--version", required=True, help="Debian package version such as 0.8.0-1")
    parser.add_argument("--output-dir", type=Path, default=ROOT / "build/deb")
    args = parser.parse_args()

    subprocess.run(["dpkg", "--validate-version", args.version], check=True)
    with args.binary.open("rb") as binary:
        ident = binary.read(20)
    if len(ident) < 20 or ident[:6] != b"\x7fELF\x02\x01" or ident[18:20] != b"\x3e\x00":
        parser.error("--binary must be a 64-bit x86 Linux ELF executable")

    args.output_dir.mkdir(parents=True, exist_ok=True)
    output = args.output_dir.resolve() / f"{PACKAGE}_{args.version}_{ARCH}.deb"
    with tempfile.TemporaryDirectory(prefix="onemoretry-deb-", dir=output.parent) as temporary:
        workspace = Path(temporary)
        tree = workspace / "package"
        control = tree / "DEBIAN"
        control.mkdir(parents=True)
        install(args.binary, tree / f"usr/lib/{PACKAGE}/{PACKAGE}", 0o755)
        launcher = tree / f"usr/bin/{PACKAGE}"
        launcher.parent.mkdir(parents=True)
        launcher.symlink_to(f"../lib/{PACKAGE}/{PACKAGE}")
        install(ROOT / f"installer/linux/{PACKAGE}.desktop", tree / f"usr/share/applications/{PACKAGE}.desktop")
        install(ROOT / "assets/icon.svg", tree / f"usr/share/icons/hicolor/scalable/apps/{PACKAGE}.svg")
        install(ROOT / "installer/linux/onemoretry.asc", tree / "etc/apt/keyrings/onemoretry.asc")
        install(ROOT / "installer/linux/onemoretry.list", tree / "etc/apt/sources.list.d/onemoretry.list")
        metadata = "io.github.nu4ddi4.OneMoreTry.metainfo.xml"
        install(ROOT / "installer/linux" / metadata, tree / "usr/share/metainfo" / metadata)
        doc = tree / f"usr/share/doc/{PACKAGE}"
        install(ROOT / "docs/GODOT_LICENSE.txt", doc / "godot-license.txt")
        install(ROOT / "docs/GODOT_COPYRIGHT.txt", doc / "godot-copyright.txt")
        install(ROOT / "assets/fonts/LICENSE.txt", doc / "font-license.txt")
        installed_kib = sum(file.stat().st_size for file in tree.rglob("*") if file.is_file() and not file.is_symlink())
        (control / "control").write_text(
            f"Package: {PACKAGE}\n"
            f"Version: {args.version}\n"
            "Section: games\n"
            "Priority: optional\n"
            f"Architecture: {ARCH}\n"
            f"Installed-Size: {(installed_kib + 1023) // 1024}\n"
            "Maintainer: OneMoreTry <95563468+nu4ddi4@users.noreply.github.com>\n"
            f"Depends: {DEPENDENCIES}\n"
            "Homepage: https://github.com/nu4ddi4/OneMoreTry\n"
            "Description: Precision platform game with forty trap encounters\n"
            " One More Try! is a side-scrolling platformer about quick retries.\n",
            encoding="utf-8",
        )
        (control / "control").chmod(0o644)
        tree.chmod(0o755)
        for directory in tree.rglob("*"):
            if directory.is_dir():
                directory.chmod(0o755)
        package = workspace / output.name
        subprocess.run(["dpkg-deb", "--root-owner-group", "--build", str(tree), str(package)], check=True)
        package.replace(output)
    print(output)


if __name__ == "__main__":
    main()
