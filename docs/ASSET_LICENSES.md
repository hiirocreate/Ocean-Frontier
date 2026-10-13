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

## ソフトウェア
| ソフトウェア | ライセンス | 備考 |
|---|---|---|
| Godot Engine 4.3 | MIT | ゲーム本体に同梱される。ビルドの「著作権表示」に Godot のライセンス表記が必要 |

有料素材・有料APIは使用していない。
