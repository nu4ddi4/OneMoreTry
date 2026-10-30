"""Fetch only the Windows release template from the official Godot ZIP via ranges."""
import io
import os
import struct
import urllib.request
import zipfile
import zlib
from pathlib import Path

VERSION = "4.6.3"
URL = f"https://github.com/godotengine/godot-builds/releases/download/{VERSION}-stable/Godot_v{VERSION}-stable_export_templates.tpz"


def main():
    with urllib.request.urlopen(urllib.request.Request(URL, method="HEAD")) as response:
        url = response.url
        length = int(response.headers["Content-Length"])

    def read(start, end):
        request = urllib.request.Request(url, headers={"Range": f"bytes={start}-{end}"})
        with urllib.request.urlopen(request) as response:
            if response.status != 206:
                raise RuntimeError("Server did not honor the HTTP range request")
            return response.read()

    tail = read(length - 65536, length - 1)
    offset = tail.rindex(b"PK\x05\x06")
    eocd = struct.unpack("<4s4H2LH", tail[offset : offset + 22])
    size, start = eocd[5], eocd[6]
    central = read(start, start + size - 1)
    # zipfile can parse a central-directory-only archive with its end record.
    archive = zipfile.ZipFile(io.BytesIO(central + tail[offset:]))
    data_home = Path(os.environ["APPDATA"]) / "Godot" if os.name == "nt" else Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share"))) / "godot"
    target = data_home / "export_templates" / f"{VERSION}.stable"
    target.mkdir(parents=True, exist_ok=True)
    for item in archive.infolist():
        if item.filename not in ("templates/windows_release_x86_64.exe", "templates/windows_debug_x86_64.exe"):
            continue
        # zipfile adjusts offsets for the artificial archive; restore the absolute offset.
        absolute = item.header_offset + start
        header = read(absolute, absolute + 29)
        fields = struct.unpack("<4s5H3L2H", header)
        data_start = absolute + 30 + fields[-2] + fields[-1]
        data = read(data_start, data_start + item.compress_size - 1)
        raw = zlib.decompress(data, -15) if item.compress_type == zipfile.ZIP_DEFLATED else data
        if len(raw) != item.file_size or zlib.crc32(raw) != item.CRC:
            raise RuntimeError("Template size/CRC check failed")
        output = target / Path(item.filename).name
        output.write_bytes(raw)
        print(f"Installed {output.name} ({len(raw):,} bytes, CRC verified)", flush=True)


if __name__ == "__main__":
    main()
