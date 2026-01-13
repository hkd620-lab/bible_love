from pathlib import Path
import re

src = Path("tools/source/raw/KJV_pg10.txt")
dst = Path("tools/source/kjv/kjv_66.txt")

BOOKMAP = {
    # Pentateuch
    "The First Book of Moses: Called Genesis": "gen",
    "The Second Book of Moses: Called Exodus": "exo",
    "The Third Book of Moses: Called Leviticus": "lev",
    "The Fourth Book of Moses: Called Numbers": "num",
    "The Fifth Book of Moses: Called Deuteronomy": "deu",

    # History
    "The Book of Joshua": "jos",
    "The Book of Judges": "jdg",
    "The Book of Ruth": "rut",
    "The First Book of Samuel": "1sa",
    "The Second Book of Samuel": "2sa",
    "The First Book of the Kings": "1ki",
    "The Second Book of the Kings": "2ki",
    # Variant headings seen in some texts
    "The Third Book of the Kings": "1ki",
    "The Fourth Book of the Kings": "2ki",

    "The First Book of the Chronicles": "1ch",
    "The Second Book of the Chronicles": "2ch",
    "Ezra": "ezr",
    "The Book of Ezra": "ezr",
    "The Book of Nehemiah": "neh",
    "The Book of Esther": "est",

    # Wisdom/Poetry
    "The Book of Job": "job",
    "The Book of Psalms": "psa",
    "The Proverbs": "pro",
    "Ecclesiastes": "ecc",
    "The Song of Solomon": "sng",

    # Major prophets
    "The Book of the Prophet Isaiah": "isa",
    "The Book of the Prophet Jeremiah": "jer",
    "The Lamentations of Jeremiah": "lam",
    "The Book of the Prophet Ezekiel": "ezk",
    "The Book of Daniel": "dan",

    # Minor prophets (often appear as single-word headings in pg10)
    "Hosea": "hos",
    "Joel": "jol",
    "Amos": "amo",
    "Obadiah": "oba",
    "Jonah": "jon",
    "Micah": "mic",
    "Nahum": "nah",
    "Habakkuk": "hab",
    "Zephaniah": "zep",
    "Haggai": "hag",
    "Zechariah": "zec",
    "Malachi": "mal",

    # Gospels/Acts
    "The Gospel According to Saint Matthew": "mat",
    "The Gospel According to Saint Mark": "mrk",
    "The Gospel According to Saint Luke": "luk",
    "The Gospel According to Saint John": "jhn",
    "The Acts of the Apostles": "act",

    # Epistles
    "The Epistle of Paul the Apostle to the Romans": "rom",
    "The First Epistle of Paul the Apostle to the Corinthians": "1co",
    "The Second Epistle of Paul the Apostle to the Corinthians": "2co",
    "The Epistle of Paul the Apostle to the Galatians": "gal",
    "The Epistle of Paul the Apostle to the Ephesians": "eph",
    "The Epistle of Paul the Apostle to the Philippians": "php",
    "The Epistle of Paul the Apostle to the Colossians": "col",
    "The First Epistle of Paul the Apostle to the Thessalonians": "1th",
    "The Second Epistle of Paul the Apostle to the Thessalonians": "2th",
    "The First Epistle of Paul the Apostle to Timothy": "1ti",
    "The Second Epistle of Paul the Apostle to Timothy": "2ti",
    "The Epistle of Paul the Apostle to Titus": "tit",
    "The Epistle of Paul the Apostle to Philemon": "phm",
    "The Epistle of Paul the Apostle to the Hebrews": "heb",
    "The General Epistle of James": "jas",
    "The First Epistle General of Peter": "1pe",
    "The Second Epistle General of Peter": "2pe",
    # Variant heading seen in some texts
    "The Second General Epistle of Peter": "2pe",
    "The First Epistle General of John": "1jn",
    "The Second Epistle General of John": "2jn",
    "The Third Epistle General of John": "3jn",
    "The General Epistle of Jude": "jud",

    # Revelation
    "The Revelation of Saint John the Divine": "rev",
}

verse_pat = re.compile(r'^(\d+):(\d+)\s+(.*\S)\s*$')

current_book = None
seen = set()
out = []
unknown_headers = set()

with src.open("r", encoding="utf-8", errors="replace") as f:
    for raw in f:
        line = raw.strip()

        # Ignore alias headings used inside Samuel/Kings sections
        if line in ("Otherwise Called:", "The First Book of the Kings", "The Second Book of the Kings"):
            continue

        # Book heading: accept any line that matches BOOKMAP keys
        if line in BOOKMAP:
            current_book = BOOKMAP[line]
            continue

        # Verse line
        m = verse_pat.match(line)
        if not m or current_book is None:
            continue

        chap = int(m.group(1))
        verse = int(m.group(2))
        text = m.group(3)

        key = (current_book, chap, verse)
        if key in seen:
            continue
        seen.add(key)

        out.append(f"{current_book}\t{chap}:{verse}\t{text}")

dst.parent.mkdir(parents=True, exist_ok=True)
dst.write_text("\n".join(out) + "\n", encoding="utf-8")

print("written:", dst)
print("lines:", len(out))
# Book coverage quick info
print("books:", len({b for (b,_,_) in seen}))
