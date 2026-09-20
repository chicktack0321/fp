import Foundation

/// 出題科目（FP技能検定の6科目）。
///
/// 学科試験は6科目から10問ずつ・計60問が出題され、合否は60問の総得点だけで決まる。
/// 科目ごとの足切りは無いので、ITパスポート版のように「分野別の合格基準」は存在しない。
/// それでも科目を習熟度の主軸に置いているのは、6科目が扱う制度が互いにほぼ独立しており、
/// 「どの科目が手つかずか」が学習者にとって唯一意味のある進捗の切り口になるため。
enum ExamField: String, Codable, CaseIterable, Identifiable {
    case lifePlanning
    case riskManagement
    case financialAssets
    case taxPlanning
    case realEstate
    case inheritance

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .lifePlanning: return "ライフプランニングと資金計画"
        case .riskManagement: return "リスク管理"
        case .financialAssets: return "金融資産運用"
        case .taxPlanning: return "タックスプランニング"
        case .realEstate: return "不動産"
        case .inheritance: return "相続・事業承継"
        }
    }

    /// 画面幅が足りない場所（グラフの軸ラベル・絞り込みのチップ）で使う短縮名。
    /// 「ライフプランニングと資金計画」は全角15文字あり、そのままでは1行に収まらない。
    var shortName: String {
        switch self {
        case .lifePlanning: return "ライフ"
        case .riskManagement: return "リスク"
        case .financialAssets: return "金融"
        case .taxPlanning: return "タックス"
        case .realEstate: return "不動産"
        case .inheritance: return "相続"
        }
    }

    /// 本試験の学科での出題数の目安（60問中）。6科目から均等に10問ずつ出る
    var questionsInExam: Int { 10 }

    var summary: String {
        switch self {
        case .lifePlanning: return "社会保険・公的年金・資金計画・FPの倫理と関連法規"
        case .riskManagement: return "生命保険・損害保険・第三分野・保険と税金"
        case .financialAssets: return "預貯金・投資信託・債券・株式・外貨・金融商品と税金"
        case .taxPlanning: return "所得税の仕組み・所得控除・申告と納付・法人税・消費税"
        case .realEstate: return "不動産の取引・法令上の規制・不動産の税金・有効活用"
        case .inheritance: return "贈与・相続の法律と税金・財産評価・事業承継"
        }
    }
}

/// 試験範囲の細目。
///
/// rawValue は `questionId` にも埋め込むため（`FP3_PENSION_0042`）、**公開後の改名は禁止**。
/// 改名は「削除+新規」になり、その問題の学習履歴が全ユーザーで失われる。
/// 試験範囲の改定で細目が増えたときは、既存を変えずにケースを追加する。
///
/// 3級と2級で細目は共通にしてある。出題範囲の区分は両級で同じで、違うのは問われる深さ
/// （3級は制度の基本、2級は要件・例外・計算）だけなので、級ごとに分けると
/// 同じ論点に別のコードが付き、問題データを級間で見比べられなくなる。
enum MidCategory: String, Codable, CaseIterable, Identifiable {
    // ライフプランニングと資金計画
    case fpEthics = "ETHIC"
    case lifePlanMethod = "LPLAN"
    case socialInsurance = "SOCINS"
    case publicPension = "PENSION"
    case corporatePension = "CORPPEN"
    case fundPlanning = "FUND"
    case smallBusinessFunding = "SME"

    // リスク管理
    case insuranceSystem = "INSBASE"
    case lifeInsurance = "LIFEINS"
    case nonLifeInsurance = "NLIFEINS"
    case thirdSectorInsurance = "THIRDINS"
    case insuranceTax = "INSTAX"
    case corporateInsurance = "CORPINS"

    // 金融資産運用
    case marketEnvironment = "MKTENV"
    case savings = "SAVINGS"
    case investmentTrust = "TRUST"
    case bonds = "BOND"
    case equities = "EQUITY"
    case foreignCurrency = "FOREX"
    case portfolio = "PORT"
    case financialProductTax = "FINTAX"
    case financialSafetyNet = "FINLAW"

