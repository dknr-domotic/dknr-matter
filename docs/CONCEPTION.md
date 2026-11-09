# Conception de dknr-matter

Document de conception rédigé avant le développement (novembre 2026). Il réunit le contexte, les éléments déjà vérifiés et les choix à faire. La section *Etat d'avancement* suit ce qui a été décidé et construit depuis.


## Objectif

Publier les entités DKNR (toutes sources confondues, lues sur MQTT) comme des appareils **Matter**, grâce à un **pont Matter** (*bridge*). Les contrôleurs Matter de la maison (Echo, et aussi Home Assistant, Apple Maison, Google Home...) les voient alors comme des appareils natifs, pilotables en local.

But principal : remplacer à terme **dknr-alexa** et son abonnement Virtual Smart Home (VSH) pour le pilotage par Alexa, avec une connexion entièrement locale (aucun serveur tiers, aucune connexion sortante obligatoire).


## Contexte vérifié (novembre 2026)

* **Echo de la maison** : des Echo Show 5, le plus récent de 2024, et d'autres Echo plus anciens. La [liste Matter d'Amazon](https://developer.amazon.com/en-US/docs/alexa/smarthome/matter-support.html) inclut *Echo Show 5 (1st Gen and newer)*, *Echo (2nd Gen and newer)*, *Echo Dot (2nd Gen and newer)*, *Echo Flex*, *Echo Input*... : les Echo Show 5 sont contrôleurs Matter (Wi-Fi, sans Thread). Les modèles exacts des autres Echo restent à vérifier dans l'application Alexa.
* **Ponts Matter chez Alexa** : la même page d'Amazon indique que les connexions Matter valent pour les appareils natifs comme pour les *non-Matter devices exposed as bridged devices through a Matter bridge*. Les Echo Matter gèrent un sous-ensemble de Matter 1.5.
* **Catégories Matter gérées par Alexa** : hubs Matter, lumières et prises, boutons, capteurs, ouvrants (serrures, volets), thermostats, ventilateurs, purificateurs, appareils ménagers, aspirateurs (même page).
* **Stabilité** : un utilisateur d'openHAB signale un pont Matter qui disparaît puis réapparaît dans l'application Alexa ([forum openHAB, mars 2026](https://community.openhab.org/t/oh-matter-bridge-and-all-bridged-device-disconnecting-from-echos/168885)). À surveiller dès les premiers tests.
* **Pas de Thread nécessaire** : le pont parle Matter sur IP (Ethernet ou Wi-Fi). Thread ne concerne que les appareils radio (voir *Evolutions*, la clé SONOFF Dongle-M est réservée à cela).
* **Réseau** : Matter utilise IPv6 (adresses locales de lien), la découverte mDNS et le port UDP 5540. Le conteneur doit tourner en `network_mode: host` avec IPv6 activé, ce qui est possible sur l'installation (comme le fait Matterbridge).


## Etat d'avancement

* **Brique Matter** : option **A** retenue (Node-RED + matter.js, `@matter/main` 0.18).
* **Prototype** (version 0.1) : structure du dépôt reprise de dknr-alexa, pont `main`, page **Pont** (état, appairage par QR code, contrôleurs appairés, sources) et deux appareils de test (prise, température).
* **Prototype validé avec un Echo** (novembre 2026) : appairage par QR code dans Alexa, pont et prise ajoutés, ordre d'Alexa vers `dknr/set`, changement d'état DKNR vu dans Alexa, température ajoutée sans nouvel appairage, appareils toujours pilotables après un redémarrage du conteneur.
* **Version 0.2** : page **Appareils** reprise de dknr-alexa (nom, pièce, type, entités, actif) à la place des appareils de test, et types lumière, variateur, prise, volet, ouverture, mouvement, température et humidité. Les deux appareils de test déjà créés restent dans la liste comme des appareils ordinaires.
* **Appareils** : pas d'import de la sauvegarde dknr-alexa, les appareils sont créés à la main dans dknr-matter (choix de novembre 2026).
* **Ponts** : rangés par identifiant dans le code, un seul créé (`main`). Le choix entre un pont unique et plusieurs ponts reste ouvert jusqu'aux tests de stabilité sur un Echo : déplacer un appareil d'un pont à un autre le recrée dans les contrôleurs, il faut donc trancher avant la bascule depuis dknr-alexa.
* **Latence observée** : plusieurs secondes entre un changement d'état côté DKNR et son affichage dans l'application Alexa du téléphone. Sans gêne pour la commande vocale. Origine à confirmer (le pont écrit l'attribut Matter dès la réception de la valeur MQTT) : comparer avec Home Assistant comme second contrôleur, ou avec les journaux de matter.js (`DKNR_MATTER_LOG: debug`).
* **Reste à valider avec du matériel** : les nouveaux types dans Alexa (variateur, volet, ouverture, mouvement, humidité), la stabilité dans le temps, Home Assistant comme second contrôleur.
* **Points relevés** :
    * matter.js ouvre ses sockets en arrière-plan : une erreur à ce moment arrête Node-RED. Le port UDP et IPv6 sont donc testés avant chaque démarrage du pont.
    * le code « à l'arrêt » d'un nœud function n'est pas attendu par Node-RED : le nouveau pont attend la fin de la fermeture de l'ancien avant de démarrer.
    * en `network_mode: host`, le tableau de bord écoute sur le port 1880 de l'hôte (variable `PORT`) et non sur le port 80.


## Choix à faire

### 1. La brique Matter

| Option | Principe | Pour | Contre |
| --- | --- | --- | --- |
| **A. Node-RED + matter.js** | Projet dknr classique (Node-RED, Dashboard 2). Le pont est créé par du code [matter.js](https://github.com/project-chip/matter.js) (`@matter/main`) dans des nœuds function (`libs`, `functionExternalModules` déjà activé), avec un *ServerNode*, un *AggregatorEndpoint* et un endpoint *bridged* par appareil, ajoutés et retirés dynamiquement. | Même structure, même tableau de bord et même logique que dknr-alexa (catalogue des entités, page Appareils, sauvegarde). Aucune dépendance à un autre produit. | Cycle de vie du serveur Matter à gérer dans Node-RED (création au démarrage, arrêt propre au redéploiement). Plus de code à écrire et à maintenir. |
| **B. Node-RED + [node-red-matter-bridge](https://github.com/sammachin/node-red-matter-bridge)** | Un nœud Node-RED par appareil Matter. | Rien à coder côté Matter. | Un nœud par appareil, exactement ce que dknr-alexa a évité. Types d'appareils limités, projet marqué *work in progress*, plantages signalés. |
| **C. [Matterbridge](https://github.com/Luligu/matterbridge) + plugin dknr** | Image `luligu/matterbridge` et un plugin TypeScript `matterbridge-dknr` qui lit le format DKNR sur MQTT (sur le modèle de son plugin zigbee2mqtt). | Produit mûr, très utilisé avec Alexa, interface d'appairage (QR code) et gestion des appareils déjà faites, suit matter.js (0.17, Matter 1.6). | Sort de la structure dknr (pas de Node-RED ni de Dashboard 2, configuration dans l'interface Matterbridge), autre chaîne de publication, dépendance à un projet tiers. |

Recommandation : **A**, pour rester dans la famille dknr et reprendre directement la page Appareils de dknr-alexa (c'était l'évolution prévue dans sa conception : *seule la sortie change*). Garder **C** en solution de repli si matter.js dans Node-RED se montre instable. Écarter B.

À valider en premier : un prototype minimal (un pont, une prise, une température) appairé à Home Assistant puis à un Echo Show 5, avec un redéploiement Node-RED et un redémarrage du conteneur au milieu.

### 2. La configuration des appareils

* **Option recommandée** : une page **Appareils** propre à dknr-matter, copiée de dknr-alexa (nom, pièce, type, une ou plusieurs entités DKNR, actif). Pas d'import de la sauvegarde dknr-alexa : les appareils sont créés à la main (décidé en novembre 2026).
* Alternative : lire directement la configuration de dknr-alexa. Plus rapide au départ, mais lie les deux projets alors que dknr-alexa doit pouvoir disparaître.

### 3. Les types d'appareils

Correspondance proposée (première version) :

| Usage DKNR | Type Matter | Remarque |
| --- | --- | --- |
| lumière (binaire) | On/Off Light | |
| lumière (variateur, `%`) | Dimmable Light | niveau 0-254 côté Matter, 0-99 côté DKNR |
| prise, VMC, climatisation, enceintes | On/Off Plug-in Unit | |
| ouverture (porte, fenêtre, baie) | Contact Sensor | `1` = ouvert sauf unité `rb` ; attention, *StateValue* Matter vaut `true` quand le contact est **fermé** |
| mouvement | Occupancy Sensor | |
| température | Temperature Sensor | centièmes de °C côté Matter |
| humidité | Humidity Sensor | nouveau par rapport à VSH |
| volet | Window Covering | position en centièmes de %, sens à vérifier (Matter : 0 = ouvert) |

Plus tard : Thermostat (consigne), Door Lock (Nuki, avec les restrictions d'Alexa sur le déverrouillage vocal), Fan.

### 4. Le pont

* **Un seul pont** (un *ServerNode*, un QR code) pour tous les appareils, ou un pont par usage ou par pièce ? Recommandation : un seul pont au départ.
* **Identifiants stables** : chaque endpoint *bridged* reçoit un identifiant dérivé de l'identifiant de l'appareil dans dknr-matter. Le changer crée un nouvel appareil chez les contrôleurs (même règle que les nœuds VSH).
* **Appairage** : code d'appairage manuel (11 chiffres) et QR code affichés sur une page du tableau de bord, comme la connexion Amazon de dknr-alexa.
* **Multi-administrateur** : un même pont peut être appairé à plusieurs contrôleurs (Alexa et Home Assistant par exemple).
* **Stockage** : l'état Matter (identité, fabrics, certificats d'appairage) est conservé dans le volume `/data` (ex : `/data/matter`), jamais dans le dépôt.

### 5. La transition depuis dknr-alexa

* Tester d'abord avec quelques appareils aux noms distincts pour éviter les doublons dans Alexa (un appareil VSH et son jumeau Matter).
* Puis basculer appareil par appareil ou d'un coup, en supprimant les appareils VSH correspondants (pièces, groupes et routines Alexa à refaire, comme lors de la migration vers dknr-alexa).
* Arrêter l'abonnement VSH une fois la bascule faite.


## Fonctionnement prévu (option A)

### Entités DKNR

Comme dknr-alexa :

* Catalogue depuis `dknr/discovery/<source>/<parent>/<entité>` (nom, groupe, type, unité, options), valeurs depuis `dknr/get/<source>/<parent>/<entité>`.
* Commandes sur `dknr/set/<source>/<parent>/<entité>`.
* Format DKNR : binaires `1` / `0`, listes par clé d'option, `rb` = binaire inversé.
* Dernière valeur conservée dans le contexte persistant pour les sources qui ne publient pas en `retain` (RFXCom, Daikin).

### Traduction

* **DKNR vers Matter** : chaque valeur reçue met à jour l'attribut de l'endpoint correspondant (`onOff`, `currentLevel`, `measuredValue`, `stateValue`, `occupancy`, position de volet...). Pas de limitation de trafic imposée comme chez VSH, mais on n'écrit que les changements.
* **Matter vers DKNR** : les événements de changement d'attribut d'un endpoint (ex : `onOff` changé par le contrôleur) publient sur `dknr/set` de chaque entité de l'appareil. Distinguer un changement venu du contrôleur d'une mise à jour venue de DKNR, pour ne pas renvoyer l'ordre en boucle.
* **Appareils groupés** : ordre envoyé à toutes les entités, état lu sur la première (comme dknr-alexa).

### Pages

* **Appareils** : liste, ajout, modification.
* **Pont** : état du serveur Matter, code d'appairage et QR code, contrôleurs appairés (fabrics), bouton de réinitialisation de l'appairage.
* **Configurer** : MQTT (hôte, port, utilisateur, mot de passe, topic `dknr`), sauvegarde et restauration.


## Structure attendue du dépôt

Comme les autres dépôts dknr (voir dknr-alexa) :

* `Dockerfile` (image `nodered/node-red`, clone du dépôt dans `/data/projects/dknr-matter`), `docker-entrypoint.sh`, `docker-compose.yaml` avec `network_mode: host`, `data/settings.js` (`httpAdminRoot: "/admin"`, projets activés, `functionExternalModules: true`).
* `package.json` avec `@flowfuse/node-red-dashboard` et `@matter/main` (option A), `flows.json`.
* `.github/workflows` : `release.yaml`, `release_dev.yaml`, `clean_repository.yml`, `update_docker_readme.yml`, `dependabot.yml`. Secrets `DOCKER_USERNAME` / `DOCKER_TOKEN` à créer sur le dépôt.
* `README.md` dans le style des autres projets, et une page sur le site [dknr-domotic.github.io](https://dknr-domotic.github.io) (section Intégrations).


## Tests

* **Sans matériel** : Home Assistant en conteneur avec son intégration Matter comme premier contrôleur, pour appairer le pont, voir les endpoints et piloter.
* **Avec Alexa** : un Echo Show 5. Vérifier la découverte, le pilotage vocal, les routines sur capteurs, et la stabilité dans le temps (pont qui disparaît, voir *Contexte*).
* **Robustesse** : redéploiement Node-RED, redémarrage du conteneur, mise à jour de l'image, ajout et retrait d'appareils sans réappairer le pont.


## Evolutions

* **dknr-thread** : nouvelle source DKNR pour les appareils Matter-over-Thread (ampoules, prises, thermostats IKEA bon marché...), avec la clé **SONOFF Dongle-M** (inutilisée aujourd'hui) flashée en firmware Thread RCP, branchée en USB, et OpenThread Border Router en conteneur. Elle aura besoin d'un contrôleur Matter (matter.js le permet aussi) pour lire et piloter ces appareils et les publier au format DKNR.
* Thermostat, serrure, ventilateur côté pont.
* Retrait de dknr-alexa une fois la bascule terminée.
