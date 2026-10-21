# Philips 55OLED855 : TV nettoyée + launcher façon Apple TV

TV : Philips 55OLED855 (modèle TP Vision **TPM191E**, carte PH9M_EA_5599, Android TV 12, 2 Go de RAM),
IP `192.168.1.160`, en Wi-Fi sur la Bbox.
Fait le 21/10/2026 à partir du dépôt [cleanyourtv](https://github.com/Gathin23/cleanyourtv) (fork :
[florentcallon/cleanyourtv](https://github.com/florentcallon/cleanyourtv)).

## Ce qui a été fait

- **Sauvegarde** avant toute modification : liste des paquets, paquets déjà désactivés, `getprop`,
  tous les réglages (`system`, `secure`, `global`), affichage, accueil, entrées TV. Elle se trouve dans
  `Documents\cleanyourtv\backup\stock-2026-10-21\`, avec la capture de l'accueil d'origine dans `shots\`.
- **42 paquets désactivés** (`pm disable-user --user 0`, rien de désinstallé), en 5 lots, avec une
  capture et un contrôle des journaux après chaque lot, puis un redémarrage de vérification. Liste
  commentée : [`debloat.txt`](debloat.txt).
  - Télémétrie Philips (DAC/candeebug, gel), e-sticker, télémétrie et restes de configuration Google
  - Promos Philips (« Top Picks », galerie Smart TV et ses applis préinstallées : ARTE, Divan.TV, MEGOGO,
    Deezer, Toon Goggles, Fishing TV, Couchplay, Fitness Buddy), WhaleLive
  - Netflix, YouTube, Apple TV, Rakuten TV, YouTube Music, Google TV, FilmoTV, TED, Play Jeux, Blacknut, Boosteroid
  - Chromecast, Alexa, Play-Fi (point d'accès), mises à jour firmware (OAD et télécommande), DLNA,
    Dropbox, TalkBack
  - Ancien accueil Google (`com.google.android.tvlauncher`), ses recommandations, l'assistant de configuration
- **Gardé volontairement** : l'Assistant Google (micro), le Play Store et les services Google, le clavier, la
  télécommande et le Bluetooth, tout ce qui fait marcher la TV, le HDMI, le tuner, le menu SOURCES,
  Ambilight et le navigateur Multimédia (USB). Tes applis à toi n'ont pas été touchées.
- **Nouveau launcher** façon Apple TV (code du dépôt, compilé par GitHub Actions sur ton fork) :
  dock **SmartTube · Wholphin · Crunchyroll · Prime Video**, grille de 4 colonnes, pastilles
  Sources / Wi-Fi / Paramètres. Wholphin (`com.github.damontecres.wholphin`) prend sa place dans le
  dock dès que tu l'installes ; d'ici là, la case est occupée par la première appli de la grille.
- **DNS anti-pub** : DNS privé Android sur `dns.adguard-dns.com`. Il ne bloque pas les pubs YouTube.
- Mémoire disponible au repos : **375 Mo avant, ~650 à 716 Mo après**.

### Ce qui ne s'est pas laissé faire

- **Play-Fi** (`com.phorus.playfi.tv`) se réactive tout seul à chaque démarrage. C'est le firmware qui
  fait ça, comme sur les autres Philips de cette génération. Il est laissé actif.
- `org.droidtv.usagelogger` et `org.droidtv.demome` sont gardés : ils demandent l'accès matériel aux
  entrées TV, et les couper peut rendre le HDMI noir.
- **Miracast** n'a pas de paquet séparé : c'est l'affichage Wi-Fi du système, et il est désactivé
  (`wifi_display_on=0`).
- La pastille Wi-Fi affiche « Wi-Fi » et pas le nom du réseau, parce que la Localisation est coupée
  (ton choix).
- Le bouton **Accueil** ramène sur la 1re tuile du dock. **Retour** depuis une appli revient sur
  l'appli quittée.
- Le logo Philips qui se balade sur un écran noir est l'économiseur anti-marquage de l'OLED. Une touche
  de la télécommande le fait disparaître.

### À noter (sans lien avec le nettoyage)

- **SmartTube est en version 23.59 (septembre 2024)**. Il n'arrive plus à charger son contenu
  (`Access token is null`), avec ou sans le DNS. Mets-le à jour depuis
  [github.com/yuliskov/SmartTube](https://github.com/yuliskov/SmartTube) (ou ton fork SmartTube-Glass).
- **Crunchyroll** demande une mise à jour : passe par le Play Store.

## Le dossier `Documents\cleanyourtv` sur ton PC

| Élément | Rôle |
|---|---|
| `repo\` | Copie du dépôt cleanyourtv (commit `8de5533`), avec `tools\tv.py` et les scripts |
| `python\` et `repo\tools\venv\` | Python portable + `adb-shell`, sans rien installer sur Windows |
| `backup\stock-2026-10-21\` | La sauvegarde complète d'avant ; `recovery-*.json` = l'état à restaurer |
| `shots\` | Toutes les captures prises sur la TV, dans l'ordre |
| `restore-tv.ps1` | Tout remettre comme avant |
| `theme\` | Thème du launcher : dock, fond d'écran |
| `install-launcher.ps1` | (Ré)installer le launcher depuis la dernière compilation de ton fork |
| `runner.ps1` / `start-runner.bat` | L'outil qui m'a servi à piloter la TV ; tu peux le supprimer |

**Pour tout ce qui suit, il faut réactiver le débogage sur la TV** : Paramètres → Préférences de
l'appareil → Options pour les développeurs → Débogage USB, puis accepter la fenêtre
« Autoriser le débogage USB ? ». **Recoupe-le après.**

Les commandes se lancent dans PowerShell, depuis `Documents\cleanyourtv`. Pour une commande isolée
sur la TV :

```powershell
$env:TV_HOST = '192.168.1.160'
.\repo\tools\venv\Scripts\python.exe -I .\repo\tools\tv.py "pm list packages -d"
```

## Réactiver une appli

- **Sans PC** : Paramètres → Applications → Voir toutes les applications → Afficher les applis
  système → l'appli → **Activer**.
- **Une appli, depuis le PC** (noms dans [`debloat.txt`](debloat.txt)), par exemple Netflix :
  ```powershell
  .\repo\tools\venv\Scripts\python.exe -I .\repo\tools\tv.py "pm enable com.netflix.ninja"
  ```
- **Tout remettre comme avant** (paquets + ancien accueil Google) :
  ```powershell
  powershell -ExecutionPolicy Bypass -File restore-tv.ps1                 # réactive tout ce qui a été désactivé
  powershell -ExecutionPolicy Bypass -File restore-tv.ps1 -UndoDns        # + coupe le DNS AdGuard
  powershell -ExecutionPolicy Bypass -File restore-tv.ps1 -RemoveLauncher # + désinstalle le nouveau launcher
  ```
  Le script rejoue l'état enregistré avant la première modification. Les 16 paquets Freeview, déjà
  désactivés d'usine, le restent. `-Force` réactive toute la liste sans cet enregistrement.

## Couper le DNS anti-pub

Paramètres → Réseau et Internet → DNS privé → Automatique. Ou bien :
`tv.py "settings put global private_dns_mode opportunistic"`.

## Changer l'ordre du dock

1. **Sur la TV, sans PC** : appui long sur la pastille **Paramètres** → « Réorganiser les applis ».
   OK prend une appli, les flèches la déplacent, Retour la pose, et Retour encore pour terminer.
2. **Par un thème, sans recompiler** : modifie `dock_apps` dans [`theme/config.json`](theme/config.json),
   puis :
   ```powershell
   powershell -ExecutionPolicy Bypass -File repo\tools\theme.ps1 -TvHost 192.168.1.160 theme
   ```
   (`-Reset` revient à la configuration intégrée.)
3. **Dans le launcher lui-même** : modifie `dock_apps` dans
   `launcher/app/src/main/res/values/config.xml` sur ton fork (directement sur GitHub, c'est possible).
   GitHub Actions recompile en ~3 min et publie une release `launcher-<commit>`. Ensuite :
   ```powershell
   powershell -ExecutionPolicy Bypass -File install-launcher.ps1
   ```
   Ce script télécharge la dernière release, vérifie son SHA-256, l'installe et la met en accueil.

## Changer le fond d'écran

Mets une image JPEG 1920×1080 nommée `wallpaper.jpg` dans le dossier du thème, passe
`"wallpaper": true` dans son `config.json`, puis pousse le thème comme ci-dessus. Pour revenir au noir :
`"wallpaper": false`, ou `theme.ps1 -Reset`. Le launcher n'affiche ni flou ni vidéo : la TV n'a que 2 Go de RAM.

## Sécurité : débogage réseau

Le port 5555 (ADB) est en clair. Quand il est ouvert, tout appareil déjà autorisé peut piloter la TV.
Coupe le **Débogage USB** quand tu as fini, et utilise « Révoquer les autorisations de débogage USB »
dans les Options pour les développeurs pour effacer les PC autorisés.
