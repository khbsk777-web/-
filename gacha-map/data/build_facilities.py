"""全国のイオン・イオンモール・ドラッグストアを OpenStreetMap から集めて facilities.json を作る。
GitHub Actions で実行する（スマホのアプリはこのファイルを読むだけ）。
データ: (c) OpenStreetMap contributors, ODbL 1.0"""
import json, re, sys, time, urllib.parse, urllib.request, datetime, os

ENDPOINTS = ["https://overpass-api.de/api/interpreter",
             "https://overpass.kumi.systems/api/interpreter",
             "https://overpass.private.coffee/api/interpreter"]
AREA = 'area["ISO3166-1"="JP"][admin_level=2]->.jp;'
QUERIES = {
    "aeon": AREA + 'nwr["shop"~"^(mall|department_store|supermarket)$"]["name"~"^(イオン|AEON)"](area.jp);'
                   'nwr["shop"~"^(mall|department_store|supermarket)$"]["brand"~"^(イオン|AEON)"](area.jp);',
    "drug": AREA + 'nwr["shop"="chemist"](area.jp);',
}
MIN_COUNT = {"aeon": 100, "drug": 3000}   # これより少ないときは取得失敗とみなし、古いデータを残す


def fetch(body):
    data = urllib.parse.urlencode({"data": "[out:json][timeout:900];" + body + "out center tags;"}).encode()
    last = None
    for ep in ENDPOINTS:
        for attempt in range(2):
            try:
                req = urllib.request.Request(ep, data=data, headers={"User-Agent": "gacha-map-facilities/1.0 (github.com/khbsk777-web)"})
                with urllib.request.urlopen(req, timeout=960) as r:
                    return json.load(r)["elements"]
            except Exception as e:  # noqa: BLE001
                last = e
                print(f"retry {ep}: {e}", file=sys.stderr)
                time.sleep(30)
    raise SystemExit(f"Overpass failed: {last}")


CTRL = re.compile(r"[\u0000-\u001f\u007f​-‏‪-‮⁦-⁩﻿]")


def clean(v, n):
    return re.sub(r"\s+", " ", CTRL.sub("", str(v or ""))).strip()[:n]


items, seen, counts = [], set(), {}
for key, q in QUERIES.items():
    els = fetch(q)
    n = 0
    for e in els:
        t = e.get("tags", {})
        lat = e.get("lat", e.get("center", {}).get("lat"))
        lon = e.get("lon", e.get("center", {}).get("lon"))
        osm = f'{e.get("type")}/{e.get("id")}'
        name = clean(t.get("name") or t.get("brand"), 60)
        if lat is None or lon is None or not name or osm in seen:
            continue
        if not (20 <= lat <= 46 and 122 <= lon <= 154) or not re.fullmatch(r"(node|way|relation)/\d+", osm):
            continue
        if key == "aeon":
            kind = "aeonmall" if re.search(r"モール|MALL|Mall", name) or t.get("shop") == "mall" else "aeon"
        else:
            kind = "chemist"
        seen.add(osm)
        items.append([round(lat, 5), round(lon, 5), kind, name, osm])
        n += 1
    counts[key] = n
    print(key, n)
    if n < MIN_COUNT[key]:
        raise SystemExit(f"too few {key}: {n} (keep old data)")

out = {"updated": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%MZ"),
       "source": "(c) OpenStreetMap contributors, ODbL 1.0", "counts": counts, "items": items}
path = os.path.join(os.path.dirname(__file__), "facilities.json")
with open(path, "w", encoding="utf-8") as f:
    json.dump(out, f, ensure_ascii=False, separators=(",", ":"))
print("wrote", path, len(items))
