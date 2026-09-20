#!/usr/bin/env python3
"""問題シードJSONの機械検証。

AI生成の問題は人手レビューを通す前提だが、レビューで見落としやすい形式面の欠陥
（IDの重複、解説の欠落、科目と細目の不一致、級にありえない選択肢数）は機械で確実に落とす。
CIとユニットテストの両方から呼ぶ。

級ごとの期待値（IDの接頭辞・ありえる選択肢の数・法令基準日）は `FPn/AppFlavor.swift` から
読み取る。ここに同じ値を書き写すと、片方だけ直したときに検証が素通りするため。

使い方:
    python scripts/validate_seed.py              # 3級・2級の両方を検証する
    python scripts/validate_seed.py FP3          # 級を指定する
    python scripts/validate_seed.py path/to.json # ファイルを直接指定する（親ディレクトリで級を判定）
"""

import json
import re
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# 細目コード → 科目。Swift側の MidCategory.field と対応させること。
# 3級と2級で細目は共通（問われる深さが違うだけ）なので、この表も級で分けない。
MID_CATEGORIES = {
    # ライフプランニングと資金計画
    "ETHIC": "lifePlanning",
    "LPLAN": "lifePlanning",
    "SOCINS": "lifePlanning",
    "PENSION": "lifePlanning",
    "CORPPEN": "lifePlanning",
    "FUND": "lifePlanning",
    "SME": "lifePlanning",
    # リスク管理
    "INSBASE": "riskManagement",
    "LIFEINS": "riskManagement",
    "NLIFEINS": "riskManagement",
    "THIRDINS": "riskManagement",
    "INSTAX": "riskManagement",
    "CORPINS": "riskManagement",
    # 金融資産運用
    "MKTENV": "financialAssets",
    "SAVINGS": "financialAssets",
    "TRUST": "financialAssets",
    "BOND": "financialAssets",
    "EQUITY": "financialAssets",
    "FOREX": "financialAssets",
    "PORT": "financialAssets",
    "FINTAX": "financialAssets",
    "FINLAW": "financialAssets",
    # タックスプランニング
    "TAXBASE": "taxPlanning",
    "INCOME": "taxPlanning",
    "DEDUCT": "taxPlanning",
    "TAXCALC": "taxPlanning",
    "FILING": "taxPlanning",
    "CORPTAX": "taxPlanning",
    "CONSTAX": "taxPlanning",
    "LOCALTAX": "taxPlanning",
    # 不動産
    "REBASE": "realEstate",
    "RETRADE": "realEstate",
    "RELAW": "realEstate",
    "RETAX": "realEstate",
    "REUSE": "realEstate",
    # 相続・事業承継
    "GIFT": "inheritance",
    "SUCCESS": "inheritance",
    "INHTAX": "inheritance",
    "VALUE": "inheritance",
    "BIZSUCC": "inheritance",
}

FIELD_NAMES = {
    "lifePlanning": "ライフプランニングと資金計画",
    "riskManagement": "リスク管理",
    "financialAssets": "金融資産運用",
    "taxPlanning": "タックスプランニング",
    "realEstate": "不動産",
    "inheritance": "相続・事業承継",
}

ALL_LABELS = ["A", "B", "C", "D"]

# 本文の長さ上限。レイアウトが崩れない範囲として設計仕様書で決めた値
MAX_QUESTION_LENGTH = 300
MAX_CHOICE_LENGTH = 120

GRADES = ["FP3", "FP2"]


class Flavor:
    """`FPn/AppFlavor.swift` から級固有の期待値を読む。

    Swift と Python に同じ値を書くと、改正対応で片方を直し忘れたときに
    検証が素通りする。値の出どころはアプリが実際に表示する Swift 側に一本化する。
    """

    def __init__(self, grade: str):
        self.grade = grade
        source = (ROOT / grade / "AppFlavor.swift").read_text(encoding="utf-8")
        self.prefix = self._one(source, r'questionIdPrefix:\s*"([^"]+)"')
        self.law_basis_date = self._one(source, r'lawBasisDate:\s*"([^"]+)"')
        counts = self._one(source, r"choiceCounts:\s*\[([0-9,\s]+)\]")
        self.choice_counts = {int(n) for n in counts.replace(" ", "").split(",") if n}

    @staticmethod
    def _one(source: str, pattern: str) -> str:
        match = re.search(pattern, source)
        if not match:
            raise SystemExit(f"AppFlavor.swift から {pattern} を読み取れません")
        return match.group(1)

    @property
    def seed_path(self) -> Path:
        return ROOT / self.grade / "Resources" / "question_master_seed.json"

    @property
    def id_pattern(self) -> re.Pattern:
        return re.compile(rf"^{re.escape(self.prefix)}_([A-Z]+)_(\d{{4}})$")

    @property
    def choice_counts_label(self) -> str:
        return "か".join(str(n) for n in sorted(self.choice_counts))


