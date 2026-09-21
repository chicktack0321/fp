# TestFlight で実機確認できるようにする手順

Mac実機を持たない前提で、GitHub Actions から TestFlight へ配信するまでの手順。
英単語特訓・古文特訓・ITパスポート特訓と同じ体制なので、やることは既に経験済みのものと同じ。

**違うのは、アプリが2つあること。** 3級と2級は App Store Connect 上で別のアプリになるため、
§3（App ID）・§4（アプリ登録）・§7（App内課金）は**それぞれに対して2回**行う。
リポジトリとGitHub Secrets（§2）は共通で、1組で足りる。

CI（`ios-build.yml`）はシミュレータ上での動作までしか見ていない。
実機でしか分からないこと（触り心地、文字の詰まり、音、触覚フィードバック、
実際の購入フロー）はここから先で確認する。

## 進捗

| | 項目 | 3級 | 2級 |
| --- | --- | --- | --- |
| 0 | バンドルID の確定 | ✅ `com.eitango.fp3` | ✅ `com.eitango.fp2` |
| 1 | 実機向けビルドの確認（dry run） | ✅ アーカイブ・埋め込み内容の検証とも通過 | ✅ 同左 |
| 2 | GitHub Secrets（2アプリ共通） | ✅ 3つとも登録済み | ✅ 同左 |
| 3 | App ID の登録 | ✅ 完了 | ✅ 完了 |
| 4 | App Store Connect でのアプリ登録 | ✅ 完了 | ✅ 完了 |
| 5 | 配信 | ✅ **ビルド5 をアップロード済み** | ✅ **ビルド6 をアップロード済み** |
| 7 | App内課金の登録 | ⬜ | ⬜ |

**初回セットアップは完了。** 以降の配信は §5（Run workflow）だけでよい。
残っているのは TestFlight 側でのテスター割り当てと、購入フローを試すなら §7 の App内課金の登録。

---

## 0. バンドルID（先に確定させる）

| アプリ | バンドルID | App内課金のプロダクトID |
| --- | --- | --- |
| FP3級特訓 | `com.eitango.fp3` | `com.eitango.fp3.unlock.advanced` |
| FP2級特訓 | `com.eitango.fp2` | `com.eitango.fp2.unlock.advanced` |

`project.yml` の `PRODUCT_BUNDLE_IDENTIFIER` と、各 `FPn/AppFlavor.swift` の
`bundleIdentifier` / `unlockProductID` に設定してある。

**App Store公開後は変更できない。** アプリの同一性そのものなので、変えると別アプリ扱いになり、
既存ユーザーは更新を受け取れず、購入も引き継げない。

`com.eitango` プレフィクスは既存アプリと揃えたもの
（英単語特訓 `com.eitango.app` / 古文特訓 `com.eitango.kobun` / ITパスポート特訓 `com.eitango.itpassport`）。
FP向けの新しいプレフィクスを作らないのは、App ID の登録がプレフィクス単位で通りやすいのと、
既存アプリと同じ開発者アカウントの下で管理が一続きになるため。

---

## 1. 先に実機向けビルドだけ確かめる（任意・準備不要）

App Store Connect の登録を始める前に、実機（arm64）向けのビルドが通るかだけを確認できる。
CIが見ているのはシミュレータ向けのビルドなので、ここで初めて分かることがある。

Actionsタブ → **TestFlight** → **Run workflow** → **配信するアプリ** を選び、
**検証のみ** にチェックを入れて実行。3級・2級それぞれで一度ずつ試しておくとよい。

Secretsもアプリ登録も不要。アーカイブを作り、埋め込まれた内容
（バンドルID・ビルド番号・暗号化宣言・表示名・アイコン・問題データ・プライバシーマニフェスト）を
検証するところまで走り、送信はしない。

問題データの検証では、**同梱されたJSONのIDが選んだ級の接頭辞（`FP3_` / `FP2_`）で
始まっているか**まで見る。3級のアプリに2級の問題が入っていても画面上は普通に動いてしまうため、
機械で確かめられるうちに止める。

---

