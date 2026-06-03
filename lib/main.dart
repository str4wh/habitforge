import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'screens/daily_checkin_screen.dart';
import 'screens/month_heatmap_screen.dart';
import 'screens/stats_screen.dart';
import 'services/notification_service.dart';

// Breakpoint: bottom nav below this, rail nav above
const kWideBreakpoint = 720.0;
// Max content width for all screens
const kMaxContentWidth = 700.0;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (!kIsWeb) {
    await NotificationService.init();
    await NotificationService.scheduleAll();
  }
  runApp(const ProviderScope(child: HabitForgeApp()));
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
        data: (_) => const MainShell(),
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
