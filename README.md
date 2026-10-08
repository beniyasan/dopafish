# Dopagaki Fishing Collection

iPhone向け 釣り×パチンコ演出ゲーム。SwiftUI + SpriteKit で作ったネイティブアプリ。
釣り場やエフェクトはコード描画、おじさんは生成イラストの画像アセット、SE・BGMはコード内合成。外部ライブラリ依存ゼロ。

## 遊び方

1. **CASTボタン長押し** → パワーためてリリースでキャスト
2. ウキが沈んだら**リーチ演出**開始（ノーマル / ロング / スーパー / ゴールデン / レインボー）
3. 正体不明の**魚影バトル**を見守る。熱いリーチほど長い演出
4. 最後の**連打!!**で画面をタップしてメーターを満タンに
5. 大物（SR以上）なら当たり演出＋メダル、小物（N/R）・逃走はハズレ相当
6. **UR/LRを釣ると RUSH 突入**: 高確率モード（残り回転数表示）。RUSH中にSSR以上を釣ると回転数追加

- ハズレリーチもある（超激アツから逃げる＝ガセ演出）
- ベストスコア・最大サイズはUserDefaultsに保存
- **AUTO**は最後の手動キャストの強さで連投（初期65%）。連打・釣果カードは手動操作
- おじさんの通常／中予告は笑顔のイラスト＋吹き出し。激アツは真剣な表情の赤いカットイン、プレミアムは金色のカットイン
- 激アツでもガセあり。カットインは当たり抽選を変更せず、連打開始・結果表示前に消える
- 派手演出: 熱いリーチで集中線＋魚影オーラ＋赤い脈動ヴィネット、金/虹リーチで雷撃、SR+で光柱、UR/LRで紙吹雪＋星屑シャワー＋雷撃、連打はタップ衝撃波、逃走時はライン切断
- **魚図鑑**: 待機画面の「図鑑」ボタン。種別の釣獲数・最大サイズを記録（UserDefaults永続化）。未捕獲は？？？表示
- **釣具屋**: コインで装備強化（Lv0〜5・永続）。金の竿=高レア魚解禁/確率UP、強化リール=逃走時にLv確率で小型以上を再抽選（Lvが高いほど大物寄り）+連打猶予、RUSH券=突入回転+Lv分
- **幻魚**: 竿MAXでのみ低確率出現するシークレット魚。図鑑にも釣るまで載らない

## レア度

| レア | 例 | 備考 |
|---|---|---|
| N | ワカサギ | 100点台 |
| R | アジ | 250点台 |
| SR | マダイ | 700点台〜・大物当たり |
| SSR | カジキ | 2000点台 |
| UR | 黄金龍魚 | 5000点・RUSH+10 |
| LR | 虹神クジラ | 15000点・RUSH+15 |

## ビルド・実行

```sh
brew install xcodegen
xcodegen generate
xcodebuild -project FishingPachinko.xcodeproj -scheme FishingPachinko \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

実機: Xcodeで `FishingPachinko.xcodeproj` を開き、Signing & Capabilities で自分の
Apple ID（無料でOK）の Personal Team を選んで実行。

自動テスト:

```sh
xcodebuild -project FishingPachinko.xcodeproj -scheme FishingPachinko \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' test
```

## デバッグ起動引数（シミュレータ検証用）

- `-rig ur|lr|ssr|sr|r|n|miss` … 次のバイト結果を固定
- `-fast` … バイトまでの待ち時間を短縮
- `-mashneed X` … 連打必要数の倍率（0.05ならほぼ1発で釣れる）
- `-win` … 連打フェーズを自動タップ（当たり演出確認用）
- `-secret` … 次の釣果を幻魚に固定（図鑑・カード確認用）

例: `xcrun simctl launch booted com.devin.FishingPachinko -rig ur -fast`

## 構成

- `FishingPachinkoApp.swift` — エントリポイント
- `ContentView.swift` — HUD・バナー・ボタン・リーチカード等 SwiftUI オーバーレイ
- `OldManView.swift` — おじさんの会話吹き出し・赤／金カットイン
- `Assets.xcassets/OldManNormal.imageset` / `OldManHot.imageset` — 通常／激アツの透過イラスト
- `GameScene.swift` — SpriteKit 描画（海・ウキ・魚影・パーティクル・カメラズーム）
- `GameModel.swift` — ゲーム状態機械・確率・リーチ演出スクリプト・ファイト・RUSH・装備強化・図鑑
- `CollectionView.swift` — 魚図鑑（DexOverlay）・釣具屋（ShopOverlay）画面
- `SoundEngine.swift` — WAV合成（SE 20種＋BGM 3曲）・AVAudioPlayer・ハプティクス
- `FishingPachinkoTests/OldManTests.swift` — セリフの寿命・重複・表示制御・アセット・画面幅別レンダリングの自動テスト
