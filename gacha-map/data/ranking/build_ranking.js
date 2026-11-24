/* ガチャマップ 全国ランキング（総合・今月 TOP30）を作る。
   GitHub Actions で1時間ごとに実行。Firebase の管理用の鍵は GitHub Secrets（FIREBASE_SERVICE_ACCOUNT）からだけ読む。
   ポイントは記録の数から計算（ズル防止）：お店登録+10 / 在庫報告+2 / 写真+5 / もらったいいね+1
   ・通報3件以上で非表示になったお店・写真の分は数えない
   ・ランキングに名前を出さない設定(hideRank)の人は表示しない
   ・メールアドレスは使わない（ニックネームだけ） */
'use strict';
const crypto = require('crypto');
const fs = require('fs');

const PT = { store: 10, report: 2, photo: 5, liked: 1 };
const LEVELS = [[0, 'ビギナー'], [30, 'ガチャ好き'], [100, 'ガチャハンター'], [300, 'ガチャマスター'], [1000, 'ガチャレジェンド']];
const TOP = 30;
const JST = 9 * 3600e3;

const NG = ['死ね', 'しね', '殺す', 'ころす', 'キモい', 'きもい', 'ブス', 'ちんこ', 'まんこ', 'セックス', 'fuck', 'shit'];
function clean(v, n) { return String(v == null ? '' : v).replace(/[\u0000-\u001f\u007f​-‏‪-‮⁦-⁩﻿]/g, '').replace(/\s+/g, ' ').trim().slice(0, n); }
function safeNick(v) {
  const s = clean(v, 20).normalize('NFKC'), low = s.toLowerCase();
  if (!s || /[<>@]/.test(s) || /https?:|www\./i.test(s) || /0\d{1,4}[-ー‐]\d{1,4}[-ー‐]\d{3,4}|0[789]0\d{8}/.test(s) || NG.some(w => low.includes(w))) return 'ガチャ好きさん';
  return clean(v, 20);
}
function level(p) { let l = LEVELS[0]; for (const x of LEVELS) if (p >= x[0]) l = x; return l[1]; }
const ms = t => (t && typeof t.toMillis === 'function') ? t.toMillis() : (typeof t === 'number' ? t : 0);
const okUid = u => typeof u === 'string' && /^[A-Za-z0-9]{1,128}$/.test(u);
const me = uid => crypto.createHash('sha256').update('gachamap:' + uid).digest('hex').slice(0, 16);

/* data: {users:[{id,name,hideRank}], stores:[{id,by,createdAt}], events:[{uid,storeId,day}], photos:[{id,by,storeId,createdAt}],
          likes:[{uid,owner,target,tid,at}], storeReports:[{sid}], reports:[{pid}]} */
function compute(data, now = Date.now()) {
  const cnt = (arr, key) => { const m = new Map(); for (const x of arr) m.set(x[key], (m.get(x[key]) || 0) + 1); return m; };
  const sRep = cnt(data.storeReports, 'sid'), pRep = cnt(data.reports, 'pid');
  const hiddenStore = new Set([...sRep].filter(([, n]) => n >= 3).map(([k]) => k));
  const hiddenPhoto = new Set([...pRep].filter(([, n]) => n >= 3).map(([k]) => k));
  const storeIds = new Set(data.stores.map(s => s.id));
  const photoIds = new Set(data.photos.map(p => p.id));

  const j = new Date(now + JST), mStart = Date.UTC(j.getUTCFullYear(), j.getUTCMonth(), 1) - JST;
  const label = `${j.getUTCFullYear()}年${j.getUTCMonth() + 1}月`;
  const inMonth = t => t >= mStart && t <= now + 60e3;

  const tot = new Map(), mon = new Map();
  const add = (uid, p, t) => { if (!okUid(uid)) return; tot.set(uid, (tot.get(uid) || 0) + p); if (inMonth(t)) mon.set(uid, (mon.get(uid) || 0) + p); };

  for (const s of data.stores) if (!hiddenStore.has(s.id)) add(s.by, PT.store, ms(s.createdAt));
  for (const e of data.events) if (storeIds.has(e.storeId) && !hiddenStore.has(e.storeId)) add(e.uid, PT.report, Number(e.day) * 86400e3);
  for (const p of data.photos) if (!hiddenPhoto.has(p.id) && !hiddenStore.has(p.storeId)) add(p.by, PT.photo, ms(p.createdAt));
  for (const l of data.likes) {
    if (l.owner === l.uid) continue;
    if (l.target === 'photo' && (!photoIds.has(l.tid) || hiddenPhoto.has(l.tid))) continue;
    if (l.target === 'store' && (!storeIds.has(l.tid) || hiddenStore.has(l.tid))) continue;
    add(l.owner, PT.liked, ms(l.at));
  }

  const users = new Map(data.users.map(u => [u.id, u]));
  const board = m => {
    const rows = [...m].filter(([uid, p]) => p > 0 && !(users.get(uid) && users.get(uid).hideRank === true))
      .sort((a, b) => b[1] - a[1] || (a[0] < b[0] ? -1 : 1));
    const out = []; let rank = 0, prev = null;
    rows.forEach(([uid, p], i) => {
      if (p !== prev) { rank = i + 1; prev = p; }
      if (rank > TOP) return;
      out.push({ rank, name: safeNick(users.get(uid) && users.get(uid).name), points: p, level: level(p), me: me(uid) });
    });
    return out;
  };
  return {
    updated: new Date(now).toISOString().slice(0, 16) + 'Z',
    points: PT,
    total: board(tot),
    month: { label, list: board(mon) },
    players: tot.size,
  };
}

async function main() {
  const out = process.argv[2];
  const sa = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (!sa) { console.log('FIREBASE_SERVICE_ACCOUNT が無いのでスキップ'); return; }
  const admin = require('firebase-admin');
  admin.initializeApp({ credential: admin.credential.cert(JSON.parse(sa)) });
  const db = admin.firestore();
  const get = async (col, fields, map) => (await db.collection(col).select(...fields).get()).docs.map(d => map(d.id, d.data()));
  const data = {
    users: await get('users', ['name', 'hideRank'], (id, x) => ({ id, name: x.name, hideRank: x.hideRank === true })),
    stores: await get('stores', ['by', 'createdAt'], (id, x) => ({ id, by: x.by, createdAt: x.createdAt })),
    events: await get('events', ['uid', 'storeId', 'day'], (id, x) => ({ uid: x.uid, storeId: x.storeId, day: x.day })),
    photos: await get('photos', ['by', 'storeId', 'createdAt'], (id, x) => ({ id, by: x.by, storeId: x.storeId, createdAt: x.createdAt })),
    likes: await get('likes', ['uid', 'owner', 'target', 'tid', 'at'], (id, x) => ({ uid: x.uid, owner: x.owner, target: x.target, tid: x.tid, at: x.at })),
    storeReports: await get('storeReports', ['sid'], (id, x) => ({ sid: x.sid })),
    reports: await get('reports', ['pid'], (id, x) => ({ pid: x.pid })),
  };
  const r = compute(data);
  fs.writeFileSync(out, JSON.stringify(r));
  console.log('ranking:', r.total.length, 'total /', r.month.list.length, 'month / players', r.players);
}

module.exports = { compute, me };
if (require.main === module) main().catch(e => { console.error('エラー:', e.message); process.exit(1); });
