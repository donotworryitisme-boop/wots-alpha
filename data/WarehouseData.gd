extends RefCounted
class_name WarehouseData

# ==========================================
# WAREHOUSE DATA — NLDKL01 TILBURG
# Static lookup tables for dock mapping, CMR addresses, carriers.
# Used by: Loading Sheet, CMR Form, BayUI session setup.
# ==========================================

# --- SENDER (same for every CMR) ---
const SENDER_NAME: String = "Decathlon Netherlands"
const SENDER_LINE2: String = "Logistique"
const SENDER_STREET: String = "Koopvaardijstraat 3"
const SENDER_POSTCODE_CITY: String = "5048 AT TILBURG"
const SENDER_CITY: String = "TILBURG"

# --- STORE CMR ADDRESSES ---
# Key = store name (uppercase, matches BayUI.store_destinations[].name)
const STORE_ADDRESSES: Dictionary = {
	"ALEXANDRIUM": {"cmr_name": "Decathlon R'dam Alexandrium", "street": "Watermanweg 323", "postcode_city": "3067 GA Rotterdam"},
	"ALKMAAR": {"cmr_name": "Decathlon Alkmaar", "street": "Noorderkade 126", "postcode_city": "1823 CJ Alkmaar"},
	"AMSTERDAM NOORD": {"cmr_name": "Decathlon Amsterdam Noord", "street": "Buikslotermeerplein 226 A", "postcode_city": "1025 GA Amsterdam"},
	"APELDOORN": {"cmr_name": "Decathlon Apeldoorn", "street": "De Voorwaarts 25", "postcode_city": "7321 MA Apeldoorn"},
	"ARENA": {"cmr_name": "Decathlon Amsterdam Arena", "street": "Johan Cruijff Boulevard 101", "postcode_city": "1101 DM Amsterdam"},
	"ARNHEM": {"cmr_name": "Decathlon Arnhem", "street": "Olympus 1", "postcode_city": "6832 EL Arnhem"},
	"BEST": {"cmr_name": "Decathlon Best", "street": "Ncb-Weg 14", "postcode_city": "5681 RH Best"},
	"BILDERDIJKSTRAAT": {"cmr_name": "Decathlon Bilderdijkstraat", "street": "Da Costakade 52", "postcode_city": "1053 WN Amsterdam"},
	"BREDA": {"cmr_name": "Decathlon Breda", "street": "Bavelseparklaan 20", "postcode_city": "4817 ZJ Breda"},
	"COOLSINGEL": {"cmr_name": "Decathlon R'dam Coolsingel", "street": "Coolsingel 45", "postcode_city": "3012 AA Rotterdam"},
	"DEN BOSCH": {"cmr_name": "Decathlon Den Bosch", "street": "Nieuwstraat 5", "postcode_city": "5211 EK Den Bosch"},
	"DEN HAAG": {"cmr_name": "Decathlon Den Haag", "street": "Grote Marktstraat 54", "postcode_city": "2511 BH Den Haag"},
	"EINDHOVEN": {"cmr_name": "Decathlon Eindhoven", "street": "Piazza 52", "postcode_city": "5611 AE Eindhoven"},
	"ENSCHEDE": {"cmr_name": "Decathlon Enschede", "street": "Van Loenshof 60", "postcode_city": "7511 NJ Enschede"},
	"GRONINGEN": {"cmr_name": "Decathlon Groningen", "street": "Sontplein 5", "postcode_city": "9723 BZ Groningen"},
	"KERKRADE": {"cmr_name": "Decathlon Kerkrade", "street": "Wiebachstraat 75", "postcode_city": "6466 NG Kerkrade"},
	"LEEUWARDEN": {"cmr_name": "Decathlon Leeuwarden", "street": "De Centrale 35", "postcode_city": "8924 CZ Leeuwarden"},
	"NIJMEGEN": {"cmr_name": "Decathlon Nijmegen", "street": "Grote Markt 3", "postcode_city": "6511 KA Nijmegen"},
	"ROERMOND": {"cmr_name": "Decathlon Roermond", "street": "Schaarbroekerweg 4a", "postcode_city": "6042 EJ Roermond"},
	"TILBURG": {"cmr_name": "Decathlon Tilburg", "street": "Pieter Vreedeplein 165", "postcode_city": "5038 BW Tilburg"},
	"WIBAUTSTRAAT": {"cmr_name": "Decathlon Amsterdam Wibautstraat", "street": "Wibautstraat 29", "postcode_city": "1091 GH Amsterdam"},
}

