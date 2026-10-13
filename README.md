# Ocean Frontier：LAST TIDE — 最後の潮流

海に覆われた世界を筏で生き抜く、Android 向けローポリ3Dサバイバルアドベンチャー。
Godot 4.3 / GDScript。有料API・有料素材なし、オフラインで遊べる。

- 正式仕様: [docs/GAME_SPEC.md](docs/GAME_SPEC.md)
- 進捗: [docs/IMPLEMENTATION_STATUS.md](docs/IMPLEMENTATION_STATUS.md) / [TASKS.md](TASKS.md)
- 既知の問題: [docs/KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md)

## 現在遊べる内容（v0.1.0 開発版）
- 筏を漕いで5つの海域を移動、漂流物（板・樽・木箱）を回収
- 筏の拡張と14種の設備（収納箱・作業台・浄水器・釣り網・焚き火台・寝床・畑・医療設備・武器製作台・船舶修理台・通信設備・防御柵・捕虜の檻・研究机）
- 40種以上のアイテムとクラフト、工具の耐久度と修理
- 空腹・水分・疲労・体力・負傷の管理、昼夜の変化、睡眠
- 漂流者の救助と5人の仲間（作業の割り当て・技能・人間関係・離脱と再会、2D立ち絵の会話）
- 沈没船・廃墟・研究施設・海底都市などの探索（潜水）、戦闘（戦う／逃げる／交渉、捕虜）
- 海図と目的地の設定、セーブ/ロード（自動セーブ）

### 操作
| 操作 | タッチ | キーボード |
|---|---|---|
| 移動 | 左下の仮想スティック | WASD / 矢印 |
| 仲間 | 「仲間」 | C |
| 海図 | 「海図」 | M |
| 探索地点を調べる | 「調べる」（地点の近くで表示） | — |
| 視点回転 | 画面をドラッグ | — |
| ズーム | ピンチ | マウスホイール |
| 回収 | 「回収」ボタン（近くに漂流物があるとき） | E / Space |
| 持ち物・クラフト | 「持ち物」 | I / Tab |
| 建築（筏の拡張） | 「建築」→ 緑の枠をタップ →「ここに建設」 | B |
| メニュー（セーブ/ロード/画質） | 「メニュー」/ Android の戻るボタン | Esc |

## 動作環境・バージョン
| 項目 | バージョン |
|---|---|
| Godot | 4.3-stable（GL Compatibility レンダラー） |
| Android | 5.0（API 21）以上、arm64-v8a、OpenGL ES 3.0 |
| Android SDK | build-tools 34.0.0 / platform android-34 |
| JDK | 17 以上（21 で動作確認） |

## Android へのインストール
1. `build/android/ocean_frontier_debug.apk` を端末にコピーする（または `tools/build_android.sh` で作成）。
2. 端末の設定で「提供元不明のアプリ」のインストールを許可する。
3. APK を開いてインストールする。
   PC から行う場合: `adb install -r build/android/ocean_frontier_debug.apk`

## セーブデータの保存場所
| 環境 | 場所 |
|---|---|
| Android | アプリ専用領域 `/data/data/com.oceanfrontier.lasttide/files/saves/slot1.json`（他アプリから不可視） |
| Linux | `~/.local/share/godot/app_userdata/Ocean Frontier_ LAST TIDE/saves/` |
| Windows | `%APPDATA%\Godot\app_userdata\Ocean Frontier_ LAST TIDE\saves\` |

`slot1.json`（本体）、`slot1.json.bak`（1つ前のセーブ）。本体が壊れていると自動的にバックアップから復旧する。
アプリがバックグラウンドへ移るとき・終了時・2分ごとに自動セーブする。

## 開発者向け
```bash
tools/run_tests.sh                 # データ検証 + ユニット/統合テスト + E2E（ヘッドレス）
tools/run_e2e_render.sh            # 実描画のE2E＋スクリーンショット（Xvfb が必要）
tools/build_android.sh             # デバッグAPKを作成
# 実描画でE2E＋スクリーンショット（build/screenshots/）
xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --script res://tools/smoke_test.gd
```

### 構成
```
scripts/core/       GameSession（全状態）、ActionSystem（行動の検証と消費）、SaveManager、GameData、DataValidator、Game（オートロード）
scripts/inventory/  Inventory（所持品・耐久度・重量）
scripts/survival/   SurvivalState（体力・空腹・水分・疲労・負傷）
scripts/building/   Raft（床タイル・建築物）
scripts/world/      3D表示（海・筏・漂流物・カメラ）
scripts/ui/         HUD・メインメニュー・仮想スティック
data/               アイテム・行動（レシピ）・建築物・海域・バランス設定（JSON）
tests/unit/         自動テスト
```
ゲームデータの数値はすべて `data/` の JSON にあり、プログラムを変えずに調整できる。
