#!/usr/bin/env python3
"""StellenRadar-Wächter: sucht neue Praktika, Trainee- und Internship-Stellen mit Maschinenbau-Bezug.

Läuft alle 2 Stunden in GitHub Actions (siehe .github/workflows/waechter.yml), ohne KI und ohne Tokens.
Quellen: jobs.ch und jobup.ch (öffentliche Such-API) sowie die Karriereseiten großer Firmen
(SAP SuccessFactors, RSS). Neue Stellen werden nur gemeldet, wenn ihr Link wirklich funktioniert.

Aufrufe:
  python waechter.py                 normaler Lauf (braucht FIREBASE_SERVICE_ACCOUNT)
  python waechter.py --trocken       ohne Firebase, Ergebnis nur anzeigen (zum Testen am PC)
  python waechter.py --test-push     sendet eine Test-Benachrichtigung ans Handy
"""
from __future__ import annotations

import argparse
import concurrent.futures as cf
import hashlib
import html
import json
import re
import sys
import time
from dataclasses import asdict, dataclass, field
from datetime import datetime, timedelta, timezone
from email.utils import parsedate_to_datetime
from pathlib import Path
from urllib.parse import quote

import requests

ORDNER = Path(__file__).resolve().parent
LOKALER_ZUSTAND = ORDNER / ".zustand-lokal.json"
NUTZERAGENT = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) "
               "Chrome/130.0 Safari/537.36 StellenRadar/1.0 (privater Stellenwaechter, alle 2 Stunden)")
TIMEOUT = (6, 15)
WEG_BEHALTEN = timedelta(days=7)        # verschwundene Stellen so lange als „nicht mehr online“ zeigen
SAMMEL_PUSH_AB = 4                      # ab so vielen neuen Stellen nur eine Sammelmeldung
MAX_LINKPRUEFUNGEN = 60
FILTER_VERSION = 2                      # neue Filter: alte Liste nicht als "nicht mehr online" übernehmen
abgelehnt: list = []                  # (Stelle, Grund) aus der Volltextprüfung, für den Trockenlauf


def jetzt() -> datetime:
    return datetime.now(timezone.utc)


# ---------------------------------------------------------------- Filter: Art der Stelle und Fachgebiet

ART = re.compile(r"praktik|praktikum|\bintern\b|\binterns?hip|internship|\btrainee|young talent|graduate|"
                 r"absolvent|hochschulpraktik|berufseinst|einstiegsprogramm|\bstage\b|stagiaire|\bstagista|"
                 r"tirocin|career starter|direkteinstieg|junior.?programm|traineeprogramm", re.I)

# Nur Studierende / keine Stelle für Absolventen: ausblenden
NICHT_ART = re.compile(r"sch[üu]ler|schnupper|lehrstelle|\blernende|lehrling|\bausbildung\b|azubi|"
                       r"werkstudent|working student|\bfms\b|vorpraktikum|berufsfindung|"
                       r"orientierungspraktikum|zivildienst|freiwillig|ferienjob|ferialprakti|\bmpc\b|\bkv\b|kaufm|commercial|"
                       r"^(master|bachelor|abschluss)arbeit|^(master|bachelor)'?s? thesis|^thesis\b", re.I)

FACH = re.compile(r"maschinenbau|mechani|m[ée]cani|konstrukt|engineer|ingenieur|ing[ée]nieur|engineering|"
                  r"entwickl|development|d[ée]veloppement|\br&d\b|\bf&e\b|produktion|"
                  r"production|fertigung|manufactur|qualit|quality|\btest|validier|validation|simulation|\bfem\b|"
                  r"finite.?element|\bcad\b|luftfahrt|raumfahrt|aerospace|a[ée]ronaut|\bspace|aviation|avionic|"
                  r"flugzeug|aircraft|helikopter|propulsion|antrieb|hydraulik|hydraulic|mechatron|werkstoff|"
                  r"material|technik|technical|technisch|technique|industrial|industriel|"
                  r"automati|robot|drohne|drone|anlagenbau|instandhaltung|maintenance|wartung|pr[üu]fstand|"
                  r"inspektion|inspection|sachverst|kfz|fahrzeug|vehicle|v[ée]hicule|engine|motor|turbin|"
                  r"verfahrenstechn|thermo|str[öo]mung|fluid|lean|kvp|industrialis|montage|assembly|maschinen|"
                  r"machine|metall|schwei[sß]|welding|kunststoff|additive|3d.?druck|druckger|fahrzeugtechn", re.I)

