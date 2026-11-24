"""全国のイオン・イオンモール・ドラッグストアを OpenStreetMap から集めて facilities.json を作る。
GitHub Actions で実行する（スマホのアプリはこのファイルを読むだけ）。
データ: (c) OpenStreetMap contributors, ODbL 1.0"""
import json, re, sys, time, urllib.parse, urllib.request, datetime, os

ENDPOINTS = ["https://overpass-api.de/api/interpreter",
             "https://overpass.private.coffee/api/interpreter",
             "https://maps.mail.ru/osm/tools/overpass/api/interpreter",
             "https://overpass.kumi.systems/api/interpreter"]
UA = {"User-Agent": "gacha-map-facilities/1.1 (https://github.com/khbsk777-web)"}
MIN_COUNT = {"aeon": 100, "drug": 3000}   # これより少ないときは失敗とみなし、古いデータを残す
CTRL = re.compile(r"[\u0000-\u001f\u007f​-‏‪-‮⁦-⁩﻿]")


def clean(v, n):
    return re.sub(r"\s+", " ", CTRL.sub("", str(v or ""))).strip()[:n]


def query(bbox):
    s, w, n, e = bbox
    bb = f"{s},{w},{n},{e}"
    return ('[out:json][timeout:240];area["ISO3166-1"="JP"][admin_level=2]->.jp;('
            f'nwr["shop"~"^(mall|department_store|supermarket)$"]["name"~"^(イオン|AEON)"](area.jp)({bb});'
            f'nwr["shop"~"^(mall|department_store|supermarket)$"]["brand"~"^(イオン|AEON)"](area.jp)({bb});'
            f'nwr["shop"="chemist"](area.jp)({bb});'
            ');out center tags;')


def fetch(bbox):
    data = urllib.parse.urlencode({"data": query(bbox)}).encode()
    last = None
    for rnd in range(3):
        for ep in ENDPOINTS:
            try:
                req = urllib.request.Request(ep, data=data, headers=UA)
                with urllib.request.urlopen(req, timeout=300) as r:
                    j = json.load(r)
                remark = str(j.get("remark", ""))
                if "error" in remark.lower() or "timed out" in remark.lower():
                    raise RuntimeError("remark: " + remark[:200])
                return j.get("elements", [])
            except Exception as ex:  # noqa: BLE001
                last = ex
                print(f"  retry {ep}: {ex}", file=sys.stderr, flush=True)
                time.sleep(10 + rnd * 20)
    raise SystemExit(f"Overpass failed for {bbox}: {last}")


# 日本を 4度×4度 の区画に分けて少しずつ取得（サーバーの負担を減らし、失敗しにくくする）
boxes = [(la, lo, la + 4, lo + 4) for la in range(24, 46, 4) for lo in range(122, 150, 4)]
items, seen, counts = [], set(), {"aeon": 0, "drug": 0}
for i, bx in enumerate(boxes, 1):
    els = fetch(bx)
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
        if t.get("shop") == "chemist":
            kind, grp = "chemist", "drug"
        elif re.match(r"^(イオン|AEON)", name) or re.match(r"^(イオン|AEON)", str(t.get("brand", ""))):
            kind = "aeonmall" if re.search(r"モール|MALL|Mall", name) or t.get("shop") == "mall" else "aeon"
            grp = "aeon"
        else:
            continue
        seen.add(osm)
        items.append([round(lat, 5), round(lon, 5), kind, name, osm])
        counts[grp] += 1
    print(f"[{i}/{len(boxes)}] {bx} -> {len(els)}  total aeon={counts['aeon']} drug={counts['drug']}", flush=True)
    time.sleep(3)

for k, m in MIN_COUNT.items():
    if counts[k] < m:
        raise SystemExit(f"too few {k}: {counts[k]} (keep old data)")

out = {"updated": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%MZ"),
       "source": "(c) OpenStreetMap contributors, ODbL 1.0", "counts": counts, "items": items}
path = os.path.join(os.path.dirname(__file__), "facilities.json")
with open(path, "w", encoding="utf-8") as f:
    json.dump(out, f, ensure_ascii=False, separators=(",", ":"))
print("wrote", path, len(items))
