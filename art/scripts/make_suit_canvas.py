"""Makes the rough canvas the rare suits are made of (GAME_DESIGN 35.12): tiling colour, normal and roughness maps from
scratch, so it is our own work. User, 2026-11-06: "Real squat suits, bench shirts ... are very rough."

    uv run --no-project --with numpy --with pillow python art/scripts/make_suit_canvas.py

A coarse twill weave you can see from a normal camera distance, with fibres and worn patches over it. The colour map is
near white: the game tints it with the part's colour. Normal maps are OpenGL style, as Roblox wants. The same seed gives
the same files. They go outside the repo, like the other prepared maps; upload with upload_group_images.py.
"""
from pathlib import Path

import numpy as np
from PIL import Image

OUT = Path(r"D:\Powerlifting Roblox Extras\Textures\SuitCanvas")
SIZE = 1024
# Threads across one tile. With StudsPerTile 1.2 (StarterGymConfig) each thread is about 0.03 stud.
THREADS = 36


def tiling_noise(rng, low_cycles, high_cycles, falloff=1.0):
    """Tiling random noise, -1 to 1, with detail between these sizes (cycles per tile)."""
    spectrum = np.fft.fft2(rng.standard_normal((SIZE, SIZE)))
    fy = np.fft.fftfreq(SIZE) * SIZE
    fx = np.fft.fftfreq(SIZE) * SIZE
    radius = np.sqrt(fx[:, None] ** 2 + fx[None, :] ** 2)
    gain = ((radius >= low_cycles) & (radius <= high_cycles)) / np.maximum(radius, 1) ** falloff
    field = np.real(np.fft.ifft2(spectrum * gain))
    return field / np.abs(field).max()


def weave():
    """A 2/1 twill: height of the cloth, 0 to 1. Each crossing is a rounded thread lying over or under."""
    cell = SIZE / THREADS
    y, x = np.mgrid[0:SIZE, 0:SIZE]
    ix, iy = np.floor(x / cell).astype(int), np.floor(y / cell).astype(int)
    fx, fy = x / cell - ix, y / cell - iy
    warp_on_top = ((ix + iy) % 3) != 0
    # A thread's round back across its width, flattening where it dips under its neighbour.
    across_warp = np.sin(np.pi * fx)
    along_warp = 0.72 + 0.28 * np.sin(np.pi * fy)
    across_weft = np.sin(np.pi * fy)
    along_weft = 0.72 + 0.28 * np.sin(np.pi * fx)
    return np.where(warp_on_top, across_warp * along_warp, 0.62 * across_weft * along_weft)


def main():
    rng = np.random.default_rng(35)
    OUT.mkdir(parents=True, exist_ok=True)
    cloth = weave()
    fibres = tiling_noise(rng, 60, 300, 0.4)
    slubs = tiling_noise(rng, 8, 40, 0.6)
    wear = tiling_noise(rng, 2, 9, 0.8)

    height = cloth + 0.22 * fibres + 0.14 * slubs
    # Normals from the height, wrapping round the edges so the tile has no seam. Strong, so it shows at a distance.
    strength = 9.0
    dx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * strength
    dy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * strength
    normal = np.dstack((-dx, dy, np.ones_like(height)))
    normal /= np.linalg.norm(normal, axis=2, keepdims=True)
    Image.fromarray(np.uint8((normal * 0.5 + 0.5) * 255)).save(OUT / "normal.png")

    # Near white, darker in the gaps between threads and in worn patches, so a tint keeps the weave.
    shade = 0.74 + 0.26 * np.clip(cloth, 0, 1) + 0.07 * fibres + 0.06 * wear
    Image.fromarray(np.uint8(np.clip(shade, 0, 1) * 255)).convert("RGB").save(OUT / "color.png")

    # Matte all over: rough canvas never shines.
    rough = 0.86 + 0.08 * (1 - np.clip(cloth, 0, 1)) + 0.05 * fibres
    Image.fromarray(np.uint8(np.clip(rough, 0, 1) * 255)).save(OUT / "roughness.png")
    print("wrote", OUT)


if __name__ == "__main__":
    main()
