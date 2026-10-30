# SWD PRM - Aplikacja Kliencka (Flutter)

Aplikacja kliencka systemu wspomagania dowodzenia ratownictwa medycznego (SWD PRM) przygotowana do kompilacji na **Windows Desktop**, **Android** (tablet) oraz **iOS** (iPad).

## Architektura aplikacji (Wspólna vs Dwie aplikacje)

Projekt został zaprojektowany z wykorzystaniem architektury wielocelowej (*multi-target*):
- **Wspólny kod bazowy:** Komunikacja WebSocket, klient REST, modele (ZRM, KZW, KMCR), kolejka offline (Outbox).
- **Trzy punkty wejściowe (`entrypoints`):**
  1. `lib/main.dart` – **Wersja uniwersalna** (z ekranem logowania i wyborem roli: Dyspozytor vs Karetka ZRM). Idealna do testów lokalnych na `localhost`.
  2. `lib/main_dispatcher.dart` – **Dedykowane Stanowisko Dyspozytora** (Windows).
  3. `lib/main_tablet.dart` – **Dedykowany Terminal Mobilny ZRM** (Android / iOS).

---

## Uruchomienie lokalne (`localhost`)

### 1. Uruchomienie uniwersalne (wybór profilu w locie)
```bash
flutter run -d windows
# lub na podłączonym tablecie / emulatorze:
flutter run -d android
```

### 2. Budowanie dedykowanych instalatorów

#### Stacja Dyspozytorska (Windows `.exe`)
```bash
flutter build windows -t lib/main_dispatcher.dart
```

#### Terminal Mobilny ZRM (Android `.apk` / tablet)
```bash
flutter build apk -t lib/main_tablet.dart
```

#### Terminal Mobilny ZRM (Apple iPad / `.ipa`)
```bash
flutter build ipa -t lib/main_tablet.dart
```

---

## Moduły

- `lib/core/models/models.dart`: Modele danych (Statusy 1–6, Zlecenia KZW, Karty Medyczne KMCR).
- `lib/core/network/`: Klient HTTP API i WebSocket ze strumieniem zdarzeń w czasie rzeczywistym.
- `lib/core/storage/offline_outbox.dart`: Kolejka offline buforująca zmiany statusu przy braku zasięgu (Outbox Pattern).
- `lib/features/dispatcher/`: Interfejs dyspozytora (zarządzanie flotą, zadysponowania, rejestr KZW).
- `lib/features/tablet_zrm/`: Dotykowy interfejs ratownika (wielkie przyciski statusowe 1–6, podgląd KZW, formularz SAMPLE/GCS).
