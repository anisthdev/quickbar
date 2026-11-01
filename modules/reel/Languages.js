.pragma library

// ISO 639-2 codes (as ffprobe reports a track's language) to names, for the
// video menu's track picker; anything else shows as its code
const names = {
    ara: "Arabic", ben: "Bengali", bul: "Bulgarian", cat: "Catalan", chi: "Chinese", zho: "Chinese",
    cze: "Czech", ces: "Czech", dan: "Danish", dut: "Dutch", nld: "Dutch", eng: "English",
    est: "Estonian", fil: "Filipino", fin: "Finnish", fre: "French", fra: "French", ger: "German",
    deu: "German", gre: "Greek", ell: "Greek", heb: "Hebrew", hin: "Hindi", hrv: "Croatian",
    hun: "Hungarian", ice: "Icelandic", isl: "Icelandic", ind: "Indonesian", ita: "Italian",
    jpn: "Japanese", kan: "Kannada", kor: "Korean", lav: "Latvian", lit: "Lithuanian",
    mal: "Malayalam", mar: "Marathi", may: "Malay", msa: "Malay", nob: "Norwegian", nor: "Norwegian",
    per: "Persian", fas: "Persian", pol: "Polish", por: "Portuguese", rum: "Romanian", ron: "Romanian",
    rus: "Russian", slo: "Slovak", slk: "Slovak", slv: "Slovenian", spa: "Spanish", srp: "Serbian",
    swe: "Swedish", tam: "Tamil", tel: "Telugu", tha: "Thai", tur: "Turkish", ukr: "Ukrainian",
    urd: "Urdu", vie: "Vietnamese", und: "Unknown"
};

function name(code) {
    if (!code)
        return "Automatic";
    if (code === "no")
        return "Off";
    return names[code] ?? code.toUpperCase();
}
