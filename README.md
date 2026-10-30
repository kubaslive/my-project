# SWD PRM Core (System Wspomagania Dowodzenia Ratownictwa Medycznego)

Kompletny system dyspozytorsko-mobilny inspirowany polskim systemem **SWD PRM** (Państwowe Ratownictwo Medyczne), zaprojektowany do działania w **zabezpieczonej sieci prywatnej** (izolowany LAN, VPN WireGuard, lokalny serwer) na platformach **Windows**, **Android** oraz **iOS** (tablety).

---

## 🏛️ Architektura Systemu

Szczegółowa specyfikacja architektoniczna, diagramy przepływu oraz procedury offline znajdują się w dokumencie:
👉 [docs/ARCHITEKTURA.md](docs/ARCHITEKTURA.md)

### Kluczowe komponenty:
1. **Backend (Golang):**
   - Szybki, lekki serwer w Go (`server/`).
   - Węzeł **WebSocket** do natychmiastowej transmisji statusów (1-6) i zleceń KZW w czasie rzeczywistym.
   - REST API do obsługi zdarzeń, karetek i kart KMCR.
   - Wbudowana testowa **Konsola WWW** pod adresem `http://localhost:8080`.
2. **Frontend Multiplatformowy (Flutter):**
   - Jeden wspólny kod Dart dla **Windows**, **Android** i **iOS** (`client/`).
   - Elastyczna architektura:
     - `lib/main.dart` – aplikacja uniwersalna z wyborem roli i adresu serwera (do testów na localhost).
     - `lib/main_dispatcher.dart` – dedykowany pulpit stacji dyspozytorskiej (Windows).
     - `lib/main_tablet.dart` – dedykowany terminal mobilny ZRM (Android / iPad).
   - Mechanizm **Offline-First (Outbox Pattern)**: buforowanie zmian w pamięci trwałej i automatyczna synchronizacja po przywróceniu zasięgu.

---

## 🚀 Szybki Start na Localhost

### 1. Uruchomienie Serwera Backend (Go)
```bash
cd server
go run cmd/server/main.go
```
Serwer uruchomi się na porcie `8080`.
Możesz od razu otworzyć w przeglądarce adres:
👉 **[http://localhost:8080](http://localhost:8080)**
Zobaczysz wbudowaną, działającą konsolę dyspozytora i symulator tabletu ratowniczego!

### 2. Uruchomienie Testów Automatycznych Serwera
```bash
cd server
go test -v ./...
```

### 3. Uruchomienie Aplikacji Klienckiej (Flutter)
```bash
cd client
# Uruchomienie na bieżącym systemie (np. Windows):
flutter run -d windows
```

---

## 📋 Standard Statusów Operacyjnych (SWD PRM)

System implementuje oficjalne statusy operacyjne Zespołów Ratownictwa Medycznego:
- **Status 1:** Wyjazd na miejsce zdarzenia
- **Status 2:** Przybycie na miejsce zdarzenia
- **Status 3:** Przejęcie pacjenta / rozpoczęcie medycznych czynności ratunkowych
- **Status 4:** Rozpoczęcie transportu do szpitala (SOR)
- **Status 5:** Przybycie do szpitala / przekazanie pacjenta
- **Status 6:** Zakończenie czynności / powrót / gotowość operacyjna
