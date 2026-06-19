# Sleep AI - 設計書

## 1. システム設計書

### アーキテクチャ概要

```
┌─────────────────────────────────────────────────────────┐
│                    Flutter App (MVVM)                    │
├──────────────┬──────────────┬───────────────────────────┤
│ Presentation │   Domain     │         Data              │
│  (Screens)   │  (Entities)  │  (Repositories/Models)    │
│  (ViewModels)│  (Use Cases) │  (Firebase/Local)         │
├──────────────┴──────────────┴───────────────────────────┤
│                  Services Layer                          │
│  Audio │ Health │ Notification │ Background │ OpenAI    │
├─────────────────────────────────────────────────────────┤
│           Firebase Backend                               │
│  Auth │ Firestore │ Storage │ Analytics │ Crashlytics  │
└─────────────────────────────────────────────────────────┘
```

### 技術スタック

| 項目 | 技術 |
|------|------|
| フロントエンド | Flutter 3.x (Dart) |
| 状態管理 | Riverpod 2.x |
| 認証 | Firebase Auth (Google/Apple) |
| データベース | Cloud Firestore |
| ストレージ | Firebase Storage |
| AI分析 | OpenAI GPT-4o |
| ヘルスケア | HealthKit (iOS) / Health Connect (Android) |
| 課金 | RevenueCat |
| バックグラウンド | flutter_background_service |
| 通知 | flutter_local_notifications |

---

## 2. データベース設計 (Cloud Firestore)

### コレクション構造

```
/users/{userId}
  - id: string
  - email: string
  - displayName: string?
  - photoUrl: string?
  - isPremium: boolean
  - premiumExpiresAt: timestamp?
  - openAIKey: string?
  - bedtimeHour: number
  - bedtimeMinute: number
  - wakeHour: number
  - wakeMinute: number
  - bedtimeNotification: boolean
  - wakeupNotification: boolean
  - aiReportNotification: boolean
  - createdAt: timestamp
  - updatedAt: timestamp

/sleep_sessions/{sessionId}
  - id: string
  - userId: string (インデックス)
  - startTime: timestamp (インデックス)
  - endTime: timestamp?
  - totalMinutes: number?
  - sleepScore: number?       // 0-100
  - recoveryScore: number?    // 0-100
  - snoreCount: number?
  - snoreTotalMinutes: number?
  - recordingPaths: string[]
  - aiReport: string?
  - healthData: map?
  - isActive: boolean (インデックス)
  - createdAt: timestamp
  - updatedAt: timestamp

/snore_events/{eventId}
  - id: string
  - sessionId: string (インデックス)
  - userId: string (インデックス)
  - startTime: timestamp
  - endTime: timestamp?
  - durationSeconds: number?
  - maxDecibel: number?
  - avgDecibel: number?
  - recordingPath: string?
  - createdAt: timestamp

/ai_reports/{reportId}
  - id: string
  - userId: string (インデックス)
  - sessionId: string
  - date: timestamp (インデックス)
  - summary: string
  - insights: string[]
  - recommendations: string[]
  - sleepQualityScore: number?
  - rawResponse: string?
  - createdAt: timestamp
```

