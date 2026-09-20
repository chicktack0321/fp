import Foundation

/// 級ごとに変わる値の入れ物。
///
/// 3級アプリと2級アプリはソースを共有し、ターゲットごとに `AppFlavor.swift` を
/// 1つだけ含める（`FP3/AppFlavor.swift` / `FP2/AppFlavor.swift`）。
/// 級の違いをこの1つの値型に集約してあるので、共通コードの側に
/// 「3級なら〜」という分岐は一切現れない。
///
/// 個別の `static let` を並べるのではなく構造体にしているのは、項目を足したときに
/// 片方の級で入れ忘れるとコンパイルが通らないようにするため。
struct ExamFlavor: Sendable {
    /// 級の表記（"3級" / "2級"）
    let grade: String

    /// ホーム画面などアプリ内で名乗る名前
    /// （ホーム画面のアイコン下は Info.plist の CFBundleDisplayName が担う）
    let appDisplayName: String

    /// 試験の正式名称
    let examDisplayName: String

    /// バンドルID。ログのサブシステム名にも使う
    let bundleIdentifier: String

    /// App内課金のプロダクトID
    let unlockProductID: String

    /// `questionId` の先頭（"FP3" / "FP2"）。
    /// 級をまたいで問題データを取り違えないための印でもある。
    let questionIdPrefix: String

    /// 学科試験で使う選択肢の数。3級は ○×（2択）と三答択一、2級は四答択一。
    /// 作問と検証で「その級にありえない選択肢数」を弾くのに使う。
    let choiceCounts: [Int]

    let writtenExam: ExamSpec
    let practicalExam: ExamSpec

    /// 法令基準日（"2026-04-01"）。FP技能検定は試験日ではなくこの日時点の法令で出題される。
    /// 問題データの改訂時にここも必ず更新する（シード側の値と一致することをテストが確かめる）。
    ///
    /// 表示用の「2026年4月1日」ではなくISO形式で持つのは、問題ごとの基準日と突き合わせて
    /// 「古い問題」を機械的に洗い出せるようにするため。表記ゆれがあると比較ができない。
    let lawBasisDate: String

    let privacyPolicyURL: URL
    let supportURL: URL

    /// 画面に出す法令基準日（"2026年4月1日"）
    var lawBasisDateDisplay: String { LawBasisDate.display(lawBasisDate) }

    /// 合格基準の説明。学科と実技の両方に合格して初めて技能士になれる点まで含める
    var passingCriteria: String {
        """
        \(writtenExam.name)・\(practicalExam.name)のどちらも \
        \(writtenExam.passingDescription)／\(practicalExam.passingDescription)。\
        両方に合格するとファイナンシャル・プランニング技能士（\(grade)）となります。\
        一方だけ合格した場合は、その科目が翌々年度末まで免除されます。
        """
    }
}

/// 法令基準日の表記。
///
/// データ側は "2026-04-01" で持ち、画面には「2026年4月1日」と出す。
/// `DateFormatter` を使わず素朴に組み立てているのは、この値が日付そのものではなく
/// 「制度の版」を指す識別子であり、端末の暦や地域設定で表記が変わってはいけないため。
enum LawBasisDate {
    static func display(_ iso: String) -> String {
        let parts = iso.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2])
        else {
            // 想定外の表記でも画面を壊さない。そのまま出せば異常に気付ける
            return iso
        }
        return "\(year)年\(month)月\(day)日"
    }
}

/// 学科・実技それぞれの出題形式
struct ExamSpec: Sendable {
    let name: String
    /// 出題形式（"○×式・三答択一式" など）
    let format: String
    let questionCount: Int
    let durationMinutes: Int
    /// 合格基準の1行表記（"60点満点中36点以上"）
    let passingDescription: String

    /// 「60問 / 90分」のような1行表記
    var summary: String {
        "\(questionCount)問 / \(durationMinutes)分"
    }
}
