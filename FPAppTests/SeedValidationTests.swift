import XCTest
@testable import FPApp

/// 同梱する問題データの検証。
///
/// `scripts/validate_seed.py` と同じ検査をテストからも実行する。CIでスクリプトを回すだけだと、
/// ローカルでシードを編集したときに気付けない。国家検定の対策アプリで解説が間違っていたり
/// 正解が引けなくなっていたりするのは致命的なので、ビルドの一部として落とす。
///
/// テストターゲットは級ごとに2つあり、それぞれ自分の級のシードをバンドルに持つ。
/// 検査の中身は級によらず同じで、違うのは `AppFlavor` から読む期待値
/// （IDの接頭辞・ありえる選択肢の数・法令基準日）だけになっている。
final class SeedValidationTests: XCTestCase {

    private struct SeedFile: Decodable {
        let version: Int
        let lawBasisDate: String
        let questions: [SeedEntry]
    }

    private struct SeedEntry: Decodable {
        let questionId: String
        let questionText: String
        let choices: [String: String]
        let correctChoice: String
        let explanation: String
        let choiceExplanations: [String: String]
        let field: String
        let midCategory: String
        let keywords: [String]?
        let difficulty: Int?
        let lawBasisDate: String?
    }

    /// 設計仕様書で決めたレイアウト上限
    private let maxQuestionLength = 300
    private let maxChoiceLength = 120

    private var seed: SeedFile!
    private var flavor: ExamFlavor { AppFlavor.current }

    override func setUpWithError() throws {
        // テストターゲットにも seed JSON をリソースとして含めてある（project.yml 参照）
        let bundle = Bundle(for: Self.self)
        guard let url = bundle.url(forResource: AppConfig.seedResourceName, withExtension: "json") else {
            XCTFail("シードファイル \(AppConfig.seedResourceName).json がテストバンドルに含まれていません")
            return
        }
        seed = try JSONDecoder().decode(SeedFile.self, from: Data(contentsOf: url))
    }

    func testSeedIsNotEmpty() {
        XCTAssertGreaterThan(seed.questions.count, 0)
        XCTAssertGreaterThan(seed.version, 0)
        XCTAssertFalse(seed.lawBasisDate.isEmpty)
    }

    /// シードの法令基準日と、アプリが画面に出す法令基準日が一致していること。
    ///
    /// ずれていると「このアプリは2026年4月1日基準です」と表示しながら別の年度の数値を
    /// 出題することになり、利用者は気付けない。改正対応のたびに両方を直す必要がある。
    func testLawBasisDateMatchesFlavor() {
        XCTAssertEqual(
            seed.lawBasisDate, flavor.lawBasisDate,
            "シードの法令基準日が AppFlavor の表示値と一致していない"
        )
    }

    /// questionId は学習履歴のキーそのもの。重複すると片方の進捗が消える
    func testQuestionIdsAreUnique() {
        let ids = seed.questions.map(\.questionId)
        XCTAssertEqual(Set(ids).count, ids.count, "questionId が重複している")
    }

    /// `<級>_<細目>_<4桁>` の形式で、IDの細目と属性が一致していること。
    /// ずれると一覧の絞り込みと採番体系が食い違う。
    ///
    /// 接頭辞まで見るのは、3級のシードを2級アプリに入れてしまう取り違えを防ぐため。
    /// 問題文だけでは級の見分けがつかず、配信してから気付くことになる。
    func testQuestionIdFormatMatchesMidCategory() {
        for question in seed.questions {
            let parts = question.questionId.split(separator: "_")
            XCTAssertEqual(parts.count, 3, "\(question.questionId): <級>_<細目>_<4桁> の形式ではない")
            guard parts.count == 3 else { continue }

            XCTAssertEqual(
                String(parts[0]), flavor.questionIdPrefix,
                "\(question.questionId): 接頭辞が \(flavor.questionIdPrefix) ではない（級の取り違え）"
            )
            XCTAssertEqual(
                String(parts[1]), question.midCategory,
                "\(question.questionId): IDの細目が midCategory と一致しない"
            )
            XCTAssertEqual(parts[2].count, 4, "\(question.questionId): 連番が4桁ではない")
            XCTAssertNotNil(Int(parts[2]), "\(question.questionId): 連番が数値ではない")
        }
    }

    /// 科目と細目の対応が Swift 側の `MidCategory.field` と一致していること
    func testFieldMatchesMidCategory() {
        for question in seed.questions {
            guard let midCategory = MidCategory(rawValue: question.midCategory) else {
                XCTFail("\(question.questionId): 未知の細目 '\(question.midCategory)'")
                continue
            }
            XCTAssertEqual(
                question.field, midCategory.field.rawValue,
                "\(question.questionId): field が細目の属する科目と一致しない"
            )
        }
    }

