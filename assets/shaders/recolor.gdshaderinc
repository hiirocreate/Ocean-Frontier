// 生成イラスト・生成3Dモデルの色置き換え（主人公の髪色・肌の色のカスタマイズ用）。
// 主人公の素材は「緑の髪」で生成してあり（他に緑を使わない配色）、緑の色相の画素だけを選んだ髪色に置き換える。
// 肌は明るい橙系の色相・中程度の彩度・高い明度の画素を選んだ肌色の比率で置き換える。
uniform bool hair_recolor = false;
uniform vec4 hair_target : source_color = vec4(0.18, 0.165, 0.17, 1.0);
uniform bool skin_recolor = false;
uniform vec4 skin_target : source_color = vec4(0.91, 0.725, 0.59, 1.0);
uniform vec4 skin_source : source_color = vec4(0.96, 0.82, 0.72, 1.0); // 生成時の基準の肌色

vec3 rc_rgb2hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}

vec3 recolor(vec3 c) {
	vec3 hsv = rc_rgb2hsv(c);
	if (hair_recolor) {
		// 緑（約 75°〜175°）で、くすみ過ぎていない画素
		float m = smoothstep(0.19, 0.23, hsv.x) * (1.0 - smoothstep(0.46, 0.50, hsv.x)) * smoothstep(0.10, 0.20, hsv.y);
		// 明度の比で陰影を保つ（生成画像の髪の中間の明るさを基準 0.55 とする）
		vec3 hair = clamp(hair_target.rgb * (hsv.z / 0.55), 0.0, 1.0);
		c = mix(c, hair, m);
	}
	if (skin_recolor) {
		float m = smoothstep(0.0, 0.03, hsv.x) * (1.0 - smoothstep(0.10, 0.13, hsv.x))
			* smoothstep(0.08, 0.14, hsv.y) * (1.0 - smoothstep(0.55, 0.65, hsv.y)) * smoothstep(0.45, 0.6, hsv.z);
		c = mix(c, clamp(c * skin_target.rgb / max(skin_source.rgb, vec3(0.05)), 0.0, 1.0), m);
	}
	return c;
}
