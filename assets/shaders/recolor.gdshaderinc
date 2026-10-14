// 生成イラスト・生成3Dモデルの色置き換え（主人公の髪色・肌の色のカスタマイズ用）。
// 主人公の素材は「緑の髪」で生成してあり（他に緑を使わない配色）、緑の色相の画素だけを選んだ髪色に置き換える。
// 肌は明るい橙系の色相・中程度の彩度・高い明度の画素を選んだ肌色の比率で置き換える。
// 色の判定・置き換えはすべて sRGB の値で行う（色の指定も sRGB のまま渡すため source_color を付けない）
uniform bool hair_recolor = false;
uniform vec4 hair_target = vec4(0.18, 0.165, 0.17, 1.0);
uniform bool skin_recolor = false;
uniform vec4 skin_target = vec4(0.91, 0.725, 0.59, 1.0);
uniform vec4 skin_source = vec4(0.96, 0.82, 0.72, 1.0); // 生成時の基準の肌色

vec3 rc_rgb2hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}

vec3 rc_to_srgb(vec3 c) {
	return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}

vec3 rc_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

// c は sRGB の色。head_region=true（3Dモデルの頭部の高さ）では、くすんだ青緑まで髪とみなす
// （画像から作った3Dモデルの頂点色は生成画像より彩度が低く、色だけでは服と区別しにくいため高さで限定する）
vec3 recolor(vec3 c, bool head_region) {
	vec3 hsv = rc_rgb2hsv(c);
	if (hair_recolor) {
		// 黄緑〜緑（約 55°〜175°。頭部では 45°〜190°）で、くすみ過ぎていない画素
		float hue_hi = head_region ? 0.53 : 0.49;
		float sat_lo = head_region ? 0.04 : 0.10;
		float hue_lo = head_region ? 0.115 : 0.14; // 頭部では黄みの強い緑も含める（肌は約 0.05〜0.10）
		float m = smoothstep(hue_lo, hue_lo + 0.04, hsv.x) * (1.0 - smoothstep(hue_hi - 0.03, hue_hi, hsv.x)) * smoothstep(sat_lo, sat_lo + 0.08, hsv.y);
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
