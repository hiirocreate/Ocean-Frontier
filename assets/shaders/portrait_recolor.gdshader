// 立ち絵（生成イラスト）用: 髪色・肌の色の置き換え。独自制作（CC0扱い）。
shader_type canvas_item;
#include "res://assets/shaders/recolor.gdshaderinc"

uniform float body_from_v = 0.45; // マスクが無い立ち絵: 上からこの割合より下を体（衣装の置き換えの対象）とする
uniform bool use_outer_mask = false;
uniform sampler2D outer_mask : filter_linear; // 上着（フードを含む）の範囲。tools/make_outfit_masks.py で作成（目の青は含まない）

void fragment() {
	// COLOR には既にテクスチャの色が入っている（二重に掛けないこと）
	COLOR = vec4(recolor(COLOR.rgb, false, use_outer_mask ? texture(outer_mask, UV).r > 0.5 : UV.y > body_from_v), COLOR.a);
}