NICHT_FACH = re.compile(r"marketing|kommunikation|communication|\bpr\b|social media|\bhr\b|human resources|"
                        r"personal(?:wesen|abteilung)|recruit|talent acquisition|finance|finanz|controlling|"
                        r"accounting|buchhalt|rechnungswesen|treuhand|steuer|\btax\b|audit(?!or)|legal|jurist|"
                        r"rechts|\brecht\b|sales|vertrieb|verkauf|vente|einkauf|procurement|purchas|journal|"
                        r"redaktion|pflege|kita|kinder|lehrer|sozial|gastro|koch|k[üu]che|hotel|apothek|"
                        r"medizin|arzt|psycholog|bank|versicherung|helpdesk|it.?support|service desk|"
                        r"informatik|software|data scien|data analy|business analy|grafik|ux|ui design|"
                        r"event|tourism|logistik|logistics|supply chain|immobilien|real estate|architekt|"
                        r"bauleit|tiefbau|hochbau|umwelt|biolog|chemie(?!ingenieur)|labor|"
                        r"politi|public affairs|public policy|unterhaltung|entertainment|medien|\bmedia\b|radio|"
                        r"fernseh|television|\bfilm|kultur|museum|bibliothek|library|business development|"
                        r"organi[sz]ation(?:al)? development|personalentwicklung|wirtschaftspr|statisti|[öo]konom|"
                        r"economic|research assistant|geb[äa]udetechn|geb[äa]udeautomation|building|\bcvc\b|hvac|"
                        r"sanit[äa]r|heizung|interior|innenarchitekt|innenausbau|bureau d'[ée]tudes|"
                        r"consult|beratung|strategy|strategie|project management office|office|sekretariat|"
                        r"assistenz|customer service|kundendienst|callcenter|ressources humaines|\brh\b|recrutement|"
                        r"administration|evaluation|electrical|electronic|elektro(?!mechan)|elektronik|"
                        r"power electronics|network|netzwerk|cloud|platform|plattform|\bdata\b|daten|\bai\b|"
                        r"\bki\b|mlops|machine learning|security|cyber|java|\bcode\b|bauingenieur|civil|"
                        r"g[ée]nie civil|b[âa]timent|cartographie|compliance|operationstechnik", re.I)

# Firmen, bei denen Praktika fast nie Maschinenbau sind
NICHT_FIRMA = re.compile(r"spital|klinik|hospital|bank|banque|assura|versicherung|assurance|finanzkontrolle|"
                         r"informatique|swissquote|treuhand|kanton(?!.*techn)", re.I)

# Stark fachliche Wörter heben einen Negativtreffer wieder auf (z. B. „Software für Maschinensteuerung“).
STARK = re.compile(r"maschinenbau|mechanical|m[ée]canique|konstruktion|aerospace|luftfahrt|raumfahrt|"
                   r"avionic|propulsion|mechatron|fem\b|simulation|hydraulik|hydraulic|fertigungstechn|"
                   r"produktionstechn|verfahrenstechn|werkstoff|robotik|robotics|drohne|drone", re.I)

