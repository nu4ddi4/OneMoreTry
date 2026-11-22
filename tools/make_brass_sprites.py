"""Render the hand-pixelled traveler, HUD glyphs and menu marker to PNG."""
from pathlib import Path

from PIL import Image

OUT = Path(__file__).resolve().parents[1] / "assets" / "art"
PALETTE = {
    "#": "#332419",
    "s": "#665039",
    "b": "#b18349",
    "g": "#dfaa5f",
    "+": "#f9d491",
    "r": "#a44a2a",
    "w": "#fff0ba",
}


def sprite(rows, palette=PALETTE):
    image = Image.new("RGBA", (len(rows[0]), len(rows)))
    for y, row in enumerate(rows):
        if len(row) != image.width:
            raise ValueError(f"Unequal sprite row length on line {y + 1}")
        for x, cell in enumerate(row):
            if cell != ".":
                color = palette[cell]
                image.putpixel((x, y), tuple(bytes.fromhex(color[1:])) + (255,))
    return image


TRAVELER = (
    "....######....",
    "...#++++++#...",
    "..#++ggggg#...",
    "..#ggggg###...",
    ".##bbb##ss##..",
    "#+++++gggggg#.",
    "#bbbbbbbbbbb#.",
    ".###s#####ss#.",
    "...#s##w##ss#.",
    "...#s#####ss#.",
    "...#ssbbbss#..",
    "..#bbggsrr#...",
    "..#bggbbbb#...",
    "...########...",
)

GLYPHS = (
    ("###", "#.#", "#.#", "#.#", "###"),
    (".#.", "##.", ".#.", ".#.", "###"),
    ("###", "..#", "###", "#..", "###"),
    ("###", "..#", ".##", "..#", "###"),
    ("#.#", "#.#", "###", "..#", "..#"),
    ("###", "#..", "###", "..#", "###"),
    ("###", "#..", "###", "#.#", "###"),
    ("###", "..#", "..#", ".#.", ".#."),
    ("###", "#.#", "###", "#.#", "###"),
    ("###", "#.#", "###", "..#", "###"),
    (".", "#", ".", "#", "."),
    (".", ".", ".", ".", "#"),
)

def main():
    OUT.mkdir(exist_ok=True)
    sprite(TRAVELER).save(OUT / "brass_traveler.png")
    glyphs = Image.new("RGBA", (4 * len(GLYPHS), 5))
    for i, rows in enumerate(GLYPHS):
        glyphs.paste(sprite(rows, {"#": "#fff0ba"}), (i * 4, 0))
    glyphs.save(OUT / "brass_digits.png")
    sprite((".####.", "######", "#.##.#", "######", ".####.", ".#..#."), {"#": "#fff0ba"}).save(OUT / "brass_skull.png")
    sprite(("#....", "##...", "###..", "####.", "#####", "####.", "###..", "##...", "#...."), {"#": "#a44a2a"}).save(OUT / "brass_cursor.png")


if __name__ == "__main__":
    main()
