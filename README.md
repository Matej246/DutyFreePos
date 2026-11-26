# DutyFree POS – Prodajni sustav

## Opis projekta

DutyFree POS je desktop aplikacija namijenjena prodaji proizvoda u duty-free trgovinama u zračnim lukama.

Projekt se razvija u sklopu kolegija Alati razvoja informacijskih sustava, studija Telematika.

Aplikacija omogućuje kupnju proizvoda korištenjem digitalnih sredstava Duty Free Credit (DFC), povezanih s putnikom i avionskom kartom.

## Korištene tehnologije

- Lazarus IDE
- Free Pascal
- Object Pascal
- SQLite
- DB Browser for SQLite
- GitHub

## Funkcionalnosti aplikacije

- Provjera 14-znamenkastog barkoda avionske karte
- Provjera statusa avionske karte
- Dohvaćanje podataka o putniku i letu
- Određivanje poreznog režima EU ili IZVAN EU
- Prikaz raspoloživog DFC salda
- Prikaz proizvoda prema kategorijama
- Dinamičko učitavanje proizvoda iz baze podataka
- Dodavanje proizvoda u košaricu
- Provjera raspoloživih zaliha
- Automatski izračun cijene i PDV-a
- Provjera raspoloživih DFC sredstava
- Potvrda i naplata kupnje
- Evidentiranje računa u SQLite bazi
- Prikaz računa i preostalog salda
- Povratak na početni ekran nakon kupnje

## Struktura projekta

- src/ – izvorni kod i grafička sučelja aplikacije
- data/ – SQLite baza podataka
- README.md – opis projekta i upute za pokretanje

## Baza podataka

Aplikacija koristi SQLite bazu podataka dutyfree.db.

Baza sadrži podatke o putnicima, avionskim kartama, letovima, artiklima, kategorijama, zalihama, novčanicima, računima, transakcijama i vaučerima.

## Upute za pokretanje

1. Preuzeti projekt s GitHuba.
2. Raspakirati projekt na računalo.
3. Instalirati Lazarus IDE i Free Pascal.
4. Otvoriti mapu src.
5. Otvoriti projekt DutyFreePOS.lpi u Lazarusu.
6. Provjeriti nalazi li se sqlite3.dll u mapi src.
7. Provjeriti nalazi li se dutyfree.db u mapi data.
8. Pokrenuti aplikaciju pritiskom na tipku F9.

## Status projekta

Projekt je u fazi razvoja i testiranja.

## Namjena projekta

Projekt je izrađen u obrazovne svrhe kao demonstracija prodajnog informacijskog sustava povezanog s relacijskom bazom podataka.