## 2. GitHub Secrets を登録する（2アプリ共通・1回だけ）

既存アプリと**同じApp Store Connect APIキーを使い回せる**。
キーは開発者アカウント単位なので、アプリごとに作り直す必要はない。
3級と2級は同じリポジトリなので、Secretsも1組で足りる。

| Secret | 内容 | 状態 |
| --- | --- | --- |
| `ASC_API_KEY_ID` | APIキーの Key ID。`J3WKQPWJ2T`（キー名: GitHub Actions CI / アクセス: 管理者） | ✅ 登録済み |
| `ASC_API_KEY_P8` | `.p8` の中身（BEGIN/END行を含む全文） | ✅ 登録済み |
| `ASC_API_ISSUER_ID` | Issuer ID（UUID形式） | ✅ 登録済み |

> **キーのアクセス権は「管理者（Admin）」にすること。**
> このワークフローは `-allowProvisioningUpdates` でクラウド署名を使い、証明書と
> プロビジョニングプロファイルをXcodeに作らせる。証明書の作成にはAdminが要る。
> 「App Manager」で作ると、ビルドもアーカイブも通ったうえで書き出しだけが
> `Cloud signing permission error` / `No profiles for '<バンドルID>' were found` で落ちる。
> 権限不足だと分かる文言が出ないので、アプリ登録の漏れと取り違えやすい。
>
> **キーのアクセス権は作成後に変更できない。** キー一覧の「編集」でできるのは
> 表示と無効化までで、名前もアクセス権も後から変えられない。
> 権限を間違えたら、**管理者で新しいキーを作り直す**しかない（＝ `.p8` の配り直しも要る）。
> キーを作るときのアクセス権の選択が、あとで取り返しのつかない唯一の項目になる。
>
> **2026年9月21日: キーを2度作り直した。**
> `3V2TDP49RN`（管理者）は `.p8` を紛失したため無効化。
> 作り直した `F5R7YD55S6` はアクセス権を App Manager にしてしまい、
> クラウド署名ができずTestFlightの書き出しで失敗したため無効化。
> 現在有効なのは管理者権限の `J3WKQPWJ2T`。
> `.p8` は発行時の一度しかダウンロードできず、再取得できないため作り直すしかない。
>
> **同じキーを使い回していた他のリポジトリのSecretsも更新が必要。**
> 更新しないと、それらのアプリのTestFlight配信が送信ステップで失敗する
> （ビルドは通るので、気付くのはアップロードの直前になる）。
> 対象: `ITpassport` / `eitango_tokkun` / `eitango_target1900` / `kobun_tokkun`

`.p8` はファイルから流し込むと改行が崩れない。

```bash
gh secret set ASC_API_KEY_ID    -R chicktack0321/fp --body "<Key ID>"
gh secret set ASC_API_ISSUER_ID -R chicktack0321/fp --body "<Issuer ID>"
gh secret set ASC_API_KEY_P8    -R chicktack0321/fp < /path/to/AuthKey_XXXXXXXXXX.p8
```

