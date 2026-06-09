import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'firebase_options.dart';
import 'models/habit.dart';
import 'providers/auth_provider.dart';
import 'providers/habits_provider.dart';
import 'screens/daily_checkin_screen.dart';
import 'screens/month_heatmap_screen.dart';
import 'screens/shame_wall_screen.dart';
import 'screens/stats_screen.dart';
import 'services/firestore_service.dart';
import 'services/notification_service.dart';
import 'services/progression_service.dart';
import 'services/rollover_service.dart';
import 'services/widget_service.dart';
import 'utils/web_utils.dart';
import 'utils/week_utils.dart';

// Breakpoint: bottom nav below this, rail nav above
const kWideBreakpoint = 720.0;
// Max content width for all screens
const kMaxContentWidth = 700.0;

// ── WorkManager background callback ──────────────────────────────────────────

@pragma('vm:entry-point')
void _workmanagerDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('current_uid');
      if (uid != null) {
        await ProgressionService.maybeRunMonday(uid);
        await RolloverService.maybeRunMidnight(uid);
        await WidgetService.updateWidget(uid);
      }
    } catch (_) {}
    return true;
  });
}

// ── Entry point ───────────────────────────────────────────────────────────────

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (!kIsWeb) {
    await NotificationService.init();
    await NotificationService.scheduleAll();
    // Persist UID so the background isolate can use it
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      final prefs = await SharedPreferences.getInstance();
      if (user != null) {
        await prefs.setString('current_uid', user.uid);
      } else {
        await prefs.remove('current_uid');
      }
    });
    // WorkManager and home_widget are Android-only
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _initWorkManager();
    }
  }
  runApp(const ProviderScope(child: HabitForgeApp()));
}

Future<void> _initWorkManager() async {
  await Workmanager().initialize(_workmanagerDispatcher,
      isInDebugMode: kDebugMode);
  await Workmanager().registerPeriodicTask(
    'habitforge_widget_refresh',
    'widgetRefreshTask',
    frequency: const Duration(minutes: 30),
    existingWorkPolicy: ExistingWorkPolicy.keep,
    constraints: Constraints(networkType: NetworkType.connected),
  );
}

class HabitForgeApp extends ConsumerWidget {
  const HabitForgeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authProvider);
    return MaterialApp(
      title: 'HabitForge',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A1A2E),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0D0D1A),
        useMaterial3: true,
      ),
      home: authAsync.when(
        data: (user) => user == null
            ? const _SplashScreen()
            : _PwaBannerWrapper(
                child: _ShameGate(uid: user.uid),
              ),
        loading: () => const _SplashScreen(),
        error: (e, _) => _ErrorScreen(error: e),
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0D0D1A),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'HabitForge',
              style: TextStyle(
                color: Color(0xFFFF6B35),
                fontSize: 36,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            SizedBox(height: 32),
            CircularProgressIndicator(color: Color(0xFFFF6B35)),
          ],
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final Object error;
  const _ErrorScreen({required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Startup error: $error\n\nCheck firebase_options.dart and run flutterfire configure.',
            style: const TextStyle(color: Colors.white70, height: 1.6),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

// ── Shell ────────────────────────────────────────────────────────────────────

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _screens = [
    DailyCheckinScreen(),
    MonthHeatmapScreen(),
    StatsScreen(),
  ];

  static const _destinations = [
    (Icons.check_circle_outline, Icons.check_circle, 'Today'),
    (Icons.calendar_month_outlined, Icons.calendar_month, 'Month'),
    (Icons.bar_chart_outlined, Icons.bar_chart, 'Stats'),
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= kWideBreakpoint;

    if (isWide) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0D1A),
        body: Row(
          children: [
            _SideRail(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: _destinations,
            ),
            Container(width: 1, color: const Color(0xFF2A2A4A)),
            Expanded(child: _screens[_index]),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: _screens[_index],
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF12122A),
        indicatorColor: const Color(0xFF2A1A0E),
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final (outline, filled, label) in _destinations)
            NavigationDestination(
              icon: Icon(outline),
              selectedIcon: Icon(filled, color: const Color(0xFFFF6B35)),
              label: label,
            ),
        ],
      ),
    );
  }
}

