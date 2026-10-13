class_name OceanWaves
extends RefCounted
## ocean.gdshader と同じ波の式。CPU側で海面の高さ・傾きを求める。


static func height(x: float, z: float, t: float, amp: float) -> float:
	return (sin(x * 0.16 + t * 1.10) * 0.50
		+ sin(z * 0.21 + t * 0.85) * 0.35
		+ sin((x + z) * 0.09 + t * 0.60) * 0.60
		+ sin((x - z) * 0.31 + t * 1.70) * 0.12
		+ sin(x * 0.73 - z * 0.41 + t * 2.30) * 0.22
		+ sin(z * 0.87 + x * 0.29 + t * 2.70) * 0.18) * amp