# Volltext der Anzeige: Hinweise, dass wirklich Maschinenbau/Aerospace gesucht wird …
VOLL_ING = re.compile(r"maschinenbau|maschineningenieur|mechanical engineer|g[ée]nie m[ée]canique|"
                      r"ing[ée]nierie m[ée]canique|ing[ée]nieur en m[ée]canique|konstruktion|mechatroni|"
                      r"luft- und raumfahrt|luftfahrt|raumfahrt|aerospace|a[ée]ronauti|verfahrenstechnik|"
                      r"werkstofftechnik|werkstoffwissenschaft|materials? science|materials? engineering|"
                      r"fertigungstechnik|produktionstechnik|wirtschaftsingenieur|industrial engineering|"
                      r"g[ée]nie industriel|(?<!bau)ingenieurwissenschaft|(?<!bau)ingenieurwesen|engineering degree|"
                      r"degree in (?:mechanical |aerospace |)engineering|fahrzeugtechnik|automotive engineering|"
                      r"solidworks|catia|\bcreo\b|siemens nx|autodesk inventor|\bansys|abaqus|\bfem\b|"
                      r"finite.?element|\bcad\b|hydraulik|hydraulics|thermodynami|str[öo]mungsmechanik|"
                      r"fluid dynamics|\bcfd\b|technische mechanik|\bmechanics\b|mikrotechnik|microtechnique|"
                      r"robotik|robotics|antriebstechnik|motorenentwicklung|engine development|prüfstand|"
                      r"test bench|maschinen- und anlagenbau|systems engineering|systemtechnik", re.I)

# … und Hinweise auf ein ganz anderes Studium (z. B. Politikwissenschaft).
FREMD = re.compile(r"politikwissenschaft|politologie|political science|sciences? politiques?|\bpolitics\b|"
                   r"internationale beziehungen|international relations|public affairs|public policy|"
                   r"sozialwissenschaft|social sciences?|geisteswissenschaft|humanities|"
                   r"kommunikationswissenschaft|medienwissenschaft|journalismus|journalism|"
                   r"rechtswissenschaft|\bjura\b|soziologie|sociology|geschichtswissenschaft|"
                   r"kulturwissenschaft|psychologie|psychology|p[äa]dagogik|erziehungswissenschaft|"
                   r"germanistik|anglistik|linguistik|theologie|kunstgeschichte|"
                   r"tourismus|hotellerie|gesundheitswissenschaft|pflegewissenschaft|"
                   r"innenarchitekt|interior design", re.I)

# Benachbarte Fächer: zählen nur, wenn sie in der Beschreibung überwiegen.
NAH = re.compile(r"betriebswirtschaft|\bbwl\b|business administration|volkswirtschaft|economics|"
                 r"bauingenieur|civil engineering|g[ée]nie civil|informatik|computer science", re.I)

LAENDER_NAMEN = {"schweiz": "CH", "switzerland": "CH", "suisse": "CH", "liechtenstein": "LI",
                 "deutschland": "DE", "germany": "DE", "österreich": "AT", "austria": "AT"}

DE_WOERTER = re.compile(r"praktik|ingenieur(?!e)|\bim bereich\b|\bfür\b|\bund\b|entwicklung|konstruktion|"
                        r"fertigung|prüf|maschinenbau|technik|\bm/w/d\b|\bw/m/d\b|\bm/w/x\b|\bd/w/m\b|"
                        r"praktikant|absolvent|qualität|produktion|\bin der\b|\bdes\b|\bder\b|\bdie\b", re.I)
FR_WOERTER = re.compile(r"stagiaire|\bstage\b|ing[ée]nieur|\bh/f\b|\bf/h\b|d[ée]veloppement|\ben\b |\bdes\b ", re.I)


def passt(titel: str, text: str = "") -> tuple[bool, str]:
    """(passt, grund). Titel entscheidet über die Art, Titel+Vorschau über das Fachgebiet."""
    t = titel.strip()
    if NICHT_ART.search(t):
        return False, "art-ausgeschlossen"
    if not ART.search(t):
        return False, "keine-praktikumsstelle"
    stark = STARK.search(t) or STARK.search(text[:600])
    if NICHT_FACH.search(t) and not STARK.search(t):    # fremdes Fach im Titel: nur ein starkes Titelwort rettet
        return False, "anderes-fachgebiet"
    if FACH.search(t) or stark:
        return True, ""
    if text and FACH.search(text[:600]) and not NICHT_FACH.search(text[:300]):
        return True, ""
    return False, "kein-maschinenbau"