class _SideRail extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<(IconData, IconData, String)> destinations;

  const _SideRail({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      color: const Color(0xFF0A0A18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 48),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'HabitForge',
                  style: TextStyle(
                    color: Color(0xFFFF6B35),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Daily Discipline',
                  style: TextStyle(color: Colors.white30, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          for (int i = 0; i < destinations.length; i++)
            _RailItem(
              icon: destinations[i].$1,
              selectedIcon: destinations[i].$2,
              label: destinations[i].$3,
              selected: selectedIndex == i,
              onTap: () => onDestinationSelected(i),
            ),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RailItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF2A1A0E)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              selected ? selectedIcon : icon,
              color: selected
                  ? const Color(0xFFFF6B35)
                  : Colors.white38,
              size: 22,
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                color: selected ? const Color(0xFFFF6B35) : Colors.white54,
                fontWeight:
                    selected ? FontWeight.bold : FontWeight.normal,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shame Gate ───────────────────────────────────────────────────────────────

final _dateFmt = DateFormat('yyyy-MM-dd');

enum _ShameGateStatus { checking, shameNeeded, clear }

class _ShameGate extends ConsumerStatefulWidget {
  final String uid;
  const _ShameGate({required this.uid});

  @override
  ConsumerState<_ShameGate> createState() => _ShameGateState();
}

class _ShameGateState extends ConsumerState<_ShameGate> {
  _ShameGateStatus _status = _ShameGateStatus.checking;
  List<MissedPunishment> _punishments = [];
  List<String> _extraMessages = [];
  late String _todayDate;

  @override
  void initState() {
    super.initState();
    _todayDate = _dateFmt.format(DateTime.now());
    _check();
  }

  Future<void> _check() async {
    // Run rollover on app open (guard inside prevents double-running per day)
    if (!kIsWeb) {
      await RolloverService.maybeRunMidnight(widget.uid);
    }
    // Only show once per calendar day
    final prefs = await SharedPreferences.getInstance();
    final lastShown = prefs.getString('shame_wall_last_shown');
    if (lastShown == _todayDate) {
      _goToClear();
      return;
    }

    final yesterday = _dateFmt.format(
      DateTime.now().subtract(const Duration(days: 1)),
    );

    final yesterdayLog = await FirestoreService.fetchLog(widget.uid, yesterday);

    // Wait for active habits to be available from the provider
    // They may already be cached; if not, we do a one-shot fetch
    List<Habit> activeHabits = ref.read(activeHabitsProvider);
    if (activeHabits.isEmpty) {
      // Habits stream may not have emitted yet — wait briefly
      for (int i = 0; i < 10 && activeHabits.isEmpty; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        if (!mounted) return;
        activeHabits = ref.read(activeHabitsProvider);
      }
    }

    if (!mounted) return;

    final punishments = computePunishments(activeHabits, yesterdayLog);

    // Monday: check if last week had no plan submitted
    final extras = <String>[];
    final now = DateTime.now();
    if (now.weekday == DateTime.monday) {
      final lastWeekKey =
          isoWeekKey(now.subtract(const Duration(days: 7)));
      final planned = await FirestoreService.isWeeklyPlanSubmitted(
          widget.uid, lastWeekKey);
      if (!planned) {
        extras.add(
          'You never planned last week ($lastWeekKey). '
          'Open the Stats tab → Plan This Week so this stops happening.',
        );
      }
    }

    if (punishments.isEmpty && extras.isEmpty) {
      _goToClear();
    } else if (punishments.isEmpty) {
      // Only extra messages — show shame wall anyway
      await prefs.setString('shame_wall_last_shown', _todayDate);
      setState(() {
        _extraMessages = extras;
        _status = _ShameGateStatus.shameNeeded;
      });
    } else {
      await prefs.setString('shame_wall_last_shown', _todayDate);
      setState(() {
        _punishments = punishments;
        _extraMessages = extras;
        _status = _ShameGateStatus.shameNeeded;
      });
    }
  }

  void _goToClear() {
    if (mounted) setState(() => _status = _ShameGateStatus.clear);
  }

  @override
  Widget build(BuildContext context) {
    switch (_status) {
      case _ShameGateStatus.checking:
        return const _SplashScreen();
      case _ShameGateStatus.clear:
        return const MainShell();
      case _ShameGateStatus.shameNeeded:
        return ShameWallScreen(
          uid: widget.uid,
          todayDate: _todayDate,
          punishments: _punishments,
          extraMessages: _extraMessages,
          onAccepted: _goToClear,
        );
    }
  }
}

// ── PWA Install Banner ────────────────────────────────────────────────────────

bool _isRunningAsStandalone() {
  if (!kIsWeb) return true;
  return isStandalonePwa();
}

enum _PwaPlatform { ios, android, other }

_PwaPlatform _detectPlatform() {
  if (!kIsWeb) return _PwaPlatform.other;
  final ua = getBrowserUserAgent();
  if (ua.contains('iphone') || ua.contains('ipad') || ua.contains('ipod')) {
    return _PwaPlatform.ios;
  }
  if (ua.contains('android')) return _PwaPlatform.android;
  return _PwaPlatform.other;
}

class _PwaBannerWrapper extends StatefulWidget {
  final Widget child;
  const _PwaBannerWrapper({required this.child});

  @override
  State<_PwaBannerWrapper> createState() => _PwaBannerWrapperState();
}

class _PwaBannerWrapperState extends State<_PwaBannerWrapper> {
  bool _showBanner = false;

  @override
  void initState() {
    super.initState();
    _checkBanner();
  }

  Future<void> _checkBanner() async {
    if (_isRunningAsStandalone()) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('pwa_banner_dismissed') == true) return;
    if (prefs.getBool('pwa_banner_shown') == true) return;
    await prefs.setBool('pwa_banner_shown', true);
    if (mounted) setState(() => _showBanner = true);
  }

  Future<void> _dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pwa_banner_dismissed', true);
    if (mounted) setState(() => _showBanner = false);
  }

  Future<void> _later() async {
    // Hide for this session; next open the banner will appear again
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pwa_banner_shown');
    if (mounted) setState(() => _showBanner = false);
  }

  void _showInstructions() {
    final platform = _detectPlatform();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PwaInstructionsSheet(
        platform: platform,
        onDismiss: _dismiss,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_showBanner)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _PwaBanner(
              onShowHow: _showInstructions,
              onDone: _dismiss,
              onLater: _later,
            ),
          ),
      ],
    );
  }
}

