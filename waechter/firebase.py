"""StellenRadar – schmaler Zugang zu Firestore (REST) und Firebase Cloud Messaging (HTTP v1).

Bewusst ohne firebase-admin: weniger Pakete, schnellerer Start in GitHub Actions.
"""
from __future__ import annotations

import json
import os
from datetime import datetime, timezone

import requests

BEREICHE = [
    "https://www.googleapis.com/auth/datastore",
    "https://www.googleapis.com/auth/firebase.messaging",
]
PUSH_THEMA = "stellen"
PUSH_KANAL = "neue_stellen"


# ---------------------------------------------------------------- Werte <-> Firestore-JSON

def kodiere(wert) -> dict:
    if wert is None:
        return {"nullValue": None}
    if isinstance(wert, bool):
        return {"booleanValue": wert}
    if isinstance(wert, int):
        return {"integerValue": str(wert)}
    if isinstance(wert, float):
        return {"doubleValue": wert}
    if isinstance(wert, datetime):
        return {"timestampValue": zeitstempel(wert)}
    if isinstance(wert, str):
        return {"stringValue": wert}
    if isinstance(wert, (list, tuple, set)):
        return {"arrayValue": {"values": [kodiere(v) for v in wert]}}
    if isinstance(wert, dict):
        return {"mapValue": {"fields": {str(k): kodiere(v) for k, v in wert.items()}}}
    raise TypeError(f"Nicht speicherbar: {type(wert)}")


def dekodiere(wert: dict):
    if "nullValue" in wert:
        return None
    if "booleanValue" in wert:
        return wert["booleanValue"]
    if "integerValue" in wert:
        return int(wert["integerValue"])
    if "doubleValue" in wert:
        return float(wert["doubleValue"])
    if "timestampValue" in wert:
        return datetime.fromisoformat(wert["timestampValue"].replace("Z", "+00:00"))
    if "stringValue" in wert:
        return wert["stringValue"]
    if "arrayValue" in wert:
        return [dekodiere(v) for v in wert["arrayValue"].get("values", [])]
    if "mapValue" in wert:
        return {k: dekodiere(v) for k, v in wert["mapValue"].get("fields", {}).items()}
    return None


def zeitstempel(dt: datetime) -> str:
    return dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z"


# ---------------------------------------------------------------- Zugang

class Firebase:
    def __init__(self, dienstkonto: dict):
        # Erst hier importieren, damit Tests und der Trockenlauf ohne google-auth auskommen.
        from google.auth.transport.requests import Request
        from google.oauth2 import service_account

        self.projekt = dienstkonto["project_id"]
        self._konto = service_account.Credentials.from_service_account_info(dienstkonto, scopes=BEREICHE)
        self._anfrage = Request()
        self._sitzung = requests.Session()

    @classmethod
    def aus_umgebung(cls) -> "Firebase":
        roh = os.environ.get("FIREBASE_SERVICE_ACCOUNT", "").strip()
        if not roh:
            raise SystemExit("FIREBASE_SERVICE_ACCOUNT fehlt (GitHub-Secret mit dem JSON-Schlüssel).")
        return cls(json.loads(roh))

    @property
    def _basis(self) -> str:
        return f"https://firestore.googleapis.com/v1/projects/{self.projekt}/databases/(default)/documents"

    def _kopf(self) -> dict:
        if not self._konto.valid:
            self._konto.refresh(self._anfrage)
        return {"Authorization": f"Bearer {self._konto.token}", "Content-Type": "application/json"}

    def lese(self, pfad: str) -> dict | None:
        r = self._sitzung.get(f"{self._basis}/{pfad}", headers=self._kopf(), timeout=20)
        if r.status_code == 404:
            return None
        r.raise_for_status()
        return {k: dekodiere(v) for k, v in r.json().get("fields", {}).items()}

    def schreibe(self, vorgaenge: list[tuple[str, dict | None, list[str] | None]]) -> None:
        """Schreibt mehrere Dokumente atomar je Paket. Daten None = löschen; Maske = nur diese Felder."""
        name = f"projects/{self.projekt}/databases/(default)/documents"
        for i in range(0, len(vorgaenge), 400):
            writes = []
            for pfad, daten, maske in vorgaenge[i:i + 400]:
                if daten is None:
                    writes.append({"delete": f"{name}/{pfad}"})
                    continue
                w = {"update": {"name": f"{name}/{pfad}",
                                "fields": {k: kodiere(v) for k, v in daten.items()}}}
                if maske:
                    w["updateMask"] = {"fieldPaths": maske}
                writes.append(w)
            r = self._sitzung.post(f"{self._basis}:commit", headers=self._kopf(),
                                   data=json.dumps({"writes": writes}), timeout=30)
            if r.status_code >= 400:
                raise RuntimeError(f"Firestore-Schreiben fehlgeschlagen ({r.status_code}): {r.text[:500]}")

    def abfrage_aelter_als(self, sammlung: str, feld: str, grenze: datetime, limit: int) -> list[tuple[str, dict]]:
        anfrage = {"structuredQuery": {
            "from": [{"collectionId": sammlung}],
            "where": {"fieldFilter": {"field": {"fieldPath": feld}, "op": "LESS_THAN", "value": kodiere(grenze)}},
            "limit": limit}}
        r = self._sitzung.post(f"{self._basis}:runQuery", headers=self._kopf(), data=json.dumps(anfrage), timeout=30)
        r.raise_for_status()
        ergebnis = []
        for zeile in r.json():
            dok = zeile.get("document")
            if not dok:
                continue
            pfad = dok["name"].split("/documents/", 1)[1]
            ergebnis.append((pfad, {k: dekodiere(v) for k, v in dok.get("fields", {}).items()}))
        return ergebnis

    def push(self, titel: str, text: str, daten: dict[str, str]) -> None:
        nachricht = {
            "message": {
                "topic": PUSH_THEMA,
                "notification": {"title": titel[:120], "body": text[:240]},
                "data": {k: str(v) for k, v in daten.items()},
                "android": {
                    "priority": "HIGH",
                    "ttl": "3600s",
                    "notification": {"channel_id": PUSH_KANAL, "tag": daten.get("id", "")[:60],
                                     "default_sound": True, "default_vibrate_timings": True},
                },
            }
        }
        r = self._sitzung.post(f"https://fcm.googleapis.com/v1/projects/{self.projekt}/messages:send",
                               headers=self._kopf(), data=json.dumps(nachricht), timeout=20)
        if r.status_code >= 400:
            raise RuntimeError(f"Push fehlgeschlagen ({r.status_code}): {r.text[:300]}")
