// Ocean Frontier: LAST TIDE — セルルック（トゥーン）シェーダー（Godot 4 / spatial）
// 拡散光 N・L を step で 2階調（bands=2）または 3階調（bands=3）にパキッと分け、
// 固い鏡面ハイライトとリムライトを足す。輪郭線は next_pass の toon_outline.gdshader で描く。
// GL Compatibility（Android）と Forward+ の両方で動作。独自制作（CC0扱い）。
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_disabled, ambient_light_disabled;
#include "res://assets/shaders/recolor.gdshaderinc"

group_uniforms base;
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_texture = false;
uniform bool use_vertex_color = true; // 既存のメッシュ結合（頂点カラー）をそのまま使う

group_uniforms shading;
uniform int bands : hint_range(2, 3) = 2;
uniform float threshold : hint_range(-1.0, 1.0) = 0.05;    // 明暗の境界（N・L）
uniform float mid_threshold : hint_range(-1.0, 1.0) = 0.55; // 3階調時の中間の境界
uniform vec4 shade_color : source_color = vec4(0.42, 0.48, 0.66, 1.0); // 影面の色（青みの影）
uniform float mid_level : hint_range(0.0, 1.0) = 0.72;      // 3階調時の中間面の明るさ
uniform float edge_softness : hint_range(0.0, 0.1) = 0.01;  // 0 で完全に固い境界（わずかに残すとジャギー軽減）
uniform float shadow_cutoff : hint_range(0.0, 1.0) = 0.5;   // 投影された影も同じ境界で2値化
uniform vec4 ambient_color : source_color = vec4(0.10, 0.14, 0.22, 1.0); // 影面の底上げ（真っ黒にしない）

group_uniforms highlight;
uniform float specular_size : hint_range(0.0, 1.0) = 0.02;
uniform float specular_strength : hint_range(0.0, 2.0) = 0.25;
uniform vec4 rim_color : source_color = vec4(0.0, 0.95, 1.0, 1.0); // 魔力のライトブルー
uniform float rim_amount : hint_range(0.0, 1.0) = 0.22;
uniform float rim_strength : hint_range(0.0, 2.0) = 0.35;
uniform float hair_min_y = 1000.0; // この高さ（モデル座標）より上を頭部として髪色の判定を緩める

varying float v_model_y;

void vertex() {
	v_model_y = VERTEX.y;
}

float cut(float edge, float x) {
	return edge_softness <= 0.0 ? step(edge, x) : smoothstep(edge - edge_softness, edge + edge_softness, x);
}

void fragment() {
	vec3 c = albedo.rgb;
	if (use_texture) {
		c *= texture(albedo_texture, UV).rgb;
	}
	if (use_vertex_color) {
		c *= COLOR.rgb;
	}
	if (hair_recolor || skin_recolor) {
		c = rc_to_linear(recolor(rc_to_srgb(c), v_model_y > hair_min_y)); // 主人公の髪色・肌の色（生成モデルのみ。判定は sRGB）
	}
	ALBEDO = c;
	// 環境光の代わりに一定の底上げ（ambient_light_disabled と組み合わせて階調を崩さない）
	EMISSION = c * ambient_color.rgb;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float shadow = cut(shadow_cutoff, ATTENUATION);
	// 2階調: 明るい面 / 影の面
	float lit = cut(threshold, ndl) * shadow;
	vec3 level = mix(shade_color.rgb, vec3(1.0), lit);
	// 3階調: 明るい面 / 中間面 / 影の面
	if (bands >= 3) {
		float hi = cut(mid_threshold, ndl) * shadow;
		level = mix(shade_color.rgb, vec3(mid_level), lit);
		level = mix(level, vec3(1.0), hi);
	}
	vec3 light_col = LIGHT_COLOR / PI;
	DIFFUSE_LIGHT += light_col * level;

	// 固い鏡面ハイライト（明るい面のみ）
	vec3 h = normalize(LIGHT + VIEW);
	float spec = cut(1.0 - specular_size, dot(NORMAL, h)) * lit;
	SPECULAR_LIGHT += light_col * spec * specular_strength;

	// リムライト（輪郭寄りの明るい面に細い縁取り光）
	float rim = 1.0 - clamp(dot(VIEW, NORMAL), 0.0, 1.0);
	float rim_mask = cut(1.0 - rim_amount, rim * pow(max(ndl, 0.0), 0.1));
	SPECULAR_LIGHT += rim_color.rgb * rim_mask * rim_strength * length(light_col) * 0.577;
}
