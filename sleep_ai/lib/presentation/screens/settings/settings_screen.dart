import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import '../../../services/notification/notification_service.dart';
import 'premium_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _openAIKey = '';
  TimeOfDay _bedtime = const TimeOfDay(hour: 23, minute: 0);
  TimeOfDay _wakeup = const TimeOfDay(hour: 7, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _openAIKey = prefs.getString(AppConstants.keyOpenAIKey) ?? '';
      _bedtime = TimeOfDay(
        hour: prefs.getInt(AppConstants.keyBedtimeHour) ?? 23,
        minute: prefs.getInt(AppConstants.keyBedtimeMinute) ?? 0,
      );
      _wakeup = TimeOfDay(
        hour: prefs.getInt(AppConstants.keyWakeHour) ?? 7,
        minute: prefs.getInt(AppConstants.keyWakeMinute) ?? 0,
      );
    });
  }

  Future<void> _saveOpenAIKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyOpenAIKey, key);
    setState(() => _openAIKey = key);
  }

  Future<void> _saveBedtime(TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.keyBedtimeHour, time.hour);
    await prefs.setInt(AppConstants.keyBedtimeMinute, time.minute);
    await NotificationService.scheduleBedtimeNotification(time.hour, time.minute);
    setState(() => _bedtime = time);
  }

  Future<void> _saveWakeup(TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.keyWakeHour, time.hour);
    await prefs.setInt(AppConstants.keyWakeMinute, time.minute);
    await NotificationService.scheduleWakeupNotification(time.hour, time.minute);
    setState(() => _wakeup = time);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authViewModelProvider);
    final user = authState.valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          // User profile
          if (user != null) _UserTile(user: user),

          _SectionHeader(title: 'プレミアム'),
          _SettingsTile(
            icon: Icons.star_rounded,
            iconColor: AppColors.warning,
            title: 'プレミアムプラン',
            subtitle: user?.isPremium == true ? '加入中' : '未加入 - ¥500/月',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const PremiumScreen())),
            trailing: user?.isPremium == true
                ? const Icon(Icons.check_circle_rounded,
                    color: AppColors.success, size: 20)
                : const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textSecondary),
          ),

          _SectionHeader(title: 'AI設定'),
          _SettingsTile(
            icon: Icons.key_rounded,
            iconColor: AppColors.primary,
            title: 'OpenAI APIキー',
            subtitle: _openAIKey.isNotEmpty ? '設定済み' : '未設定',
            onTap: () => _showAPIKeyDialog(context),
          ),

          _SectionHeader(title: '通知'),
          _SettingsTile(
            icon: Icons.bedtime_rounded,
            iconColor: AppColors.primaryLight,
            title: '就寝通知',
            subtitle: '${_bedtime.format(context)} に通知',
            onTap: () async {
              final t = await showTimePicker(
                context: context,
                initialTime: _bedtime,
                builder: (context, child) => Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.dark(
                        primary: AppColors.primary),
                  ),
                  child: child!,
                ),
              );
              if (t != null) await _saveBedtime(t);
            },
          ),
          _SettingsTile(
            icon: Icons.wb_sunny_rounded,
            iconColor: AppColors.warning,
            title: '起床通知',
            subtitle: '${_wakeup.format(context)} に通知',
            onTap: () async {
              final t = await showTimePicker(
                context: context,
                initialTime: _wakeup,
              );
              if (t != null) await _saveWakeup(t);
            },
          ),

          _SectionHeader(title: 'データ'),
          _SettingsTile(
            icon: Icons.download_rounded,
            iconColor: AppColors.secondary,
            title: 'CSVエクスポート',
            subtitle: 'プレミアム機能',
            onTap: user?.isPremium == true
                ? () => _exportCsv(context, ref)
                : () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const PremiumScreen())),
          ),

          _SectionHeader(title: 'アカウント'),
          _SettingsTile(
            icon: Icons.logout_rounded,
            iconColor: AppColors.error,
            title: 'サインアウト',
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppColors.card,
                  title: const Text('サインアウト'),
                  content: const Text('サインアウトしますか？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('キャンセル'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('サインアウト',
                          style: TextStyle(color: AppColors.error)),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await ref.read(authViewModelProvider.notifier).signOut();
              }
            },
          ),

          const SizedBox(height: 40),
          Center(
            child: Text(
              'Sleep AI v${AppConstants.appVersion}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showAPIKeyDialog(BuildContext context) {
    final controller = TextEditingController(text: _openAIKey);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('OpenAI APIキー'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'sk-...',
            labelText: 'APIキー',
          ),
          obscureText: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              _saveOpenAIKey(controller.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('保存',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    // CSV export implementation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('CSVをエクスポートしています...')),
    );
  }
}

class _UserTile extends StatelessWidget {
  final dynamic user;
  const _UserTile({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundImage:
                user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
            backgroundColor: AppColors.primary,
            child: user.photoUrl == null
                ? Text(
                    (user.displayName?.isNotEmpty == true
                            ? user.displayName![0]
                            : user.email[0])
                        .toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.displayName ?? 'ユーザー',
                    style: Theme.of(context).textTheme.titleMedium),
                Text(user.email,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          if (user.isPremium == true)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [AppColors.warning, Color(0xFFFF6B00)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('PRO',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      subtitle: subtitle != null
          ? Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium)
          : null,
      trailing: trailing ??
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.textSecondary),
      onTap: onTap,
    );
  }
}
