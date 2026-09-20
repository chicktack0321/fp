#!/usr/bin/env python3
"""アプリアイコンとアプリ内ロゴを級ごとに書き出す。

元になる絵柄を外から受け取らず、この場で描いている。
理由は、3級と2級で変わるのが級の表記だけであり、画像編集ソフトで2枚を別々に保守すると
色や字詰めが必ずずれるため。描画条件をコードに置けば、2つのアイコンは常に同じ体裁になる。

App Store のアイコンには決まりがある。
  - 1024x1024 の正方形
  - アルファチャンネルを持たない（透過があると審査で弾かれる）
  - 角丸を焼き込まない（Apple 側がマスクをかけるので、素材に角丸があると角に縁が残る）

アプリ内ロゴ（AppLogo）も同じ絵柄から作る。こちらは cornerRadius: 10 の浅いクリップなので、
角丸なしの正方形でないと角の残りがそのまま見える。

使い方: リポジトリのどこからでも `python scripts/make_app_icon.py`
必要なもの: Pillow
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent

ICON_SIZE = 1024
LOGO_SIZES = [("AppLogo.png", 80), ("AppLogo@2x.png", 160), ("AppLogo@3x.png", 240)]

# 級ごとの配色。3級は入門らしい青、2級はひとつ深い藍にして、
# ホーム画面に2つ並んだときに取り違えないようにする（形と字は同じなので色で分ける）
GRADES = {
    "FP3": {"badge": "3級", "top": (56, 122, 223), "bottom": (24, 62, 140)},
    "FP2": {"badge": "2級", "top": (86, 96, 204), "bottom": (38, 32, 104)},
}

# 日本語（「級」）が出る太めのフォントを順に探す。
# 見つからないと豆腐（□）が焼き込まれたアイコンができてしまうので、無ければ止める。
JP_FONT_CANDIDATES = [
    "C:/Windows/Fonts/YuGothB.ttc",
    "C:/Windows/Fonts/meiryob.ttc",
    "C:/Windows/Fonts/msgothic.ttc",
    "/System/Library/Fonts/ttf/HiraginoSans-W7.ttc",
    "/System/Library/Fonts/Hiragino Sans W7.ttc",
    "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc",
]
# ラテン字（"FP"）は和文フォントの欧文より、専用の太字のほうが字面が締まる
LATIN_FONT_CANDIDATES = [
    "C:/Windows/Fonts/arialbd.ttf",
    "C:/Windows/Fonts/segoeuib.ttf",
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
] + JP_FONT_CANDIDATES


def load_font(candidates, size):
    for path in candidates:
        if Path(path).exists():
            try:
                return ImageFont.truetype(path, size)
            except OSError:
                continue
    return None


def vertical_gradient(size, top, bottom):
    """縦のグラデーション。単色だと他の学習アプリに埋もれる"""
    gradient = Image.new("RGB", (1, size))
    for y in range(size):
        t = y / max(size - 1, 1)
        gradient.putpixel(
            (0, y),
            tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3)),
        )
    return gradient.resize((size, size), Image.BICUBIC)


def centered(draw, font, text):
    """テキストの実寸（bbox）を返す。フォントの行送りを含む高さで中央を取ると、
    字面が上寄りに見えるため必ず bbox から測る"""
    box = draw.textbbox((0, 0), text, font=font)
    return box[2] - box[0], box[3] - box[1], box[0], box[1]


def draw_icon(grade: str, spec: dict) -> Image.Image:
    size = ICON_SIZE
    image = vertical_gradient(size, spec["top"], spec["bottom"])
    draw = ImageDraw.Draw(image)

    latin = load_font(LATIN_FONT_CANDIDATES, int(size * 0.42))
    jp = load_font(JP_FONT_CANDIDATES, int(size * 0.17))
    if latin is None or jp is None:
        raise SystemExit(
            "日本語の太字フォントが見つかりません。JP_FONT_CANDIDATES にパスを足してください。"
        )

    # "FP" は中央よりやや上。下に級のバッジを置く前提で重心を取る
    w, h, ox, oy = centered(draw, latin, "FP")
    draw.text(
        ((size - w) / 2 - ox, size * 0.38 - h / 2 - oy),
        "FP",
        font=latin,
        fill=(255, 255, 255),
    )

    # 級のバッジ。白地に級の色で抜くと、小さく縮めても「3」「2」が潰れない
    badge = spec["badge"]
    bw, bh, box_x, box_y = centered(draw, jp, badge)
    pad_x, pad_y = size * 0.075, size * 0.045
    box_w, box_h = bw + pad_x * 2, bh + pad_y * 2
    left, top = (size - box_w) / 2, size * 0.66
    draw.rounded_rectangle(
        [left, top, left + box_w, top + box_h],
        radius=box_h / 2,
        fill=(255, 255, 255),
    )
    draw.text(
        (left + pad_x - box_x, top + pad_y - box_y),
        badge,
        font=jp,
        fill=spec["bottom"],
    )

    return image


def write(grade: str, image: Image.Image) -> None:
    assets = ROOT / grade / "Resources" / "Assets.xcassets"
    icon_path = assets / "AppIcon.appiconset" / "AppIcon-1024.png"
    logo_dir = assets / "AppLogo.imageset"
    icon_path.parent.mkdir(parents=True, exist_ok=True)
    logo_dir.mkdir(parents=True, exist_ok=True)

    # "RGB" のまま保存する。アルファチャンネルが残っていると App Store Connect が弾く
    image.save(icon_path)
    print(f"  {icon_path.relative_to(ROOT)}")

    for name, px in LOGO_SIZES:
        path = logo_dir / name
        image.resize((px, px), Image.LANCZOS).save(path)
        print(f"  {path.relative_to(ROOT)}")


def main() -> int:
    for grade, spec in GRADES.items():
        print(f"{grade}:")
        write(grade, draw_icon(grade, spec))
    return 0


if __name__ == "__main__":
    sys.exit(main())