    /// 選択肢が A から途切れなく並び、その級にありえる数であること。
    ///
    /// AとCだけを持つ問題を通すと、出題画面でBの位置が空欄になる。
    /// 数そのものも級で決まっていて（3級は2択か3択、2級は4択）、
    /// 違う数が混ざっていたら級を取り違えたデータとして落とす。
    func testChoiceCountMatchesExamFormat() {
        for question in seed.questions {
            let count = question.choices.count
            XCTAssertTrue(
                flavor.choiceCounts.contains(count),
                "\(question.questionId): 選択肢が\(count)個。\(flavor.grade)は\(flavor.choiceCounts.map(String.init).joined(separator: "か"))択のみ"
            )
            let expected = Set(ChoiceLabel.labels(count: count).map(\.rawValue))
            XCTAssertEqual(
                Set(question.choices.keys), expected,
                "\(question.questionId): choices のキーが A から連続していない"
            )
        }
    }

    func testChoicesAreCompleteAndDistinct() {
        for question in seed.questions {
            let texts = question.choices.values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            XCTAssertFalse(texts.contains(where: \.isEmpty), "\(question.questionId): 空の選択肢がある")
            // 同じ文言の選択肢があると、正解を選んでも不正解になりうる
            XCTAssertEqual(
                Set(texts).count, texts.count,
                "\(question.questionId): 同じ文言の選択肢がある"
            )
            for (label, text) in question.choices {
                XCTAssertLessThanOrEqual(
                    text.count, maxChoiceLength,
                    "\(question.questionId): 選択肢 \(label) が\(maxChoiceLength)字を超えている"
                )
            }
        }
    }

    /// 正解が、その問題に実在する選択肢を指していること。
    /// 3択の問題で correctChoice が D になっていると、正解が選べない問題が配信される。
    func testCorrectChoiceIsValid() {
        for question in seed.questions {
            XCTAssertNotNil(
                ChoiceLabel(rawValue: question.correctChoice),
                "\(question.questionId): correctChoice '\(question.correctChoice)' が A/B/C/D ではない"
            )
            XCTAssertNotNil(
                question.choices[question.correctChoice],
                "\(question.questionId): correctChoice '\(question.correctChoice)' に対応する選択肢が無い"
            )
        }
    }

    /// 出題されるすべての選択肢に解説があること。
    /// 誤答選択肢がなぜ誤りかを知ることが択一問題の学習価値の半分を占めるため、
    /// 1本でも欠けると解説パネルが空欄のまま表示される。
    func testEveryChoiceHasExplanation() {
        for question in seed.questions {
            XCTAssertEqual(
                Set(question.choiceExplanations.keys), Set(question.choices.keys),
                "\(question.questionId): choiceExplanations のキーが choices と一致しない"
            )
            XCTAssertFalse(
                question.explanation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                "\(question.questionId): explanation が空"
            )
            for (label, text) in question.choiceExplanations {
                XCTAssertFalse(
                    text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    "\(question.questionId): 選択肢 \(label) の解説が空"
                )
            }
        }
    }

    /// 解説の書き出しで正誤が判別できること。
    /// 崩れると、解説パネルで「どれが正解の説明か」を読み取れなくなる。
    func testExplanationsStartWithVerdict() {
        for question in seed.questions {
            for (label, text) in question.choiceExplanations {
                let expected = label == question.correctChoice ? "正解" : "不正解"
                XCTAssertTrue(
                    text.hasPrefix(expected),
                    "\(question.questionId): 選択肢 \(label) の解説が '\(expected)' で始まっていない"
                )
            }
        }
    }

    func testQuestionTextLengthIsWithinLayoutLimit() {
        for question in seed.questions {
            XCTAssertFalse(
                question.questionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                "\(question.questionId): questionText が空"
            )
            XCTAssertLessThanOrEqual(
                question.questionText.count, maxQuestionLength,
                "\(question.questionId): questionText が\(maxQuestionLength)字を超えている"
            )
        }
    }

    /// 同じ論点を二度出題していないことの最低限の検出
    func testQuestionTextsAreUnique() {
        let texts = seed.questions.map(\.questionText)
        XCTAssertEqual(Set(texts).count, texts.count, "同じ問題文が複数ある")
    }

    func testDifficultyIsValid() {
        for question in seed.questions {
            let difficulty = question.difficulty ?? QuestionDifficulty.standard.rawValue
            XCTAssertNotNil(
                QuestionDifficulty(rawValue: difficulty),
                "\(question.questionId): difficulty '\(difficulty)' が 1/2/3 ではない"
            )
        }
    }

    /// 無料で解ける問題が残っていること。
    /// 全問が応用（課金対象）になると、未購入の利用者は演習を1問も始められない。
    func testFreeTierHasQuestions() {
        let freeDifficulties = AccessRights.locked.availableDifficulties.map(\.rawValue)
        let freeCount = seed.questions.filter {
            freeDifficulties.contains($0.difficulty ?? QuestionDifficulty.standard.rawValue)
        }.count

        XCTAssertGreaterThan(freeCount, 0, "未購入でも出題できる問題が1問もない")
    }

    /// 6科目すべてに問題があること。ホームの科目別習熟度が成立しなくなる
    func testAllFieldsAreCovered() {
        let fields = Set(seed.questions.map(\.field))
        for field in ExamField.allCases {
            XCTAssertTrue(
                fields.contains(field.rawValue),
                "\(field.displayName) の問題が1問もない"
            )
        }
    }
}
