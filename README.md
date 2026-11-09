# README

[![Release](https://img.shields.io/docker/v/jcpd/dknr-matter?sort=semver)](https://img.shields.io/docker/v/jcpd/dknr-matter?sort=semver)
[![Pull](https://img.shields.io/docker/pulls/jcpd/dknr-matter)](https://img.shields.io/docker/pulls/jcpd/dknr-matter)
[![Issue](https://img.shields.io/github/issues/dknr-domotic/dknr-matter)](https://img.shields.io/github/issues/dknr-domotic/dknr-matter)
[![License](https://img.shields.io/github/license/dknr-domotic/dknr-matter)](https://github.com/dknr-domotic/dknr-matter/blob/master/LICENSE)


## A propos

**dknr-matter** publie les entités des autres projets DKNR (Zigbee, Z-Wave, RFXCom, Daikin...), lues sur MQTT, comme des appareils **Matter** grâce à un pont Matter (*bridge*). Les contrôleurs Matter de la maison (Echo d'Amazon, Home Assistant, Apple Maison, Google Home...) les voient comme des appareils natifs et les pilotent en local : aucun serveur tiers, aucun abonnement, aucune connexion entrante ou sortante vers internet.

> **Prototype.** Cette première version sert à valider la brique Matter ([matter.js](https://github.com/project-chip/matter.js) dans Node-RED) : elle publie deux appareils de test, une prise et une température, choisis depuis le tableau de bord. La page Appareils et les autres types d'appareils viendront ensuite, voir [docs/CONCEPTION.md](docs/CONCEPTION.md).


## Fonctionnalités

- **Pont Matter** sur le réseau local (Matter sur IP, sans Thread), appairé par QR code ou code manuel depuis le tableau de bord.
- **Plusieurs contrôleurs** sur le même pont (ex : Alexa et Home Assistant), avec la liste des contrôleurs appairés.
- **Toutes les sources DKNR** : les entités sont lues depuis la discovery DKNR, sans dépendre de dknr-domotic.
- **Appareils de test** : une prise (On/Off Plug-in Unit) et une température (Temperature Sensor).
- **Appairage conservé** au redémarrage et à la mise à jour du conteneur.


## Matériel requis

* un serveur MQTT, partagé avec les autres projets DKNR.
* au moins un projet DKNR publiant des entités (ex : [DKNR Zigbee](https://github.com/dknr-domotic/dknr-zigbee)).
* un contrôleur Matter sur le même réseau local (Echo compatible Matter, Home Assistant, Apple Maison, Google Home...).
* une machine exécutant le logiciel docker, sur le même réseau local que les contrôleurs, avec IPv6 activé.


## Installation

Des images Docker prêtes à l'emploi sont disponibles.
Utilisez le fichier docker-compose.yaml à la racine du dépôt en fournissant les variables d'environnement suivantes :

* **DKNR_USERNAME** : login de l'interface node-red.
* **DKNR_PASSWORD** : mot de passe de l'interface node-red.
* **DKNR_SECRET**   : un mot secret pour encrypter les credits.

Matter utilise les adresses IPv6 locales, la découverte mDNS et le port UDP 5540 : le conteneur tourne sur le réseau de l'hôte (`network_mode: host`), sans redirection de port. Variables facultatives :

* **PORT** : port HTTP du tableau de bord et de l'éditeur Node-RED (`1880` par défaut).
* **DKNR_MATTER_PORT** : port UDP du pont Matter (`5540` par défaut).
* **DKNR_MATTER_INTERFACE** : interface réseau utilisée pour la découverte Matter (ex : `eth0`). Par défaut toutes les interfaces de l'hôte sont utilisées ; à renseigner si les contrôleurs ne trouvent pas le pont sur un hôte qui a beaucoup d'interfaces (réseaux docker, VPN...).
* **DKNR_MATTER_LOG** : niveau des journaux de matter.js, `debug`, `info`, `notice`, `warn` ou `error` (`notice` par défaut).

Le tableau de bord DKNR est disponible sur `http://<ip du serveur docker>:1880/` et l'éditeur Node-RED sur `http://<ip du serveur docker>:1880/admin`.

L'identité du pont et ses appairages sont conservés dans le volume (`/data/matter`). Supprimer le volume impose d'appairer à nouveau le pont dans chaque contrôleur.


## Configuration

### MQTT

Dans la page **Configurer** : **adresse IP**, **port**, **utilisateur** et **mot de passe** du serveur MQTT, le même que celui des autres projets DKNR, et **topic** racine des topics DKNR (`dknr` par défaut).

La page **Pont** liste les sources DKNR reçues, avec leurs nombres d'appareils et d'entités.

### Appairage

Dans la page **Pont**, le cadre **Appairage** affiche un QR code et un code manuel tant que le pont n'a pas de contrôleur. Dans l'application du contrôleur, ajoutez un appareil Matter et scannez le QR code ou saisissez le code. Le pont et ses appareils apparaissent dans le contrôleur.

Pour ajouter un autre contrôleur au même pont, cliquez sur **Ouvrir l'appairage** : le QR code est à nouveau valable pendant 15 minutes.

**Réinitialiser l'appairage** fait oublier tous les contrôleurs au pont et lui donne de nouveaux codes. Les appareils sont alors à supprimer puis à ajouter à nouveau dans chaque contrôleur.

Si le pont ne démarre pas (IPv6 indisponible, port UDP déjà utilisé), son état l'indique et le bouton **Réessayer** relance le démarrage une fois le problème corrigé.

### Appareils de test

Dans le cadre **Appareils de test** de la page **Pont**, choisissez l'entité DKNR de la **prise de test** (entité binaire, ou variateur) et celle de la **température de test**. L'appareil est ajouté au pont dès le choix, sans nouvel appairage ; choisir **Aucune** le retire du pont et des contrôleurs.


## Fonctionnement

### DKNR vers Matter

L'état d'un appareil Matter vient de sa première entité (`dknr/get/<source>/<parent>/<entité>`) :

| Type | Entité DKNR | Appareil Matter | Etat Matter |
|---|---|---|---|
| Prise | binaire, ou nombre (variateur) | On/Off Plug-in Unit | allumé si `1` (`0` pour l'unité `rb`) ou supérieur à 0 |
| Température | nombre | Temperature Sensor | °C, au centième |

Seuls les changements sont écrits. La dernière valeur des entités utilisées est conservée : après un redémarrage, les états sont rétablis sans attendre que chaque entité change, même pour les sources qui ne conservent pas leurs valeurs sur le serveur MQTT (ex : RFXCom).

### Matter vers DKNR

Un ordre d'un contrôleur est publié sur `dknr/set/<source>/<parent>/<entité>` pour chaque entité de l'appareil :

* Prise : `1` / `0` pour une entité binaire. Pour un variateur (nombre), « allume » envoie `99` (sauf s'il est déjà allumé, son niveau est conservé) et « éteins » `0`.

Seuls les changements venus d'un contrôleur sont publiés, pas ceux écrits depuis une valeur DKNR : un ordre ne revient pas en boucle. Si l'entité ne suit pas l'ordre dans les 10 secondes, son état réel est réécrit dans l'appareil Matter.

### Node-RED

Le pont est créé par du code matter.js dans le nœud function `bridges` de l'onglet `custom` (onglet *Au démarrage* du nœud). Il est arrêté proprement à chaque déploiement et à l'arrêt de Node-RED, puis recréé : les contrôleurs le retrouvent sans nouvel appairage.

Les ponts sont rangés par identifiant. Un seul existe aujourd'hui, `main` : son identifiant nomme son dossier de stockage (`/data/matter/main`) et ne doit jamais changer. L'identifiant d'un appareil DKNR donne son numéro d'endpoint Matter : le changer crée un nouvel appareil dans les contrôleurs.

Les identifiants de fabricant et de produit du pont sont ceux de test de la spécification Matter (`0xFFF1` / `0x8000`) : le pont n'est pas certifié, certains contrôleurs le signalent à l'appairage.


## A faire

* Page **Appareils** (nom, pièce, type, entités, actif).
* Autres types : lumière, variateur, ouverture, mouvement, humidité, volet, puis thermostat, serrure et ventilateur.
* Sauvegarde et restauration de la configuration.


## Contribuer

Ce projet est **open-source**, vous pouvez participer en créant des [tickets](https://github.com/dknr-domotic/dknr-matter/issues) ou en proposant de [requêtes](https://github.com/dknr-domotic/dknr-matter/pulls) sur le dépôt github du projet.


## Voir aussi

- [DKNR Domotic](https://github.com/dknr-domotic/dknr-domotic)
- [DKNR Alexa](https://github.com/dknr-domotic/dknr-alexa)
- [DKNR Zigbee](https://github.com/dknr-domotic/dknr-zigbee)
- [DKNR Z-Wave](https://github.com/dknr-domotic/dknr-zwave)
- [matter.js](https://github.com/project-chip/matter.js)
- Documentation des projets DKNR : https://dknr-domotic.github.io
