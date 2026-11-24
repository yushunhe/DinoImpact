#!/usr/bin/env python3
"""Export aligned idle/release frames, with zero to three arrows in each pose."""
from pathlib import Path

from PIL import Image, ImageDraw

ART = Path(__file__).resolve().parent
OUTPUT = ART.parents[1] / 'Assets/Resources/Dino'
FRAME_SIZE = (40, 48)
# Both cells share the same saddle, quiver mouth and hairline after cropping.
CELLS = [(86, -15, 846, 897), (915, -15, 1675, 897)]


def main():
    with Image.open(ART / 'rider-poses.png') as sheet:
        for pose, cell in zip(('idle', 'shoot'), CELLS):
            body = sheet.convert('RGBA').crop(cell).resize(FRAME_SIZE, Image.Resampling.BOX)
            body.putalpha(body.getchannel('A').point(lambda a: 255 if a >= 128 else 0))
            for count in range(4):
                frame = body.copy()
                draw = ImageDraw.Draw(frame)
                # Roots meet the diagonal opening of the quiver. Stagger the pale
                # fletchings so each remaining arrow reads at native resolution.
                for x, y, dx, dy in [(14, 23, -5, -6), (13, 24, -7, -3), (15, 23, -1, -8)][:count]:
                    tip = (x + dx, y + dy)
                    draw.line([tip, (x, y)], fill='#533721', width=2)
                    draw.line([tip, (x + dx // 2, y + dy // 2)], fill='#f9edcb', width=2)
                    draw.point(tip, fill='#fff9e9')
                name = 'rider' if (pose, count) == ('idle', 3) else f'rider_{pose}_{count}'
                frame.save(OUTPUT / f'{name}.png')


if __name__ == '__main__':
    main()
