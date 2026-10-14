// 立ち絵（生成イラスト）用: 髪色・肌の色の置き換え。独自制作（CC0扱い）。
shader_type canvas_item;
#include "res://assets/shaders/recolor.gdshaderinc"

void fragment() {
	// COLOR には既にテクスチャの色が入っている（二重に掛けないこと）
	COLOR = vec4(recolor(COLOR.rgb, false), COLOR.a);
}
