"""Build a signed, static APT repository for the One More Try! amd64 package."""
import argparse
import gzip
import hashlib
import os
import re
import shutil
import subprocess
from datetime import datetime, timezone
from email.utils import format_datetime
from pathlib import Path

PACKAGE = "onemoretry"
SUITE = "stable"
COMPONENT = "main"
ARCH = "amd64"


def deb_field(package: Path, field: str) -> str:
    return subprocess.check_output(["dpkg-deb", "--field", str(package), field], text=True).strip()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--deb", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path, help="New repository directory")
    parser.add_argument("--fingerprint", required=True, help="Full fingerprint of the OpenPGP signing key")
    args = parser.parse_args()
    fingerprint = args.fingerprint.upper()
    if not re.fullmatch(r"(?:[0-9A-F]{40}|[0-9A-F]{64})", fingerprint):
        parser.error("--fingerprint must be a full OpenPGP fingerprint")
    package, architecture = (deb_field(args.deb, field) for field in ("Package", "Architecture"))
    if package != PACKAGE or architecture != ARCH:
        parser.error(f"Expected a {PACKAGE} {ARCH} package")

    root = args.output.resolve()
    root.mkdir(parents=True, exist_ok=False)
    pool = root / f"pool/{COMPONENT}/o/{PACKAGE}"
    pool.mkdir(parents=True)
    shutil.copyfile(args.deb, pool / args.deb.name)

    distribution = root / "dists" / SUITE
    index_directory = distribution / f"{COMPONENT}/binary-{ARCH}"
    index_directory.mkdir(parents=True)
    index = subprocess.check_output(
        ["dpkg-scanpackages", "--arch", ARCH, "pool", "/dev/null"], cwd=root
    )
    (index_directory / "Packages").write_bytes(index)
    (index_directory / "Packages.gz").write_bytes(gzip.compress(index, mtime=0))

    release = distribution / "Release"
    lines = [
        "Origin: OneMoreTry",
        "Label: One More Try!",
        f"Suite: {SUITE}",
        f"Codename: {SUITE}",
        f"Architectures: {ARCH}",
        f"Components: {COMPONENT}",
        f"Date: {format_datetime(datetime.now(timezone.utc), usegmt=True)}",
    ]
    indexes = sorted(index_directory.iterdir())
    for digest in ("sha256", "sha512"):
        lines.append(f"{digest.upper()}:")
        for path in indexes:
            content = path.read_bytes()
            relative = path.relative_to(distribution).as_posix()
            lines.append(f" {hashlib.new(digest, content).hexdigest()} {len(content):16d} {relative}")
    release.write_text("\n".join(lines) + "\n", encoding="utf-8")

    signing = ["gpg", "--batch", "--local-user", fingerprint]
    passphrase = os.environ.get("APT_SIGNING_PASSPHRASE")
    if passphrase:
        signing += ["--pinentry-mode", "loopback", "--passphrase-fd", "0"]
    password_input = (passphrase + "\n").encode() if passphrase else None
    subprocess.run(
        signing + ["--output", str(distribution / "InRelease"), "--clearsign", str(release)],
        input=password_input, check=True,
    )
    subprocess.run(
        signing + ["--armor", "--output", str(distribution / "Release.gpg"), "--detach-sign", str(release)],
        input=password_input, check=True,
    )
    public_key = subprocess.check_output(["gpg", "--batch", "--armor", "--export", fingerprint])
    if not public_key:
        raise RuntimeError("The signing key has no exportable public certificate")
    (root / "onemoretry-archive-keyring.asc").write_bytes(public_key)


if __name__ == "__main__":
    main()