def passt_volltext(titel: str, volltext: str) -> tuple[bool, str]:
    """Zweite Stufe: Die ganze Stellenbeschreibung muss wirklich nach Maschinenbau/Aerospace klingen."""
    titel_stark = bool(STARK.search(titel))
    if not volltext:
        return titel_stark, "" if titel_stark else "keine-beschreibung"
    ing = {m.lower() for m in VOLL_ING.findall(volltext)}
    fremd = {m.lower() for m in FREMD.findall(volltext)}
    nah = {m.lower() for m in NAH.findall(volltext)}
    if fremd and not titel_stark and len(ing) < 2:
        return False, "anderes-studium: " + sorted(fremd)[0]
    if len(fremd) + len(nah) > len(ing) and not titel_stark:
        return False, "anderes-studium: " + sorted(fremd | nah)[0]
    if titel_stark or ing:
        return True, ""
    return False, "beschreibung-ohne-maschinenbau"


def sprache(titel: str, text: str = "") -> str:
    probe = f"{titel} {text[:300]}"
    de = len(DE_WOERTER.findall(probe))
    fr = len(FR_WOERTER.findall(probe))
    if de >= 1 and de >= fr:
        return "de"
    if fr >= 2:
        return "fr"
    return "en"


# ---------------------------------------------------------------- Datenmodell

@dataclass
class Stelle:
    id: str
    titel: str
    firma: str
    ort: str
    land: str
    url: str
    quelle: str
    datum: datetime | None = None          # Veröffentlichung laut Quelle
    sprache: str = "de"                    # Sprache der Anzeige (geschätzt)
    englisch_pflicht: bool | None = None   # nur bei jobs.ch bekannt
    sprachen: list[str] = field(default_factory=list)
    vorschau: str = ""
    volltext: str = ""                     # ganze Beschreibung, nur zum Filtern (wird nicht gespeichert)

    def fuer_speicher(self) -> dict:
        d = asdict(self)
        d.pop("volltext", None)
        d["englischPflicht"] = d.pop("englisch_pflicht")
        return d


def kurz_hash(text: str, n: int = 16) -> str:
    return hashlib.sha1(text.encode("utf-8")).hexdigest()[:n]


def _sitzung() -> requests.Session:
    s = requests.Session()
    s.headers.update({"User-Agent": NUTZERAGENT, "Accept-Language": "de-CH,de;q=0.9,en;q=0.6"})
    return s


def _sauber(text: str) -> str:
    text = re.sub(r"<[^>]+>", " ", html.unescape(text or ""))
    return re.sub(r"\s+", " ", text).strip()


# ---------------------------------------------------------------- Quelle: jobs.ch / jobup.ch

def _jobsch_dokument(d: dict, host: str) -> Stelle | None:
    links = d.get("_links") or {}
    url = ((links.get("detail_de") or links.get("detail_fr") or links.get("detail_en") or {}).get("href") or "")
    if not url:
        return None
    skills = d.get("language_skills") or []
    sprachen = sorted({s.get("language", "") for s in skills if s.get("language")})
    en = [s for s in skills if s.get("language") == "en"]
    englisch = bool(en and int(en[0].get("level") or 0) >= 3) if skills else None
    datum = None
    for k in ("publication_date", "initial_publication_date"):
        if d.get(k):
            try:
                datum = datetime.fromisoformat(d[k])
                break
            except ValueError:
                pass
    titel = _sauber(d.get("title", ""))
    vorschau = _sauber(d.get("preview", ""))
    return Stelle(id="jc-" + d["job_id"], titel=titel, firma=_sauber(d.get("company_name") or ""),
                  ort=_sauber(d.get("place") or ""), land="CH", url=url, quelle=host.replace("www.", ""),
                  datum=datum, sprache=sprache(titel, vorschau), englisch_pflicht=englisch,
                  sprachen=sprachen, vorschau=vorschau[:280])


