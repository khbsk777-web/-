"""全国のイオン・イオンモール・ドラッグストア・本屋・ガチャガチャ屋さんの一覧 facilities.json を作る。
GitHub Actions で、Geofabrik の日本の地図データ（OpenStreetMap）から osmium で取り出したものを読む。
データ: (c) OpenStreetMap contributors, ODbL 1.0"""
import json, re, sys, datetime, os

MIN_COUNT = {"aeon": 100, "drug": 3000, "books": 1000, "gacha": 50}   # これより少ないときは失敗とみなし、古いデータを残す
CTRL = re.compile(r"[\u0000-\u001f\u007f​-‏‪-‮⁦-⁩﻿]")
AEON = re.compile(r"^(イオン|AEON)")
GACHA = re.compile(r"(?<![ァ-ヴー])(ガチャ|ガシャ)(?!ン)|カプセルトイ|カプセル トイ|gashapon|gachapon|\bgacha|capsule ?toy", re.I)


def clean(v, n):
    return re.sub(r"\s+", " ", CTRL.sub("", str(v or ""))).strip()[:n]


def center(g):
    pts = []

    def walk(c):
        if isinstance(c, (list, tuple)) and len(c) >= 2 and all(isinstance(x, (int, float)) for x in c[:2]):
            pts.append(c)
        elif isinstance(c, (list, tuple)):
            for x in c:
                walk(x)
    walk(g.get("coordinates"))
    if not pts:
        return None
    return sum(p[1] for p in pts) / len(pts), sum(p[0] for p in pts) / len(pts)


src = sys.argv[1]
items, seen, counts = [], set(), {"aeon": 0, "drug": 0, "books": 0, "gacha": 0}
with open(src, encoding="utf-8") as f:
    for line in f:
        line = line.strip().lstrip("\x1e")
        if not line:
            continue
        ft = json.loads(line)
        t = ft.get("properties", {})
        typ, oid = t.get("@type"), t.get("@id")
        osm = f"{typ}/{oid}"
        if not re.fullmatch(r"(node|way|relation)/\d+", osm) or osm in seen:
            continue
        name = clean(t.get("name") or t.get("brand"), 60)
        shop = t.get("shop", "")
        vend = str(t.get("vending", ""))
        if not name and re.search(r"toys|capsule", vend):
            name = "カプセルトイ自販機"
        if not name:
            continue
        if GACHA.search(name) or GACHA.search(str(t.get("brand", ""))) or re.search(r"toys|capsule", vend):
            kind, grp = "gacha", "gacha"
        elif shop == "books":
            kind, grp = "books", "books"
        elif shop == "chemist":
            kind, grp = "chemist", "drug"
        elif shop in ("mall", "department_store", "supermarket") and (AEON.match(name) or AEON.match(str(t.get("brand", "")))):
            kind = "aeonmall" if re.search(r"モール|MALL|Mall", name) or shop == "mall" else "aeon"
            grp = "aeon"
        else:
            continue
        c = center(ft.get("geometry") or {})
        if not c:
            continue
        lat, lon = c
        if not (20 <= lat <= 46 and 122 <= lon <= 154):
            continue
        seen.add(osm)
        items.append([round(lat, 5), round(lon, 5), kind, name, osm])
        counts[grp] += 1

print("counts", counts)
for k, m in MIN_COUNT.items():
    if counts[k] < m:
        raise SystemExit(f"too few {k}: {counts[k]} (keep old data)")

out = {"updated": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%MZ"),
       "source": "(c) OpenStreetMap contributors, ODbL 1.0 (Geofabrik extract)", "counts": counts, "items": items}
path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "facilities.json")
with open(path, "w", encoding="utf-8") as f:
    json.dump(out, f, ensure_ascii=False, separators=(",", ":"))
print("wrote", path, len(items))