def validate(path: Path, flavor: Flavor) -> list[str]:
    """検出したエラーの一覧を返す。空リストなら合格。"""
    errors: list[str] = []

    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        return [f"JSONとして読めません: {e}"]

    for key in ("version", "lawBasisDate", "questions"):
        if key not in data:
            errors.append(f"トップレベルに '{key}' がありません")
    if errors:
        return errors

    # 表示する法令基準日と出題内容がずれると、利用者は古い数値を覚えたまま受験することになる
    if data["lawBasisDate"] != flavor.law_basis_date:
        errors.append(
            f"lawBasisDate '{data['lawBasisDate']}' が AppFlavor の "
            f"'{flavor.law_basis_date}' と一致しません"
        )

    questions = data["questions"]
    if not isinstance(questions, list) or not questions:
        return ["'questions' が空、または配列ではありません"]

    seen_ids: set[str] = set()
    seen_texts: dict[str, str] = {}

    for i, q in enumerate(questions):
        where = f"[{i}] {q.get('questionId', '(IDなし)')}"

        qid = q.get("questionId", "")
        match = flavor.id_pattern.match(qid)
        if not match:
            errors.append(
                f"{where}: questionId の形式が {flavor.prefix}_<細目>_<4桁> ではありません"
            )
        else:
            id_category = match.group(1)
            if id_category not in MID_CATEGORIES:
                errors.append(f"{where}: questionId の細目 '{id_category}' は未知のコードです")
            elif id_category != q.get("midCategory"):
                # IDと属性がずれていると、一覧の絞り込みと採番体系が食い違う
                errors.append(
                    f"{where}: questionId の細目 '{id_category}' が "
                    f"midCategory '{q.get('midCategory')}' と一致しません"
                )

        if qid in seen_ids:
            errors.append(f"{where}: questionId が重複しています")
        seen_ids.add(qid)

        text = (q.get("questionText") or "").strip()
        if not text:
            errors.append(f"{where}: questionText が空です")
        elif len(text) > MAX_QUESTION_LENGTH:
            errors.append(f"{where}: questionText が{MAX_QUESTION_LENGTH}字を超えています（{len(text)}字）")
        # 同じ論点を二度出題しないための最低限の検出。表記まで同一のものだけを拾う
        if text in seen_texts:
            errors.append(f"{where}: questionText が {seen_texts[text]} と重複しています")
        else:
            seen_texts[text] = qid

        mid = q.get("midCategory")
        field = q.get("field")
        if mid not in MID_CATEGORIES:
            errors.append(f"{where}: midCategory '{mid}' は未知のコードです")
        elif MID_CATEGORIES[mid] != field:
            errors.append(
                f"{where}: field '{field}' は midCategory '{mid}' の科目 "
                f"'{MID_CATEGORIES[mid]}' と一致しません"
            )

        choices = q.get("choices") or {}
        count = len(choices)
        # 選択肢の数は級で決まっている（3級は○×か三答択一、2級は四答択一）。
        # 違う数が混ざっていたら、級を取り違えたデータとして落とす
        if count not in flavor.choice_counts:
            errors.append(
                f"{where}: 選択肢が{count}個です。"
                f"{flavor.grade}は{flavor.choice_counts_label}択のみ"
            )
        expected_labels = ALL_LABELS[:count] if count else []
        if sorted(choices.keys()) != expected_labels:
            errors.append(
                f"{where}: choices のキーが {'/'.join(expected_labels) or '(なし)'} ではありません"
            )
        else:
            for label in expected_labels:
                choice = (choices[label] or "").strip()
                if not choice:
                    errors.append(f"{where}: 選択肢 {label} が空です")
                elif len(choice) > MAX_CHOICE_LENGTH:
                    errors.append(
                        f"{where}: 選択肢 {label} が{MAX_CHOICE_LENGTH}字を超えています（{len(choice)}字）"
                    )
            # 同じ文言の選択肢があると、正解を選んでも不正解になりうる
            texts = [c.strip() for c in choices.values()]
            if len(set(texts)) != len(texts):
                errors.append(f"{where}: 選択肢に同じ文言のものがあります")

        correct = q.get("correctChoice")
        if correct not in expected_labels:
            errors.append(
                f"{where}: correctChoice '{correct}' がこの問題に存在する選択肢ではありません"
            )

        if not (q.get("explanation") or "").strip():
            errors.append(f"{where}: explanation が空です")

        explanations = q.get("choiceExplanations") or {}
        if sorted(explanations.keys()) != expected_labels:
            errors.append(f"{where}: choiceExplanations のキーが choices と一致しません")
        else:
            for label in expected_labels:
                body = (explanations[label] or "").strip()
                if not body:
                    errors.append(f"{where}: 選択肢 {label} の解説が空です")
                    continue
                # 誤答の解説が「なぜ違うか」から書き出されているかを機械的に担保する。
                # ここが崩れていると、解説パネルで正誤の区別がつかなくなる
                expected = "正解" if label == correct else "不正解"
                if not body.startswith(expected):
                    errors.append(
                        f"{where}: 選択肢 {label} の解説が '{expected}' で始まっていません"
                    )

        difficulty = q.get("difficulty", 2)
        if difficulty not in (1, 2, 3):
            errors.append(f"{where}: difficulty '{difficulty}' が 1/2/3 ではありません")

        keywords = q.get("keywords")
        if keywords is not None and not isinstance(keywords, list):
            errors.append(f"{where}: keywords が配列ではありません")

        per_question_basis = q.get("lawBasisDate")
        if per_question_basis is not None and not isinstance(per_question_basis, str):
            errors.append(f"{where}: lawBasisDate が文字列ではありません")

    return errors