def hole_jobsch(konfig: dict, s: requests.Session) -> tuple[list[Stelle], list[str]]:
    stellen: dict[str, Stelle] = {}
    fehler: list[str] = []
    for host in konfig["hosts"]:
        basis = f"https://{host}/api/v1/public/search"
        anfragen = [f"employment-type-ids%5B%5D={konfig['praktikum_typ']}"]
        anfragen += [f"query={quote(q)}" for q in konfig["suchbegriffe"]]
        for anfrage in anfragen:
            max_seiten = konfig["max_seiten"] if anfrage.startswith("employment") else 3
            for seite in range(1, max_seiten + 1):
                try:
                    r = s.get(f"{basis}?{anfrage}&rows=20&page={seite}", timeout=TIMEOUT)
                    r.raise_for_status()
                    daten = r.json()
                except Exception as f:  # noqa: BLE001
                    fehler.append(f"{host} {anfrage} S.{seite}: {f}")
                    break
                for d in daten.get("documents", []):
                    if d.get("is_active") is False:
                        continue
                    st = _jobsch_dokument(d, host)
                    if st and st.id not in stellen:
                        stellen[st.id] = st
                if seite >= int(daten.get("num_pages") or 1):
                    break
    return list(stellen.values()), fehler


def hole_jobsch_volltext(st: Stelle, s: requests.Session) -> str:
    """Ganze Beschreibung einer jobs.ch/jobup.ch-Anzeige (öffentliche Detail-API)."""
    host = "www.jobup.ch" if st.quelle == "jobup.ch" else "www.jobs.ch"
    try:
        r = s.get(f"https://{host}/api/v1/public/search/job/{st.id[3:]}", timeout=TIMEOUT)
        r.raise_for_status()
        d = r.json()
    except Exception:  # noqa: BLE001
        return ""
    teile = [d.get(k) or "" for k in ("template_profession", "template_lead_text", "template_text", "template")]
    return _sauber(" ".join(t for t in teile if isinstance(t, str)))


# ---------------------------------------------------------------- Quelle: SAP SuccessFactors (RSS)

_ORT = re.compile(r"\s*\(([^()]*)\)\s*$")


def _sf_titel_ort(roh: str) -> tuple[str, str, str]:
    """'Praktikum X (Rostock, DE)' -> ('Praktikum X', 'Rostock', 'DE')."""
    m = _ORT.search(roh)
    if not m:
        return roh.strip(), "", ""
    teile = [t.strip() for t in m.group(1).split(",") if t.strip()]
    land = teile[-1].upper() if teile and len(teile[-1]) == 2 else ""
    if not land and teile and teile[-1].lower() in LAENDER_NAMEN:
        land = LAENDER_NAMEN[teile[-1].lower()]
    ort = teile[0] if teile else ""
    return roh[:m.start()].strip(), ort, land


def parse_sf_rss(xml: str, firma: dict) -> list[Stelle]:
    stellen = []
    for it in re.findall(r"<item>(.*?)</item>", xml, re.S):
        tm = re.search(r"<title>(?:<!\[CDATA\[)?(.*?)(?:\]\]>)?</title>", it, re.S)
        lm = re.search(r"<link>(.*?)</link>", it, re.S)
        if not tm or not lm:
            continue
        titel, ort, land = _sf_titel_ort(html.unescape(tm.group(1)).strip())
        link = html.unescape(lm.group(1)).strip().split("?")[0]
        jm = re.search(r"/(\d{6,})/?$", link)
        if not jm:
            continue
        dm = re.search(r"<pubDate>(.*?)</pubDate>", it)
        datum = None
        if dm:
            try:
                datum = parsedate_to_datetime(dm.group(1).strip())
            except (TypeError, ValueError):
                pass
        bm = re.search(r"<description>(?:<!\[CDATA\[)?(.*?)(?:\]\]>)?</description>", it, re.S)
        text = _sauber(bm.group(1)) if bm else ""
        stellen.append(Stelle(id=f"sf-{firma['id']}-{jm.group(1)}", titel=titel, firma=firma["firma"], ort=ort,
                              land=land, url=link, quelle=firma["host"], datum=datum,
                              sprache=sprache(titel, text), vorschau=text[:280], volltext=text))
    return stellen


