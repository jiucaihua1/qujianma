import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qujianma/models/app_settings.dart';
import 'package:qujianma/models/identity_shortcut.dart';
import 'package:qujianma/models/pickup_item.dart';
import 'package:qujianma/pages/identity_code_page.dart';
import 'package:qujianma/services/app_state.dart';

class _FakeAppState extends AppState {
  _FakeAppState({List<PickupItem>? items}) : _items = items ?? [];

  final List<PickupItem> _items;

  @override
  bool get initialized => true;

  @override
  List<PickupItem> get pendingItems => _items;

  @override
  int get pendingCount => _items.length;

  @override
  AppSettings get settings => const AppSettings();

  @override
  List<IdentityShortcut> get shortcuts => IdentityShortcut.defaults();

  @override
  List<IdentityShortcut> get visibleShortcuts => IdentityShortcut.defaults();

  @override
  Map<String, List<PickupItem>> get groupedPendingByStation {
    final map = <String, List<PickupItem>>{};
    for (final item in _items) {
      map.putIfAbsent(item.stationName, () => []).add(item);
    }
    return map;
  }
}

void main() {
  testWidgets('IdentityCodePage renders shortcuts and pending summary', (
    tester,
  ) async {
    var tappedPickup = false;
    final state = _FakeAppState(
      items: [
        PickupItem(
          id: 1,
          code: '12-3-405',
          stationName: '菜鸟驿站',
          createdAt: DateTime(2026, 11, 24),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IdentityCodePage(
            appState: state,
            onGoToPickupTab: () => tappedPickup = true,
            onGoToSettingsTab: () {},
          ),
        ),
      ),
    );

    expect(find.text('身份码'), findsOneWidget);
    expect(find.text('待取 1 件'), findsOneWidget);
    expect(find.text('淘宝 / 菜鸟身份码'), findsOneWidget);
    expect(find.text('拼多多身份码'), findsOneWidget);

    await tester.tap(find.text('待取 1 件'));
    expect(tappedPickup, isTrue);
  });
}
