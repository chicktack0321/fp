#!/usr/bin/env python3
"""作問バッチをシードへ取り込む。

`questionId` は作問時には振らず、ここで採番する。AIに採番させると、
バッチをまたいだ連番の管理ができず衝突する。

バッチファイルは questionId を持たない問題の配列（作問プロンプトの出力形式そのまま）。
取り込み先の級はバッチの置き場所（`batches/FP3/` か `batches/FP2/`）で決まる。

    python scripts/merge_questions.py batches/FP3/pension-01.json [...]

やること:
  - 細目ごとに既存の最大連番の続きから採番する
  - 問題文が既存と重複していれば取り込まずに報告する
  - シードの version を1つ上げる（アプリ更新時にUpsertを走らせるため）

取り込み後は必ず `python scripts/validate_seed.py` を通すこと。
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GRADES = ["FP3", "FP2"]


def seed_path(grade: str) -> Path:
    return ROOT / grade / "Resources" / "question_master_seed.json"


def grade_of(path: Path) -> str:
    grade = next((g for g in GRADES if g in path.resolve().parts), None)
    if grade is None:
        raise SystemExit(f"バッチの置き場所から級を判定できません: {path}（batches/FP3/ か batches/FP2/ に置く）")
    return grade


def next_numbers(questions, prefix):
    """細目ごとの次の連番を求める。

    欠番は埋めない。取り下げた問題のIDを再利用すると、その問題を解いた人の
    学習履歴が別の問題に引き継がれてしまう。
    """
    pattern = re.compile(rf"^{re.escape(prefix)}_([A-Z]+)_(\d{{4}})$")
    highest = {}
    for q in questions:
        match = pattern.match(q.get("questionId", ""))
        if not match:
            continue
        category, number = match.group(1), int(match.group(2))
        highest[category] = max(highest.get(category, 0), number)
    return {category: number + 1 for category, number in highest.items()}


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__, file=sys.stderr)
        return 1

    paths = [Path(p) for p in sys.argv[1:]]
    grades = {grade_of(p) for p in paths}
    if len(grades) > 1:
        raise SystemExit(f"1回の実行で複数の級を混ぜられません: {sorted(grades)}")
    grade = grades.pop()

    seed = json.loads(seed_path(grade).read_text(encoding="utf-8"))
    questions = seed["questions"]
    prefix = grade

    counters = next_numbers(questions, prefix)
    existing_texts = {q["questionText"].strip(): q["questionId"] for q in questions}

    added = 0
    skipped = []

    for path in paths:
        batch = json.loads(path.read_text(encoding="utf-8"))
        for entry in batch:
            text = entry["questionText"].strip()
            if text in existing_texts:
                skipped.append((path.name, text[:40], existing_texts[text]))
                continue

            category = entry["midCategory"]
            number = counters.get(category, 1)
            counters[category] = number + 1

            entry["questionId"] = f"{prefix}_{category}_{number:04d}"
            questions.append(entry)
            existing_texts[text] = entry["questionId"]
            added += 1

    # version を上げないと、更新後のアプリでUpsertが走らず新しい問題が出てこない
    seed["version"] += 1
    seed_path(grade).write_text(
        json.dumps(seed, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    print(f"{grade}: {added}問を取り込みました（シードversion {seed['version']} / 合計{len(questions)}問）")
    for name, text, existing in skipped:
        print(f"  スキップ（問題文が重複）: {name} \"{text}…\" ← {existing}")
    print("\n次に: python scripts/validate_seed.py " + grade)
    return 0


if __name__ == "__main__":
    sys.exit(main())