# --- DOCK ASSIGNMENTS ---
# Key = store name → dock number (int)
# Co-loading pairs share the same dock.
const STORE_DOCKS: Dictionary = {
	"ALEXANDRIUM": 18,
	"ALKMAAR": 23,
	"AMSTERDAM NOORD": 19,
	"APELDOORN": 23,
	"ARENA": 11,
	"ARNHEM": 24,
	"BEST": 22,
	"BILDERDIJKSTRAAT": 13,
	"BREDA": 11,
	"COOLSINGEL": 25,
	"DEN BOSCH": 14,
	"DEN HAAG": 25,
	"EINDHOVEN": 13,
	"ENSCHEDE": 19,
	"GRONINGEN": 21,
	"KERKRADE": 9,
	"LEEUWARDEN": 20,
	"NIJMEGEN": 18,
	"ROERMOND": 9,
	"TILBURG": 12,
	"WIBAUTSTRAAT": 12,
}

# --- CO-LOADING DOCK OVERRIDES ---
# Some co-loading pairs can use either of two docks. First dock is preferred.
const CO_DOCK_OVERRIDES: Dictionary = {
	"GRONINGEN/LEEUWARDEN": [20, 21],
	"LEEUWARDEN/GRONINGEN": [20, 21],
	"ENSCHEDE/NIJMEGEN": [19, 18],
	"NIJMEGEN/ENSCHEDE": [18, 19],
	"ALEXANDRIUM/AMSTERDAM NOORD": [18, 19],
	"AMSTERDAM NOORD/ALEXANDRIUM": [19, 18],
}

# --- CARRIER ASSIGNMENTS ---
# Key = dock number → carrier name
const DOCK_CARRIERS: Dictionary = {
	9: "Schotpoort",
	11: "DHL",
	12: "DHL",
	13: "DHL",
	14: "DHL",
	18: "Schotpoort",
	19: "Schotpoort",
	20: "Schotpoort",
	21: "Schotpoort",
	22: "Schotpoort",
	23: "Schotpoort",
	24: "Schotpoort",
	25: "Schotpoort",
}


# ==========================================
# LOOKUP FUNCTIONS
# ==========================================

static func get_store_address(store_name: String) -> Dictionary:
	if store_name in STORE_ADDRESSES:
		return STORE_ADDRESSES[store_name]
	return {"cmr_name": store_name, "street": "", "postcode_city": ""}


static func get_dock_number(store_name: String, co_partner_name: String = "") -> int:
	if co_partner_name != "":
		var pair_key: String = store_name + "/" + co_partner_name
		if pair_key in CO_DOCK_OVERRIDES:
			var docks: Array = CO_DOCK_OVERRIDES[pair_key]
			if not docks.is_empty():
				return docks[0] as int
	if store_name in STORE_DOCKS:
		return STORE_DOCKS[store_name] as int
	return 23  # Fallback — Apeldoorn dock


static func get_carrier(dock_number: int) -> String:
	if dock_number in DOCK_CARRIERS:
		return DOCK_CARRIERS[dock_number] as String
	return "Schotpoort"


static func generate_expedition_number(rng: RandomNumberGenerator) -> String:
	var base: int = rng.randi_range(4000000, 4999999)
	return "%08d" % base


static func generate_co_expedition_numbers(rng: RandomNumberGenerator) -> Array:
	var exp1: String = generate_expedition_number(rng)
	var offset: int = rng.randi_range(10, 20)
	var exp2_int: int = int(exp1) + offset
	var exp2: String = "%08d" % exp2_int
	return [exp1, exp2]


# Full CMR sender block as a single string (for display)
static func get_sender_block() -> String:
	return "%s\n%s\n%s\n%s" % [SENDER_NAME, SENDER_LINE2, SENDER_STREET, SENDER_POSTCODE_CITY]


# Full CMR consignee block for a store
static func get_consignee_block(store_name: String) -> String:
	var addr: Dictionary = get_store_address(store_name)
	return "%s\n%s\n%s" % [addr.cmr_name, addr.street, addr.postcode_city]
