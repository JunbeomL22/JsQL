struct NullCurrency <: AbstractCurrency end

struct Currency <: AbstractCurrency
	name::String
	code::String
	numeric::Int
	symbol::String
	fractionSymbol::String
	fractionsPerUnit::Int
	rounding::Function
	formatString::String
end

# Data from http://fx.sauder.ubc.ca/currency_table.html
# and http://www.thefinancials.com/vortex/CurrencyFormats.html

const list_currencies=[
# America
("U.S. dollar", "USD", 840, "\$", "¢", 100, identity, "%3% %1\$.2f"),
# Asia
("Chinese yuan", "CNY", 156, "Y", "", 100, identity, "%3% %1\$.2f"),
("Hong
 Kong dollar", "HKD", 344, "HK\$", "", 100, identity, "%3% %1\$.2f"),
("Indian rupee", "INR", 356, "Rs", "", 100, identity, "%3% %1\$.2f"),
("Iranian rial", "IRR", 364, "Rls", "", 1, identity, "%3% %1\$.2f"),
("Japanese yen", "JPY", 392, "¥", "", 100, identity, "%3% %1\$.0f"),
("South-Korean won", "KRW", 410, "W", "", 100, identity, "%3% %1\$.0f"),
("Singapore dollar", "SGD", 702, "S\$", "", 100, identity, "%3% %1\$.2f"),
("Thai baht", "THB", 764, "Bht", "", 100, identity, "%1\$.2f %3%"),
("Taiwan dollar", "TWD", 901, "NT\$", "", 100, identity, "%3% %1\$.2f"),
# Europe
("European Euro", "EUR", 978, "", "", 100, x->round(x,2), "%2% %1\$.2f"),
("British pound sterling", "GBP", 826,  "£", "p", 100, identity, "%3% %1\$.2f"),
# Oceania
("Australian dollar", "AUD", 36, "A\$", "", 100, identity, "%3% %1\$.2f"),
("New Zealand dollar", "NZD", 554, "NZ\$", "", 100, identity, "%3% %1\$.2f")
]

list_deprecated=Dict(
"ATS"=>"EUR",
"BEF"=>"EUR",
"CYP"=>"EUR",
"DEM"=>"EUR",
"EEK"=>"EUR",
"ESP"=>"EUR",
"FIM"=>"EUR",
"FRF"=>"EUR",
"GRD"=>"EUR",
"IEP"=>"EUR",
"ITL"=>"EUR",
"LUF"=>"EUR",
"LVL"=>"EUR",
"MTL"=>"EUR",
"NLG"=>"EUR",
"PTE"=>"EUR",
"SIT"=>"EUR",
"SKK"=>"EUR",
"TRL"=>"TRY",
"ROL"=>"RON",
"PEH"=>"PEI",
"PEI"=>"PEN"
)

# Codegen function
for currency in list_currencies
	@eval ($(Symbol("$(currency[2])"*"Currency")))()=Currency(($currency)...)
end