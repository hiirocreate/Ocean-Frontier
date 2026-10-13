# 素材管理表 (ASSET_STATUS)

状態: 完成 / 仮素材 / 未作成。「仮」は完成版で置き換えが必要。

| 素材ID | 表示名 | 種類 | ファイルパス | 制作方法 | ライセンス | 用途 | 対応 | 状態 | 仮 |
|---|---|---|---|---|---|---|---|---|---|
| ui_font_jp | Noto Sans JP | フォント | assets/fonts/NotoSansJP-Regular.ttf | 既存無料素材 | OFL 1.1 | UI | 全画面 | 完成 | いいえ |
| ui_icon | アプリアイコン | SVG | assets/ui/icon.svg | 手書きSVG | 独自 | アイコン | — | 仮素材 | はい |
| env_ocean | 海面 | シェーダー | scripts/world/ocean.gdshader | コード | 独自 | 海 | 全海域 | 完成（初期海域） | いいえ |
| env_sky | 空・照明 | 手続き生成 | scripts/world/world.gd | ProceduralSky + 時刻照明 | 独自 | 空 | — | 完成（天候なし） | いいえ |
| raft_tile | 筏の床 | 3D | scripts/world/raft_view.gd | プリミティブ組合せ | 独自 | 筏 | raft_foundation | 仮素材 | はい |
| bld_* | 建築物7種（収納箱・作業台・浄水器・釣り網・焚き火台・寝床・畑） | 3D | scripts/building/building_models.gd | プリミティブ組合せ（生産数で見た目変化） | 独自 | 筏 | buildings.json | 仮素材 | はい |
| site_* | 探索地点の目印10種（沈没船・無人船・ブイ・廃墟・研究施設・海底都市・赤潮の渦・市場・要塞・海賊の根城） | 3D | scripts/world/site_models.gd | プリミティブ組合せ | 独自 | 探索 | sites.json | 仮素材 | はい |
| raft_mast | 帆柱とランタン | 3D | scripts/world/world.gd | プリミティブ組合せ | 独自 | 筏 | — | 仮素材 | はい |
| debris_plank / barrel / crate | 漂流物3種 | 3D | scripts/world/debris.gd | プリミティブ組合せ | 独自 | 漂流物 | world_zones | 仮素材 | はい |
| char_protagonist_model | 主人公3Dモデル | 3D | scripts/characters/character_model.gd | プリミティブ組合せ＋手続きアニメ | 独自 | 探索 | 主人公 | 仮素材 | はい |
| char_portraits | 立ち絵（主人公＋仲間5名×表情6種） | 2D（図形描画） | scripts/ui/portrait_view.gd | コードで描画（配色・髪型・装飾をデータから） | 独自 | 会話・仲間画面 | 全キャラクター | 仮素材 | はい |
| char_crew_models | 仲間5名の3Dモデル | 3D | scripts/characters/character_model.gd（apply_look） | プリミティブ組合せ | 独自 | 探索・筏 | 全仲間 | 仮素材 | はい |
| encounter_boat | 漂流者の小舟 | 3D | scripts/world/encounter.gd | プリミティブ組合せ | 独自 | 救助・再会 | — | 仮素材 | はい |
| item_icons | アイテムアイコン | 2D | assets/items/*.png | — | — | UI | 全アイテム | 未作成（文字表示で代替） | — |
| title_bg | タイトル背景 | シェーダー | scripts/ui/main_menu.gd | コード | 独自 | タイトル | — | 仮素材 | はい |
| audio_* | 効果音・BGM | 音声 | assets/audio/ | — | — | — | — | 未作成 | — |

## 不足素材（完成版で必要）
- 主人公と主要キャラクター5名の2Dイラスト一式（設定画・立ち絵・表情差分・アイコン）
- Blender製の探索用3Dモデル（.glb）とアニメーション
- アイテムアイコン（13種、今後増加）
- 効果音（回収・建築・クラフト・UI）、環境音（波・風）、BGM

## 存在しない素材の扱い
- データ検証（`DataValidator`）がアイテムのアイコン、建築物のモデルのパスの存在を検査し、存在しなければ開発時エラーにする。
- 実行時はアイコン未設定のアイテムは文字のみで表示し、クラッシュしない。
