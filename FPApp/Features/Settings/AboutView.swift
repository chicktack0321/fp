import SwiftUI

/// このアプリについて。
///
/// 国家検定の名称を使うため、指定試験機関と提携していないことの明示がApp Reviewで問われうる。
/// 金融商品と税制を扱うので、個別の助言ではないという断りも同じ場所に置く。
/// あわせて、購入の復元・プライバシーポリシー・問い合わせ先という
/// 「審査で所在を確認される導線」をここ1か所にまとめている。
struct AboutView: View {
    @State private var entitlements = Entitlements.shared
    @State private var isRestoring = false
    @State private var restoreMessage: String?

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Image("AppLogo")
                            .resizable()
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(AppFlavor.current.appDisplayName).font(.headline)
                            Text(AppFlavor.current.examDisplayName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text("通信を一切行いません。学習の記録は端末内にのみ保存されます。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("利用状況") {
                // 問い合わせで最初に聞くのがバージョンなので、利用者が自分で見つけられる場所に出す。
                // サポートページでも「このアプリについてで確認できます」と案内している
                LabeledContent("バージョン", value: AppInfo.versionDescription)
                LabeledContent("出題できる問題", value: entitlements.accessSummary)
                if let remaining = entitlements.trialDaysRemaining {
                    LabeledContent("お試し期間", value: "残り\(remaining)日")
                }
            }

            Section("試験の概要") {
                // 学科と実技は別々に合否が出る。片方だけ載せると、
                // 「60点満点中36点以上」を試験全体の基準だと受け取られる
                examRow(AppFlavor.current.writtenExam)
                examRow(AppFlavor.current.practicalExam)
                VStack(alignment: .leading, spacing: 4) {
                    Text("合格基準").font(.subheadline)
                    Text(AppFlavor.current.passingCriteria)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }

            Section("問題データ") {
                // 法令基準日は「いつの制度で覚えたか」を決める。書いておかないと、
                // 改正前の数値を覚えたまま受験することになる
                LabeledContent("法令基準日", value: AppFlavor.current.lawBasisDateDisplay)
                Text(AppConfig.lawBasisNotice)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button {
                    restore()
                } label: {
                    HStack {
                        Text("購入を復元")
                        if isRestoring {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(isRestoring)
            } footer: {
                // 機種変更・再インストール時の案内はストアの審査でも所在を見られる
                Text("機種変更やアプリの入れ直しのあと、同じ Apple アカウントであれば無料で復元できます。")
            }

            Section("リンク") {
                Link("プライバシーポリシー", destination: AppFlavor.current.privacyPolicyURL)
                Link("使い方・お問い合わせ", destination: AppFlavor.current.supportURL)
            }

            Section {
                Text(AppConfig.trademarkNotice)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(AppConfig.disclaimer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("このアプリについて")
        .navigationBarTitleDisplayMode(.inline)
        .alert("購入の復元", isPresented: .constant(restoreMessage != nil)) {
            Button("OK") { restoreMessage = nil }
        } message: {
            Text(restoreMessage ?? "")
        }
    }

    /// 学科・実技それぞれの1行。形式・問題数・時間・合格基準を同じ並びで出す
    private func examRow(_ spec: ExamSpec) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(spec.name).font(.subheadline)
            Text("\(spec.format) / \(spec.summary) / \(spec.passingDescription)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }

    private func restore() {
        isRestoring = true
        Task {
            let restored = await entitlements.restorePurchases()
            isRestoring = false
            restoreMessage = restored
                ? "購入を復元しました。すべての問題が出題対象になります。"
                : "復元できる購入が見つかりませんでした。"
        }
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
