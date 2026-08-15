# ELIAMINI FAMILY — Flutter App (KAMILI)

App ya M-Koba na SMS Automation, toleo la Flutter (ONLINE - inahitaji internet,
inatumia GitHub API kuhifadhi data, na Pushbullet API kutuma SMS — sawa kabisa
na app ya Streamlit ya awali).

## Vipengele vyote vilivyokamilika ✅
- **Login / Jisajili** (ELIHUDI, YUSUPH, FIDE) — password PBKDF2-SHA256, sawa
  na Python, hivyo `users.csv` ya zamani GitHub inafanya kazi bila mabadiliko.
- **Remember-me** (session token HMAC) kwenye Android Keystore.
- **Nimesahau Password** — barua pepe ya nambari ya kurejesha kupitia Resend
  (hiari — kama huna akaunti ya Resend, sehemu hii tu haitafanya kazi).
- **Backend ya Wanachama (Registration)** — ongeza/hariri/futa, pandisha GitHub.
- **Money SMS** — pakia Vodacom Statement (PDF), uoanishe deposit na
  wanachama kwa NAMBA YA SIMU (sawa na mantiki ya Tab 1 ya Python), hesabu
  Kianzio + Deni la Michango, hariri Ledger, pandisha GitHub, hariri namba za
  SMS, hifadhi namba hizo Backend, na TUMA SMS kupitia Pushbullet (sambamba).
- **Ledger** (mwonekano wa haraka wa deni la kila mtu, bila PDF).
- **Broadcast SMS** — chagua wanachama (mmoja/wachache/wote), andika ujumbe,
  tuma kupitia Pushbullet.
- **Wasifu Wangu / Mipangilio** — badilisha Pushbullet Token, chagua simu ya
  kutuma SMS, kasi ya kutuma (workers), idadi ya miezi ya hesabu ya deni,
  pima muunganiko wa GitHub/Pushbullet.
- **GitHub Actions** — kila unapopush, APK inajengwa KIOTOMATIKO (hakuna
  haja ya Flutter kwenye computer yako!).

## Kikomo kimoja muhimu (uwazi kamili)
Kutuma SMS bado kunategemea **internet + Pushbullet** (simu ya kiongozi
lazima iwe na app ya Pushbullet ikiwa imewashwa na "SMS" imewezeshwa), sawa
kabisa na app ya Streamlit ya awali — SI SIM ya moja kwa moja ya simu ya
mtumiaji wa app hii (hilo lingehitaji app ya offline, ambayo ulisema
hutokuitaka tena).

---

## NJIA A (RAHISI ZAIDI): Jenga APK kwa GitHub Actions — HUHITAJI Flutter kwenye computer

1. Tengeneza repo mpya GitHub (au tumia iliyopo), **PRIVATE** ni bora.
2. Pakia (push) folda hii YOTE (ikiwemo `.github/workflows/build-apk.yml`)
   kwenye repo hiyo — angalia hatua za mwisho za jibu hili kwa amri za git.
3. Fungua tab ya **"Actions"** kwenye GitHub repo yako.
4. Utaona workflow "**Jenga APK (ELIAMINI FAMILY)**" ikiendesha kiotomatiki
   (au bofya "Run workflow" kuiendesha kwa mkono).
5. Workflow ikiisha (dakika 5-10), fungua run hiyo, chini utaona
   **Artifacts** → `eliamini-family-apk` → pakua (zip yenye APK ndani).
6. Nakili APK kwenye simu yako, isakinishe.

Kila mara unapopush mabadiliko mapya ya `lib/`, APK mpya itajengwa kiotomatiki.

---

## NJIA B: Jenga APK kwenye computer yako (kama una Flutter)

### 1) Sakinisha Flutter SDK (kama huna)
https://docs.flutter.dev/get-started/install — kisha:
```bash
flutter --version
flutter doctor
```

### 2) Tengeneza miundo ya Android (haipo kwenye folda hii kwa makusudi)
```bash
cd eliamini_family
flutter create . --project-name eliamini_family --org com.eliamini
```

### 3) Ongeza ruhusa ya INTERNET (Android)
Fungua `android/app/src/main/AndroidManifest.xml`, ongeza ndani ya
`<manifest>` (juu ya `<application>`):
```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

### 4) Pakua dependencies na jenga
```bash
flutter pub get
flutter build apk --release
```
APK: `build/app/outputs/flutter-apk/app-release.apk`

---

## Kuanzisha data mara ya kwanza
1. Utaombwa GitHub Token/Repo/Branch (repo hiyohiyo ya Streamlit ya awali —
   data (`members.csv`, `ledger.csv`, `users.csv`) inaendelea kutumika
   palepale, HAKUNA haja ya kuhamisha chochote).
2. (Hiari) Weka RESEND_API_KEY/RESEND_FROM_EMAIL kama unataka "Nimesahau
   Password" ifanye kazi.
3. Login na akaunti uliyokuwa nayo tayari (password ileile) — au "Jisajili"
   kama app mpya kabisa.
4. Fungua ikoni ya mtu (👤 chini kulia) kuweka Pushbullet Token yako na
   kuchagua simu ya kutuma SMS.

## Amri za kupush GitHub (mfano)
```bash
cd eliamini_family
git init
git add .
git commit -m "ELIAMINI FAMILY - Flutter app kamili"
git branch -M main
git remote add origin https://github.com/JINA_LAKO/JINA_LA_REPO.git
git push -u origin main
```
