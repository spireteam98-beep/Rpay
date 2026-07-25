from collections import deque
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "images" / "wayaki_logo.png"


def create_icon(size: int, safe_scale: float = 0.70) -> Image.Image:
    source = Image.open(SOURCE).convert("RGB")
    left_area = source.crop((0, 0, 820, source.height))
    luminance = left_area.convert("L")
    pixels = luminance.load()
    visited = bytearray(luminance.width * luminance.height)
    mask = Image.new("L", luminance.size)
    mask_pixels = mask.load()

    for y in range(luminance.height):
        for x in range(luminance.width):
            offset = y * luminance.width + x
            if visited[offset] or pixels[x, y] <= 52:
                continue

            queue = deque([(x, y)])
            visited[offset] = 1
            component = []
            min_x = x
            while queue:
                current_x, current_y = queue.popleft()
                component.append((current_x, current_y))
                min_x = min(min_x, current_x)
                for next_x, next_y in (
                    (current_x - 1, current_y),
                    (current_x + 1, current_y),
                    (current_x, current_y - 1),
                    (current_x, current_y + 1),
                ):
                    if not (
                        0 <= next_x < luminance.width
                        and 0 <= next_y < luminance.height
                    ):
                        continue
                    next_offset = next_y * luminance.width + next_x
                    if visited[next_offset] or pixels[next_x, next_y] <= 52:
                        continue
                    visited[next_offset] = 1
                    queue.append((next_x, next_y))

            if len(component) > 500 and min_x < 650:
                for component_x, component_y in component:
                    mask_pixels[component_x, component_y] = 255

    bounds = mask.getbbox()
    if bounds is None:
        raise RuntimeError("Could not locate the Wayaki W mark in the official logo.")

    mark_rgb = Image.new("RGB", left_area.size, "#050506")
    mark_rgb.paste(left_area, mask=mask)
    mark = mark_rgb.crop(bounds)
    target = max(1, int(size * safe_scale))
    mark.thumbnail((target, target), Image.Resampling.LANCZOS)

    icon = Image.new("RGB", (size, size), "#050506")
    icon.paste(mark, ((size - mark.width) // 2, (size - mark.height) // 2))
    return icon


def save_png(path: Path, size: int, safe_scale: float = 0.70) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    create_icon(size, safe_scale).save(path, "PNG", optimize=True)


save_png(ROOT / "landing" / "favicon.png", 64)
save_png(ROOT / "landing" / "assets" / "wayaki-icon-180.png", 180)
save_png(ROOT / "landing" / "assets" / "wayaki-icon-192.png", 192)
save_png(ROOT / "landing" / "assets" / "wayaki-icon-512.png", 512)

save_png(ROOT / "web" / "favicon.png", 64)
save_png(ROOT / "web" / "icons" / "Icon-192.png", 192)
save_png(ROOT / "web" / "icons" / "Icon-512.png", 512)
save_png(ROOT / "web" / "icons" / "Icon-maskable-192.png", 192, 0.58)
save_png(ROOT / "web" / "icons" / "Icon-maskable-512.png", 512, 0.58)

ico_source = create_icon(256)
ico_source.save(
    ROOT / "landing" / "favicon.ico",
    "ICO",
    sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
)
ico_source.save(
    ROOT / "web" / "favicon.ico",
    "ICO",
    sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
)

print("Generated Wayaki web icons from", SOURCE)