### Firestoreセキュリティルール

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users: 自分のデータのみ
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    // Sleep sessions: 自分のデータのみ
    match /sleep_sessions/{sessionId} {
      allow read, write: if request.auth != null
        && request.auth.uid == resource.data.userId;
      allow create: if request.auth != null
        && request.auth.uid == request.resource.data.userId;
    }
    // Snore events: 自分のデータのみ
    match /snore_events/{eventId} {
      allow read, write: if request.auth != null
        && request.auth.uid == resource.data.userId;
      allow create: if request.auth != null
        && request.auth.uid == request.resource.data.userId;
    }
    // AI reports: 自分のデータのみ
    match /ai_reports/{reportId} {
      allow read, write: if request.auth != null
        && request.auth.uid == resource.data.userId;
      allow create: if request.auth != null
        && request.auth.uid == request.resource.data.userId;
    }
  }
}
```

### Firestoreインデックス（firestore.indexes.json）

```json
{
  "indexes": [
    {
      "collectionGroup": "sleep_sessions",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "userId", "order": "ASCENDING"},
        {"fieldPath": "startTime", "order": "DESCENDING"}
      ]
    },
    {
      "collectionGroup": "sleep_sessions",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "userId", "order": "ASCENDING"},
        {"fieldPath": "isActive", "order": "ASCENDING"},
        {"fieldPath": "startTime", "order": "DESCENDING"}
      ]
    },
    {
      "collectionGroup": "snore_events",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "sessionId", "order": "ASCENDING"},
        {"fieldPath": "startTime", "order": "ASCENDING"}
      ]
    },
    {
      "collectionGroup": "ai_reports",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "userId", "order": "ASCENDING"},
        {"fieldPath": "date", "order": "DESCENDING"}
      ]
    }
  ]
}
```

---

## 3. Flutterフォルダ構成

```
sleep_ai/
├── lib/
│   ├── main.dart                           # エントリーポイント
│   ├── firebase_options.dart               # Firebase設定
│   ├── core/
│   │   ├── constants/
│   │   │   └── app_constants.dart          # 定数
│   │   ├── theme/
│   │   │   └── app_theme.dart              # ダークテーマ
│   │   ├── utils/                          # ユーティリティ
│   │   └── errors/                         # エラー定義
│   ├── data/
│   │   ├── models/
│   │   │   ├── sleep_session.dart          # 睡眠セッション
│   │   │   ├── snore_event.dart            # いびきイベント
│   │   │   ├── health_snapshot.dart        # 健康データ
│   │   │   ├── ai_report.dart              # AIレポート
│   │   │   └── user_model.dart             # ユーザー
│   │   └── repositories/
│   │       ├── sleep_repository.dart       # 睡眠データ操作
│   │       └── user_repository.dart        # ユーザー操作
│   ├── services/
│   │   ├── audio/
│   │   │   └── snore_detector.dart         # いびき検知
│   │   ├── background/
│   │   │   └── background_service.dart     # バックグラウンド
│   │   ├── health/
│   │   │   └── health_service.dart         # ヘルスケア連携
│   │   └── notification/
│   │       └── notification_service.dart   # 通知
│   ├── infrastructure/
│   │   └── openai/
│   │       └── openai_service.dart         # OpenAI API
│   └── presentation/
│       ├── viewmodels/
│       │   ├── auth_viewmodel.dart         # 認証VM
│       │   ├── sleep_viewmodel.dart        # 睡眠記録VM
│       │   └── dashboard_viewmodel.dart    # ダッシュボードVM
│       ├── screens/
│       │   ├── auth/
│       │   │   └── auth_screen.dart        # ログイン画面
│       │   ├── home/
│       │   │   ├── home_screen.dart        # ホーム（ナビ）
│       │   │   └── dashboard_tab.dart      # ダッシュボード
│       │   ├── sleep/
│       │   │   └── sleep_tracking_screen.dart # 睡眠記録
│       │   ├── snore/
│       │   │   └── snore_history_screen.dart  # いびき履歴
│       │   ├── analysis/
│       │   │   └── analysis_screen.dart    # AI分析
│       │   └── settings/
│       │       ├── settings_screen.dart    # 設定
│       │       └── premium_screen.dart     # プレミアム
│       └── widgets/
│           ├── cards/
│           │   ├── sleep_score_card.dart
│           │   ├── stat_card.dart
│           │   └── ai_report_card.dart
│           └── charts/
│               ├── sleep_chart.dart
│               └── snore_chart.dart
├── android/
│   └── app/src/main/AndroidManifest.xml
├── ios/
│   └── Runner/Info.plist
└── pubspec.yaml
```

---

## 4. Firebase構成

### Firebaseプロジェクト設定手順

```bash
# 1. Firebase CLIインストール
npm install -g firebase-tools

