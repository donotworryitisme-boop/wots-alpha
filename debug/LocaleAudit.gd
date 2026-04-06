class_name LocaleAudit
extends RefCounted

## Locale coverage audit tool.
## Walks Locale._ui and reports missing translations per language.
## Usage: call LocaleAudit.run_audit() from anywhere to get a report string.
## Can also be triggered from the portal dev tools section.


static func run_audit() -> String:
	var langs: Array[String] = ["EN", "NL", "FR", "PT", "ES", "IT", "HR", "PL"]
	var total_keys: int = 0
	var missing_per_lang: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0]
	var missing_keys_per_lang: Array[Array] = [[], [], [], [], [], [], [], []]

	var ui_dict: Dictionary = _get_ui_dict()
	for key: String in ui_dict.keys():
		var arr: Array = ui_dict[key]
		total_keys += 1
		for i: int in range(mini(arr.size(), 8)):
			var val: String = str(arr[i])
			if val.strip_edges() == "":
				missing_per_lang[i] += 1
				missing_keys_per_lang[i].append(key)

	# Build report
	var report: String = "=== LOCALE COVERAGE AUDIT ===\n"
	report += "Total translatable keys: %d\n\n" % total_keys

	for i: int in range(langs.size()):
		var filled: int = total_keys - missing_per_lang[i]
		var pct: float = (float(filled) / float(total_keys)) * 100.0 if total_keys > 0 else 0.0
		var status: String = "COMPLETE" if missing_per_lang[i] == 0 else "%d MISSING" % missing_per_lang[i]
		report += "%s: %d/%d (%.0f%%) — %s\n" % [langs[i], filled, total_keys, pct, status]
		if missing_per_lang[i] > 0:
			for mk: String in missing_keys_per_lang[i]:
				report += "  - %s\n" % mk

	# SOP coverage check
	report += "\n=== SOP ARTICLE COVERAGE ===\n"
	report += "SOP articles are currently English-only.\n"
	report += "Translations needed for: NL, FR, PT, ES, IT, HR, PL\n"

	return report


static func run_audit_bbcode() -> String:
	## Returns audit results formatted with BBCode for RichTextLabel display.
	var langs: Array[String] = ["EN", "NL", "FR", "PT", "ES", "IT", "HR", "PL"]
	var total_keys: int = 0
	var missing_per_lang: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0]
	var missing_keys_per_lang: Array[Array] = [[], [], [], [], [], [], [], []]

	var ui_dict: Dictionary = _get_ui_dict()
	for key: String in ui_dict.keys():
		var arr: Array = ui_dict[key]
		total_keys += 1
		for i: int in range(mini(arr.size(), 8)):
			var val: String = str(arr[i])
			if val.strip_edges() == "":
				missing_per_lang[i] += 1
				missing_keys_per_lang[i].append(key)

	var bb: String = "[b]LOCALE COVERAGE AUDIT[/b]\n"
	bb += UITokens.BB_DIM + "Total translatable keys: %d" % total_keys + UITokens.BB_END + "\n\n"

	for i: int in range(langs.size()):
		var filled: int = total_keys - missing_per_lang[i]
		var pct: float = (float(filled) / float(total_keys)) * 100.0 if total_keys > 0 else 0.0
		var clr: String = UITokens.BB_SUCCESS if missing_per_lang[i] == 0 else (UITokens.BB_WARNING if pct >= 80.0 else UITokens.BB_ERROR)
		var status: String = "COMPLETE" if missing_per_lang[i] == 0 else "%d missing" % missing_per_lang[i]
		bb += clr + "[b]%s[/b]" % langs[i] + UITokens.BB_END + " "
		bb += "%d/%d (%.0f%%) — %s\n" % [filled, total_keys, pct, status]
		if missing_per_lang[i] > 0 and missing_per_lang[i] <= 10:
			for mk: String in missing_keys_per_lang[i]:
				bb += "  " + UITokens.BB_DIM + mk + UITokens.BB_END + "\n"

	bb += "\n" + UITokens.BB_HINT + "[b]SOP ARTICLES[/b]" + UITokens.BB_END + "\n"
	bb += UITokens.BB_WARNING + "English-only" + UITokens.BB_END + " — translations needed for NL, FR, PT, ES, IT, HR, PL\n"

	return bb


static func _get_ui_dict() -> Dictionary:
	## Access Locale._ui via the class. Since _ui is static, access directly.
	return Locale._ui
