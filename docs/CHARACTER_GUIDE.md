# キャラクターガイド (CHARACTER_GUIDE)

主要キャラクターは「外見から性格・経歴が推測できる」ことを原則とする（仕様11）。
2Dイラストと3Dモデルで**同じ配色・シルエット**を使う。下表の配色コードがその基準。

## 主人公：漂流者（名前はプレイヤーが決定予定。仮名「ナギ」）
- 立場: 記憶の一部を失った漂流者。実は沈んだ研究施設と関係がある（第3章で判明）。
- 性格: 慎重だが粘り強い。
- 外見: 20代前半。ボサボサの黒髪短髪、日焼けした肌、潮で色あせたシャツ、青緑のベスト、赤錆色のスカーフ（唯一の手がかりの刺繍入り）、小さな革の鞄。
- 配色: 肌 `#e8b996` / 髪 `#2e2a2b` / シャツ `#d8cfb8` / ベスト `#3f6b73` / ズボン `#4a4f5e` / スカーフ `#c2553d`
- 3D: `scripts/characters/character_model.gd`（仮・プリミティブ構成）
- 2D: `scripts/ui/portrait_view.gd`（仮・図形描画。髪型 messy、装飾 scarf）

## 主要キャラクター（実装済み：data/characters/survivors.json）
| ID | 役割 | 外見の要点 | 配色の軸 |
|---|---|---|---|
| `mira` | 元海洋研究者 | 丸眼鏡、白衣を改造した防水コート、記録端末を首から下げる | 白・灰青 |
| `garrett` | 元軍人 | 大柄、短い白髪混じり、古い軍用ジャケット、片腕に古傷 | オリーブ・黒 |
| `tobi` | 少年技術者 | ゴーグル、工具ベルト、油汚れ | 黄土・橙 |
| `selene` | 商人 | 色鮮やかな布を重ねた服、多数のアクセサリー、帳簿 | 紫・金 |
| `rook` | 海賊 | 継ぎはぎの外套、片目の眼帯、銛を背負う | 暗赤・黒 |

## 必要な素材（各主要キャラクター）
設定画 / 顔アップ / 三面図 / 会話用立ち絵 / 表情差分（通常・笑顔・怒り・悲しみ・驚き）/ 探索用3Dモデル / アイコン / アニメーション（待機・歩行・作業）

## 表情差分の命名
`assets/characters/portraits/<id>_<expression>.png`（例: `mira_smile.png`）

## 2D/3D 共通の外見パラメータ
survivors.json の `colors`（skin, hair, shirt, outer, pants, accent）・`hair_style`（long / long_wavy / spiky / crop / tied / messy）・`accessory`（glasses / goggles / scar / earrings / eyepatch / scarf）を、
立ち絵（PortraitView）と3Dモデル（CharacterModel.apply_look）の両方が参照する。正式イラスト・Blenderモデルもこの値に合わせて制作する。

## 表情
normal / smile / sad / angry / surprised / tired（会話データの `expression`）
