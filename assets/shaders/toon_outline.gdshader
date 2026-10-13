// Ocean Frontier: LAST TIDE — 輪郭線パス（背面法線押し出し / inverted hull）
// toon_cel のマテリアルの next_pass に設定する。表面を裏返して描き（cull_front）、
// 頂点をクリップ空間で法線方向へ押し出すので、距離に関係なく画面上でほぼ一定の太さになる。
// フラットシェーディングのローポリ（面ごとに法線が分かれる）では角で線が割れるため、
// extrude_from_center=true でメッシュ中心からの方向に押し出すこともできる。独自制作（CC0扱い）。
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled;

uniform vec4 outline_color : source_color = vec4(0.102, 0.102, 0.180, 1.0); // #1A1A2E
uniform float outline_px : hint_range(0.0, 10.0) = 3.5; // 1080p 基準の線幅（ピクセル）
uniform float max_world_width = 0.04; // 近距離で線が太くなりすぎないための上限（m）
uniform bool extrude_from_center = false;
uniform vec3 center = vec3(0.0);

void vertex() {
	vec3 dir = extrude_from_center ? normalize(VERTEX - center + vec3(1e-5)) : NORMAL;
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 view_n = normalize((MODELVIEW_MATRIX * vec4(dir, 0.0)).xyz);
	vec2 screen_n = (PROJECTION_MATRIX * vec4(view_n, 0.0)).xy;
	float len_n = length(screen_n);
	if (len_n > 1e-5) {
		screen_n /= len_n;
		// ピクセル→NDC（高さ1080基準でスケールし、端末解像度に依存しない太さにする）
		float px = outline_px * VIEWPORT_SIZE.y / 1080.0;
		vec2 ndc_off = screen_n * px * 2.0 / VIEWPORT_SIZE;
		// 近距離の上限（ワールド幅に換算して制限）
		float world_per_px = clip.w * 2.0 / (VIEWPORT_SIZE.y * PROJECTION_MATRIX[1][1]);
		ndc_off *= min(1.0, max_world_width / max(px * world_per_px, 1e-5));
		clip.xy += ndc_off * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
