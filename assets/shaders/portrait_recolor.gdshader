// 立ち絵（生成イラスト）用: 髪色・肌の色の置き換え。独自制作（CC0扱い）。
shader_type canvas_item;
#include "res://assets/shaders/recolor.gdshaderinc"

uniform float body_from_v = 0.45; // 立ち絵の上からこの割合より下を体（衣装の置き換えの対象）とする

void fragment() {
	// COLOR には既にテクスチャの色が入っている（二重に掛けないこと）
	COLOR = vec4(recolor(COLOR.rgb, false, UV.y > body_from_v), COLOR.a);
}
