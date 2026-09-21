import Foundation

/// バンドルに焼き込まれたバージョン情報。
///
/// `MARKETING_VERSION`（表示用のバージョン）と `CURRENT_PROJECT_VERSION`（ビルド番号）は
/// `project.yml` と TestFlight のワークフローが決めるので、ここでは読むだけにする。
/// Info.plist から読むことで、どの経路でビルドしても実際に配信された値と一致する。
enum AppInfo {
    /// 表示用のバージョン（例: "1.0"）
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
    }

    /// ビルド番号。TestFlightではワークフローの実行番号が入る
    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
    }

    /// 「このアプリについて」に出す1行（例: "1.0 (12)"）。
    ///
    /// ビルド番号まで出すのは、問い合わせを受けたときに配信済みのどのビルドかを
    /// 特定できるようにするため。同じバージョン1.0でもビルドは何本も上がる。
    static var versionDescription: String { "\(version) (\(build))" }
}
