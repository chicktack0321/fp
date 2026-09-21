import Foundation

/// 2級アプリの級固有設定。3級アプリは `FP3/AppFlavor.swift` が同じ形の値を持つ。
///
/// このファイルはターゲット `FP2App` にだけ含める。共通ソース側は
/// `AppFlavor.current` しか見ないので、級の違いはここ1か所に閉じる。
enum AppFlavor {
    static let current = ExamFlavor(
        grade: "2級",
        appDisplayName: "FP2級特訓",
        examDisplayName: "2級ファイナンシャル・プランニング技能検定",
        bundleIdentifier: "com.eitango.fp2",
        unlockProductID: "com.eitango.fp2.unlock.advanced",
        questionIdPrefix: "FP2",
        // 2級の学科はすべて四答択一式。○×は出ないため、2択・3択の問題が
        // 混ざっていたら3級用データの取り違えとして弾く。
        choiceCounts: [4],
        writtenExam: ExamSpec(
            name: "学科試験",
            format: "四答択一式",
            questionCount: 60,
            durationMinutes: 120,
            passingDescription: "60点満点中36点以上"
        ),
        practicalExam: ExamSpec(
            name: "実技試験（資産設計提案業務）",
            format: "多肢選択式・記述式",
            questionCount: 40,
            durationMinutes: 90,
            passingDescription: "100点満点中60点以上"
        ),
        lawBasisDate: "2026-04-01",
        // 3級・2級で同じページを指す。同じ内容のページを級ごとに保守すると必ず食い違うため、
        // 1つのサイトに集約して両アプリから参照している。
        // App Store Connect のプライバシーポリシーURL・サポートURLにも同じものを登録すること。
        privacyPolicyURL: URL(string: "https://sites.google.com/view/fp-g3-g2/privacy-policy")!,
        supportURL: URL(string: "https://sites.google.com/view/fp-g3-g2/")!
    )
}