# 2. ログイン
firebase login

# 3. プロジェクト作成
firebase projects:create sleep-ai-prod

# 4. FlutterFire CLI
dart pub global activate flutterfire_cli
flutterfire configure --project=sleep-ai-prod

# 5. Firestore有効化
# Firebase Console → Firestore Database → 作成

# 6. Authentication有効化
# Firebase Console → Authentication → Sign-in method
# → Google、Apple を有効化

# 7. Storage有効化
# Firebase Console → Storage → 開始

# 8. Firestore rules deploy
firebase deploy --only firestore:rules

# 9. Firestore indexes deploy
firebase deploy --only firestore:indexes
```

### Firebase Storage Rules

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /recordings/{userId}/{allPaths=**} {
      allow read, write: if request.auth != null
        && request.auth.uid == userId;
    }
  }
}
```

---

## 5. UIモックアップ（テキスト表現）

### ダッシュボード
```
┌─────────────────────────────┐
│ 6月19日(木)          [⚙]    │
│ Sleep AI                    │
│─────────────────────────────│
│ [睡眠スコア  85/100] [回復スコア 78/100]│
│ ████████████░   ██████████░ │
│─────────────────────────────│
│ [🌙 7h 24m] [🎤 3回]        │
│ [👟 8,432歩] [❤️ 62bpm]     │
│─────────────────────────────│
│ 睡眠時間の推移               │
│ ╔═══════════════════╗      │
│ ║   📈 折れ線グラフ  ║      │
│ ╚═══════════════════╝      │
│─────────────────────────────│
│ AIレポート            [更新] │
│ ┌─────────────────────────┐ │
│ │✨ 昨日の睡眠時間は7時間  │ │
│ │   24分でした。深睡眠の  │ │
│ │   割合が良好です。      │ │
│ └─────────────────────────┘ │
└─────────────────────────────┘
```

### 睡眠記録画面
```
┌─────────────────────────────┐
│ 睡眠記録          [● REC]  │
│─────────────────────────────│
│                             │
│                             │
│        ┌─────────┐          │
│       ╱           ╲         │
│      │  🌙  STOP  │         │
│      │             │         │
│       ╲           ╱         │
│        └─────────┘          │
│      (赤グラデーション)      │
│                             │
│       06:23:45              │
│    就寝: 23:00              │
│                             │
│  [🎤 いびき 3回] [⏱ 2分]  │
│                             │
│ ─────────────────────────── │
│ 音量          45.2 dB      │
│ ████████████░░░░░░░░        │
└─────────────────────────────┘
```

### AI分析画面
```
┌─────────────────────────────┐
│ AI分析                  [↻] │
│─────────────────────────────│
│ ┌─────────────────────────┐ │
│ │✨ AIサマリー            │ │
│ │                         │ │
│ │ 昨日の睡眠時間は7時間   │ │
│ │ 18分でした。午前2時〜   │ │
│ │ 3時にいびきが集中して   │ │
│ │ います。                │ │
│ └─────────────────────────┘ │
│ 発見                        │
│ ①深睡眠の割合が21%（良好） │
│ ②いびきは就寝後4時間後に集中│
│ ③運動量が多く回復率85%      │
│                             │
│ 推奨アクション              │
│ ✅ 横向き寝を推奨します     │
│ ✅ 就寝前のアルコール控えて │
│                             │
│    AI品質スコア             │
│      ┌───┐                  │
│     ╱  85 ╲                 │
│    │       │                │
│     ╲     ╱                 │
│      └───┘                  │
└─────────────────────────────┘
```

---

## 6. API設計

### OpenAI API

**エンドポイント:** `POST /v1/chat/completions`

**システムプロンプト:**
```
あなたは睡眠専門のAIアシスタントです。
ユーザーの睡眠データを分析し、日本語で具体的なアドバイスを提供してください。
回答はJSON形式で以下の構造にしてください:
{
  "summary": "睡眠全体のサマリー（1-2文）",
  "insights": ["具体的な気づき1", "気づき2", "気づき3"],
  "recommendations": ["推奨アクション1", "推奨アクション2"],
  "sleepQualityScore": 85
}
```

