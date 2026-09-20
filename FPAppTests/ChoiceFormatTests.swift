import XCTest
import SwiftData
@testable import FPApp

/// 選択肢の数が問題ごとに変わることの確認。
///
/// FP技能検定は級で出題形式が違う（3級の学科は○×式と三答択一式、2級の学科は四答択一式）。
/// 1つのモデルで2〜4択を扱うため、「使わない選択肢が表示に混ざらない」ことと
/// 「○×式だけは並べ替えない」ことを、共通コードの側で確かめておく。
///
/// ここが壊れると、2択の問題に空の選択肢ボタンが出たり、
/// ○と×が毎回入れ替わって読み違いによる誤答を招いたりする。
@MainActor
final class ChoiceFormatTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var viewModel: QuizViewModel!

    override func setUp() async throws {
        let schema = Schema([QuestionMaster.self, UserProgress.self, StudyLog.self])
        container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        context = container.mainContext
        StudySettings.studyScope = .default
        viewModel = QuizViewModel()
    }

    override func tearDown() async throws {
        StudySettings.studyScope = .default
        viewModel = nil
        container = nil
        context = nil
    }

    @discardableResult
    private func insert(_ id: String, choiceCount: Int, correct: ChoiceLabel = .a) -> QuestionMaster {
        let question = QuestionMaster(
            questionId: id,
            questionText: "問題文 \(id)",
            choiceA: choiceCount >= 1 ? "選択肢A" : "",
            choiceB: choiceCount >= 2 ? "選択肢B" : "",
            choiceC: choiceCount >= 3 ? "選択肢C" : "",
            choiceD: choiceCount >= 4 ? "選択肢D" : "",
            choiceCount: choiceCount,
            correctChoice: correct,
            explanation: "解説",
            explanationA: "正解。",
            explanationB: "不正解。",
            explanationC: choiceCount >= 3 ? "不正解。" : "",
            explanationD: choiceCount >= 4 ? "不正解。" : "",
            field: MidCategory.publicPension.field,
            midCategory: .publicPension,
            lawBasisDate: "2026-04-01",
            // 未購入でも出題される基礎で作る。権利の状態に左右されずに
            // 選択肢の数だけを見たいので、課金の境界をまたがせない
            difficulty: .basic
        )
        context.insert(question)
        return question
    }

    // MARK: - モデル

    /// 使わない選択肢は表示にも採点にも現れない
    func testOrderedChoicesOnlyIncludesActiveLabels() {
        XCTAssertEqual(insert("Q2", choiceCount: 2).orderedChoices.map(\.label), [.a, .b])
        XCTAssertEqual(insert("Q3", choiceCount: 3).orderedChoices.map(\.label), [.a, .b, .c])
        XCTAssertEqual(insert("Q4", choiceCount: 4).orderedChoices.map(\.label), [.a, .b, .c, .d])
    }

    /// 範囲外の値を渡しても2〜4に収まる。
    /// シードの不正値でアプリが壊れる（空の選択肢しかない問題が出る）のを防ぐ。
    func testChoiceCountIsClamped() {
        XCTAssertEqual(insert("QLow", choiceCount: 0).choiceCount, 2)
        XCTAssertEqual(insert("QHigh", choiceCount: 9).choiceCount, 4)
    }

    func testIsTrueFalseOnlyForTwoChoices() {
        XCTAssertTrue(insert("QTF", choiceCount: 2).isTrueFalse)
        XCTAssertFalse(insert("QThree", choiceCount: 3).isTrueFalse)
    }

    func testLabelsForCount() {
        XCTAssertEqual(ChoiceLabel.labels(count: 2), [.a, .b])
        XCTAssertEqual(ChoiceLabel.labels(count: 3), [.a, .b, .c])
        XCTAssertEqual(ChoiceLabel.labels(count: 4), [.a, .b, .c, .d])
    }

    // MARK: - 出題

    /// 3択の問題を出題したとき、表示される選択肢はちょうど3つで、空文字が混ざらない
    func testQuizShowsOnlyActiveChoices() {
        insert("Q3", choiceCount: 3, correct: .c)
        viewModel.configure(context: context)
        viewModel.startNewQuiz()

        let displayed = viewModel.questions[0]
        XCTAssertEqual(displayed.choices.count, 3)
        XCTAssertEqual(Set(displayed.choices.map(\.label)), [.a, .b, .c])
        XCTAssertFalse(displayed.choices.contains { $0.text.isEmpty }, "空の選択肢が混ざってはいけない")
        XCTAssertEqual(displayed.choices[displayed.correctIndex].label, .c)
    }

    /// ○×式は本試験と同じく「正しい」「誤り」の順で固定する。
    /// 2択では並べ替えても測れるものは変わらないのに、○と×が入れ替わると
    /// 読み違いによる誤答を増やすだけになる。
    func testTrueFalseChoicesAreNotShuffled() {
        insert("QTF", choiceCount: 2, correct: .b)
        viewModel.configure(context: context)

        for _ in 0..<30 {
            viewModel.startNewQuiz()
            let displayed = viewModel.questions[0]
            XCTAssertEqual(displayed.choices.map(\.label), [.a, .b], "○×式は並べ替えない")
            XCTAssertEqual(displayed.correctIndex, 1)
            viewModel.returnToStart()
        }
    }

    /// 3択以上は毎回並べ替える。固定順だと「この問題の答えは3番目」という
    /// 位置記憶で解けてしまい、間隔反復が測るものが知識ではなく並び順の記憶になる。
    func testThreeChoicesAreShuffled() {
        insert("Q3", choiceCount: 3, correct: .a)
        viewModel.configure(context: context)

        var seenOrders = Set<[String]>()
        for _ in 0..<40 {
            viewModel.startNewQuiz()
            seenOrders.insert(viewModel.questions[0].choices.map(\.label.rawValue))
            viewModel.returnToStart()
        }
        XCTAssertGreaterThan(seenOrders.count, 1, "3択は表示順が変わりうる")
    }

    /// ○×式では選択肢の記号を出さない（「A 正しい」は読みにくいだけ）
    func testDisplayLabelIsEmptyForTrueFalse() {
        insert("QTF", choiceCount: 2)
        insert("Q4", choiceCount: 4)
        viewModel.configure(context: context)
        viewModel.startNewQuiz()

        for question in viewModel.questions {
            let labels = (0..<question.choices.count).map { question.displayLabel(at: $0) }
            if question.question.isTrueFalse {
                XCTAssertEqual(labels, ["", ""], "○×式は記号を出さない")
            } else {
                XCTAssertEqual(labels, ["A", "B", "C", "D"], "択一は位置に応じた記号を出す")
            }
        }
    }

    /// 2択と4択が混ざったセットでも、それぞれの数で正しく採点できる
    func testMixedFormatsAreScoredIndependently() {
        insert("QTF", choiceCount: 2, correct: .b)
        insert("Q4", choiceCount: 4, correct: .d)
        viewModel.configure(context: context)
        viewModel.startNewQuiz()

        while viewModel.phase == .inProgress {
            guard let question = viewModel.currentQuestion else { break }
            viewModel.selectAnswer(question.correctIndex)
            viewModel.goToNextQuestion()
        }

        XCTAssertEqual(viewModel.resultSummary.correctCount, 2)
        XCTAssertEqual(viewModel.resultSummary.totalCount, 2)
    }
}
