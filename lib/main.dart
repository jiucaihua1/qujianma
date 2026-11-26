import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pages/identity_code_page.dart';
import 'pages/pickup_list_page.dart';
import 'pages/settings_page.dart';
import 'services/app_state.dart';
import 'services/ocr_service.dart';
import 'services/quick_tile_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const QujianmaApp());
}

class QujianmaApp extends StatefulWidget {
  const QujianmaApp({super.key, this.appState, this.ocrService});

  final AppState? appState;
  final OcrService? ocrService;

  @override
  State<QujianmaApp> createState() => _QujianmaAppState();
}

class _QujianmaAppState extends State<QujianmaApp> with WidgetsBindingObserver {
  late final AppState _appState;
  late final OcrService _ocrService;
  int _currentTab = 0;
  bool _appliedDefaultTab = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appState = widget.appState ?? AppState();
    _ocrService = widget.ocrService ?? OcrService();
    QuickTileService.setCallbacks(
      onDatabaseChanged: () {
        if (_appState.initialized) {
          _appState.reloadItems();
        }
      },
      onLaunchAction: _handleLaunchAction,
    );
    _initApp();
  }

  Future<void> _initApp() async {
    await _appState.init();
    if (!mounted) return;
    final launchAction = await QuickTileService.consumeLaunchAction();
    if (!mounted) return;
    if (!_appliedDefaultTab) {
      var targetTab = _appState.settings.defaultTabIndex.clamp(0, 1);
      if (launchAction == QuickTileService.actionOpenPickupTab) {
        targetTab = 1;
      } else if (launchAction == QuickTileService.actionOpenTileSetup) {
        targetTab = 2;
      }
      setState(() {
        _currentTab = targetTab;
        _appliedDefaultTab = true;
      });
    }
    await _checkClipboard();
  }

  void _handleLaunchAction(String action) {
    if (!mounted) return;
    if (action == QuickTileService.actionOpenPickupTab) {
      if (_appState.initialized) {
        _appState.reloadItems();
      }
      setState(() => _currentTab = 1);
    } else if (action == QuickTileService.actionOpenTileSetup) {
      setState(() => _currentTab = 2);
    } else if (action == QuickTileService.actionOpenDefaultTab) {
      setState(() => _currentTab = _appState.settings.defaultTabIndex.clamp(0, 1));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_appState.initialized) {
        _appState.reloadItems();
      }
      // Wait 350ms so Android 10–17 / HyperOS window finishes gaining input focus
      // before reading the clipboard.
      Future<void>.delayed(const Duration(milliseconds: 350), () {
        if (mounted) {
          _checkClipboard();
        }
      });
    }
  }

  Future<void> _checkClipboard() async {
    if (!_appState.initialized || !_appState.settings.autoDetectClipboard) {
      return;
    }
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      _appState.inspectClipboardText(data?.text);
    } catch (_) {
      // Ignore clipboard permission denials quietly.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.appState == null) {
      _appState.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '取件码',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: AnimatedBuilder(
        animation: _appState,
        builder: (context, _) {
          if (!_appState.initialized) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final pendingCount = _appState.pendingCount;

          return Scaffold(
            body: IndexedStack(
              index: _currentTab,
              children: [
                IdentityCodePage(
                  appState: _appState,
                  onGoToPickupTab: () => setState(() => _currentTab = 1),
                  onGoToSettingsTab: () => setState(() => _currentTab = 2),
                ),
                PickupListPage(
                  appState: _appState,
                  ocrService: _ocrService,
                ),
                SettingsPage(appState: _appState),
              ],
            ),
            bottomNavigationBar: Container(
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppTheme.cardBorder, width: 1),
                ),
              ),
              child: NavigationBar(
                selectedIndex: _currentTab,
                onDestinationSelected: (index) {
                  setState(() => _currentTab = index);
                },
                destinations: [
                  const NavigationDestination(
                    icon: Icon(Icons.qr_code_2_outlined),
                    selectedIcon: Icon(Icons.qr_code_2_rounded),
                    label: '身份码',
                  ),
                  NavigationDestination(
                    icon: Badge(
                      isLabelVisible: pendingCount > 0,
                      label: Text('$pendingCount'),
                      child: const Icon(Icons.inventory_2_outlined),
                    ),
                    selectedIcon: Badge(
                      isLabelVisible: pendingCount > 0,
                      label: Text('$pendingCount'),
                      child: const Icon(Icons.inventory_2_rounded),
                    ),
                    label: '取件一览',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings_rounded),
                    label: '设置',
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
