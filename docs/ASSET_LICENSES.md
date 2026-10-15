# 素材ライセンス (ASSET_LICENSES)

| 素材 | パス | 出典 | ライセンス | 用途 |
|---|---|---|---|---|
| Noto Sans JP Regular | `assets/fonts/NotoSansJP-Regular.ttf` | Google Fonts（npm `@expo-google-fonts/noto-sans-jp@0.2.3` 経由で取得） | SIL Open Font License 1.1（`assets/fonts/OFL.txt`） | UI全般の日本語表示。再配布可、フォント単体の販売不可 |
| アプリアイコン | `assets/ui/icon.svg` | 本プロジェクトで作成 | プロジェクト独自 | アプリアイコン |
| 海面シェーダー | `scripts/world/ocean.gdshader` | 本プロジェクトで作成 | プロジェクト独自 | 海の描画 |
| 効果音・環境音・BGM | `assets/audio/*.wav` | `tools/generate_audio.py` で数式合成（外部素材なし） | プロジェクト独自 | 全画面 |
| アイテムアイコン | `assets/items/*.png` | `tools/generate_icons.gd` で図形描画 | プロジェクト独自 | UI |
| ランチャーアイコン | `assets/ui/icon_*.png` | `assets/ui/icon.svg` から生成 | プロジェクト独自 | Android |
| 3D仮モデル一式 | `scripts/characters/character_model.gd`, `scripts/world/raft_view.gd`, `scripts/world/debris.gd` | 本プロジェクトでコード生成 | プロジェクト独自 | 主人公・筏・漂流物 |
| 主人公セル調立ち絵（青年層） | `assets/characters/portraits/protagonist_youth_cel.svg` | `tools/art/gen_protagonist_svg.py` で生成 | プロジェクト独自 | 立ち絵・作成画面（予定） |
| 斧のローポリモデル | `assets/items/models/axe.glb` | `tools/blender/axe_lowpoly.py`（Blender 5.2 / bpy で生成） | プロジェクト独自 | アイテム表示・手持ち（予定） |
| トゥーンシェーダー | `assets/shaders/toon_cel.gdshader`, `assets/shaders/toon_outline.gdshader` | 本プロジェクトで作成 | プロジェクト独自 | セルルック描画 |
| 主人公セル調立ち絵（青年層・SVG） | `assets/characters/portraits/protagonist_youth_cel.svg` | `tools/art/gen_protagonist_svg.py` で生成 | プロジェクト独自 | 参考用 |
| 斧のローポリモデル | `assets/items/models/axe.glb` | `tools/blender/axe_lowpoly.py`（Blender / bpy で生成） | プロジェクト独自 | アイテム（未組込） |
| トゥーンシェーダー・色置き換え | `assets/shaders/toon_*.gdshader`, `recolor.gdshaderinc`, `portrait_recolor.gdshader` | 本プロジェクトで作成 | プロジェクト独自 | セルルック描画 |
| キャラクター立ち絵（88枚） | `assets/characters/portraits/*.webp` | Animagine XL 4.0 でローカル生成（`tools/art/`）。背景除去は rembg（isnet-anime） | 生成物は制作者に帰属（モデルは CreativeML Open RAIL++-M。利用制限条項〈違法・有害用途の禁止など〉に従う） | 会話・仲間画面・作成画面 |
| キャラクター3Dモデル（23体） | `assets/characters/models/*.glb` | 上記の全身画像を TripoSR（MIT）で3D化し、`tools/blender/rig_generated_character.py` で軽量化・骨・アニメーション | 生成物は制作者に帰属 | 探索・作成画面 |

## ソフトウェア
| ソフトウェア | ライセンス | 備考 |
|---|---|---|
| Blender（bpy 5.2.2） | GPL（生成物の .glb は制作者に帰属） | 斧モデル生成。ゲームには同梱しない |
| Animagine XL 4.0（cagliostrolab） | CreativeML Open RAIL++-M | 立ち絵の生成のみ。ゲームには同梱しない |
| TripoSR（Tripo AI / Stability AI） | MIT | 画像→3D。ゲームには同梱しない |
| rembg（isnet-anime / u2net） | MIT / Apache-2.0 | 背景除去。ゲームには同梱しない |
| Blender（bpy 5.2.2） | GPL（生成物の .glb は制作者に帰属） | モデル生成・リギング。ゲームには同梱しない |
| Godot Engine 4.3 | MIT | ゲーム本体に同梱される。ビルドの「著作権表示」に Godot のライセンス表記が必要 |

有料素材・有料APIは使用していない。
