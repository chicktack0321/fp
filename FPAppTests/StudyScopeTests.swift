import XCTest
import SwiftData
@testable import FPApp

/// 出題範囲の絞り込みと、課金の権利との掛け合わせ。
///
/// 「設定で絞った」と「未購入で出題されない」を混ぜると、利用者が原因を判断できず、
/// 画面の案内も出し分けられない。積として扱えていることを確認する。
@MainActor
final class StudyScopeTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() async throws {
        let schema = Schema([QuestionMaster.self, UserProgress.self, StudyLog.self])
        container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        context = container.mainContext
    }

    override func tearDown() async throws {
        container = nil
        context = nil
    }

    @discardableResult
    private func insert(
        _ id: String,
        midCategory: MidCategory,
        difficulty: QuestionDifficulty
    ) -> QuestionMaster {
        let question = QuestionMaster(
            questionId: id,
            questionText: "問題文 \(id)",
            choiceA: "A", choiceB: "B", choiceC: "C", choiceD: "D",
            correctChoice: .a,
            explanation: "解説",
            explanationA: "正解。", explanationB: "不正解。",
            explanationC: "不正解。", explanationD: "不正解。",
            field: midCategory.field,
            midCategory: midCategory,
            lawBasisDate: "2026-04-01",
            difficulty: difficulty
        )
        context.insert(question)
        return question
    }

    // MARK: - StudyScope の判定

    func testDefaultScopeIncludesEveryDifficultyWhenUnlocked() {
        let scope = StudyScope.default
        let question = insert("FPTEST_PENSION_0001", midCategory: .publicPension, difficulty: .advanced)

        XCTAssertTrue(
            scope.contains(
                question,
                availableDifficulties: Set(QuestionDifficulty.allCases),
                unspecified: StudyScope.studyDefaultDifficulties
            ),
            "既定の出題範囲から基礎を外さない。制度の名称と数値をそのまま問う問題も本試験に出るため"
        )
    }

    /// 権利が無いと標準・応用の問題は出題対象から外れ、基礎だけが残る
    func testLockedRightsExcludeStandardAndAdvancedQuestions() {
        let scope = StudyScope.default
        let advanced = insert("FPTEST_PENSION_0001", midCategory: .publicPension, difficulty: .advanced)
        let standard = insert("FPTEST_PENSION_0002", midCategory: .publicPension, difficulty: .standard)
        let basic = insert("FPTEST_PENSION_0003", midCategory: .publicPension, difficulty: .basic)

        let available = AccessRights.locked.availableDifficulties

        XCTAssertFalse(
            scope.contains(advanced, availableDifficulties: available, unspecified: StudyScope.studyDefaultDifficulties)
        )
        XCTAssertFalse(
            scope.contains(standard, availableDifficulties: available, unspecified: StudyScope.studyDefaultDifficulties)
        )
        XCTAssertTrue(
            scope.contains(basic, availableDifficulties: available, unspecified: StudyScope.studyDefaultDifficulties)
        )
    }

    func testFieldFilter() {
        var scope = StudyScope.default
        scope.setField(.financialAssets)

        let strategy = insert("FPTEST_EQUITY_0001", midCategory: .equities, difficulty: .basic)
        let technology = insert("FPTEST_PENSION_0001", midCategory: .publicPension, difficulty: .basic)
        let all = Set(QuestionDifficulty.allCases)

        XCTAssertTrue(scope.contains(strategy, availableDifficulties: all, unspecified: all))
        XCTAssertFalse(scope.contains(technology, availableDifficulties: all, unspecified: all))
    }

    /// 細目を選んだら、科目の指定より細目が優先される
    func testMidCategoryOverridesField() {
        var scope = StudyScope.default
        scope.midCategory = .publicPension

        let security = insert("FPTEST_PENSION_0001", midCategory: .publicPension, difficulty: .basic)
        let network = insert("FPTEST_SOCINS_0001", midCategory: .socialInsurance, difficulty: .basic)
        let all = Set(QuestionDifficulty.allCases)

        XCTAssertTrue(scope.contains(security, availableDifficulties: all, unspecified: all))
        XCTAssertFalse(scope.contains(network, availableDifficulties: all, unspecified: all))
        XCTAssertEqual(scope.effectiveField, .lifePlanning, "細目から科目が決まる")
    }

    /// 科目を変えたら、その科目に属さない細目の選択は捨てる。
    /// 残すと「不動産 / 公的年金」のような0問確定の組み合わせが作れてしまう。
    func testChangingFieldClearsIncompatibleMidCategory() {
        var scope = StudyScope.default
        scope.setField(.lifePlanning)
        scope.midCategory = .publicPension

        scope.setField(.financialAssets)

        XCTAssertNil(scope.midCategory)
        XCTAssertEqual(scope.field, .financialAssets)
    }

    func testChangingFieldKeepsCompatibleMidCategory() {
        var scope = StudyScope.default
        scope.setField(.lifePlanning)
        scope.midCategory = .publicPension

        scope.setField(.lifePlanning)

        XCTAssertEqual(scope.midCategory, .publicPension, "同じ科目に属する細目は残す")
    }

    func testSummaryDescribesOnlySpecifiedConditions() {
        XCTAssertEqual(StudyScope.default.summary, "すべて")

        var scope = StudyScope.default
        scope.setField(.realEstate)
        XCTAssertEqual(scope.summary, "不動産")

        scope.difficulty = .advanced
        XCTAssertEqual(scope.summary, "不動産 / 応用")

        scope.midCategory = .realEstateRegulation
        XCTAssertEqual(scope.summary, "法令上の規制 / 応用", "細目を選んだら科目ではなく細目を出す")
    }

    // MARK: - リポジトリ経由の出題プール

    /// 出題プールは「ユーザー設定 × 権利」の積になる
    func testStudyPoolIsIntersectionOfScopeAndRights() {
        insert("FPTEST_EQUITY_0001", midCategory: .equities, difficulty: .basic)
        insert("FPTEST_EQUITY_0002", midCategory: .equities, difficulty: .advanced)
        insert("FPTEST_PENSION_0001", midCategory: .publicPension, difficulty: .basic)
        insert("FPTEST_PENSION_0002", midCategory: .publicPension, difficulty: .advanced)

        let repository = QuestionRepository(context: context)

        var scope = StudyScope.default
        scope.setField(.financialAssets)

        // 設定で金融資産運用に絞り、権利が無い（標準・応用が外れる）→ 基礎の1問だけ
        let locked = repository.fetchStudyPool(
            scope: scope,
            availableDifficulties: AccessRights.locked.availableDifficulties
        )
        XCTAssertEqual(locked.map(\.questionId), ["FPTEST_EQUITY_0001"])

        // 同じ設定で権利がある → 金融資産運用の2問
        let unlocked = repository.fetchStudyPool(
            scope: scope,
            availableDifficulties: Set(QuestionDifficulty.allCases)
        )
        XCTAssertEqual(unlocked.count, 2)
    }

    /// 習熟度の集計は権利で絞らない。
    /// 未購入でも応用問題の習熟度を見られるほうが、何を解放することになるのかが伝わる。
    func testMasteryScopeIgnoresPurchaseState() {
        insert("FPTEST_PENSION_0001", midCategory: .publicPension, difficulty: .basic)
        insert("FPTEST_PENSION_0002", midCategory: .publicPension, difficulty: .advanced)

        let repository = QuestionRepository(context: context)
        let questions = repository.fetchQuestions(matching: .default)

        XCTAssertEqual(questions.count, 2, "集計では応用問題も数える")
    }

    func testCountsByField() {
        insert("FPTEST_EQUITY_0001", midCategory: .equities, difficulty: .basic)
        insert("FPTEST_RETAX_0001", midCategory: .realEstateTax, difficulty: .basic)
        insert("FPTEST_PENSION_0001", midCategory: .publicPension, difficulty: .basic)
        insert("FPTEST_SOCINS_0001", midCategory: .socialInsurance, difficulty: .basic)

        let counts = QuestionRepository(context: context).countsByField()

        XCTAssertEqual(counts[.financialAssets], 1)
        XCTAssertEqual(counts[.realEstate], 1)
        XCTAssertEqual(counts[.lifePlanning], 2)
    }

    func testCountByDifficulty() {
        insert("FPTEST_PENSION_0001", midCategory: .publicPension, difficulty: .advanced)
        insert("FPTEST_PENSION_0002", midCategory: .publicPension, difficulty: .advanced)
        insert("FPTEST_PENSION_0003", midCategory: .publicPension, difficulty: .basic)

        let repository = QuestionRepository(context: context)

        XCTAssertEqual(repository.count(difficulty: .advanced), 2)
        XCTAssertEqual(repository.count(difficulty: .basic), 1)
        XCTAssertEqual(repository.count(difficulty: .standard), 0)
    }
}