def hole_successfactors(firma: dict, begriffe: list[str], s: requests.Session) -> tuple[list[Stelle], list[str]]:
    stellen: dict[str, Stelle] = {}
    fehler = []
    for begriff in begriffe:
        for start in range(0, 200, 20):
            url = (f"https://{firma['host']}/services/rss/job/?locale=de_DE"
                   f"&keywords=({quote(begriff)})&startrow={start}")
            try:
                r = s.get(url, timeout=TIMEOUT)
                r.raise_for_status()
            except Exception as f:  # noqa: BLE001
                fehler.append(f"{firma['firma']} {begriff}: {f}")
                break
            neu = parse_sf_rss(r.text, firma)
            for st in neu:
                stellen.setdefault(st.id, st)
            if len(neu) < 20:
                break
    return list(stellen.values()), fehler


# ---------------------------------------------------------------- Linkprüfung

def link_ok(url: str, s: requests.Session) -> bool:
    """Öffnet die Anzeige wie ein Browser. Gilt nur, wenn sie wirklich da ist (kein 404, keine Umleitung)."""
    try:
        r = s.get(url, timeout=TIMEOUT, allow_redirects=True)
    except requests.RequestException:
        return False
    if r.status_code != 200:
        return False
    ende = r.url.split("?")[0].rstrip("/")
    anfang = url.split("?")[0].rstrip("/")
    if ende != anfang:
        # Umleitung auf Suche/Startseite = Anzeige weg. Gleiche ID in der Zieladresse ist in Ordnung.
        kennung = re.findall(r"[0-9a-f-]{8,}|\d{6,}", anfang)
        if not kennung or kennung[-1] not in ende:
            return False
    text = r.text[:200000].lower()
    for zeichen in ("job not found", "stelle nicht gefunden", "nicht mehr verfügbar", "no longer available",
                    "position has been filled", "stelle ist nicht mehr", "page not found", "seite nicht gefunden"):
        if zeichen in text:
            return False
    return True


# ---------------------------------------------------------------- Ein Lauf

def sammeln(konfig: dict) -> tuple[list[Stelle], dict[str, dict]]:
    s = _sitzung()
    status: dict[str, dict] = {}
    alle: list[Stelle] = []
    with cf.ThreadPoolExecutor(max_workers=8) as pool:
        auftraege = {pool.submit(hole_jobsch, konfig["jobsch"], s): "jobs.ch / jobup.ch"}
        for f in konfig["successfactors"]:
            auftraege[pool.submit(hole_successfactors, f, konfig["sf_suchbegriffe"], s)] = f["firma"]
        for zukunft in cf.as_completed(auftraege):
            name = auftraege[zukunft]
            try:
                stellen, fehler = zukunft.result()
            except Exception as f:  # noqa: BLE001
                stellen, fehler = [], [str(f)]
            alle.extend(stellen)
            status[name] = {"ok": bool(stellen) or not fehler, "gefunden": len(stellen),
                            "fehler": "; ".join(fehler)[:300]}
    laender = set(konfig["laender"])
    gefiltert: dict[str, Stelle] = {}
    for st in alle:
        if st.land and st.land not in laender:
            continue
        if not st.land:          # Firmenseite ohne Ortsangabe: Land unbekannt, lieber weglassen
            continue
        if NICHT_FIRMA.search(st.firma):
            continue
        ok, _ = passt(st.titel, st.vorschau)
        if ok:
            gefiltert.setdefault(st.id, st)
    # Zweite Stufe: ganze Beschreibung lesen (jobs.ch über die Detail-API, Firmenseiten aus dem RSS)
    ohne_text = [st for st in gefiltert.values() if not st.volltext and st.id.startswith("jc-")]
    with cf.ThreadPoolExecutor(max_workers=8) as pool:
        for st, text in zip(ohne_text, pool.map(lambda x: hole_jobsch_volltext(x, s), ohne_text)):
            st.volltext = text
    abgelehnt.clear()
    for sid in list(gefiltert):
        st = gefiltert[sid]
        ok, grund = passt_volltext(st.titel, st.volltext or st.vorschau)
        if not ok:
            abgelehnt.append((st, grund))
            del gefiltert[sid]
    # Gleiche Stelle auf jobs.ch und jobup.ch / Firmenseite: nur einmal (Firma + Titel)
    eindeutig: dict[str, Stelle] = {}
    for st in sorted(gefiltert.values(), key=lambda x: (not x.id.startswith("sf-"), x.quelle != "jobs.ch")):
        firma1 = (re.findall(r"\w+", st.firma.lower()) or [""])[0]
        schluessel = kurz_hash(firma1 + "|" + re.sub(r"\W+", "", st.titel.lower()))
        eindeutig.setdefault(schluessel, st)
    for name in status:
        status[name]["passend"] = sum(1 for st in eindeutig.values()
                                      if (st.quelle in ("jobs.ch", "jobup.ch") and name.startswith("jobs.ch"))
                                      or st.firma == name)
    return list(eindeutig.values()), status