    // タックスプランニング
    case taxSystem = "TAXBASE"
    case incomeTax = "INCOME"
    case incomeDeduction = "DEDUCT"
    case taxCalculation = "TAXCALC"
    case taxFiling = "FILING"
    case corporateTax = "CORPTAX"
    case consumptionTax = "CONSTAX"
    case localTax = "LOCALTAX"

    // 不動産
    case realEstateBasics = "REBASE"
    case realEstateTrade = "RETRADE"
    case realEstateRegulation = "RELAW"
    case realEstateTax = "RETAX"
    case realEstateUtilization = "REUSE"

    // 相続・事業承継
    case gift = "GIFT"
    case succession = "SUCCESS"
    case inheritanceTax = "INHTAX"
    case propertyValuation = "VALUE"
    case businessSuccession = "BIZSUCC"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fpEthics: return "FPと倫理・関連法規"
        case .lifePlanMethod: return "ライフプランニングの手法"
        case .socialInsurance: return "社会保険"
        case .publicPension: return "公的年金"
        case .corporatePension: return "企業年金・個人年金"
        case .fundPlanning: return "資金計画（住宅・教育・老後）"
        case .smallBusinessFunding: return "中小法人の資金計画"

        case .insuranceSystem: return "保険制度全般"
        case .lifeInsurance: return "生命保険"
        case .nonLifeInsurance: return "損害保険"
        case .thirdSectorInsurance: return "第三分野の保険"
        case .insuranceTax: return "保険と税金"
        case .corporateInsurance: return "法人契約の保険"

        case .marketEnvironment: return "マーケット環境の理解"
        case .savings: return "預貯金・金融類似商品"
        case .investmentTrust: return "投資信託"
        case .bonds: return "債券投資"
        case .equities: return "株式投資"
        case .foreignCurrency: return "外貨建商品"
        case .portfolio: return "ポートフォリオ・デリバティブ"
        case .financialProductTax: return "金融商品と税金"
        case .financialSafetyNet: return "セーフティネットと関連法規"

        case .taxSystem: return "わが国の税制"
        case .incomeTax: return "所得税の仕組みと各種所得"
        case .incomeDeduction: return "損益通算と所得控除"
        case .taxCalculation: return "税額計算と税額控除"
        case .taxFiling: return "申告と納付"
        case .corporateTax: return "法人税"
        case .consumptionTax: return "消費税"
        case .localTax: return "個人住民税・事業税"

        case .realEstateBasics: return "不動産の見方"
        case .realEstateTrade: return "不動産の取引"
        case .realEstateRegulation: return "法令上の規制"
        case .realEstateTax: return "不動産の税金"
        case .realEstateUtilization: return "不動産の有効活用"

        case .gift: return "贈与と法律・税金"
        case .succession: return "相続と法律"
        case .inheritanceTax: return "相続と税金"
        case .propertyValuation: return "相続財産の評価"
        case .businessSuccession: return "事業承継対策"
        }
    }

    /// 属する科目。細目を選んだら科目は自動的に決まる（両方をユーザーに選ばせない）
    var field: ExamField {
        switch self {
        case .fpEthics, .lifePlanMethod, .socialInsurance, .publicPension,
             .corporatePension, .fundPlanning, .smallBusinessFunding:
            return .lifePlanning
        case .insuranceSystem, .lifeInsurance, .nonLifeInsurance,
             .thirdSectorInsurance, .insuranceTax, .corporateInsurance:
            return .riskManagement
        case .marketEnvironment, .savings, .investmentTrust, .bonds, .equities,
             .foreignCurrency, .portfolio, .financialProductTax, .financialSafetyNet:
            return .financialAssets
        case .taxSystem, .incomeTax, .incomeDeduction, .taxCalculation,
             .taxFiling, .corporateTax, .consumptionTax, .localTax:
            return .taxPlanning
        case .realEstateBasics, .realEstateTrade, .realEstateRegulation,
             .realEstateTax, .realEstateUtilization:
            return .realEstate
        case .gift, .succession, .inheritanceTax, .propertyValuation, .businessSuccession:
            return .inheritance
        }
    }

    static func all(in field: ExamField) -> [MidCategory] {
        allCases.filter { $0.field == field }
    }
}

