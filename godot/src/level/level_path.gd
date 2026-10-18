class_name LevelPath
## くだ（tube）ステージの道。点の列から「この位置での進む向き」「距離 d の地点」を返す。

var points: PackedVector3Array = PackedVector3Array()
var _cum: PackedFloat32Array = PackedFloat32Array()
var total := 0.0


func setup(pts: Array) -> void:
	points = PackedVector3Array()
	for p in pts:
		points.append(p)
	_cum = PackedFloat32Array()
	total = 0.0
	for i in points.size():
		if i == 0:
			_cum.append(0.0)
		else:
			total += points[i].distance_to(points[i - 1])
			_cum.append(total)


func is_valid() -> bool:
	return points.size() >= 2


func start() -> Vector3:
	return points[0] if points.size() > 0 else Vector3.ZERO


func end() -> Vector3:
	return points[points.size() - 1] if points.size() > 0 else Vector3.ZERO


## いちばん近い線分の番号と、その線分上の割合
func nearest_segment(pos: Vector3) -> Dictionary:
	var best_i := 0
	var best_t := 0.0
	var best_d := INF
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var ab := b - a
		var l2 := ab.length_squared()
		var t := 0.0
		if l2 > 0.0001:
			t = clampf((pos - a).dot(ab) / l2, 0.0, 1.0)
		var p := a + ab * t
		var d := p.distance_squared_to(pos)
		if d < best_d:
			best_d = d
			best_i = i
			best_t = t
	return {"index": best_i, "t": best_t, "dist": sqrt(best_d)}


func direction_at(pos: Vector3) -> Vector3:
	if not is_valid():
		return Vector3.FORWARD
	var seg := nearest_segment(pos)
	var i: int = seg["index"]
	var d := points[i + 1] - points[i]
	# 次の線分と少しブレンドして なめらかに
	if i + 2 < points.size():
		var d2 := points[i + 2] - points[i + 1]
		d = d.normalized().lerp(d2.normalized(), float(seg["t"])).normalized()
	d.y = 0.0
	if d.length() < 0.01:
		return Vector3.FORWARD
	return d.normalized()


func progress_at(pos: Vector3) -> float:
	if not is_valid():
		return 0.0
	var seg := nearest_segment(pos)
	var i: int = seg["index"]
	var seg_len := points[i].distance_to(points[i + 1])
	return _cum[i] + seg_len * float(seg["t"])


func sample(dist: float) -> Dictionary:
	if not is_valid():
		return {"position": Vector3.ZERO, "direction": Vector3.FORWARD, "at_end": true}
	if dist >= total:
		return {"position": end(), "direction": (end() - points[points.size() - 2]).normalized(), "at_end": true}
	var i := 0
	while i < _cum.size() - 2 and _cum[i + 1] < dist:
		i += 1
	var seg_len := _cum[i + 1] - _cum[i]
	var t := 0.0 if seg_len <= 0.0001 else (dist - _cum[i]) / seg_len
	var p := points[i].lerp(points[i + 1], t)
	var d := (points[i + 1] - points[i]).normalized()
	return {"position": p, "direction": d, "at_end": false}