**入力データ形式:**
```
【昨日の睡眠データ】
睡眠時間: 7時間24分
就寝時刻: 23:00
起床時刻: 06:24

【いびきデータ】
いびき回数: 3回
いびき総時間: 4分30秒
最大いびき音量: 62.3dB
いびきが多い時間帯: 2時台

【健康データ】
歩数: 8432歩
平均心拍数: 62bpm
消費カロリー: 345kcal
運動時間: 45分
```

### RevenueCat API（課金）

```dart
// 商品ID設定
static const monthlyProductId = 'sleep_ai_premium_monthly';
static const premiumEntitlement = 'premium';

// 購入フロー
final offerings = await Purchases.getOfferings();
final package = offerings.current?.monthly;
final info = await Purchases.purchasePackage(package!);
final isPremium = info.entitlements.active.containsKey('premium');
```

---

## 7. 実装コード

実装済みファイル一覧:
- `lib/main.dart` - アプリエントリーポイント
- `lib/core/constants/app_constants.dart` - 定数
- `lib/core/theme/app_theme.dart` - ダークテーマ
- `lib/data/models/*.dart` - データモデル (Freezed)
- `lib/data/repositories/*.dart` - Firestoreリポジトリ
- `lib/services/audio/snore_detector.dart` - いびき検知エンジン
- `lib/services/background/background_service.dart` - バックグラウンド
- `lib/services/health/health_service.dart` - HealthKit/Health Connect
- `lib/services/notification/notification_service.dart` - 通知
- `lib/infrastructure/openai/openai_service.dart` - GPT-4o連携
- `lib/presentation/viewmodels/*.dart` - MVVM ViewModels
- `lib/presentation/screens/**/*.dart` - 全画面実装
- `lib/presentation/widgets/**/*.dart` - 再利用可能Widget

---

## 8. App Store公開手順

### 事前準備
```
1. Apple Developer Program加入 ($99/年)
   https://developer.apple.com/programs/

2. App Store Connectでアプリ作成
   - Bundle ID: com.yourdomain.sleepai
   - App名: Sleep AI
   - カテゴリ: ヘルスケア/フィットネス

3. 必要な権限設定 (Info.plist)
   ✅ NSMicrophoneUsageDescription (いびき検知)
   ✅ NSHealthShareUsageDescription (HealthKit)
   ✅ UIBackgroundModes: audio (バックグラウンド録音)
```

### ビルド・申請手順
```bash
# 1. バージョン更新 (pubspec.yaml)
version: 1.0.0+1

# 2. Xcodeでビルド
cd ios && pod install
open Runner.xcworkspace

# 3. Xcodeでアーカイブ
# Product → Archive → Distribute App → App Store Connect

# 4. App Store Connect設定
# - スクリーンショット (6.7", 6.5", 5.5")
# - アプリ説明文
# - キーワード: 睡眠,いびき,AI,記録,分析
# - プライバシーポリシーURL
# - サポートURL

# 5. 審査提出
# HealthKit使用の説明を詳細に記載
# バックグラウンドオーディオの説明を記載

# 6. 審査期間: 通常1-3日
```

### HealthKit審査ポイント
- 実際にHealthKitデータを使用していることを審査員に伝える
- HealthKitデータを広告に使用しない旨を明記

---

## 9. Google Play公開手順

### 事前準備
```
1. Google Play Console登録 ($25 一括)
   https://play.google.com/console

2. アプリ作成
   - パッケージ名: com.yourdomain.sleepai
   - アプリ名: Sleep AI
   - カテゴリ: 健康＆フィットネス

3. 必要な権限設定 (AndroidManifest.xml)
   ✅ RECORD_AUDIO
   ✅ FOREGROUND_SERVICE
   ✅ FOREGROUND_SERVICE_MICROPHONE
   ✅ Health Connect権限
```