/// 問題の難易度。**課金の境界を兼ねる**。
///
/// 難易度で切っているのは、機能ではなく「出題される問題の範囲」を売り物にするため。
/// 機能を止める作りにすると、期間終了時に「使えなくなった」という受け取られ方をする。
enum QuestionDifficulty: Int, Codable, CaseIterable, Identifiable {
    /// 制度の名称・数値をそのまま問う入門レベル
    case basic = 1
    /// 本試験の中心レベル。要件・例外・適用の可否を問う
    case standard = 2
    /// 計算問題、複数制度の組み合わせ、実技で問われる事例判断
    case advanced = 3

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .basic: return "基礎"
        case .standard: return "標準"
        case .advanced: return "応用"
        }
    }

    var summary: String {
        switch self {
        case .basic: return "制度の名称と数値を問う入門レベル"
        case .standard: return "本試験の中心となるレベル"
        case .advanced: return "計算・複合論点・実技レベル"
        }
    }
}

/// 選択肢のラベル。シードJSONのキーであり、表示順のシャッフル前の識別子でもある。
///
/// FP技能検定は級によって選択肢の数が違う（3級の学科は○×と三答択一、2級の学科は四答択一）。
/// 問題ごとに使う数が変わるため、ラベルは常にA〜Dを定義しておき、
/// 実際にいくつ使うかは `QuestionMaster.choiceCount` が持つ。
enum ChoiceLabel: String, Codable, CaseIterable, Identifiable {
    case a = "A"
    case b = "B"
    case c = "C"
    case d = "D"

    var id: String { rawValue }

    /// 選択肢が `count` 個の問題で使うラベル。2なら [A, B]、3なら [A, B, C]。
    static func labels(count: Int) -> [ChoiceLabel] {
        Array(allCases.prefix(max(QuestionMaster.minChoiceCount, min(count, allCases.count))))
    }
}

/// 問題ごとの習熟段階。
///
/// 直近の正誤で反転させるのではなく、間隔反復の習得段階（`UserProgress.reviewBox`）から導く。
/// 1回正解しただけで「習得済み」にすると、実際には翌週忘れている問題まで習得扱いになり、
/// 習熟度の表示が学習の実態と乖離して意味を失う。
enum LearningStatus: String, Codable, CaseIterable, Identifiable {
    /// 一度も出題していない
    case notStudied
    /// 直近で間違えた、または復習期限が過ぎている
    case needsReview
    /// 正解を重ねている途中（復習間隔は1〜3日）
    case learning
    /// 1週間以上の間隔を空けても正解できた
    case memorized

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .notStudied: return "未学習"
        case .needsReview: return "要復習"
        case .learning: return "学習中"
        case .memorized: return "習得済み"
        }
    }

    /// この段階に到達する条件。画面上の「iマーク」でそのまま見せる。
    var criteria: String {
        switch self {
        case .notStudied: return "まだ一度も出題されていない問題です。"
        case .needsReview: return "直近で間違えたか、復習の期限が来ている問題です。優先して出題されます。"
        case .learning: return "正解を重ねている途中の問題です。1〜3日の間隔で再出題されます。"
        case .memorized: return "1週間以上あけても正解できた問題です。以後は間隔を広げて確認します。"
        }
    }

    /// 問題一覧・習熟度バー・凡例で同じ見た目にするため、記号と色は段階自身に持たせる
    var symbolName: String {
        switch self {
        case .notStudied: return "circle"
        case .needsReview: return "exclamationmark.circle.fill"
        case .learning: return "arrow.triangle.2.circlepath.circle.fill"
        case .memorized: return "checkmark.circle.fill"
        }
    }
}
