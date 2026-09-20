import SwiftUI

/// 出題範囲を選ぶカード。
///
/// 全問をまとめて扱うと習熟度がほとんど動かず、出題も科目が散らばって
/// 「いま何を潰しているのか」が分からなくなる。範囲を狭められること自体が機能なので、
/// 各画面に散らさず1つの部品にまとめている。
struct StudyScopeCard: View {
    let title: String
    @Binding var scope: StudyScope
    /// この条件に何問入るか。0問のまま始めさせないための表示
    var matchingCount: Int?

    var body: some View {
        DashboardCard(title: title) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    menu(title: "科目", selected: scope.field?.shortName ?? "すべて") {
                        Button("すべての科目") { scope.setField(nil) }
                        ForEach(ExamField.allCases) { field in
                            Button(field.displayName) { scope.setField(field) }
                        }
                    }
                    Spacer(minLength: 12)
                    menu(title: "難易度", selected: scope.difficulty?.displayName ?? "すべて") {
                        Button("すべての難易度") { scope.difficulty = nil }
                        ForEach(QuestionDifficulty.allCases) { difficulty in
                            Button(difficulty.displayName) { scope.difficulty = difficulty }
                        }
                    }
                }

                HStack {
                    menu(title: "細目", selected: scope.midCategory?.displayName ?? "すべて") {
                        Button("すべての細目") { scope.midCategory = nil }
                        // 科目を選んでいればその科目のものだけを出す。
                        // 40個を科目横断で並べると目的の項目に辿り着けない。
                        ForEach(availableMidCategories) { category in
                            Button(category.displayName) { scope.midCategory = category }
                        }
                    }
                    Spacer()
                }

                if let matchingCount {
                    Divider()
                    HStack {
                        Text("この条件の問題")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(matchingCount)問")
                            .font(.subheadline).bold()
                            .foregroundStyle(matchingCount == 0 ? .orange : .primary)
                            .contentTransition(.numericText())
                    }
                    if matchingCount == 0 {
                        Text("条件に合う問題がありません。絞り込みを緩めてください。")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }

                if !scope.isDefault {
                    Button("条件をリセット") { scope = .default }
                        .font(.caption)
                }
            }
        }
    }

    private var availableMidCategories: [MidCategory] {
        guard let field = scope.field else { return MidCategory.allCases }
        return MidCategory.all(in: field)
    }

    // Picker(.menu) はラベルと選択値を1行に詰めようとして幅の狭い端末で崩れるため、
    // Menu を直接使って1行に固定する
    private func menu<Content: View>(
        title: String,
        selected: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Menu {
            content()
        } label: {
            HStack(spacing: 4) {
                Text(title).foregroundStyle(.primary)
                Text(selected).foregroundStyle(.secondary)
                Image(systemName: "chevron.up.chevron.down").font(.caption2)
            }
            .font(.subheadline)
            .lineLimit(1)
            .fixedSize()
        }
    }
}
