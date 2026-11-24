/// Datenquelle (Firestore) und App-Zustand mit den Einstellungen auf dem Handy.
library;

import 'dart:async';
import 'dart:collection';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'modelle.dart';

abstract class Datenquelle {
  Stream<StellenDaten> stellen();
}

class FirestoreQuelle implements Datenquelle {
  final FirebaseFirestore _db;
  FirestoreQuelle([FirebaseFirestore? db]) : _db = db ?? FirebaseFirestore.instance;

  @override
  Stream<StellenDaten> stellen() =>
      _db.collection('meta').doc('stellen').snapshots().map((d) => StellenDaten.ausDaten(d.data()));
}

class AppZustand extends ChangeNotifier {
  final Datenquelle quelle;
  SharedPreferences? _prefs;
  final DateTime Function() _uhr;

  StellenDaten daten = const StellenDaten();
  bool geladen = false;
  Object? fehler;

  final LinkedHashSet<String> gesehen;
  final Set<String> gemerkt;
  final Set<String> beworben;
  final Set<String> ausgeblendet;

  /// Filter
  Set<String> laender;
  bool nurDeutsch;
  String suche = '';

  /// Aktiver Reiter unten (0 Stellen, 1 Merkliste, 2 Einstellungen).
  final ValueNotifier<int> reiter = ValueNotifier(0);

  final List<StreamSubscription<dynamic>> _abos = [];
  Timer? _takt;

  AppZustand({required this.quelle, SharedPreferences? prefs, DateTime Function()? uhr})
      : _prefs = prefs,
        _uhr = uhr ?? DateTime.now,
        gesehen = LinkedHashSet.of(prefs?.getStringList('gesehen') ?? const []),
        gemerkt = {...?prefs?.getStringList('gemerkt')},
        beworben = {...?prefs?.getStringList('beworben')},
        ausgeblendet = {...?prefs?.getStringList('ausgeblendet')},
        laender = {...(prefs?.getStringList('laender') ?? const ['CH', 'LI', 'DE', 'AT'])},
        nurDeutsch = prefs?.getBool('nurDeutsch') ?? false;

  DateTime jetzt() => _uhr();

  void starte() {
    _abos.add(quelle.stellen().listen((d) {
      daten = d;
      geladen = true;
      fehler = null;
      notifyListeners();
    }, onError: (Object e) {
      fehler = e;
      geladen = true;
      notifyListeners();
    }));
    _takt = Timer.periodic(const Duration(seconds: 60), (_) => notifyListeners());
  }

  Future<void> _speichere(Future<bool> Function(SharedPreferences p) schreiben) async {
    try {
      final p = _prefs ??= await SharedPreferences.getInstance();
      await schreiben(p);
    } catch (e) {
      debugPrint('Speichern fehlgeschlagen: $e');
    }
  }

  /// Stellen für die Hauptliste: aktiv, nicht ausgeblendet, nicht beworben, Filter angewendet.
  List<Stelle> get sichtbar {
    final q = suche.trim().toLowerCase();
    final liste = daten.stellen.where((s) {
      if (!s.aktiv || ausgeblendet.contains(s.id) || beworben.contains(s.id)) return false;
      if (s.land.isNotEmpty && !laender.contains(s.land)) return false;
      if (nurDeutsch && !s.deutschFreundlich) return false;
      if (q.isNotEmpty && !'${s.titel} ${s.firma} ${s.ort}'.toLowerCase().contains(q)) return false;
      return true;
    }).toList();
    liste.sort((a, b) {
      final n = (istNeu(b) ? 1 : 0) - (istNeu(a) ? 1 : 0);
      if (n != 0) return n;
      return b.ersterfasst.compareTo(a.ersterfasst);
    });
    return liste;
  }

  /// Neu = in den letzten 3 Tagen gefunden und noch nicht angetippt.
  bool istNeu(Stelle s) =>
      !gesehen.contains(s.id) &&
      s.ersterfasst.isAfter(jetzt().subtract(const Duration(days: 3))) &&
      (s.neu || s.ersterfasst.isAfter(jetzt().subtract(const Duration(days: 1))));

  int get neuAnzahl => sichtbar.where(istNeu).length;

  Stelle? stelleNachId(String id) {
    for (final s in daten.stellen) {
      if (s.id == id) return s;
    }
    return null;
  }

  List<Stelle> get merkliste => daten.stellen.where((s) => gemerkt.contains(s.id) || beworben.contains(s.id)).toList()
    ..sort((a, b) => (beworben.contains(a.id) ? 1 : 0) - (beworben.contains(b.id) ? 1 : 0));

  void markiereGesehen(String id) {
    if (!gesehen.add(id)) return;
    while (gesehen.length > 1500) {
      gesehen.remove(gesehen.first);
    }
    final liste = gesehen.toList();
    _speichere((p) => p.setStringList('gesehen', liste));
    notifyListeners();
  }

  void alleGesehen() {
    for (final s in sichtbar) {
      gesehen.add(s.id);
    }
    final liste = gesehen.toList();
    _speichere((p) => p.setStringList('gesehen', liste));
    notifyListeners();
  }

  void _umschalten(Set<String> menge, String id, String schluessel) {
    if (!menge.remove(id)) menge.add(id);
    final liste = menge.toList();
    _speichere((p) => p.setStringList(schluessel, liste));
    notifyListeners();
  }

  void umschaltenGemerkt(String id) => _umschalten(gemerkt, id, 'gemerkt');
  void umschaltenBeworben(String id) => _umschalten(beworben, id, 'beworben');
  void umschaltenAusgeblendet(String id) => _umschalten(ausgeblendet, id, 'ausgeblendet');

  void setzeLand(String land, bool an) {
    if (an) {
      laender.add(land);
    } else {
      laender.remove(land);
    }
    final liste = laender.toList();
    _speichere((p) => p.setStringList('laender', liste));
    notifyListeners();
  }

  void setzeNurDeutsch(bool wert) {
    nurDeutsch = wert;
    _speichere((p) => p.setBool('nurDeutsch', wert));
    notifyListeners();
  }

  void setzeSuche(String text) {
    suche = text;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final a in _abos) {
      a.cancel();
    }
    _takt?.cancel();
    reiter.dispose();
    super.dispose();
  }
}

class Zustand extends InheritedNotifier<AppZustand> {
  const Zustand({super.key, required AppZustand zustand, required super.child}) : super(notifier: zustand);

  static AppZustand von(BuildContext context) => context.dependOnInheritedWidgetOfExactType<Zustand>()!.notifier!;
  static AppZustand lesen(BuildContext context) => context.getInheritedWidgetOfExactType<Zustand>()!.notifier!;
}
