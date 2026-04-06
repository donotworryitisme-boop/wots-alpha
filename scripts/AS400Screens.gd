class_name AS400Screens
extends RefCounted

## AS400 screen rendering, pixel art helpers, and date formatting.
## Extracted from AS400Terminal — lives as `_term._screens`.

const S = AS400Terminal.S

var _term: AS400Terminal

# Pixel-art digit patterns (5 wide x 5 tall, using * like real AS400)
const DIGIT_ART: Dictionary = {
	"0": [" *** ","*   *","*   *","*   *"," *** "],
	"1": ["  *  ","  *  ","  *  ","  *  ","  *  "],
	"2": [" *** ","    *"," *** ","*    "," *** "],
	"3": [" *** ","    *"," *** ","    *"," *** "],
	"4": ["*   *","*   *"," *** ","    *","    *"],
	"5": [" *** ","*    "," *** ","    *"," *** "],
	"6": [" *** ","*    "," *** ","*   *"," *** "],
	"7": [" *** ","    *","    *","    *","    *"],
	"8": [" *** ","*   *"," *** ","*   *"," *** "],
	"9": [" *** ","*   *"," *** ","    *"," *** "],
}


func _init(term: AS400Terminal) -> void:
	_term = term


func date_compact(ddate: String) -> String:
	if ddate == "": return UITokens.LOADING_DATE_DDMMYY
	var parts: PackedStringArray = ddate.split("/")
	if parts.size() == 3:
		return parts[0] + parts[1] + parts[2].right(2)
	return ddate


func build_deca_art(art_rows: Array, fg_color: String) -> String:
	var bg_c := "[color=#000000]"
	var fg_c := fg_color
	var E := "[/color]"
	var out := "[center][font_size=36]"
	for row: String in art_rows:
		for _dup: int in range(2):
			var i := 0
			while i < row.length():
				var ch: String = row[i]
				var run := 1
				while i + run < row.length() and row[i + run] == ch:
					run += 1
				if ch == "1":
					out += fg_c + "█".repeat(run) + E
				else:
					out += bg_c + "█".repeat(run) + E
				i += run
			out += "\n"
	out += "[/font_size][/center]"
	return out


func build_number_art(num: int, _digits: int, color: String) -> Array:
	var s := str(num)
	var rows: Array = ["", "", "", "", ""]
	for i: int in range(s.length()):
		if i > 0:
			for r: int in range(5): rows[r] += " "
		var d: String = s[i]
		var art: Array = DIGIT_ART.get(d, DIGIT_ART["0"])
		for r: int in range(5):
			rows[r] += art[r]
	var result: Array = []
	for row: String in rows:
		var line := ""
		for ch: String in row:
			if ch == "*":
				line += color + "*[/color]"
			else:
				line += " "
		result.append(line)
	return result


