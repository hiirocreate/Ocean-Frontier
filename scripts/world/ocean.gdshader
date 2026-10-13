shader_type spatial;
// ローポリ風の海面。頂点を波で変位させ、フラットシェーディング（面法線）で多面体の質感を出す。
// 波の関数は scripts/world/ocean_waves.gd と同一（筏の上下動に使用）。
render_mode cull_back, specular_schlick_ggx;

uniform vec4 shallow_color : source_color = vec4(0.12, 0.70, 0.69, 1.0);
uniform vec4 deep_color : source_color = vec4(0.04, 0.31, 0.47, 1.0);
uniform vec4 foam_color : source_color = vec4(0.85, 0.95, 0.96, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.66, 0.85, 0.90, 1.0);
uniform float wave_height = 0.45;
uniform float time_sec = 0.0;

varying float wave_h;

float wave(vec2 p, float t) {
	return sin(p.x * 0.16 + t * 1.10) * 0.50
		+ sin(p.y * 0.21 + t * 0.85) * 0.35
		+ sin((p.x + p.y) * 0.09 + t * 0.60) * 0.60
		+ sin((p.x - p.y) * 0.31 + t * 1.70) * 0.12
		+ sin(p.x * 0.73 - p.y * 0.41 + t * 2.30) * 0.22
		+ sin(p.y * 0.87 + p.x * 0.29 + t * 2.70) * 0.18;
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = wave(wp.xz, time_sec) * wave_height;
	VERTEX.y += h;
	wave_h = h;
}

void fragment() {
	vec3 n = normalize(cross(dFdy(VERTEX), dFdx(VERTEX)));
	NORMAL = n;
	float k = clamp(wave_h / (wave_height * 1.8) * 0.5 + 0.5, 0.0, 1.0);
	vec3 col = mix(deep_color.rgb, shallow_color.rgb, k);
	col = mix(col, foam_color.rgb, smoothstep(0.88, 1.0, k) * 0.5);
	// 視線と面の角度によるフレネル（遠くほど空の色を映す）
	float fres = pow(1.0 - clamp(dot(n, normalize(VIEW)), 0.0, 1.0), 4.0);
	ALBEDO = mix(col, horizon_color.rgb * 0.8, fres * 0.45);
	ROUGHNESS = 0.35;
	SPECULAR = 0.35;
}
