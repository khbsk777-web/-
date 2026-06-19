import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../../data/repositories/user_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  Package? _package;
  bool _isLoading = false;
  bool _isPurchasing = false;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    setState(() => _isLoading = true);
    try {
      final offerings = await Purchases.getOfferings();
      final pkg = offerings.current?.monthly;
      setState(() {
        _package = pkg;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _purchase() async {
    if (_package == null) return;
    setState(() => _isPurchasing = true);
    try {
      final info = await Purchases.purchasePackage(_package!);
      final isPremium =
          info.entitlements.active.containsKey(AppConstants.premiumEntitlement);

      if (isPremium) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          await UserRepository().updatePremiumStatus(uid, true, null);
        }
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('プレミアムへようこそ！'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('購入に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  Future<void> _restore() async {
    try {
      final info = await Purchases.restorePurchases();
      final isPremium =
          info.entitlements.active.containsKey(AppConstants.premiumEntitlement);
      if (isPremium && mounted) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          await UserRepository().updatePremiumStatus(uid, true, null);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('購入が復元されました'),
              backgroundColor: AppColors.success),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('復元に失敗しました: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A2E), AppColors.background],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Close button
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Header
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [AppColors.warning, Color(0xFFFF6B00)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.warning.withOpacity(0.4),
                              blurRadius: 30,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.star_rounded,
                            color: Colors.white, size: 44),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Sleep AI Premium',
                        style: Theme.of(context).textTheme.displayMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'AIで睡眠を最適化する',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 32),

                      // Features
                      ..._features.map(
                        (f) => _FeatureRow(icon: f.$1, title: f.$2, desc: f.$3),
                      ),
                      const SizedBox(height: 32),

                      // Price card
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppColors.warning.withOpacity(0.5)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _isLoading
                                      ? '---'
                                      : (_package?.storeProduct.priceString ??
                                          '¥500'),
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 40,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    ' /月',
                                    style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 16),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'いつでもキャンセル可能',
                              style: TextStyle(
                                  color: AppColors.textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // CTA buttons
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    ElevatedButton(
                      onPressed: _isPurchasing ? null : _purchase,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warning,
                      ),
                      child: _isPurchasing
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('プレミアムを開始'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _restore,
                      child: const Text(
                        '購入を復元',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _features = [
    (Icons.history_rounded, '無制限保存', '全期間の睡眠データを保存・閲覧'),
    (Icons.psychology_rounded, 'AI毎日分析', 'GPT-4oによる詳細な睡眠分析'),
    (Icons.bar_chart_rounded, '詳細レポート', '週次・月次レポートと傾向分析'),
    (Icons.download_rounded, 'CSVエクスポート', '全データをCSVで書き出し'),
    (Icons.mic_rounded, '高精度いびき検知', 'より正確ないびき検知と記録'),
  ];
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;

  const _FeatureRow(
      {required this.icon, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.warning, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: Theme.of(context).textTheme.titleMedium),
                Text(desc,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          const Icon(Icons.check_rounded,
              color: AppColors.success, size: 20),
        ],
      ),
    );
  }
}