class _PwaBanner extends StatelessWidget {
  final VoidCallback onShowHow;
  final VoidCallback onDone;
  final VoidCallback onLater;
  const _PwaBanner({
    required this.onShowHow,
    required this.onDone,
    required this.onLater,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1A1A2E),
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "You're missing notifications. Add HabitForge to your Home Screen to receive daily accountability alerts.",
                style: TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onLater,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white54,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        textStyle: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      child: const Text('Later'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: onShowHow,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B35),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        textStyle: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      child: const Text('Download'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PwaInstructionsSheet extends StatelessWidget {
  final _PwaPlatform platform;
  final VoidCallback onDismiss;

  const _PwaInstructionsSheet({
    required this.platform,
    required this.onDismiss,
  });

  void _downloadApk() {
    triggerApkDownload();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Install HabitForge',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Get daily accountability alerts on your device.',
            style: TextStyle(color: Colors.white54, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          if (platform == _PwaPlatform.android) ...[
            // ── Option 1: APK ────────────────────────────────────────────────
            _InstallOption(
              icon: Icons.android,
              iconColor: const Color(0xFF00C853),
              title: 'Install Android App (Recommended)',
              subtitle: 'Full native app — better performance and notifications.',
              steps: const [
                '1. Tap "Download APK" below',
                '2. Open the downloaded file',
                '3. If prompted, enable "Install from unknown sources"\n   Settings → Apps → Special app access → Install unknown apps',
                '4. Tap Install',
              ],
              action: ElevatedButton.icon(
                onPressed: () {
                  _downloadApk();
                  Navigator.of(context).pop();
                  onDismiss();
                },
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Download APK'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C853),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ── Option 2: PWA ────────────────────────────────────────────────
            _InstallOption(
              icon: Icons.add_to_home_screen,
              iconColor: const Color(0xFFFF6B35),
              title: 'Or Add to Home Screen (PWA)',
              subtitle: 'Quick shortcut — works without downloading anything.',
              steps: const [
                "Tap Chrome's three-dot menu (⋮)",
                "Tap 'Add to Home Screen'",
                'Tap Add',
              ],
              action: OutlinedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onDismiss();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white54,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(fontSize: 14),
                ),
                child: const Text("Got it, I'll do it"),
              ),
            ),
          ] else ...[
            // ── iOS / Other: single instruction block ────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D1A),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    platform == _PwaPlatform.ios
                        ? Icons.ios_share
                        : Icons.info_outline,
                    color: const Color(0xFFFF6B35),
                    size: 28,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      platform == _PwaPlatform.ios
                          ? "Tap the Share button → Scroll down → Tap 'Add to Home Screen' → Tap Add"
                          : "Open this app in Safari (iOS) or Chrome (Android) for notifications to work",
                      style: const TextStyle(
                          color: Colors.white, fontSize: 15, height: 1.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onDismiss();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B35),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                child: const Text("Got it, I'll do it"),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InstallOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final List<String> steps;
  final Widget action;

  const _InstallOption({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.steps,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2A4A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 14),
          ...steps.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                s,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 13, height: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 14),
          action,
        ],
      ),
    );
  }
}
