#!/usr/bin/env python3
"""正解の位置の偏りをならす。

作問していると、正解を先に書いてから誤答を足す癖が出て、正解がAやBに寄る。
アプリは出題時に選択肢をシャッフルするので学習そのものには影響しないが、
問題一覧の詳細はシード上の並びで表示されるし、偏りはレビュー時に
「誤答を作り込めていない問題」を見つける手掛かりにもなるので、ならしておく。

やること: 択一問題の選択肢とその解説を入れ替えて、正解のラベルを均等に配り直す。
選択肢の文言・解説・正解の対応関係は保ったまま位置だけを変えるので、内容は変わらない。

○×式（2択）は対象外。「正しい」「誤り」の並びには意味があり、
入れ替えると読み手の期待と食い違う。○と×の偏りは作問側で直すこと。

    python scripts/rebalance_answers.py FP3        # 書き換える
    python scripts/rebalance_answers.py FP3 --dry  # 変更点を出すだけ

実行後は必ず `python scripts/validate_seed.py` を通すこと。
"""
import json
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GRADES = ["FP3", "FP2"]
ALL_LABELS = ["A", "B", "C", "D"]


def seed_path(grade: str) -> Path:
    return ROOT / grade / "Resources" / "question_master_seed.json"


def rotate(question: dict, target: str) -> bool:
    """正解が `target` の位置に来るよう、選択肢と解説を入れ替える。

    正解と target の中身を交換するだけの最小の入れ替えにしている。
    全体をシャッフルすると差分が大きくなり、レビュー時に
    「内容を直したのか位置を動かしただけなのか」を読み分けられなくなる。
    """
    current = question["correctChoice"]
    if current == target:
        return False

    choices = question["choices"]
    explanations = question["choiceExplanations"]
    choices[current], choices[target] = choices[target], choices[current]
    explanations[current], explanations[target] = explanations[target], explanations[current]
    question["correctChoice"] = target
    return True


def rebalance(questions: list[dict], dry: bool) -> int:
    changed = 0

    # 選択肢の数ごとに配り直す。3択と4択で均等の意味が違う
    for n in sorted({len(q["choices"]) for q in questions if len(q["choices"]) > 2}):
        group = [q for q in questions if len(q["choices"]) == n]
        labels = ALL_LABELS[:n]
        # 各ラベルの目標本数。割り切れない分は先頭のラベルから1問ずつ多く持たせる
        quota = {label: len(group) // n for label in labels}
        for i in range(len(group) % n):
            quota[labels[i]] += 1

        before = Counter(q["correctChoice"] for q in group)

        # すでに目標以下のラベルはそのまま残し、超過しているものだけ動かす。
        # 全問を並べ替えると、正解の位置が毎回変わって差分が読めなくなる。
        assigned = Counter()
        overflow = []
        for q in group:
            label = q["correctChoice"]
            if assigned[label] < quota[label]:
                assigned[label] += 1
            else:
                overflow.append(q)

        need = [label for label in labels for _ in range(quota[label] - assigned[label])]
        for q, label in zip(overflow, need):
            if rotate(q, label):
                changed += 1

        after = Counter(q["correctChoice"] for q in group)
        print(f"  {n}択（{len(group)}問）")
        print("    前: " + "  ".join(f"{l}:{before.get(l, 0):>3}" for l in labels))
        print("    後: " + "  ".join(f"{l}:{after.get(l, 0):>3}" for l in labels))

    if dry:
        print("\n--dry のため書き込んでいません")
    return changed


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    dry = "--dry" in sys.argv

    grades = args or GRADES
    for grade in grades:
        if grade not in GRADES:
            print(f"級は {' / '.join(GRADES)} のいずれかを指定してください: {grade}", file=sys.stderr)
            return 1

    for grade in grades:
        path = seed_path(grade)
        seed = json.loads(path.read_text(encoding="utf-8"))
        print(f"{grade}:")
        changed = rebalance(seed["questions"], dry)
        if changed and not dry:
            # version は上げない。位置を入れ替えただけで出題内容は変わっておらず、
            # 利用者の端末でUpsertを走らせる必要がないため（問題を足したときに上げる）
            path.write_text(json.dumps(seed, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
            print(f"  {changed}問の正解の位置を入れ替えました")
        elif not changed:
            print("  入れ替えの必要はありませんでした")

    print("\n次に: python scripts/validate_seed.py")
    return 0


if __name__ == "__main__":
    sys.exit(main())
