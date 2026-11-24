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


PREFS = ("北海道 青森県 岩手県 宮城県 秋田県 山形県 福島県 茨城県 栃木県 群馬県 埼玉県 千葉県 東京都 神奈川県 新潟県 富山県 "
         "石川県 福井県 山梨県 長野県 岐阜県 静岡県 愛知県 三重県 滋賀県 京都府 大阪府 兵庫県 奈良県 和歌山県 鳥取県 島根県 "
         "岡山県 広島県 山口県 徳島県 香川県 愛媛県 高知県 福岡県 佐賀県 長崎県 熊本県 大分県 宮崎県 鹿児島県 沖縄県").split()


def query(pref):
    return ('[out:json][timeout:180];'
            f'area["name"="{pref}"]["admin_level"="4"]["boundary"="administrative"]->.a;('
            'nwr["shop"~"^(mall|department_store|supermarket)$"]["name"~"^(イオン|AEON)"](area.a);'
            'nwr["shop"~"^(mall|department_store|supermarket)$"]["brand"~"^(イオン|AEON)"](area.a);'
            'nwr["shop"="chemist"](area.a);'
            ');out center tags;')


def fetch(pref):
    data = urllib.parse.urlencode({"data": query(pref)}).encode()
    last = None
    for rnd in range(2):
        for ep in ENDPOINTS:
            try:
                req = urllib.request.Request(ep, data=data, headers=UA)
                with urllib.request.urlopen(req, timeout=200) as r:
                    j = json.load(r)
                remark = str(j.get("remark", ""))
                if "error" in remark.lower() or "timed out" in remark.lower():
                    raise RuntimeError("remark: " + remark[:200])
                return j.get("elements", [])
            except Exception as ex:  # noqa: BLE001
                last = ex
                print(f"  retry {pref} {ep}: {ex}", file=sys.stderr, flush=True)
                time.sleep(15 + rnd * 30)
    raise SystemExit(f"Overpass failed for {pref}: {last}")


# 都道府県ごとに少しずつ取得（日本国内だけ・サーバーの負担が小さい）
items, seen, counts = [], set(), {"aeon": 0, "drug": 0}
for i, pref in enumerate(PREFS, 1):
    els = fetch(pref)
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
    print(f"[{i}/47] {pref}: {len(els)}  total aeon={counts['aeon']} drug={counts['drug']}", flush=True)
    time.sleep(2)

for k, m in MIN_COUNT.items():
    if counts[k] < m:
        raise SystemExit(f"too few {k}: {counts[k]} (keep old data)")

out = {"updated": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%MZ"),
       "source": "(c) OpenStreetMap contributors, ODbL 1.0", "counts": counts, "items": items}
path = os.path.join(os.path.dirname(__file__), "facilities.json")
with open(path, "w", encoding="utf-8") as f:
    json.dump(out, f, ensure_ascii=False, separators=(",", ":"))
print("wrote", path, len(items))