def lauf(args) -> int:
    start = time.monotonic()
    t = jetzt()
    konfig = json.loads((ORDNER / "quellen.json").read_text("utf-8"))

    fb = None
    if args.trocken:
        zustand = _lokal_lesen()
    else:
        from firebase import Firebase
        fb = Firebase.aus_umgebung()
        zustand = fb.lese("intern/stellen_zustand") or {}

    bekannt: dict = zustand.get("bekannt", {}) or {}          # id -> erstmals gesehen (ISO)
    vorher: dict = {d["id"]: d for d in (zustand.get("liste") or [])}
    if zustand.get("filterVersion") != FILTER_VERSION:
        vorher = {}
    erster_lauf = not bekannt

    gefunden, status = sammeln(konfig)
    s = _sitzung()

    # Neue Stellen: Link prüfen, bevor sie gemeldet werden.
    kandidaten = [st for st in gefunden if st.id not in bekannt]
    kandidaten.sort(key=lambda x: x.datum or t, reverse=True)
    geprueft: dict[str, bool] = {}
    if not erster_lauf:
        with cf.ThreadPoolExecutor(max_workers=8) as pool:
            for st, ok in zip(kandidaten[:MAX_LINKPRUEFUNGEN],
                              pool.map(lambda x: link_ok(x.url, s), kandidaten[:MAX_LINKPRUEFUNGEN])):
                geprueft[st.id] = ok

    liste: list[dict] = []
    neue: list[dict] = []
    for st in gefunden:
        d = st.fuer_speicher()
        if st.id in bekannt:
            d["ersterfasst"] = bekannt[st.id]
            d["neu"] = False
        else:
            if not erster_lauf and not geprueft.get(st.id):
                continue          # Link (noch) nicht geprüft oder kaputt: im nächsten Lauf erneut
            bekannt[st.id] = t.isoformat()
            d["ersterfasst"] = t.isoformat()
            d["neu"] = not erster_lauf
            if d["neu"]:
                neue.append(d)
        d["aktiv"] = True
        d["datum"] = st.datum.isoformat() if st.datum else None
        liste.append(d)

    # Verschwundene Stellen noch eine Woche als „nicht mehr online“ behalten
    aktuell = {d["id"] for d in liste}
    for sid, alt in vorher.items():
        if sid in aktuell:
            continue
        weg = alt.get("weg") or t.isoformat()
        if t - datetime.fromisoformat(weg) < WEG_BEHALTEN:
            alt.update({"aktiv": False, "weg": weg, "neu": False})
            liste.append(alt)

    liste.sort(key=lambda d: (d.get("ersterfasst") or "", d.get("datum") or ""), reverse=True)
    # „bekannt“ klein halten: Einträge älter als 120 Tage, die nicht mehr online sind, vergessen
    grenze = (t - timedelta(days=120)).isoformat()
    bekannt = {k: v for k, v in bekannt.items() if k in aktuell or v > grenze}

    dauer = time.monotonic() - start
    meta = {"letzterLauf": t, "dauerSek": round(dauer, 1), "anzahl": sum(1 for d in liste if d["aktiv"]),
            "neueStellen": len(neue), "quellen": status, "stellen": liste}

    if args.trocken:
        _ausgeben(liste, neue, status, dauer)
        _lokal_schreiben({"bekannt": bekannt, "liste": liste, "filterVersion": FILTER_VERSION})
        return 0

    fb.schreibe([("meta/stellen", meta, None),
                 ("intern/stellen_zustand", {"bekannt": bekannt, "liste": liste, "letzterLauf": t,
                                           "filterVersion": FILTER_VERSION}, None)])
    fehler = 0
    for titel, text, daten in push_texte(neue):
        try:
            fb.push(titel, text, daten)
        except Exception as f:  # noqa: BLE001
            print(f"Push fehlgeschlagen: {f}")
            fehler += 1
    print(f"{len(liste)} Stellen, {len(neue)} neu, {dauer:.1f} s")
    for name, st in sorted(status.items()):
        print(f"  {'ok' if st['ok'] else '!!'} {name}: {st['gefunden']} gelesen, {st['passend']} passend "
              f"{st['fehler']}")
    return 1 if fehler else 0


