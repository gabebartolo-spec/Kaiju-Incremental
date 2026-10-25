extends RefCounted
## Markdown and JSON for the city audits' full runs (tools/audit/run_city_audit.gd). Each
## builder returns {data (JSON-able), markdown, summary (one line)}.

const RULES: Array[String] = [
	"stub", "arms", "close", "zero", "split", "angle", "aspect", "water", "kerb"
]


## The roads table: one row per stage and seed, rule counts, then the merged histograms.
static func roads(rows: Array[Dictionary]) -> Dictionary:
	var lines: Array[String] = []
	lines.append("| stage | map seed | result | " + " | ".join(RULES) + " | picture |")
	lines.append("|---".repeat(RULES.size() + 4) + "|")
	var failed := 0
	var totals := {}
	var hists := {}
	for row: Dictionary in rows:
		var rules: Dictionary = row["rules"]
		var cells: Array[String] = []
		for rule: String in RULES:
			var n := Num.i(rules.get(rule, 0))
			cells.append(str(n) if n > 0 else "")
			totals[rule] = Num.i(totals.get(rule, 0)) + n
		var ok := rules.is_empty()
		failed += 0 if ok else 1
		var png := str(row.get("png", "")).get_file()
		lines.append(
			(
				"| %d | %d | %s | %s | %s |"
				% [row["tier"], row["seed"], "pass" if ok else "FAIL", " | ".join(cells), png]
			)
		)
		var metrics: Dictionary = row["metrics"]
		_merge_hists(hists, Num.i(row["tier"]), metrics)
	lines.append("")
	lines.append("Totals by rule: %s" % JSON.stringify(totals))
	for key: String in hists:
		lines.append("")
		var hist: Dictionary = hists[key]
		lines.append("%s: %s" % [key, _hist_line(hist)])
	var summary := "roads: %d of %d cities fail; %s" % [failed, rows.size(), JSON.stringify(totals)]
	return {
		"data": {"rows": _plain(rows), "totals": totals, "hists": _plain(hists)},
		"markdown": "\n".join(lines) + "\n",
		"summary": summary,
	}


## Sums every *_hist metric per stage ("stage N <metric>"), plus the mean streets per node.
static func _merge_hists(hists: Dictionary, tier: int, metrics: Dictionary) -> void:
	for key: String in metrics:
		if not key.ends_with("_hist"):
			continue
		var name := "stage %d %s" % [tier, key]
		if not hists.has(name):
			hists[name] = {}
		var into: Dictionary = hists[name]
		var src: Dictionary = metrics[key]
		for bin: Variant in src:
			into[bin] = Num.i(into.get(bin, 0)) + Num.i(src[bin])
	var spn := "stage %d streets_per_node" % tier
	if not hists.has(spn):
		hists[spn] = {}
	var bucket := snappedf(Num.f(metrics["streets_per_node"]), 0.1)
	var per: Dictionary = hists[spn]
	per[bucket] = Num.i(per.get(bucket, 0)) + 1


static func _hist_line(hist: Dictionary) -> String:
	var keys := hist.keys()
	keys.sort()
	var parts: Array[String] = []
	for k: Variant in keys:
		parts.append("%s:%d" % [str(k), Num.i(hist[k])])
	return " ".join(parts)


## A copy JSON can hold: Vector2 as [x, z], dictionary keys as strings.
static func _plain(value: Variant) -> Variant:
	if value is Vector2:
		var v: Vector2 = value
		return [snappedf(v.x, 0.01), snappedf(v.y, 0.01)]
	if value is Dictionary:
		var out := {}
		var d: Dictionary = value
		for k: Variant in d:
			out[str(k)] = _plain(d[k])
		return out
	if value is Array:
		var out: Array = []
		for item: Variant in value:
			out.append(_plain(item))
		return out
	return value