Key ID は `.p8` のファイル名に含まれているが、**Issuer ID はキーからは分からない**。
発行元アカウントの識別子なので、[App Store Connect](https://appstoreconnect.apple.com/access/integrations/api) →
ユーザーとアクセス → 統合 → App Store Connect API のキー一覧の上から取る。
既存アプリにも同じ値が入っているが、**GitHubのSecretsは書き込み専用で読み出せない**ため、
そちらから写すことはできない。

`.p8` を無くした場合も再ダウンロードできない。同じ画面で新しいキーを作り、
**同じキーを使っている全リポジトリのSecretsをそのとき合わせて更新する**
（1回だけダウンロードできる `.p8` を、その場で全リポジトリへ流し込んでしまうのが確実）。

```bash
for r in fp ITpassport eitango_tokkun eitango_target1900 kobun_tokkun; do
  gh secret set ASC_API_KEY_ID    -R chicktack0321/$r --body "<Key ID>"
  gh secret set ASC_API_ISSUER_ID -R chicktack0321/$r --body "<Issuer ID>"
  gh secret set ASC_API_KEY_P8    -R chicktack0321/$r < /path/to/AuthKey_XXXXXXXXXX.p8
done
```

登録できたか確認:

```bash
gh secret list -R chicktack0321/fp
```

---

## 3. App ID を登録する（アプリごとに1回ずつ）

[developer.apple.com](https://developer.apple.com/account/resources/identifiers/list) →
Certificates, Identifiers & Profiles → Identifiers → **+**

- 種類: **App IDs** → **App**
- Description: `FP3 Tokkun` / `FP2 Tokkun`（管理用の名前。何でもよい）
- Bundle ID: **Explicit** を選び、`com.eitango.fp3` または `com.eitango.fp2` を入力
- Capabilities: 既定のままでよい（App内課金は明示的な有効化が不要）

先にここで登録しておく。CIの `-allowProvisioningUpdates` は証明書と
プロビジョニングプロファイルを自動で用意してくれるが、次の手順の
バンドルIDのドロップダウンには「登録済みのApp ID」しか出てこない。

---

## 4. App Store Connect にアプリを登録する（アプリごとに1回ずつ）

[App Store Connect](https://appstoreconnect.apple.com/apps) → マイApp → **+** → 新規App

| 項目 | 3級 | 2級 |
| --- | --- | --- |
| プラットフォーム | iOS | iOS |
| 名前（30文字以内・全アプリで一意） | 例: `FP3級特訓 - ファイナンシャルプランナー` | 例: `FP2級特訓 - ファイナンシャルプランナー` |
| プライマリ言語 | 日本語 | 日本語 |
| バンドルID | `com.eitango.fp3` | `com.eitango.fp2` |
| SKU | `fp3-tokkun` | `fp2-tokkun` |
| ユーザーアクセス | フルアクセス | フルアクセス |

**この登録をせずにワークフローを実行するとアップロードで失敗する。**
ビルド自体は通るので、失敗するのは最後の送信ステップになる。

### カテゴリと年齢制限について

カテゴリは「教育」を第1カテゴリにする。金融・ファイナンスを選ぶと、
実際の資産管理や取引を行うアプリとして審査され、金融機関との関係や
投資助言の資格について説明を求められることがある。本アプリは試験対策の学習アプリであり、
個別の助言も取引も行わない（その旨はアプリ内の「このアプリについて」にも常設してある）。

---

## 5. 配信する

Actionsタブ → **TestFlight** ワークフロー → **Run workflow** → **配信するアプリ** を選ぶ。

pushのたびに配信するとビルドが溜まりテスターへの通知も続くため、手動トリガーにしてある。
「両方」を用意していないのは、片方の配信が失敗したときに
もう片方が上がったのかどうかを一目で判断できなくなるため。2回実行する。

ワークフローは送信前に次を機械的に検証する。ここで止まったらアップロードはされない。

- バンドルIDが選んだ級のものになっているか
- ビルド番号が実行番号で更新されているか
- `ITSAppUsesNonExemptEncryption`（未宣言だと輸出コンプライアンスで配信が止まる）
- `CFBundleDisplayName`（無いとホーム画面が `FP3App` になる）
- アプリアイコンと `Assets.car`（アイコンが無いビルドはApp Store Connectが弾く）
- `question_master_seed.json` が入っていて、IDの接頭辞が級と一致しているか
- `PrivacyInfo.xcprivacy` と UserDefaults の利用理由の宣言

アップロード後、App Store Connect 側の処理に5〜15分かかる。
処理が終わると TestFlight タブにビルドが現れる。

### 内部テストで配信する（最短）

TestFlight → 内部テスト → グループを作り、自分のApple Accountを追加してビルドを割り当てる。
**内部テストは審査なしで即座に配信される**（App Store Connectのユーザー100人まで）。
動作確認だけならこれで足りる。

外部テスター（最大10,000人）へ配る場合は初回ビルドに Beta App Review が入り、
ベータ版アプリの説明・フィードバック用メールアドレス・連絡先の入力が必要になる。

---

## 6. 実機で確認したいこと

シミュレータでは分からない、または見落としやすい箇所。

| 見るところ | なぜ |
| --- | --- |
| 3級の○×問題 | 選択肢の記号（A/B）を出さない作りにしてある。「正しい」「誤り」が2つ並ぶ見た目が成立しているか |
| 3級の三答択一 | 選択肢が3つでもカードの余白が間延びしていないか |
| 演習の解説パネル | 長い解説をスクロールしながら読めるか。解答後に解説の先頭へ送る動きが速すぎないか |
| 「次の問題へ」の位置 | 解説を読み終えた自然な位置にあるか。誤タップで飛ばしてしまわないか |
| 問題文と選択肢の折り返し | 実機の文字サイズ設定（特に大きめ）で詰まらないか。2級の選択肢は3級より長い |
| 科目名の表示 | 「ライフプランニングと資金計画」が切れていないか。狭い場所では短縮名を使っている |
| 触覚フィードバック | 正解1回・不正解3回の震え方。シミュレータでは再現されない |
| 効果音とBGM | 波形合成なので実機のスピーカーで耳障りでないか |
| 「このアプリについて」 | 法令基準日と、指定試験機関と提携していない旨・個別助言ではない旨が読めるか |
| 購入画面 | §7の通り、IAP未登録だと価格が出ない |

---

## 7. App内課金の登録（アプリごとに1回ずつ）

登録していないと、購入画面は「価格を読み込んでいます」のまま止まり、購入ボタンは押せない。

App Store Connect →（アプリ）→ 収益化 → App内課金 で非消耗型として登録する。

| 項目 | 3級 | 2級 |
| --- | --- | --- |
| タイプ | 非消耗型 | 非消耗型 |
| 参照名 | 標準・応用問題の解放 | 標準・応用問題の解放 |
| 製品ID | `com.eitango.fp3.unlock.advanced` | `com.eitango.fp2.unlock.advanced` |
| 価格 | ¥300 | ¥480 |

製品IDは各 `FPn/AppFlavor.swift` の `unlockProductID` および
`FPn/Products.storekit` と一致させる。ずれていると商品情報が取得できず、
シミュレータでは動くのに実機で価格が出ないという分かりにくい壊れ方をする。

価格を2級のほうを高くしてあるのは、収録する論点の量と、購入までの検討度合いが違うため。
揃えたい場合は `FPn/Products.storekit` の `displayPrice` と
App Store Connect 側の価格を両方変更する（請求額として正しいのはApp Store Connect側）。

登録して「提出準備完了」になれば、TestFlightのビルドから
Sandbox環境で購入を試せる（実際の課金は発生しない）。

なお `Products.storekit` はシミュレータとUIテスト専用で、実機の挙動には影響しない。

---

## 8. うまくいかないときの切り分け

| 症状 | 原因と対処 |
| --- | --- |
| `ASC_API_KEY_P8 / ASC_API_KEY_ID が未設定です` | §2。Secretsが入っていない |
| `バンドルIDが想定と違います` | `project.yml` と `FPn/AppFlavor.swift` の値がずれている |
| `同梱された問題データに FP3_ で始まるIDがありません` | `project.yml` のターゲットが参照している `Resources` が別の級のものになっている |
| 送信ステップで `No suitable application records were found` | §4のアプリ登録がまだ。バンドルIDの綴りも確認する |
| `Cloud signing permission error` と `No profiles for ... were found` が**同時に**出る | APIキーのアクセス権が足りない。App Managerでは証明書を作れない。権限は後から変えられないので、**管理者で新しいキーを作り直す**（§2） |
| `No profiles for 'com.eitango.fp3' were found` だけが出る | §3のApp ID登録がまだ |
| ビルド番号が重複していると言われる | App Store Connectは同じ（バージョン, ビルド番号）を二度受け付けない。ワークフローは実行番号を使うので、通常は起きない。バージョンを上げるときは `project.yml` の `MARKETING_VERSION` を変更する |
| TestFlightにビルドが出てこない | 処理に5〜15分かかる。それ以上なら、App Store Connectから届くメールに理由が書かれている |
