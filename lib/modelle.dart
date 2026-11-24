/// Datenmodelle. Die Felder entsprechen dem Firestore-Dokument `meta/stellen`,
/// das der Wächter schreibt (waechter/waechter.py: Stelle.fuer_speicher und meta).
library;

import 'package:cloud_firestore/cloud_firestore.dart';

String _text(Object? v) => v is String ? v : '';
bool? _wahrOderNull(Object? v) => v is bool ? v : null;

DateTime? zeitAus(Object? v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  return null;
}

class Stelle {
  final String id;
  final String titel;
  final String firma;
  final String ort;
  final String land;
  final String url;
  final String quelle;
  final DateTime? datum;
  final DateTime ersterfasst;

  /// Sprache der Anzeige: de, en oder fr (vom Wächter geschätzt).
  final String sprache;

  /// Nur bei jobs.ch/jobup.ch bekannt: verlangt die Anzeige gutes Englisch?
  final bool? englischPflicht;
  final List<String> sprachen;
  final String vorschau;
  final bool neu;
  final bool aktiv;

  const Stelle({
    required this.id,
    required this.titel,
    required this.firma,
    required this.ort,
    required this.land,
    required this.url,
    required this.quelle,
    this.datum,
    required this.ersterfasst,
    this.sprache = 'de',
    this.englischPflicht,
    this.sprachen = const [],
    this.vorschau = '',
    this.neu = false,
    this.aktiv = true,
  });

  static Stelle? ausDaten(Map<String, dynamic> d) {
    final id = _text(d['id']);
    final url = _text(d['url']);
    if (id.isEmpty || url.isEmpty) return null;
    return Stelle(
      id: id,
      titel: _text(d['titel']),
      firma: _text(d['firma']),
      ort: _text(d['ort']),
      land: _text(d['land']),
      url: url,
      quelle: _text(d['quelle']),
      datum: zeitAus(d['datum']),
      ersterfasst: zeitAus(d['ersterfasst']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      sprache: _text(d['sprache']).isEmpty ? 'de' : _text(d['sprache']),
      englischPflicht: _wahrOderNull(d['englischPflicht']),
      sprachen: [for (final s in (d['sprachen'] as List? ?? const [])) '$s'],
      vorschau: _text(d['vorschau']),
      neu: d['neu'] == true,
      aktiv: d['aktiv'] != false,
    );
  }

  String get ortText => [ort, land].where((s) => s.isNotEmpty).join(', ');

  /// Deutsche Anzeige ohne Pflicht-Englisch – Clemens' Wunsch.
  bool get deutschFreundlich => sprache == 'de' && englischPflicht != true;
}

class QuellenStatus {
  final String name;
  final bool ok;
  final int gefunden;
  final int passend;
  final String fehler;
  const QuellenStatus(this.name, {this.ok = true, this.gefunden = 0, this.passend = 0, this.fehler = ''});
}

class StellenDaten {
  final List<Stelle> stellen;
  final DateTime? letzterLauf;
  final List<QuellenStatus> quellen;
  const StellenDaten({this.stellen = const [], this.letzterLauf, this.quellen = const []});

  static StellenDaten ausDaten(Map<String, dynamic>? d) {
    if (d == null) return const StellenDaten();
    final stellen = <Stelle>[];
    for (final e in (d['stellen'] as List? ?? const [])) {
      if (e is Map) {
        final s = Stelle.ausDaten(e.cast<String, dynamic>());
        if (s != null) stellen.add(s);
      }
    }
    final quellen = <QuellenStatus>[];
    final q = d['quellen'];
    if (q is Map) {
      for (final e in q.entries) {
        final v = e.value is Map ? (e.value as Map).cast<String, dynamic>() : const <String, dynamic>{};
        quellen.add(QuellenStatus('${e.key}',
            ok: v['ok'] != false,
            gefunden: (v['gefunden'] as num?)?.toInt() ?? 0,
            passend: (v['passend'] as num?)?.toInt() ?? 0,
            fehler: _text(v['fehler'])));
      }
      quellen.sort((a, b) => a.name.compareTo(b.name));
    }
    return StellenDaten(stellen: stellen, letzterLauf: zeitAus(d['letzterLauf']), quellen: quellen);
  }
}

// ---------------------------------------------------------------- Zeit-Texte

String zweistellig(int n) => n.toString().padLeft(2, '0');

String datumText(DateTime t) {
  final l = t.toLocal();
  return '${zweistellig(l.day)}.${zweistellig(l.month)}.${l.year}';
}

String vorZeit(DateTime zeit, DateTime jetzt) {
  final d = jetzt.difference(zeit);
  if (d.inMinutes < 1) return 'gerade eben';
  if (d.inMinutes < 60) return 'vor ${d.inMinutes} Min';
  if (d.inHours < 24) return 'vor ${d.inHours} Std';
  if (d.inDays == 1) return 'gestern';
  if (d.inDays < 7) return 'vor ${d.inDays} Tagen';
  return datumText(zeit);
}

/// Der Wächter läuft alle 2 Stunden. Mehr als 3 Stunden ohne Lauf = etwas stimmt nicht.
bool waechterVerspaetet(DateTime? letzterLauf, DateTime jetzt) =>
    letzterLauf == null || jetzt.difference(letzterLauf) > const Duration(hours: 3);
