import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:mkvoodoo_ui/services/backend_bridge.dart';
import 'package:mkvoodoo_ui/services/theme_provider.dart';
import 'package:mkvoodoo_ui/controllers/dashboard_controller.dart';
import 'package:mkvoodoo_ui/controllers/wizard_controller.dart';
import 'package:mkvoodoo_ui/controllers/queue_controller.dart';
import 'package:mkvoodoo_ui/controllers/settings_controller.dart';
import 'package:mkvoodoo_ui/controllers/youtube_controller.dart';
import 'package:mkvoodoo_ui/controllers/navigation_controller.dart';
import 'package:mkvoodoo_ui/controllers/clipper_controller.dart';
import 'package:mkvoodoo_ui/services/backend_clipper_api.dart';
import 'package:media_kit/media_kit.dart';
import 'package:mkvoodoo_ui/pages/dashboard_page.dart';
import 'package:mkvoodoo_ui/pages/wizard_page.dart';
import 'package:mkvoodoo_ui/pages/queue_page.dart';
import 'package:mkvoodoo_ui/pages/settings_page.dart';
import 'package:mkvoodoo_ui/pages/youtube_page.dart';
import 'package:mkvoodoo_ui/pages/clipper_page.dart';

void main() {
  MediaKit.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        Provider(create: (_) => BackendBridge()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(
          create: (context) =>
              DashboardController(context.read<BackendBridge>()),
        ),
        ChangeNotifierProvider(
          create: (context) => WizardController(context.read<BackendBridge>()),
        ),
        ChangeNotifierProvider(
          create: (context) => QueueController(context.read<BackendBridge>()),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              SettingsController(context.read<BackendBridge>()),
        ),
        ChangeNotifierProvider(
          create: (context) => YoutubeController(context.read<BackendBridge>()),
        ),
        ChangeNotifierProvider(create: (_) => NavigationController()),
        ChangeNotifierProvider(
          create: (context) => ClipperController(
            BackendClipperApi(context.read<BackendBridge>()),
          ),
        ),
      ],
      child: const MKVoodooApp(),
    ),
  );
}

class MKVoodooApp extends StatelessWidget {
  const MKVoodooApp({super.key, this.clipperPage = const ClipperPage()});

  final Widget clipperPage;

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    final darkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF39FF14),
        brightness: Brightness.dark,
        surface: const Color(0xFF0A0A0E), // Solid surface for overlays
        primary: const Color(0xFF39FF14),
        secondary: const Color(0xFFB900FF),
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      scaffoldBackgroundColor: Colors.transparent,
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.03),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
        elevation: 0,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: const Color(0xFF39FF14).withValues(alpha: 0.15),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        selectedIconTheme: const IconThemeData(
          color: Color(0xFF39FF14),
          size: 28,
        ),
        unselectedIconTheme: IconThemeData(
          color: Colors.white.withValues(alpha: 0.4),
          size: 24,
        ),
        selectedLabelTextStyle: const TextStyle(
          color: Color(0xFF39FF14),
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.4),
          fontSize: 12,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.05),
        thickness: 1,
      ),
    );

    final lightTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF39FF14),
        brightness: Brightness.light,
        surface: const Color(0xFFF0F0F0), // Solid surface for overlays
        primary: const Color(0xFF39FF14),
        secondary: const Color(0xFFB900FF),
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
      scaffoldBackgroundColor: Colors.transparent,
      cardTheme: CardThemeData(
        color: Colors.black.withValues(alpha: 0.03),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
        ),
        elevation: 0,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: const Color(0xFF39FF14).withValues(alpha: 0.15),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        selectedIconTheme: const IconThemeData(
          color: Color(0xFF39FF14),
          size: 28,
        ),
        unselectedIconTheme: IconThemeData(
          color: Colors.black.withValues(alpha: 0.4),
          size: 24,
        ),
        selectedLabelTextStyle: const TextStyle(
          color: Color(0xFF39FF14),
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: Colors.black.withValues(alpha: 0.4),
          fontSize: 12,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.black.withValues(alpha: 0.05),
        thickness: 1,
      ),
    );

    return MaterialApp(
      title: 'MKVoodoo',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      theme: lightTheme,
      darkTheme: darkTheme,
      home: MainLayout(clipperPage: clipperPage),
    );
  }
}

class MainLayout extends StatefulWidget {
  const MainLayout({super.key, this.clipperPage = const ClipperPage()});

  final Widget clipperPage;

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavigationController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF030305)
          : const Color(0xFFF9F9F9),
      body: Container(
        decoration: isDark
            ? const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.8, -0.8),
                  radius: 1.5,
                  colors: [
                    Color(0xFF1A0A2E), // Subtle mystic purple tint
                    Color(0xFF050508), // Deep dark
                  ],
                ),
              )
            : null,
        child: Row(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 8, 16),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.02)
                    : Colors.black.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.05),
                ),
                boxShadow: [
                  if (isDark)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: NavigationRail(
                backgroundColor: Colors.transparent,
                selectedIndex: nav.selectedIndex,
                onDestinationSelected: (int index) {
                  nav.navigateTo(index);
                },
                labelType: NavigationRailLabelType.all,
                groupAlignment: -0.9,
                leading: Column(
                  children: [
                    const SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF39FF14,
                            ).withValues(alpha: 0.25),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          isDark
                              ? 'assets/MKVoodoo logo - Final - Dark Background.png'
                              : 'assets/MKVoodoo logo - Final - Light Background.png',
                          width: 56,
                          height: 56,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.dashboard_rounded),
                    label: Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text('Dashboard'),
                    ),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.add_to_photos_rounded),
                    label: Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text('New Job'),
                    ),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.smart_display_rounded),
                    label: Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text('YouTube'),
                    ),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.content_cut_rounded),
                    label: Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text('Clipper'),
                    ),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.queue_play_next_rounded),
                    label: Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text('Queue'),
                    ),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.settings_rounded),
                    label: Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text('Settings'),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody(nav.selectedIndex)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(int selectedIndex) {
    return IndexedStack(
      index: selectedIndex,
      children: [
        const DashboardPage(),
        const WizardPage(),
        const YoutubePage(),
        widget.clipperPage,
        const QueuePage(),
        const SettingsPage(),
      ],
    );
  }
}
