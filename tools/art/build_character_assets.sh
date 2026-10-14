#!/usr/bin/env bash
# キャラクター素材の一括生成（CPUのみ・無料・オフラインで再現可能なローカル生成）。
#   1) 立ち絵の基本（表情 normal）と全身画像  … Animagine XL 4.0
#   2) 全身画像 → 3Dメッシュ                 … TripoSR（MIT）
#   3) 3Dメッシュ → 軽量化・骨・アニメーション … Blender（tools/blender/rig_generated_character.py）
#   4) 表情差分（基本画像から img2img）
#   5) 立ち絵の背景除去・切り抜き・WebP化     … rembg isnet-anime
# 必要な環境は環境変数で渡す:
#   GEN_PY（diffusers/rembg入りのpython） TSR_PY・TSR_DIR（TripoSR） BPY（bpy入りのpython）
#   MODEL_DIR（animagine-xl-4.0 の diffusers 形式） WORK（作業ディレクトリ）
set -eu
cd "$(dirname "$0")/../.."
ROOT=$PWD
: "${GEN_PY:?}" "${TSR_PY:?}" "${TSR_DIR:?}" "${BPY:?}" "${MODEL_DIR:?}" "${WORK:?}"
mkdir -p "$WORK/out" "$WORK/tsr" assets/characters/models assets/characters/portraits
python3 tools/art/character_jobs.py base > "$WORK/jobs_base.json"
python3 tools/art/character_jobs.py expr > "$WORK/jobs_expr.json"
echo "== 1) 基本画像"; "$GEN_PY" tools/art/gen_images.py "$MODEL_DIR" none "$WORK/jobs_base.json" "$WORK/out"
echo "== 2-3) 3D化・リギング"
for f in "$WORK"/out/*_full.png; do
  id=$(basename "$f" _full.png)
  [ -f "assets/characters/models/$id.glb" ] && continue
  (cd "$TSR_DIR" && "$TSR_PY" run.py "$f" --device cpu --output-dir "$WORK/tsr/$id" --mc-resolution 256 --model-save-format glb >/dev/null 2>&1) \
    || { echo "TripoSR 失敗: $id"; continue; }
  "$BPY" tools/blender/rig_generated_character.py -- "$WORK/tsr/$id/0/mesh.glb" "assets/characters/models/$id.glb" 2>&1 | grep "\[rig\]" || true
done
echo "== 4) 表情差分"; "$GEN_PY" tools/art/gen_images.py "$MODEL_DIR" none "$WORK/jobs_expr.json" "$WORK/out"
echo "== 5) 立ち絵の仕上げ"; "$GEN_PY" tools/art/process_portraits.py "$WORK/out" assets/characters/portraits
echo "== 完了"
