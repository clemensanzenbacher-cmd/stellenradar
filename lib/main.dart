import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'daten.dart';
import 'push.dart';
import 'screens/shell.dart';
import 'screens/stelle_blatt.dart';
import 'theme.dart';
import 'widgets/bausteine.dart';

final ValueNotifier<String?> startFehler = ValueNotifier(null);

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      startFehler.value ??= details.exceptionAsString();
    };
    PlatformDispatcher.instance.onError = (fehler, stack) {
      startFehler.value ??= '$fehler';
      return true;
    };
    ErrorWidget.builder = (details) => Material(
          color: Farben.fehlerFlaeche,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Anzeigefehler: ${details.exceptionAsString()}',
                style: const TextStyle(color: Farben.fehler, fontSize: 13)),
          ),
        );
    runApp(const Startrahmen());
  }, (fehler, stack) {
    startFehler.value ??= '$fehler';
  });
}

/// Zeigt sofort einen Ladebildschirm, startet Firebase und wechselt dann in die App.
class Startrahmen extends StatefulWidget {
  const Startrahmen({super.key});

  @override
  State<Startrahmen> createState() => _StartrahmenState();
}

class _StartrahmenState extends State<Startrahmen> {
  AppZustand? _zustand;
  String _schritt = 'Starte …';
  String? _fehler;
  bool _laeuft = false;

  @override
  void initState() {
    super.initState();
    startFehler.addListener(_fehlerGemeldet);
    _starte();
  }

  @override
  void dispose() {
    startFehler.removeListener(_fehlerGemeldet);
    super.dispose();
  }

  void _fehlerGemeldet() {
    final f = startFehler.value;
    if (_zustand == null && f != null && mounted) setState(() => _fehler ??= f);
  }

  void _setze(String schritt) {
    if (mounted) setState(() => _schritt = schritt);
  }

  Future<void> _starte() async {
    if (_laeuft) return;
    _laeuft = true;
    setState(() => _fehler = null);
    try {
      _setze('Verbinde mit Firebase …');
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp().timeout(const Duration(seconds: 20));
      }
      _setze('Lade Einstellungen …');
      SharedPreferences? prefs;
      try {
        prefs = await SharedPreferences.getInstance().timeout(const Duration(seconds: 8));
      } catch (e) {
        debugPrint('Einstellungen nicht verfügbar: $e');
      }
      _setze('Lade Stellen …');
      final zustand = AppZustand(quelle: FirestoreQuelle(), prefs: prefs)..starte();
      if (mounted) setState(() => _zustand = zustand);
    } on TimeoutException {
      if (mounted) setState(() => _fehler = 'Zeitüberschreitung bei „$_schritt“ – ist das Handy online?');
    } catch (e) {
      if (mounted) setState(() => _fehler = '$e');
    } finally {
      _laeuft = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final z = _zustand;
    if (z != null) return StellenRadarApp(zustand: z);
    final fehler = _fehler;
    if (fehler != null) return StartfehlerApp(fehler: fehler, schritt: _schritt, nochmal: _starte);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: baueTheme(),
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.engineering, size: 64, color: Farben.akzent),
              const SizedBox(height: 16),
              Text('StellenRadar', style: Schrift.h1(28)),
              const SizedBox(height: 24),
              const SizedBox(
                  width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3, color: Farben.akzent)),
              const SizedBox(height: 14),
              Text(_schritt, style: Schrift.body(14, Farben.textMittel)),
            ],
          ),
        ),
      ),
    );
  }
}

class StellenRadarApp extends StatefulWidget {
  final AppZustand zustand;

  /// In Tests `false`: dann wird Firebase Messaging nicht angefasst.
  final bool mitPush;
  const StellenRadarApp({super.key, required this.zustand, this.mitPush = true});

  @override
  State<StellenRadarApp> createState() => _StellenRadarAppState();
}

class _StellenRadarAppState extends State<StellenRadarApp> {
  final _navigator = GlobalKey<NavigatorState>();
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  Push? _push;

  @override
  void initState() {
    super.initState();
    if (widget.mitPush) {
      _push = Push(messenger: _messenger, oeffnen: _oeffneAusPush);
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          await _push?.starte();
        } catch (e) {
          debugPrint('Push nicht verfügbar: $e');
        }
      });
    }
  }

  /// Tippen auf eine Benachrichtigung: Stelle öffnen bzw. zur Liste.
  void _oeffneAusPush(String id, String url) {
    final nav = _navigator.currentState;
    if (nav == null) return;
    nav.popUntil((r) => r.isFirst);
    widget.zustand.reiter.value = 0;
    final kontext = _navigator.currentContext;
    if (kontext == null) return;
    final stelle = widget.zustand.stelleNachId(id);
    if (stelle != null) {
      zeigeStelle(kontext, stelle);
    } else if (url.isNotEmpty) {
      oeffneLink(kontext, url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Zustand(
      zustand: widget.zustand,
      child: MaterialApp(
        title: 'StellenRadar',
        debugShowCheckedModeBanner: false,
        navigatorKey: _navigator,
        scaffoldMessengerKey: _messenger,
        theme: baueTheme(),
        locale: const Locale('de', 'DE'),
        supportedLocales: const [Locale('de', 'DE')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Hauptrahmen(push: _push),
      ),
    );
  }
}

class StartfehlerApp extends StatelessWidget {
  final Object fehler;
  final String schritt;
  final VoidCallback? nochmal;
  const StartfehlerApp({super.key, required this.fehler, this.schritt = '', this.nochmal});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: baueTheme(),
      home: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text('StellenRadar startet nicht', style: Schrift.h1(24)),
              const SizedBox(height: 12),
              Text(
                'Bitte ein Bildschirmfoto davon an Claude schicken. '
                '${schritt.isEmpty ? '' : 'Hängen geblieben bei: $schritt'}',
                style: Schrift.body(15, Farben.textMittel),
              ),
              const SizedBox(height: 16),
              SelectableText('$fehler', style: Schrift.klein(Farben.fehler, 13)),
              if (nochmal != null) ...[
                const SizedBox(height: 24),
                HauptKnopf('Erneut versuchen', symbol: Icons.refresh, onTap: nochmal),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