def push_texte(neue: list[dict]) -> list[tuple[str, str, dict]]:
    if not neue:
        return []
    if len(neue) >= SAMMEL_PUSH_AB:
        firmen = ", ".join(dict.fromkeys(d["firma"] for d in neue))
        return [(f"{len(neue)} neue Praktika/Trainee-Stellen", firmen[:200], {"id": "sammel", "url": ""})]
    texte = []
    for d in neue:
        ort = ", ".join(x for x in (d["ort"], d["land"]) if x)
        texte.append((f"Neu: {d['firma']}", f"{d['titel']} · {ort}", {"id": d["id"], "url": d["url"]}))
    return texte


# ---------------------------------------------------------------- Lokal (Trockenlauf)

def _lokal_lesen() -> dict:
    if not LOKALER_ZUSTAND.exists():
        return {}
    return json.loads(LOKALER_ZUSTAND.read_text("utf-8"))


def _lokal_schreiben(zustand: dict) -> None:
    LOKALER_ZUSTAND.write_text(json.dumps(zustand, ensure_ascii=False, indent=1, default=str), "utf-8")


def _ausgeben(liste, neue, status, dauer) -> None:
    for name, st in sorted(status.items()):
        print(f"{'ok' if st['ok'] else '!!'} {name}: {st['gefunden']} gelesen, {st['passend']} passend {st['fehler']}")
    print(f"\n{sum(1 for d in liste if d['aktiv'])} passende Stellen, {len(neue)} neu, {dauer:.1f} s\n")
    for d in liste:
        if d["aktiv"]:
            en = " [EN Pflicht]" if d.get("englischPflicht") else ""
            print(f"{d['land']:2} {d['sprache']} {d['firma'][:28]:28} | {d['titel'][:80]}{en}")
    if abgelehnt:
        print(f"\nNach Prüfung der Beschreibung aussortiert ({len(abgelehnt)}):")
        for st, grund in abgelehnt:
            print(f"  - {st.firma[:28]:28} | {st.titel[:70]}  [{grund}]")


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--trocken", action="store_true", help="ohne Firebase, nur anzeigen")
    p.add_argument("--test-push", action="store_true", help="Test-Benachrichtigung senden")
    args = p.parse_args()
    if args.test_push:
        from firebase import Firebase
        Firebase.aus_umgebung().push("StellenRadar-Test", "Push kommt an – der Stellen-Wächter ist startklar.",
                                     {"id": "test", "url": ""})
        return 0
    return lauf(args)


if __name__ == "__main__":
    sys.exit(main())