def report_distribution(path: Path, flavor: Flavor) -> None:
    """出題の偏りを目視で確認するための集計。エラーではないので警告としてのみ出す。"""
    data = json.loads(path.read_text(encoding="utf-8"))
    questions = data["questions"]

    by_field = Counter(q.get("field") for q in questions)
    by_difficulty = Counter(q.get("difficulty", 2) for q in questions)
    by_category = Counter(q.get("midCategory") for q in questions)
    by_answer = Counter(q.get("correctChoice") for q in questions)
    by_choice_count = Counter(len(q.get("choices") or {}) for q in questions)

    total = len(questions)
    print(
        f"収録問題数: {total}問"
        f"（{flavor.grade} / シードversion {data['version']} / 法令基準日 {data['lawBasisDate']}）"
    )

    # 学科は6科目から10問ずつ出るため、収録も均等が目標になる
    print("\n科目別（本試験は6科目から10問ずつ＝各16.7%）:")
    for field, label in FIELD_NAMES.items():
        count = by_field.get(field, 0)
        print(f"  {label:<20} {count:>4}問 ({count / total * 100:5.1f}%)")

    print("\n難易度別（目安は 30 : 50 : 20）:")
    for level, label in ((1, "基礎"), (2, "標準"), (3, "応用")):
        count = by_difficulty.get(level, 0)
        print(f"  {label:<12} {count:>4}問 ({count / total * 100:5.1f}%)")

    print("\n出題形式:")
    for count, n in sorted(by_choice_count.items()):
        label = "○×式" if count == 2 else f"{count}択"
        print(f"  {label:<8} {n:>4}問 ({n / total * 100:5.1f}%)")

    # 正解の位置の偏り。アプリは出題時にシャッフルするため学習には影響しないが、
    # 偏りが大きいと作問時に正解を先に書く癖が出ている合図になる。
    # ○×式は正誤どちらが答えかに意味があるので、ここでは択一だけを見る。
    #
    # 3択と4択は均等の水準が違う（33%と25%）ので、混ぜて一つの割合で見ない。
    # 混ぜると、3択だけのデータが常に偏って見える。
    choice_questions = [q for q in questions if len(q.get("choices") or {}) > 2]
    if choice_questions:
        print("\n正解の位置（択一のみ。偏っていれば作問の癖の合図）:")
        for n in sorted({len(q["choices"]) for q in choice_questions}):
            group = [q for q in choice_questions if len(q["choices"]) == n]
            counts = Counter(q.get("correctChoice") for q in group)
            labels = ALL_LABELS[:n]
            line = "  ".join(f"{label}:{counts.get(label, 0):>3}" for label in labels)
            print(f"  {n}択（{len(group)}問）  {line}")
            # 均等からの離れ具合で判定する。3択なら33%、4択なら25%が均等
            most = max(counts.values())
            if most / len(group) > 1 / n + 0.12:
                print(
                    f"    警告: {most / len(group) * 100:.0f}%が1か所に集中しています"
                    f"（均等は{100 / n:.0f}%）。"
                    "python scripts/rebalance_answers.py で平準化できます。"
                )

    # ○×式で「正しい」ばかりが答えになっていると、読まずに○を選んで当たってしまう
    tf_questions = [q for q in questions if len(q.get("choices") or {}) == 2]
    if tf_questions:
        correct_a = sum(1 for q in tf_questions if q.get("correctChoice") == "A")
        print(f"\n○×式の正解（Aが「正しい」側。半々が目安）: A:{correct_a} / B:{len(tf_questions) - correct_a}")
        if abs(correct_a / len(tf_questions) - 0.5) > 0.20:
            print("  警告: ○と×の偏りが大きすぎます。読まずに当てられてしまいます。")

    # 正解だけが長いと、内容を知らなくても「いちばん長い選択肢」を選んで当てられてしまう。
    # 文字数そのものより、画面で何行に折り返されるかが利用者に見える差になるので行数で測る。
    per_line = 22  # iPhoneの選択肢ボタンで日本語がおおよそ折り返す字数

    def line_count(text):
        return -(-len(text) // per_line)

    longest_lines = 0
    for q in choice_questions:
        correct = q.get("correctChoice")
        choices = q.get("choices") or {}
        if correct not in choices:
            continue
        others = [line_count(v) for k, v in choices.items() if k != correct]
        if others and line_count(choices[correct]) > max(others):
            longest_lines += 1

    if choice_questions:
        print("\n選択肢の長さ（正解だけが長いと、読まずに当てられてしまう）:")
        ratio = longest_lines / len(choice_questions)
        print(f"  正解が行数で最も長い問題: {longest_lines}問 ({ratio * 100:.0f}%)")
        if ratio > 0.35:
            print(
                "  警告: 正解が最も長い問題が多すぎます。誤答を書き足して差をなくしてください"
                "（削るのではなく足すと、誤答としてのもっともらしさも上がります）。"
            )

    print("\n細目別:")
    missing = [c for c in MID_CATEGORIES if c not in by_category]
    for category, count in sorted(by_category.items()):
        print(f"  {category:<10} {count:>4}問")
    if missing:
        print(f"\n  未収録の細目: {', '.join(sorted(missing))}")


def run(flavor: Flavor, path: Path) -> bool:
    print(f"===== {flavor.grade}: {path.relative_to(ROOT)}")
    if not path.exists():
        print(f"シードファイルが見つかりません: {path}", file=sys.stderr)
        return False

    errors = validate(path, flavor)
    if errors:
        print(f"検証に失敗しました（{len(errors)}件）:\n", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return False

    print("検証に合格しました\n")
    report_distribution(path, flavor)
    print()
    return True


def main() -> int:
    arg = sys.argv[1] if len(sys.argv) > 1 else None

    if arg in GRADES:
        targets = [(Flavor(arg), Flavor(arg).seed_path)]
    elif arg:
        path = Path(arg).resolve()
        # 級はファイルの置き場所（FP3/ か FP2/）で決まる
        grade = next((g for g in GRADES if g in path.parts), None)
        if grade is None:
            print(f"パスから級を判定できません: {path}", file=sys.stderr)
            return 1
        targets = [(Flavor(grade), path)]
    else:
        targets = [(Flavor(g), Flavor(g).seed_path) for g in GRADES]

    return 0 if all(run(flavor, path) for flavor, path in targets) else 1


if __name__ == "__main__":
    sys.exit(main())
