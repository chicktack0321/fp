import Foundation
import SwiftData

/// 問題マスターデータ。アプリ更新時に同梱JSONで丸ごとUpsertされる Read-Only 想定のテーブル。
///
/// `UserProgress` とは `questionId` (String) でのみ緩く結びつけ、SwiftDataの `@Relationship` は張らない。
/// 理由: リレーションを張ると QuestionMaster の delete/upsert 時に UserProgress へカスケードが
/// 波及するリスクがあるため。「マスターは総入れ替え、学習履歴は絶対保持」という要件上、
/// 意図的に疎結合にしている。
@Model
final class QuestionMaster {
    /// `<級>_<細目コード>_<4桁連番>`（例: "FP3_PENSION_0042"）。JSON側の主キーと一致させる。
    /// **公開後の改名は禁止**。改名は「削除+新規」となり、その問題の学習履歴が全ユーザーで失われる。
    @Attribute(.unique) var questionId: String

    var questionText: String

    /// 選択肢。シード上のA〜Dの並びをそのまま保持する。
    /// 出題時は毎回シャッフルするため（`QuizViewModel.buildQuestion`）、この並び順自体に意味はない。
    ///
    /// 使う数は問題によって変わる（`choiceCount`）。使わない分は空文字で残す。
    /// 配列にせず固定のプロパティにしているのは、SwiftDataの述語（`#Predicate`）で
    /// 配列要素を扱うより素直で、かつ選択肢ごとの解説と1対1で並ぶため。
    var choiceA: String
    var choiceB: String
    var choiceC: String
    var choiceD: String

    /// 実際に出題する選択肢の数（2〜4）。
    ///
    /// FP技能検定は級によって形式が違う。3級の学科は ○×式（2択）と三答択一式（3択）、
    /// 2級の学科は四答択一式（4択）。级ごとにモデルを分けると共通コードが
    /// 級を意識することになるため、1つのモデルで数を可変にしている。
    var choiceCount: Int = Self.maxChoiceCount

    var correctChoiceRaw: String

    /// 正解の理由の要約
    var explanation: String

    /// 選択肢ごとの解説。独立したフィールドで持つのは、解説画面で
    /// 「利用者が選んだ選択肢の解説」だけを取り出して強調表示するため。
    /// 1本のテキストに混ぜると分解できない。
    var explanationA: String
    var explanationB: String
    var explanationC: String
    var explanationD: String

    var fieldRaw: String
    var midCategoryRaw: String

    /// 主題キーワード（"小規模宅地等の特例" など）。問題一覧の検索と、作問時の重複検出に使う
    var keywords: [String]

    /// 準拠した法令基準日（例: "2026-04-01"）。
    ///
    /// FP技能検定は試験日ではなく法令基準日時点の制度で出題され、税制・社会保険の数値は
    /// 毎年変わる。改正のたびに古い問題を機械的に洗い出す必要があるため、問題ごとに持つ。
    var lawBasisDate: String

    /// 難易度。出題範囲の絞り込みと課金の境界を兼ねる（`AccessRights.availableDifficulties`）
    var difficultyRaw: Int

    /// マスターデータの更新検知用（seed JSON の updatedAt をそのまま保持）
    var updatedAt: Date

    init(
        questionId: String,
        questionText: String,
        choiceA: String,
        choiceB: String,
        choiceC: String = "",
        choiceD: String = "",
        choiceCount: Int = QuestionMaster.maxChoiceCount,
        correctChoice: ChoiceLabel,
        explanation: String,
        explanationA: String,
        explanationB: String,
        explanationC: String = "",
        explanationD: String = "",
        field: ExamField,
        midCategory: MidCategory,
        keywords: [String] = [],
        lawBasisDate: String,
        difficulty: QuestionDifficulty = .standard,
        updatedAt: Date = .now
    ) {
        self.questionId = questionId
        self.questionText = questionText
        self.choiceA = choiceA
        self.choiceB = choiceB
        self.choiceC = choiceC
        self.choiceD = choiceD
        self.choiceCount = Self.clampChoiceCount(choiceCount)
        self.correctChoiceRaw = correctChoice.rawValue
        self.explanation = explanation
        self.explanationA = explanationA
        self.explanationB = explanationB
        self.explanationC = explanationC
        self.explanationD = explanationD
        self.fieldRaw = field.rawValue
        self.midCategoryRaw = midCategory.rawValue
        self.keywords = keywords
        self.lawBasisDate = lawBasisDate
        self.difficultyRaw = difficulty.rawValue
        self.updatedAt = updatedAt
    }

    // MARK: - 選択肢の数

    static let minChoiceCount = 2
    static let maxChoiceCount = 4

    static func clampChoiceCount(_ count: Int) -> Int {
        min(max(count, minChoiceCount), maxChoiceCount)
    }

    /// この問題で実際に使うラベル。表示・採点・解説のすべてがこれを基準にする。
    /// 直接 `ChoiceLabel.allCases` を回すと、2択の問題で空の選択肢が出てしまう。
    var activeLabels: [ChoiceLabel] {
        ChoiceLabel.labels(count: choiceCount)
    }

    /// ○×式の問題か。解説パネルの見出しを「選択肢Aの解説」ではなく
    /// 選択肢の文言そのもので出すなど、表示の細部を変えるのに使う。
    var isTrueFalse: Bool { choiceCount == Self.minChoiceCount }

    // MARK: - 生値から enum への変換

    var correctChoice: ChoiceLabel {
        get { ChoiceLabel(rawValue: correctChoiceRaw) ?? .a }
        set { correctChoiceRaw = newValue.rawValue }
    }

    var field: ExamField {
        get { ExamField(rawValue: fieldRaw) ?? .lifePlanning }
        set { fieldRaw = newValue.rawValue }
    }

    var midCategory: MidCategory {
        get { MidCategory(rawValue: midCategoryRaw) ?? .lifePlanMethod }
        set { midCategoryRaw = newValue.rawValue }
    }

    var difficulty: QuestionDifficulty {
        get { QuestionDifficulty(rawValue: difficultyRaw) ?? .standard }
        set { difficultyRaw = newValue.rawValue }
    }

    // MARK: - 選択肢へのアクセス

    /// 選択肢1つぶんの表示データ。
    /// タプルではなく型にしてあるのは、`ForEach` に直接渡せるようにするため。
    struct Choice: Identifiable {
        let label: ChoiceLabel
        let text: String
        let explanation: String
        let isCorrect: Bool

        var id: String { label.rawValue }
    }

    /// シード上の並び（A→）。問題一覧の詳細で使う。
    /// 演習では位置記憶で解けてしまわないよう、`QuizViewModel` が毎回並べ替える。
    var orderedChoices: [Choice] {
        activeLabels.map {
            Choice(
                label: $0,
                text: choiceText(for: $0),
                explanation: choiceExplanation(for: $0),
                isCorrect: $0 == correctChoice
            )
        }
    }

    func choiceText(for label: ChoiceLabel) -> String {
        switch label {
        case .a: return choiceA
        case .b: return choiceB
        case .c: return choiceC
        case .d: return choiceD
        }
    }

    func choiceExplanation(for label: ChoiceLabel) -> String {
        switch label {
        case .a: return explanationA
        case .b: return explanationB
        case .c: return explanationC
        case .d: return explanationD
        }
    }

    var correctChoiceText: String { choiceText(for: correctChoice) }
}
