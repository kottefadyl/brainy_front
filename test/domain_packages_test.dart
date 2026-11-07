import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brainy/auth_api.dart';
import 'package:brainy/collections_api.dart';
import 'package:brainy/domain_packages_sheet.dart';

class PackageAuth extends AuthApi {
  bool conflict = false;
  final calls = <String>[];
  @override
  Future<Map<String, dynamic>> authenticatedRequest(
    String query,
    Map<String, dynamic> variables, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    if (query.contains('domainPackagePilots')) {
      calls.add('pilots');
      return {
        'domainPackagePilots': [
          {
            'id': 'brainy.simple-sales',
            'version': '1.0.0',
            'name': 'Ventes simples',
            'description': 'Produits avec prix et ventes avec total calculé.',
            'packageJson': '{"id":"brainy.simple-sales"}',
          },
        ],
      };
    }
    if (query.contains('previewDomainPackage')) {
      calls.add('preview:${variables['collectionId']}');
      return {
        'previewDomainPackage': {
          'packageId': 'brainy.simple-sales',
          'version': '1.0.0',
          'name': 'Ventes simples',
          'description': 'Produits et ventes',
          'notice': 'Chaque vente garde son prix.',
          'author': 'Brainy',
          'license': 'CC0-1.0',
          'publishedAt': '2026-11-07',
          'signatureStatus': 'NONE',
          'keyFingerprint': null,
          'mode': conflict ? 'INSTALL' : 'NEW_COLLECTION',
          'installedVersion': null,
          'dataFormats': ['Produit', 'Vente'],
          'addedFields': <String>[],
          'units': <String>[],
          'codeLists': <String>[],
          'views': ['Ventes'],
          'formulas': ['Total'],
          'stockRules': <String>[],
          'exampleObjects': 1,
          'dependencies': ['Unités intégrées : €'],
          'adjustments': <String>[],
          'conflicts': conflict
              ? [
                  'Un format de données nommé Produit existe déjà dans cette collection',
                ]
              : <String>[],
          'allowed': !conflict,
        },
      };
    }
    if (query.contains('installDomainPackage')) {
      calls.add('install:${variables['collectionName']}');
      return {
        'installDomainPackage': {'collectionId': 'installed'},
      };
    }
    throw UnimplementedError(query);
  }
}

Widget host(PackageAuth auth, void Function(String?) onResult) => MaterialApp(
  locale: const Locale('fr'),
  supportedLocales: const [Locale('en'), Locale('fr')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: Scaffold(
    body: Builder(
      builder: (context) => ElevatedButton(
        onPressed: () async => onResult(
          await showDomainPackages(
            context,
            api: CollectionsApi(auth),
            collections: const [],
            userId: 'me',
            userName: 'Camille',
            french: true,
          ),
        ),
        child: const Text('Open'),
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'mobile: a Brainy package is previewed then installed as a new collection',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final auth = PackageAuth();
      String? result;
      await tester.pumpWidget(host(auth, (value) => result = value));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Installer une copie locale'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Installer une copie locale'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Ventes simples'));
      await tester.pumpAndSettle();
      expect(find.text('Nouvelle collection'), findsWidgets);
      expect(find.text('Chaque vente garde son prix.'), findsOneWidget);
      expect(find.text('• Produit'), findsOneWidget);
      await tester.tap(
        find.widgetWithText(FilledButton, 'Installer une copie locale'),
      );
      await tester.pumpAndSettle();
      expect(auth.calls, contains('install:Ventes simples'));
      expect(result, 'installed');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('conflicts block installation with a visible reason', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = PackageAuth()..conflict = true;
    await tester.pumpWidget(host(auth, (_) {}));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ventes simples'));
    await tester.pumpAndSettle();
    expect(find.text('Conflits à résoudre'), findsOneWidget);
    expect(find.textContaining('L’installation est bloquée'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Installer une copie locale'),
          )
          .onPressed,
      isNull,
    );
    expect(auth.calls.where((call) => call.startsWith('install')), isEmpty);
    expect(tester.takeException(), isNull);
  });
}