func render() -> void:
	if _term._display == null: return
	# Log AS400 state transitions
	if _term.state != _term._prev_logged_state:
		_term._prev_logged_state = _term.state
		if _term._ui._session != null:
			_term._ui._session.log_action("as400_state", str(_term.state))
	# --- DECATHLON pixel art ---
	var _deca_art := [
		"11100111100111001100111101001010000011001001",
		"10010100001000010010011001001010000100101101",
		"10010111001000011110011001111010000100101011",
		"10010100001000010010011001001010000100101001",
		"11100111100111010010011001001011110011001001",
	]
	var t: String = "[font_size=24]"
	var d: String = "19/03/26"
	var H: String = "[color=#00ff00]"
	var C: String = "[color=#00ffff]"
	var Y: String = "[color=#ffff00]"
	var W: String = "[color=#ffffff]"
	var R: String = "[color=#ff0000]"
	var P: String = "[color=#ff88aa]"
	var B: String = "[color=#8888ff]"
	var E: String = "[/color]"

	# State 0: Sign On — DECATHLON
	if _term.state == S.SIGN_ON:
		t += "[center]%sSign On%s[/center]\n\n" % [W, E]
		t += "[center]%sSystem . . . . . :   NLDKL01%s[/center]\n" % [H, E]
		t += "[center]%sSub-system . . . :   QINTER%s[/center]\n" % [H, E]
		t += "[center]%sScreen . . . . . :   TILBN1117%s[/center]\n\n" % [H, E]
		t += "[center]%sUser  . . . . . . . . . . . .%s   %s_________%s[/center]\n" % [P, E, Y, E]
		t += "[center]%sPassword  . . . . . . . . . .%s[/center]\n\n" % [P, E]
		t += "[/font_size]" + build_deca_art(_deca_art, B) + "[font_size=24]\n"
		t += "[center]%s(C) COPYRIGHT IBM CORP. 1980, 2018.%s[/center]\n" % [W, E]
		_term._input_field.placeholder_text = "Type 'BAYB2B' and press Enter"

	# State 1: Sign On password
	elif _term.state == S.PASSWORD:
		t += "[center]%sSign On%s[/center]\n\n" % [W, E]
		t += "[center]%sSystem . . . . . :   NLDKL01%s[/center]\n" % [H, E]
		t += "[center]%sSub-system . . . :   QINTER%s[/center]\n" % [H, E]
		t += "[center]%sScreen . . . . . :   TILBN1117%s[/center]\n\n" % [H, E]
		t += "[center]%sUser  . . . . . . . . . . . .%s   %sBAYB2B%s[/center]\n" % [P, E, H, E]
		t += "[center]%sPassword  . . . . . . . . . .%s   %s______%s[/center]\n\n" % [P, E, Y, E]
		t += "[/font_size]" + build_deca_art(_deca_art, B) + "[font_size=24]\n"
		t += "[center]%s(C) COPYRIGHT IBM CORP. 1980, 2018.%s[/center]\n" % [W, E]
		_term._input_field.placeholder_text = "Type '123456' and press Enter"

	# State 2: Simplified Menu (PSIP0120)
	elif _term.state == S.MENU_MAIN:
		t += "%s%s%s   %s***%s       %s[u]Simplified Men[/u]%s        %s***%s %sDKOSUT01%s    %sNLDKL01%s\n" % [H, d, E, H, E, C, E, H, E, H, E, H, E]
		t += "%s19:16:23%s                    %sPSIP0120%s           %sENTER%s   %sSOHKPVR%s\n" % [H, E, Y, E, H, E, H, E]
		t += "%s─────────────────────────────────────────────────────────────────────────────%s\n" % [H, E]
		t += "                      %sProfession Opt%s\n" % [C, E]
		t += "                                                %s10  Change%s\n" % [H, E]
		t += "                                                    %sPassword%s\n" % [H, E]
		t += "  %s 1%s  %s-%s\n" % [Y, E, H, E]
		t += "  %s 2%s  %s-%s                                         %s20  GE Menu%s\n" % [Y, E, H, E, H, E]
		t += "  %s 3%s  %s-%s\n" % [Y, E, H, E]
		t += "  %s 4%s  %s-%s                                         %s30  PARCELx%s\n" % [Y, E, H, E, H, E]
		t += "%s─────────────────────────────────────────────────────────────────────────────%s\n" % [H, E]
		t += "                  %sOwn Options%s                   %s40  Recep Dock%s  %s390%s\n\n" % [C, E, H, E, Y, E]
		t += "  %s11%s  %s-%s                                         %s50  Ship Dock%s   %s390%s\n" % [Y, E, H, E, H, E, Y, E]
		t += "  %s12%s  %s-%s\n" % [Y, E, H, E]
		t += "  %s13%s  %s-%s                                         %s80  Modification%s\n" % [Y, E, H, E, H, E]
		t += "  %s14%s  %s-%s                                             %sOwn Options%s\n" % [Y, E, H, E, H, E]
		t += "  %s15%s  %s-%s\n" % [Y, E, H, E]
		t += "                                                %s90  End of cession%s\n\n" % [H, E]
		t += "                %sYour Choice%s %s__%s\n" % [H, E, Y, E]
		t += "\n%s─────────────────────────────────────────────────────────────────────────────%s\n" % [C, E]
		t += "%sF3=Exit  F10=Reinit Docks%s\n" % [C, E]
		_term._input_field.placeholder_text = "Type '50' for Ship Dock"

	# State 3: MENU DES APPLICATIONS (after typing 50 — Ship Dock)
	elif _term.state == S.MENU_SHIP_DOCK:
		t += "%s19:29:15%s              %s[u]MENU DES APPLICATIONS[/u]%s             %s%s NLDKL01%s\n" % [H, E, C, E, H, d, E]
		t += "                                                          %sGDMRVIS1%s\n\n" % [H, E]
		t += "%s─────────────────────────────────────────────────────────────────────────────%s\n\n" % [H, E]
		t += "      %s1%s  %s-   EXPEDITION COLIS INTERNATIONAL%s\n" % [Y, E, H, E]
		t += "      %s2%s  %s-   RECEPTION COLIS INTERNATIONAL%s\n" % [Y, E, H, E]
		t += "\n\n\n\n\n\n\n\n\n\n"
		t += "              %sVotre choix ==>%s  %s__%s\n" % [H, E, Y, E]
		t += "\n%s─────────────────────────────────────────────────────────────────────────────%s\n" % [C, E]
		t += "%sF3  Fin de travail   F4  Give my feedback about AS400%s\n" % [C, E]
		_term._input_field.placeholder_text = "Type '01' for Expedition"

	# State 4: SEND AN INTERNATIONAL PARCEL / MENU01 (after typing 01)
	elif _term.state == S.MENU_PARCEL:
		t += "%s19:29:26%s          %s[u]SEND AN INTERNATIONAL PARCEL[/u]%s       %s%s NLDKL01%s\n" % [H, E, C, E, H, d, E]
		t += "  %s1%s                                                     %sMENU01%s\n\n" % [Y, E, H, E]
		t += "%s─────────────────────────────────────────────────────────────────────────────%s\n\n" % [H, E]
		t += "      %s1%s  %s-   Param{trage%s\n\n" % [Y, E, H, E]
		t += "      %s2%s  %s-%s   %s[u]: menu : Operation[/u]%s\n\n" % [Y, E, H, E, C, E]
		t += "      %s3%s  %s-   Menu : Export%s\n\n" % [Y, E, H, E]
		t += "      %s4%s  %s-   : menu : Utilities%s\n\n" % [Y, E, H, E]
		t += "      %s5%s  %s-   Piloting Parcel%s\n\n" % [Y, E, H, E]
		t += "      %s6%s  %s-   Enter a Transit Flow 4%s\n\n\n" % [Y, E, H, E]
		t += "              %sVotre choix :%s  %s__%s\n" % [H, E, Y, E]
		t += "\n%s─────────────────────────────────────────────────────────────────────────────%s\n" % [C, E]
		t += "                                           %s(C)  INFO3D    1989,1990%s\n" % [H, E]
		t += "  %sF1=Aide       F3=Exit                          F12=Précédent%s\n" % [C, E]
		_term._input_field.placeholder_text = "Type '02' for Operation menu"

	# State 5: MENU : OPERATION / MENU03 (after typing 02)
	elif _term.state == S.MENU_OPERATION:
		t += "%s19:29:36%s              %s[u]: MENU : OPERATION[/u]%s              %s%s NLDKL01%s\n" % [H, E, C, E, H, d, E]
		t += "  %s2%s                                                     %sMENU03%s\n\n" % [Y, E, H, E]
		t += "%s─────────────────────────────────────────────────────────────────────────────%s\n\n" % [H, E]
		t += "      %s1%s   %s-   Delete UAT%s\n" % [Y, E, H, E]
		t += "      %s2%s   %s-   Create UAT (regroup parcels)%s\n" % [Y, E, H, E]
		t += "      %s3%s   %s-   CFP : Control UAT%s\n" % [Y, E, H, E]
		t += "      %s4%s   %s-   : Menu : Addressing UAT%s\n" % [Y, E, H, E]
		t += "      %s5%s   %s-   Create shipment%s\n" % [Y, E, H, E]
		t += "      %s6%s   %s-   Manage shipping%s\n\n" % [Y, E, H, E]
		t += "      %s7%s   %s-   Visualize left on loading bay%s\n" % [Y, E, H, E]
		t += "      %s8%s   %s-   Visualize RAQ Worldwide Warehouse%s\n" % [Y, E, H, E]
		t += "      %s9%s   %s-   Visualize a parcel%s\n\n" % [Y, E, H, E]
		t += "      %s10%s  %s-   Menu : dangerous substances%s\n" % [Y, E, H, E]
		t += "      %s11%s  %s-   Transport schedule%s\n\n" % [Y, E, H, E]
		t += "              %sVotre choix :%s  %s__%s\n" % [H, E, Y, E]
		t += "\n%s─────────────────────────────────────────────────────────────────────────────%s\n" % [C, E]
		t += "  %sF1=Aide       F3=Exit                          F12=Précédent F16=Premier menu%s\n" % [C, E]
		_term._input_field.placeholder_text = "Type '05' for Create shipment, or '06' for Manage shipping"

	# State 6: Badge login popup
	elif _term.state == S.BADGE_LOGIN:
		t += "%s%s%s   %s***%s    %s[u]EXPEDITION EN COURS[/u]%s    %s***%s  %sQUAI390%s    %sNLDKL01%s\n" % [H, d, E, H, E, C, E, H, E, H, E, H, E]
		t += "%s19:29:57%s                                    %sAFFICH.%s  %sPIEHDFR%s\n\n" % [H, E, Y, E, H, E]
		t += "%sExpéditeur :   14    390 CAR%s\n" % [H, E]
		t += "         ┌─────────────────────────────────────────┐\n"
		t += "         │ %sCode opé/badge:%s  %s_______%s               │\n" % [H, E, Y, E]
		t += "         │ %sNom            :%s                         │\n" % [H, E]
		t += "         │ %sPrénom         :%s                         │\n" % [H, E]
		t += "         │                                         │\n"
		t += "         │ %sF3:Retour   F6:Chgt Mot Passe%s          │\n" % [H, E]
		t += "         └─────────────────────────────────────────┘\n"
		var exp_dest: String = _term._ui.current_dest_name
		if _term._ui.current_dest2_name != "":
			exp_dest = _term._ui.current_dest_name + "/" + _term._ui.current_dest2_name
		var s7_exp: String = "06948174"
		if _term._ui._session != null and _term._ui._session.expedition_number_1 != "":
			s7_exp = _term._ui._session.expedition_number_1
		t += "%s__  %s XXXXXXXX    7 %5s %-18s   EN COURS%s\n" % [H, s7_exp, _term._ui.current_dest_code, exp_dest, E]
		t += "%s__  06938346 XXXXXXXX    7  2680 CIRCULAR CENTER TILB EN COURS%s\n" % [H, E]
		t += "%s__  06929233 00873747    7  1570 ALKMAAR              EN COURS%s\n" % [H, E]
		t += "%s__  06845806 XXXXXXXX    7  2680 CIRCULAR CENTER TILB EN COURS%s\n" % [H, E]
		t += "\n\n                                                                      %s+%s\n" % [H, E]
		t += "\n%s─────────────────────────────────────────────────────────────────────────────%s\n" % [C, E]
		t += "%sF3=Sortie    F6=Créer%s                                                %sAIDE%s\n" % [C, E, C, E]
		_term._input_field.placeholder_text = "Type '8600555' (your badge code)"

	# State 7: Badge password
	elif _term.state == S.BADGE_PASSWORD:
		t += "%s%s%s   %s***%s    %s[u]EXPEDITION EN COURS[/u]%s    %s***%s  %sQUAI390%s    %sNLDKL01%s\n" % [H, d, E, H, E, C, E, H, E, H, E, H, E]
		t += "%s19:29:57%s                                    %sAFFICH.%s  %sPIEHDFR%s\n\n" % [H, E, Y, E, H, E]
		t += "%sExpéditeur :   14    390 CAR%s\n" % [H, E]
		t += "         ┌─────────────────────────────────────────┐\n"
		t += "         │ %sCode opé/badge:%s  %s8600555%s               │\n" % [H, E, H, E]
		t += "         │ %sMot de passe  :%s  %s______%s                │\n" % [H, E, Y, E]
		t += "         │                                         │\n"
		t += "         │ %sF3:Retour   F6:Chgt Mot Passe%s          │\n" % [H, E]
		t += "         └─────────────────────────────────────────┘\n"
		var exp_dest7: String = _term._ui.current_dest_name
		if _term._ui.current_dest2_name != "":
			exp_dest7 = _term._ui.current_dest_name + "/" + _term._ui.current_dest2_name
		var s7b_exp: String = "06948174"
		if _term._ui._session != null and _term._ui._session.expedition_number_1 != "":
			s7b_exp = _term._ui._session.expedition_number_1
		t += "%s__  %s XXXXXXXX    7 %5s %-18s   EN COURS%s\n" % [H, s7b_exp, _term._ui.current_dest_code, exp_dest7, E]
		t += "%s__  06938346 XXXXXXXX    7  2680 CIRCULAR CENTER TILB EN COURS%s\n" % [H, E]
		t += "%s__  06929233 00873747    7  1570 ALKMAAR              EN COURS%s\n" % [H, E]
		t += "%s__  06845806 XXXXXXXX    7  2680 CIRCULAR CENTER TILB EN COURS%s\n" % [H, E]
		t += "\n\n                                                                      %s+%s\n" % [H, E]
		t += "\n%s─────────────────────────────────────────────────────────────────────────────%s\n" % [C, E]
		t += "%sF3=Sortie    F6=Créer%s                                                %sAIDE%s\n" % [C, E, C, E]
		_term._input_field.placeholder_text = "Type '123456' (your password)"

	# State 8: RAQ screen (DSPF COLIS RAQ/RAC)
	elif _term.state == S.RAQ:
		_term._input_field.placeholder_text = "N° Colis ou UAT — F10 to confirm, F3=Back to Scanning"
		t += "%s%s%s   %s***%s    %s[u]DSPF COLIS RAQ/RAC[/u]%s     %s***%s  %sQUAI390%s    %sNLDKL01%s\n" % [H, d, E, H, E, C, E, H, E, H, E, H, E]
		t += "%s19:32:25%s                                    %sAFFICH.%s  %sPJJIDFR%s\n\n" % [H, E, Y, E, H, E]
		var raq_seq_filter: int = _term._get_tab_dest_seq(_term._active_tab)
		var all_raq_pallets: Array = []
		for p: Dictionary in _term.last_avail_cache:
			if raq_seq_filter > 0 and p.get("dest", 1) != raq_seq_filter: continue
			if p.is_uat: all_raq_pallets.append(p)
		for p: Dictionary in _term.last_loaded_cache:
			if raq_seq_filter > 0 and p.get("dest", 1) != raq_seq_filter: continue
			all_raq_pallets.append(p)
		var total_colis: int = 0
		for p: Dictionary in all_raq_pallets:
			total_colis += p.collis
		t += "%sExp{diteur   :   14    390   CAR TILBURG EXPE%s       %sTotal colis :   %d%s\n" % [H, E, H, total_colis, E]
		if _term._ui.current_dest2_name != "":
			var raq_tab_code: String = _term._tabs[_term._active_tab].get("dest_code", "") if not _term._tabs.is_empty() else ""
			var raq_tab_name: String = _term._tabs[_term._active_tab].get("dest_name", "") if not _term._tabs.is_empty() else ""
			if raq_tab_code != "":
				var raq_seq: int = _term._get_tab_dest_seq(_term._active_tab)
				t += "%sDestinataire :    7  %5s   %s  %s(Seq.%d — CO LOADING)%s\n\n" % [H, raq_tab_code, raq_tab_name, Y, raq_seq, E]
			else:
				t += "%sDestinataire :    7  %s[NON DEFINI]%s  %s(CO LOADING)%s\n\n" % [H, R, E, Y, E]
		else:
			t += "%sDestinataire :    7  %5s   %s%s\n\n" % [H, _term._ui.current_dest_code, _term._ui.current_dest_name, E]
		t += "%s5=D{tail Colis/UAT   7=Validation UAT transit vocal%s\n\n" % [C, E]
		t += "%s? N{ U.A.T                  Flx Uni NBC SE EM Colis                  Dt Col  CCC/%s\n" % [H, E]
		t += "%s                              CFP     CD                       Dt Exp Adresse%s\n" % [H, E]
		var se_map: Dictionary = {"Mecha": "86", "Bulky": "90", "Bikes": "89", "ServiceCenter": "86", "C&C": "86", "ADR": "86"}
		var uni_map: Dictionary = {"Mecha": "62*", "Bulky": "10 ", "Bikes": "63*", "ServiceCenter": "02*", "C&C": "61*", "ADR": "62*"}
		var em_map: Dictionary = {"Mecha": "11", "Bulky": "11", "Bikes": "11", "ServiceCenter": "11", "C&C": "11", "ADR": "11"}
		var has_unscanned: bool = false
		for p: Dictionary in all_raq_pallets:
			if p.get("scan_time", "") == "":
				has_unscanned = true
				break
		var transit_pending: bool = (_term._ui._session != null and not _term._ui._session.transit_collected and (_term._ui._session.transit_loose_entries.size() > 0 or _term._ui._session.transit_items.size() > 0))
		var adr_in_locker: bool = (_term._ui._session != null and _term._ui._session.has_adr and _term._ui._session.adr_items.size() > 0)
		var all_cleared: bool = (not has_unscanned and not transit_pending and not adr_in_locker)
		if all_cleared:
			t += "\n%s  [SHIPMENT COMPLETE — ALL ITEMS SCANNED]%s\n\n" % [Y, E]
		else:
			var scanned_regular: Array = []
			var scanned_cc: Array = []
			var unscanned_regular: Array = []
			var unscanned_cc: Array = []
			for p: Dictionary in all_raq_pallets:
				if p.type == "ADR": continue
				var stime: String = p.get("scan_time", "")
				if stime != "":
					if p.type == "C&C": scanned_cc.append(p)
					else: scanned_regular.append(p)
				else:
					if p.type == "C&C": unscanned_cc.append(p)
					else: unscanned_regular.append(p)
			for p: Dictionary in scanned_regular:
				var stime: String = p.get("scan_time", "")
				var se: String = se_map.get(p.type, "86")
				var uni: String = uni_map.get(p.type, "02*")
				var em: String = em_map.get(p.type, "11")
				var date_col: String = date_compact(p.get("delivery_date", ""))
				t += "%s  %-20s  MAG %s   0 %s %s %-20s %s %s%s\n" % [H, p.id, uni, se, em, p.get("colis_id", "N/A"), date_col, stime, E]
			for p: Dictionary in scanned_cc:
				var stime: String = p.get("scan_time", "")
				t += "%s  %-20s  MAP 10    0 86 11 %-20s %s %s%s\n" % [H, p.id, p.get("colis_id", "N/A"), UITokens.LOADING_DATE_DDMMYY, stime, E]
			for p: Dictionary in unscanned_regular:
				var se: String = se_map.get(p.type, "86")
				var uni: String = uni_map.get(p.type, "02*")
				var em: String = em_map.get(p.type, "11")
				var date_col: String = date_compact(p.get("delivery_date", ""))
				t += "%s  %-20s  MAG %s   0 %s %s %-20s %s%s\n" % [C, p.id, uni, se, em, p.get("colis_id", "N/A"), date_col, E]
			for p: Dictionary in unscanned_cc:
				t += "%s  %-20s  MAP 10    0 86 11 %-20s %s%s\n" % [W, p.id, p.get("colis_id", "N/A"), UITokens.LOADING_DATE_DDMMYY, E]
			if _term._ui._session != null and not _term._ui._session.transit_collected:
				for entry: Dictionary in _term._ui._session.transit_loose_entries:
					var e_dest: int = entry.get("dest", 1)
					if raq_seq_filter > 0 and e_dest != raq_seq_filter: continue
					t += "%s  %-20s  MAG ---   -- -- -- %-20s%s\n" % [C, "", entry.get("colis_id", "N/A"), E]
			if _term._ui._session != null and not _term._ui._session.transit_collected:
				for p_tr: Dictionary in _term._ui._session.transit_items:
					var p_tr_dest: int = p_tr.get("dest", 1)
					if _term._ui.current_dest2_name != "":
						var tr_seq: int = _term._get_tab_dest_seq(_term._active_tab)
						if tr_seq > 0 and p_tr_dest != tr_seq:
							continue
					t += "%s  %-20s  MAP ---   0 86 -- %-20s%s\n" % [C, p_tr.id, p_tr.get("colis_id", ""), E]
			if _term._ui._session != null and _term._ui._session.has_adr:
				for p_adr: Dictionary in _term._ui._session.adr_items:
					var p_adr_dest: int = p_adr.get("dest", 1)
					if _term._ui.current_dest2_name != "":
						var adr_seq: int = _term._get_tab_dest_seq(_term._active_tab)
						if adr_seq > 0 and p_adr_dest != adr_seq:
							continue
					t += "%s  %-20s  MAP ADR  %2d 86 11 %-20s %s LOCKER%s\n" % [R, p_adr.id, p_adr.collis, p_adr.get("colis_id", ""), UITokens.LOADING_DATE_DDMMYY, E]
				for p_adr: Dictionary in _term._ui._session.inventory_available:
					if p_adr.get("type", "") == "ADR":
						var p_adr_dest: int = p_adr.get("dest", 1)
						if _term._ui.current_dest2_name != "":
							var adr_seq: int = _term._get_tab_dest_seq(_term._active_tab)
							if adr_seq > 0 and p_adr_dest != adr_seq:
								continue
						t += "%s  %-20s  MAP ADR  %2d 86 11 %-20s %s%s\n" % [R, p_adr.id, p_adr.collis, p_adr.get("colis_id", ""), UITokens.LOADING_DATE_DDMMYY, E]
				for p_adr: Dictionary in _term.last_loaded_cache:
					if p_adr.get("type", "") == "ADR":
						var p_adr_dest: int = p_adr.get("dest", 1)
						if raq_seq_filter > 0 and p_adr_dest != raq_seq_filter: continue
						var adr_stime: String = p_adr.get("scan_time", "")
						t += "%s  %-20s  MAP ADR  %2d 86 11 %-20s %s %s%s\n" % [H, p_adr.id, p_adr.collis, p_adr.get("colis_id", ""), UITokens.LOADING_DATE_DDMMYY, adr_stime, E]
		t += "\n%s─────────────────────────────────────────────────────────────────────────────%s\n" % [C, E]
		t += "%sF3=Sortie  F5=Ttes UAT  F7=UAT non Adress{es  F8=UAT Adress{es  F9=CCC/ADR%s\n" % [C, E]
		t += "%sF10=NBC/CFP   F11=EM/CD   F15=Tri F&R%s\n" % [C, E]

	# State 9: Validation
	elif _term.state == S.VALIDATION:
		_term._input_field.placeholder_text = "F3=Sortie"
		t += "%s%s%s   %s***%s    %s[u]DSPF COLIS RAQ/RAC[/u]%s     %s***%s  %sQUAI390%s    %sNLDKL01%s\n" % [H, d, E, H, E, C, E, H, E, H, E, H, E]
		t += "%s09:01:00%s                                    %sAFFICH.%s  %sPJJIDFR%s\n\n" % [H, E, Y, E, H, E]
		t += "%sExpéditeur   :   14    390   CAR TILBURG EXPE%s\n" % [H, E]
		if _term._ui.current_dest2_name != "":
			var s9_tab_code: String = _term._tabs[_term._active_tab].get("dest_code", "") if not _term._tabs.is_empty() else ""
			var s9_tab_name: String = _term._tabs[_term._active_tab].get("dest_name", "") if not _term._tabs.is_empty() else ""
			if s9_tab_code != "":
				var s9_seq: int = _term._get_tab_dest_seq(_term._active_tab)
				t += "%sDestinataire :    7  %5s   %s  %s(Seq.%d — CO LOADING)%s\n\n" % [H, s9_tab_code, s9_tab_name, Y, s9_seq, E]
			else:
				t += "%sDestinataire :    7  %s[NON DEFINI]%s  %s(CO LOADING)%s\n\n" % [H, R, E, Y, E]
		else:
			t += "%sDestinataire :    7  %5s   %s%s\n\n" % [H, _term._ui.current_dest_code, _term._ui.current_dest_name, E]
		t += "%s╔══════════════════════════════════════════════════════════════╗%s\n" % [Y, E]
		t += "%s║                                                  ║%s\n" % [Y, E]
		t += "%s║     VALIDATION EFFECTUEE                         ║%s\n" % [Y, E]
		t += "%s║     (RAQ CONFIRMED)                              ║%s\n" % [Y, E]
		t += "%s║                                                  ║%s\n" % [Y, E]
		t += "%s╚══════════════════════════════════════════════════════════════╝%s\n\n" % [Y, E]
		var s9_exp: String = ""
		if _term._ui._session != null:
			s9_exp = _term._ui._session.expedition_number_1
		var s9_weight: float = 0.0
		var s9_dm3: int = 0
		if _term._ui._session != null:
			for s9_p: Dictionary in _term._ui._session.inventory_loaded:
				s9_weight += s9_p.get("weight_kg", 0.0)
				s9_dm3 += s9_p.get("dm3", 0)
		t += "%sN° Expédition   :%s  %s%s%s\n" % [H, E, Y, s9_exp, E]
		t += "%sPoids brut (kg) :%s  %s%.0f%s\n" % [H, E, Y, s9_weight, E]
		t += "%sVolume (dm³)    :%s  %s%d%s\n\n" % [H, E, Y, s9_dm3, E]
		t += "%s→ Transfer expedition, weight + dm³ to your CMR.%s\n" % [C, E]
		t += "\n%s─────────────────────────────────────────────────────────────────────────────%s\n" % [C, E]
		t += "%sF3=Sortie%s\n" % [C, E]

	# === EASTER EGG: Recep Dock (state 15) ===
	elif _term.state == S.RECEP_DOCK:
		_term._input_field.placeholder_text = "F3=Retour"
		t += "%s%s%s   %s***%s      %s[u]RECEP DOCK 390[/u]%s        %s***%s  %sQUAI390%s    %sNLDKL01%s\n" % [H, d, E, H, E, C, E, H, E, H, E, H, E]
		t += "%s09:00:18%s                                    %sAFFICH.%s  %sPIRCDFR%s\n\n" % [H, E, Y, E, H, E]
		t += "%s  Réception — Gestion des arrivages%s\n\n" % [H, E]
		t += "%s  Aucune réception en cours.%s\n\n" % [H, E]
		t += "%s  (Ce module n'est pas actif dans cette version de la simulation.)%s\n" % [Y, E]
		t += "\n\n\n\n\n\n"
		t += "\n%s─────────────────────────────────────────────────────────────────────────────%s\n" % [C, E]
		t += "%sF3=Retour  F12=Annuler%s\n" % [C, E]

	# === EASTER EGG: Impression (state 16) ===
	elif _term.state == S.IMPRESSION:
		_term._input_field.placeholder_text = "F3=Retour"
		t += "%s%s%s   %s***%s      %s[u]IMPRESSION[/u]%s            %s***%s  %sQUAI390%s    %sNLDKL01%s\n" % [H, d, E, H, E, C, E, H, E, H, E, H, E]
		t += "%s09:00:18%s                                    %sAFFICH.%s  %sPIEMIFR%s\n\n" % [H, E, Y, E, H, E]
		t += "%s  01 - Imprimer CMR%s\n" % [H, E]
		t += "%s  02 - Imprimer Bordereau%s\n" % [H, E]
		t += "%s  03 - Imprimer Etiquettes%s\n\n" % [H, E]
		t += "%s  (Les impressions ne sont pas actives dans cette version.)%s\n" % [Y, E]
		t += "\n\n\n\n\n\n"
		t += "\n%s─────────────────────────────────────────────────────────────────────────────%s\n" % [C, E]
		t += "%sF3=Retour  F12=Annuler%s\n" % [C, E]

	# === EASTER EGG: RAQ Par Magasin (state 17) ===
	elif _term.state == S.RAQ_PAR_MAGASIN:
		_term._input_field.placeholder_text = "F3=Retour"
		t += "%s%s%s   %s***%s      %s[u]RAQ PAR MAGASIN[/u]%s       %s***%s  %sQUAI390%s    %sNLDKL01%s\n" % [H, d, E, H, E, C, E, H, E, H, E, H, E]
		t += "%s09:00:30%s                                    %sAFFICH.%s  %sPIEHMFR%s\n\n" % [H, E, Y, E, H, E]
		t += "%s  Entrez le code magasin :%s %s_____%s\n\n" % [H, E, Y, E]
		t += "%s  (La consultation par magasin n'est pas active dans cette version.)%s\n" % [Y, E]
		t += "\n\n\n\n\n\n\n\n"
		t += "\n%s─────────────────────────────────────────────────────────────────────────────%s\n" % [C, E]
		t += "%sF3=Retour  F12=Annuler%s\n" % [C, E]

	# === SCANNING SCREEN (state 18) ===
	elif _term.state == S.SCANNING:
		_term._input_field.placeholder_text = "N° Colis ou UAT — Shift+F1 or F13=RAQ"
		t += "%s%s%s   %s***%s      %s[u]SCANNING QUAI[/u]%s          %s***%s  %sQUAI390%s    %sNLDKL01%s\n" % [H, d, E, H, E, C, E, H, E, H, E, H, E]
		t += "%s19:32:02%s                                    %sENTRER%s   %sPII1PVR%s\n\n" % [H, E, H, E, H, E]
		if _term._ui.current_dest2_name != "" and not _term._tabs.is_empty():
			var tab_code: String = _term._tabs[_term._active_tab].get("dest_code", "")
			var tab_name: String = _term._tabs[_term._active_tab].get("dest_name", "")
			if tab_code != "":
				var tab_seq: int = _term._get_tab_dest_seq(_term._active_tab)
				var seq_color: String = Y if tab_seq == 1 else "[color=#e67e22]"
				t += "  %sDESTINATAIRE ACTIF:%s %s%s %s (Seq.%d)%s\n\n" % [H, E, seq_color, tab_name, tab_code, tab_seq, E]
			else:
				t += "  %sDESTINATAIRE ACTIF:%s %s[NON DEFINI — Allez sur SAISIE d'abord]%s\n\n" % [H, E, R, E]
		var colis_remaining: int = 0
		var uat_remaining: int = 0
		var colis_loaded: int = 0
		var uat_loaded: int = 0
		var scan_seq_filter: int = _term._get_tab_dest_seq(_term._active_tab)
		for p: Dictionary in _term.last_avail_cache:
			if scan_seq_filter > 0 and p.get("dest", 1) != scan_seq_filter: continue
			if p.is_uat:
				uat_remaining += 1
				colis_remaining += p.collis
		for p: Dictionary in _term.last_loaded_cache:
			if scan_seq_filter > 0 and p.get("dest", 1) != scan_seq_filter: continue
			if p.is_uat:
				uat_loaded += 1
				colis_loaded += p.collis
		var G := "[color=#00ff00]"
		t += "  %sCOLIS EN RESTE A CHARGER%s    %sUAT VOCAL%s    %sUAT EN RESTE A CHARGER%s\n" % [H, E, H, E, H, E]
		t += "[/font_size][font_size=28]"
		var cr_art: Array = build_number_art(colis_remaining, 4, G)
		var ur_art: Array = build_number_art(uat_remaining, 4, G)
		for r: int in range(5):
			t += "    %s              %s\n" % [cr_art[r], ur_art[r]]
		t += "[/font_size][font_size=24]\n"
		var load_mins: int = 0
		var load_secs: int = 0
		if _term._ui._session != null:
			var t_total: float = _term._ui._session.total_time
			load_mins = int(t_total / 60.0)
			load_secs = int(t_total) % 60
		t += "%s------------------------------]TEMPS CHARGEMENT]------------------------------%s\n" % [C, E]
		t += "  %sCOLIS CHARGES%s              %s]   %02d:%02d:%02d   ]%s      %sUAT CHARGEES%s\n" % [H, E, H, load_mins, load_secs, 0, E, H, E]
		t += "[/font_size][font_size=28]\n"
		var cl_art: Array = build_number_art(colis_loaded, 4, G)
		var ul_art: Array = build_number_art(uat_loaded, 4, G)
		for r: int in range(5):
			t += "    %s              %s\n" % [cl_art[r], ul_art[r]]
		t += "[/font_size][font_size=24]\n"
		t += "    %sN° Colis ou UAT%s %s_________________________%s\n" % [H, E, Y, E]
		t += "    %sMode%s %s+%s\n" % [H, E, Y, E]
		t += "\n%s─────────────────────────────────────────────────────────────────────────────%s\n" % [C, E]
		t += "%sF3=Sortie F5=R@J F13=RAQ (or Shift+F1)  F10=Valider F14=UAT/Colis Charg{s%s\n" % [C, E]
		t += "%sF6=Toisage F7=EXPE colis sans flux F8=UAT normal/vrac F9=Modif support UAT%s\n" % [C, E]

	# === SAISIE D'UNE EXPEDITION (state 19) ===
	elif _term.state == S.SAISIE_EXPEDITION:
		var tab_dest_code: String = _term._tabs[_term._active_tab].get("dest_code", "") if not _term._tabs.is_empty() else ""
		var tab_dest_name: String = _term._tabs[_term._active_tab].get("dest_name", "") if not _term._tabs.is_empty() else ""
		var tab_seal: String = _term._tabs[_term._active_tab].get("seal_entered", "") if not _term._tabs.is_empty() else ""
		var dest_filled: bool = tab_dest_code != ""
		var seal_filled: bool = tab_seal != ""
		if not dest_filled:
			_term._input_field.placeholder_text = "Enter store destination code, then press Enter"
		elif not seal_filled:
			_term._input_field.placeholder_text = "Enter seal number, then press Enter"
		else:
			_term._input_field.placeholder_text = "F10=Valider (proceed to scanning) — F3=Sortie"
		t += "%s%s%s   %s***%s    %s[u]SAISIE D'UNE EXPEDITION[/u]%s  %s***%s  %sQUAI390%s    %sNLDKL01%s\n" % [H, d, E, H, E, C, E, H, E, H, E, H, E]
		t += "%s19:30:24%s                                    %sAJOUTER%s  %sPID2E1R%s\n\n" % [H, E, R, E, H, E]
		var s19_exp: String = "06948174"
		if _term._ui._session != null and _term._ui._session.expedition_number_1 != "":
			s19_exp = _term._ui._session.expedition_number_1
		t += "%sN{exp{dition    :%s  %s%s%s              %sExp{diteur camion:%s %s[u]14    390[/u]%s\n\n" % [H, E, Y, s19_exp, E, H, E, Y, E]
		t += "%sExpediteur       :   14    390%s %sCAR TILBURG EXPE%s\n\n" % [H, E, H, E]
		if dest_filled:
			t += "%sDestinataire     :%s  %s 7  %s%s   %s%s%s\n\n" % [H, E, Y, tab_dest_code, E, H, tab_dest_name, E]
		else:
			t += "%sDestinataire     :%s  %s 7  ________%s   %s" % [H, E, Y, E, R] + Locale.t("as400.saisie_dest_hint") + "%s\n\n" % E
		if seal_filled:
			t += "%sSEAL number 1    :%s  %s[u]%s[/u]%s\n" % [H, E, Y, tab_seal, E]
		elif dest_filled:
			t += "%sSEAL number 1    :%s  %s________%s   %s" % [H, E, Y, E, R] + Locale.t("as400.saisie_seal_hint") + "%s\n" % E
		else:
			t += "%sSEAL number 1    :%s  %s________%s\n" % [H, E, Y, E]
		t += "%sSEAL number 2    :%s  %s________%s\n\n" % [H, E, Y, E]
		t += "%sType transport :%s %s1%s\n" % [H, E, Y, E]
		t += "%sPrestataire    :%s %sDHL%s\n" % [H, E, Y, E]
		t += "%sType exp{dition :%s %s[u]C[/u]%s %s(C=Classical / S=Specific)%s\n\n\n" % [H, E, Y, E, H, E]
		var operators: Array = ["Benancio", "Lydia", "Lorena", "Zuzanna", "Georgios", "Damian"]
		var op_name: String = operators[hash(tab_dest_name if dest_filled else "default") % operators.size()]
		t += "%sOp{rateur        :%s                  %s%s%s\n" % [H, E, R, op_name.to_upper(), E]
		t += "\n%s─────────────────────────────────────────────────────────────────────────────%s\n" % [C, E]
		t += "%sF3=Sortie    F4=Invite    F10=Valider%s                            %sAIDE%s\n" % [C, E, C, E]

	# === EXPEDITION EN COURS (state 22) ===
	elif _term.state == S.EXPEDITION_EN_COURS:
		_term._input_field.placeholder_text = "F6=Créer (opens badge login) — F3=Sortie"
		t += "%s%s%s   %s***%s    %s[u]EXPEDITION EN COURS[/u]%s    %s***%s  %sQUAI390%s    %sNLDKL01%s\n" % [H, d, E, H, E, C, E, H, E, H, E, H, E]
		t += "%s19:29:57%s                                    %sAFFICH.%s  %sPIEHDFR%s\n\n" % [H, E, Y, E, H, E]
		t += "%sExp{diteur :   14    390 CAR TILBURG EXPE%s\n\n" % [H, E]
		t += "%sAfficher @ partir de : N{ exp{dition :%s %s________%s\n\n" % [H, E, Y, E]
		t += "%sIndiquez vos options, puis appuyez sur Entr{e.%s\n" % [H, E]
		t += "%s2=Compl{ter    4=Supprimer%s\n\n" % [H, E]
		t += "%sOpt N{Exp{  Plb n{1     Code destinataire          Par        Etat%s\n" % [H, E]
		var exp_dest22: String = _term._ui.current_dest_name
		if _term._ui.current_dest2_name != "":
			exp_dest22 = _term._ui.current_dest_name + "/" + _term._ui.current_dest2_name
		var s22_exp: String = "06948174"
		if _term._ui._session != null and _term._ui._session.expedition_number_1 != "":
			s22_exp = _term._ui._session.expedition_number_1
		t += "%s__  %s XXXXXXXX    7 %5s %-20s Georgios   EN COURS%s\n" % [H, s22_exp, _term._ui.current_dest_code, exp_dest22, E]
		t += "%s__  06947961 XXXXXXXX   14    63 CAR HOUPLINES (quai  Artemios   EN COURS%s\n" % [H, E]
		t += "%s__  06938346 XXXXXXXX    7  2680 CIRCULAR CENTER TILB JAKUB      EN COURS%s\n" % [H, E]
		t += "%s__  06929233 00873747    7  1570 ALKMAAR              Georgios   EN COURS%s\n" % [H, E]
		t += "%s__  06845806 XXXXXXXX    7  2680 CIRCULAR CENTER TILB DANIEL     EN COURS%s\n" % [H, E]
		t += "\n\n\n                                                                      %s+%s\n" % [H, E]
		t += "\n%s─────────────────────────────────────────────────────────────────────────────%s\n" % [C, E]
		t += "%sF3=Sortie    F6=Cr{er%s                                                %sAIDE%s\n" % [C, E, C, E]
		t += "%sFin de balayage; utilisez la touche D{filH afin d'explorer davantage d'enreg%s\n" % [H, E]

	# === EASTER EGG: GE Menu (state 20) ===
	elif _term.state == S.GE_MENU:
		_term._input_field.placeholder_text = "Votre choix ==> (1-8, or F3)"
		t += "%s19:17:20%s                  %s[u]MENU DES APPLICATIONS[/u]%s             %s%s NLDKL01%s\n" % [H, E, C, E, H, d, E]
		t += "                                                          %sGDMRVIS1%s\n\n" % [H, E]
		t += "%s─────────────────────────────────────────────────────────────────────────────%s\n\n" % [H, E]
		t += "      %s1  -   Outils d'aides @ la décision%s\n" % [H, E]
		t += "      %s2  -   GESTION ENTREPOT OXYLANE%s\n" % [H, E]
		t += "      %s3  -   Remise en fonction des écrans%s\n" % [H, E]
		t += "      %s4  -   Gestion des factures%s\n" % [H, E]
		t += "      %s5  -   Menu Radio%s\n" % [H, E]
		t += "      %s6  -   Adressage dirigé par les ORGANISATEUR%s\n" % [H, E]
		t += "      %s7  -   HUB MENU%s\n" % [H, E]
		t += "      %s8  -   Gestion des Profils utilisateurs%s\n" % [H, E]
		t += "\n\n\n\n\n"
		t += "                    %sVotre choix ==>%s  %s__%s\n" % [H, E, Y, E]
		t += "\n%s─────────────────────────────────────────────────────────────────────────────%s\n" % [C, E]
		t += "  %sF3  Fin de travail   F4  Give my feedback about AS400%s\n" % [C, E]

	# === EASTER EGG: AIDE A LA DECISION (state 21) ===
	elif _term.state == S.AIDE_DECISION:
		_term._input_field.placeholder_text = "Votre choix : (1-5, or F3)"
		t += "%s19:17:38%s       %s[u]AIDE A LA DECISION   D E C A T H L O N[/u]%s     %s%s NLDKL01%s\n" % [H, E, C, E, H, d, E]
		t += "    %s1%s                                                     %sDECINIT%s\n\n" % [H, E, H, E]
		t += "%s─────────────────────────────────────────────────────────────────────────────%s\n\n" % [H, E]
		t += "      %s1  -   Query/400%s\n\n" % [H, E]
		t += "      %s2  -   Tableaux de pilotage%s\n\n" % [H, E]
		t += "      %s3  -   Accès aux autres ordinateurs%s\n\n" % [H, E]
		t += "      %s4  -   REACTIVATION DES ECRANS%s\n\n" % [H, E]
		t += "      %s5  -   WORK WTR%s\n\n\n" % [H, E]
		t += "              %sVotre choix :%s  %s_%s\n" % [H, E, Y, E]
		t += "                                               %s(C)  INFO3D    1989,1990%s\n" % [H, E]
		t += "\n%s─────────────────────────────────────────────────────────────────────────────%s\n" % [C, E]
		t += "  %sF1=Aide       F3=Exit                          F12=Précédent%s\n" % [C, E]

	t += "[/font_size]"
	if _term.error:
		t += "\n[font_size=16][color=#ff4444][b]  *** Choix non valide — F3 pour revenir ***[/b][/color][/font_size]"
	_term._display.text = t
