#!/usr/bin/env python3
"""元画像からアプリアイコンとアプリ内ロゴを級ごとに書き出す。

絵柄そのものはこのスクリプトでは扱わない。文字や配色を変えたいときは
元画像（`docs/assets/fpN-icon-source.png`）を直すこと。
ここにあるのは「App Storeに出せる形かどうかを検査して書き出す」処理だけ。

App Store のアイコンには決まりがある。満たしていなければ止める。
  - 1024x1024 の正方形
  - アルファチャンネルを持たない（透過があると審査で弾かれる）
  - 角丸を焼き込まない（Apple 側がマスクをかけるので、素材に角丸があると角に縁が残る）

加えて、絵柄が Apple の角丸マスクの外にはみ出していないかも見る。
はみ出しはビルドも審査も通ってしまい、ホーム画面に並べて初めて気付く類の欠陥なので、
書き出しのたびに機械で確かめる。

アプリ内ロゴ（AppLogo）も同じ元画像から作る。こちらは cornerRadius: 10 の浅いクリップなので、
角丸なしの正方形でないと角の残りがそのまま見える。

使い方: リポジトリのどこからでも `python scripts/make_app_icon.py`
必要なもの: Pillow
"""
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent

ICON_SIZE = 1024
LOGO_SIZES = [("AppLogo.png", 80), ("AppLogo@2x.png", 160), ("AppLogo@3x.png", 240)]

GRADES = {
    "FP3": ROOT / "docs/assets/fp3-icon-source.png",
    "FP2": ROOT / "docs/assets/fp2-icon-source.png",
}

# 背景からこれだけ離れていれば絵柄とみなす（RGB各成分の差の合計）
CONTENT_DELTA = 40

# iOSのアイコンマスクの近似。Appleのマスクは円弧ではなく superellipse なので、
# 円弧で判定すると実際には切れない絵柄まではみ出し扱いになる。
SUPERELLIPSE_EXPONENT = 5.0


def load_source(path: Path) -> Image.Image:
    if not path.exists():
        raise SystemExit(f"元画像が見つかりません: {path}")

    im = Image.open(path)

    if im.size != (ICON_SIZE, ICON_SIZE):
        raise SystemExit(
            f"{path.name}: {im.size[0]}x{im.size[1]} です。"
            f"App Storeのアイコンは {ICON_SIZE}x{ICON_SIZE} の正方形でなければなりません。"
        )

    # 透過があるとApp Store Connectがアップロードを弾く。
    # RGBへ変換するだけだと透明部分が黒く落ちるので、白地に載せてから落とす。
    if im.mode in ("RGBA", "LA") or "transparency" in im.info:
        print(f"  警告: {path.name} に透過があります。白地に載せてから不透明化します")
        background = Image.new("RGB", im.size, (255, 255, 255))
        background.paste(im.convert("RGBA"), mask=im.convert("RGBA").split()[-1])
        return background

    return im.convert("RGB")


def content_pixels(im: Image.Image) -> list[tuple[int, int]]:
    """絵柄の画素を拾う。

    各行の左端を背景色とみなす。背景が縦のグラデーションでも行ごとに基準を取り直すので、
    グラデーション自体を絵柄と誤認しない。
    """
    width, height = im.size
    px = im.load()
    points = []
    for y in range(height):
        bg = px[0, y]
        for x in range(width):
            c = px[x, y]
            if abs(c[0] - bg[0]) + abs(c[1] - bg[1]) + abs(c[2] - bg[2]) > CONTENT_DELTA:
                points.append((x, y))
    return points


def check_mask(im: Image.Image, name: str) -> None:
    """絵柄がAppleの角丸マスクの外に出ていないか確かめる"""
    points = content_pixels(im)
    if not points:
        raise SystemExit(f"{name}: 背景一色で絵柄がありません")

    half = ICON_SIZE / 2.0
    outside = sum(
        1
        for x, y in points
        if (abs(x + 0.5 - half) / half) ** SUPERELLIPSE_EXPONENT
        + (abs(y + 0.5 - half) / half) ** SUPERELLIPSE_EXPONENT
        > 1.0
    )

    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    print(f"  絵柄の範囲: x {min(xs)}..{max(xs)} / y {min(ys)}..{max(ys)}")

    if outside:
        raise SystemExit(
            f"{name}: 絵柄が角丸マスクの外に{outside}画素はみ出しています。"
            "ホーム画面で角が切れます。元画像の余白を広げてください。"
        )


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
    for grade, source in GRADES.items():
        print(f"{grade}  ← {source.relative_to(ROOT)}")
        image = load_source(source)
        check_mask(image, source.name)
        write(grade, image)
    return 0


if __name__ == "__main__":
    sys.exit(main())