### ビルド・申請手順
```bash
# 1. 署名キー生成
keytool -genkey -v -keystore sleep-ai.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias sleep-ai

# 2. key.properties設定
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=sleep-ai
storeFile=../sleep-ai.jks

# 3. AABビルド
flutter build appbundle --release

# 4. Google Play Consoleにアップロード
# リリース → 本番 → 新しいリリースを作成

# 5. コンテンツレーティング設定
# 対象年齢: 17歳以上 (健康データ使用)

# 6. Health Connectの宣言
# アプリの権限ページに使用目的を明記

# 7. データセーフティセクション記入
# - 収集データ: 健康・フィットネス、音声
# - データ暗号化: あり
# - データ削除方法: アカウント削除で全削除

# 8. 審査期間: 通常2-7日
```

---

## 10. 月額課金機能実装

### RevenueCat設定手順

```bash
# 1. RevenueCat登録
# https://app.revenuecat.com

# 2. アプリ作成
# - App Store Connect API Key設定
# - Google Play API設定

# 3. Entitlement作成
# Identifier: premium
# 説明: Sleep AI Premium

# 4. 商品設定
App Store:
  - Product ID: sleep_ai_premium_monthly
  - 価格: ¥500/月
  - App Store Connectで先に商品作成必要

Google Play:
  - Product ID: sleep_ai_premium_monthly
  - 価格: ¥500/月
  - Google Playで先にサブスクリプション作成必要

# 5. Offering設定
# Current offering に monthly パッケージを追加

# 6. APIキー取得
# App Settings → API Keys → Public SDK key
```

### 課金制限の実装

```dart
// 無料ユーザーは7日間のみ表示
Future<List<SleepSession>> getSessions({
  required String userId,
  required bool isPremium,
  required DateTime from,
  required DateTime to,
}) async {
  final cutoff = isPremium
      ? from
      : DateTime.now().subtract(const Duration(days: 7));
  final effectiveFrom = from.isAfter(cutoff) ? from : cutoff;
  
  return await _sleepRepo.getSessions(
    userId: userId,
    from: effectiveFrom,
    to: to,
  );
}
```

### 課金状態の確認（起動時）

```dart
Future<void> checkPremiumStatus() async {
  final info = await Purchases.getCustomerInfo();
  final isPremium = info.entitlements.active
      .containsKey(AppConstants.premiumEntitlement);
  
  await UserRepository().updatePremiumStatus(
    userId,
    isPremium,
    info.entitlements.active['premium']?.expirationDate,
  );
}
```

---

## セットアップチェックリスト

### Firebase
- [ ] Firebaseプロジェクト作成
- [ ] `flutterfire configure` 実行
- [ ] `firebase_options.dart` 生成確認
- [ ] Firestore有効化・ルール設定
- [ ] Authentication (Google/Apple) 有効化
- [ ] Storage有効化
- [ ] Crashlytics有効化

### iOS固有
- [ ] Apple Developer Program加入
- [ ] Bundle ID設定
- [ ] HealthKit Capability追加 (Xcode)
- [ ] Background Modes: Audio追加 (Xcode)
- [ ] Sign in with Apple Capability追加 (Xcode)
- [ ] APN証明書設定

### Android固有
- [ ] SHA-1/SHA-256フィンガープリント設定
- [ ] google-services.json配置
- [ ] Health Connect API有効化

### RevenueCat
- [ ] App Store商品作成 (App Store Connect)
- [ ] Google Play商品作成 (Google Play Console)
- [ ] RevenueCat設定
- [ ] APIキーを`app_constants.dart`に設定

### OpenAI
- [ ] OpenAI APIキー取得
- [ ] アプリ内設定画面でユーザーが入力

### ビルド設定
- [ ] `pubspec.yaml` パッケージバージョン確認
- [ ] `flutter pub get` 実行
- [ ] `flutter pub run build_runner build` (コード生成)
- [ ] iOS: `pod install`
- [ ] デバイスでの動作確認
