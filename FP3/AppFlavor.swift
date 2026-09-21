import Foundation

/// 3級アプリの級固有設定。2級アプリは `FP2/AppFlavor.swift` が同じ形の値を持つ。
///
/// このファイルはターゲット `FP3App` にだけ含める。共通ソース側は
/// `AppFlavor.current` しか見ないので、級の違いはここ1か所に閉じる。
enum AppFlavor {
    static let current = ExamFlavor(
        grade: "3級",
        appDisplayName: "FP3級特訓",
        examDisplayName: "3級ファイナンシャル・プランニング技能検定",
        bundleIdentifier: "com.eitango.fp3",
        unlockProductID: "com.eitango.fp3.unlock.advanced",
        questionIdPrefix: "FP3",
        // 3級の学科は ○×式（2択）と三答択一式（3択）の2種類。
        // 四答択一は3級では出ないため、4択の問題が混ざっていたら作問ミスとして弾く。
        choiceCounts: [2, 3],
        writtenExam: ExamSpec(
            name: "学科試験",
            format: "○×式・三答択一式",
            questionCount: 60,
            durationMinutes: 90,
            passingDescription: "60点満点中36点以上"
        ),
        practicalExam: ExamSpec(
            name: "実技試験（資産設計提案業務）",
            format: "多肢選択式",
            questionCount: 20,
            durationMinutes: 60,
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
