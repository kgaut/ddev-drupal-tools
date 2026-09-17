# 0011 — Sans drush, `db-*-get` fait un mysqldump envoyé directement en local

- **Statut** : En vigueur
- **Date** : 17/09/2026
- **Ticket** : #11
- **Périmètre** : commandes
- **Remplace** : —
- **Amende** : —

## Contexte

Mesuré le 17/09/2026 :

- `db-{prod,preprod}-dump` écrit un dump **sur le serveur** par `<ENV>_DRUSH sql-dump`.
  `db-*-get` rapatrie ensuite le plus récent du dossier `<ENV>_DB_PATH`, et `db-*-import`
  enchaîne get puis import. L'ADR `0009-commandes-etapes-selon-le-type-ddev` réserve
  `db-*-dump` aux projets Drupal et renvoie le dump sans drush à #11.
- Le projet Symfony `datafcid.nikonclub.fr` n'a ni drush, ni dossier de dumps sur le serveur.
  Sa prod n'a que 891 Mo libres sur 2 Go dans `/home`.
- Sa session de travail prend ses dumps ainsi, et en a vérifié le contenu (9 procédures
  `DEFINER`) :

  ```
  ssh … "set -o pipefail; nice -n 10 mysqldump --single-transaction --quick --routines --triggers --events --no-tablespaces <base> | nice -n 10 gzip -6" > <local>.sql.gz
  ```

  - Identifiants : `~/.my.cnf` du compte SSH, section `[client]`, sans base.
  - Nom de la base : différent selon l'environnement.
  - `--no-tablespaces` est nécessaire (pas de droit PROCESS).
- `set -o pipefail` est refusé par le dash 0.5.11 de Debian 11, qui arrête alors le shell. Dans
  un sous-shell, le test ne casse rien (vérifié en conteneur `debian:11-slim` et `bash:3.2` /
  busybox).
- `db-import` ne retient que les extensions de dump connues : un fichier `.sql.gz.part` est
  ignoré (vérifié par test).

Supposé :
- les serveurs visés ont un shell de login POSIX, comme pour les autres commandes distantes ;
- mysqldump (MySQL ou MariaDB) termine un dump réussi par `-- Dump completed`, sauf réglage
  `skip-comments`.

## Décision

- `db-{prod,preprod}-get` a désormais deux modes, choisis par la configuration :
  - **`<ENV>_DB_PATH` défini** (avec `<ENV>_PATH`) : il rapatrie le dump le plus récent du
    serveur. C'est le comportement d'avant, et il **l'emporte** si les deux variables sont
    définies ;
  - **`<ENV>_DB_NAME` défini, sans `<ENV>_DB_PATH`** : il lance sur le serveur
    `nice -n 10 mysqldump --single-transaction --quick --routines --triggers --no-tablespaces '<base>' | nice -n 10 gzip`,
    et la sortie arrive **directement** dans le dossier de dumps local. Rien n'est écrit sur le
    serveur. Seuls `<ENV>_USER`, `<ENV>_HOST` et `<ENV>_DB_NAME` sont requis.
- **Identifiants** : `~/.my.cnf` du compte SSH, lu par mysqldump. L'addon ne lit ni ne transmet
  aucun mot de passe.
- **`pipefail`** est activé côté serveur seulement si le shell le connaît (test en sous-shell).
- **Écriture sûre** :
  - le flux arrive dans `<fichier>.sql.gz.part` ;
  - le fichier n'est gardé, renommé en `<date>-<ENV>_URL|projet DDEV-<env>.sql.gz`, que si
    `gzip -t` passe **et** que la dernière ligne commence par `-- Dump completed` ;
  - sinon, il est supprimé (y compris sur SIGINT et SIGTERM) et la commande sort en erreur.
- `db-*-import` n'est pas modifié : get puis import fonctionne dans les deux modes.
- `db-*-dump` reste fondé sur drush. Sans `<ENV>_DRUSH`, son erreur renvoie vers `db-*-get`
  quand `<ENV>_DB_NAME` est défini, ou quand le projet n'est pas de type Drupal. Un projet
  Drupal sans ces deux variables garde le message générique « variable manquante ».
- Cette décision **complète** `0009-commandes-etapes-selon-le-type-ddev`, dont la règle sur
  `db-*-dump` reste en vigueur.
- Limites :
  - pas de mysqldump **sur le serveur** (dump dans `<ENV>_DB_PATH` sans drush) ;
  - pas d'options mysqldump configurables ;
  - pas de `--events` ;
  - pas d'hôte ni de port de base distincts ailleurs que dans `.my.cnf`.

## Options écartées

- **Une nouvelle commande** (`db-*-pull`, par exemple) : deux commandes de plus, et
  `db-*-import` aurait dû choisir entre deux chemins. Le rôle de `db-*-get`, « poser un dump
  de l'environnement dans le dossier local », couvre déjà le besoin.
- **Changer le sens de `db-*-dump`** (dump local sans drush) : la même commande écrirait
  tantôt sur le serveur, tantôt en local.
- **Choisir le mode d'après le type DDEV** : le type décrit le projet local, pas ce qui existe
  sur le serveur. Un projet Drupal peut aussi manquer de place côté serveur. Le mode suit donc
  la configuration.
- **Une variable de mode explicite** (`<ENV>_DUMP_MODE`) : c'est une variable de plus, alors
  que la présence de `<ENV>_DB_PATH` ou de `<ENV>_DB_NAME` suffit à dire l'intention.
- **Passer les identifiants par l'addon** (variables, lecture du `.env` du serveur) : le mot de
  passe circulerait dans la commande SSH et dans les listes de processus. `.my.cnf` est la
  voie standard.
- **Garder `--events`** (commande de datafcid) : il échoue sans le droit EVENT, et des
  événements planifiés de prod ne doivent pas tourner en local.
- **`set -o pipefail` sans test** : cela casserait les serveurs dont le shell est un dash
  ancien.
- **Écrire directement le fichier final** : un dump interrompu pourrait être pris par
  `db-import` comme le plus récent.

## Conséquences

- Interdit désormais :
  - faire transiter un mot de passe de base par l'addon ;
  - écrire le flux ailleurs que dans un `.part` contrôlé ;
  - ajouter une commande de récupération parallèle à `db-*-get`.
- Un `.my.cnf` réglé en `skip-comments` fait refuser tous les dumps (pas de ligne de fin). Le
  message affiche la dernière ligne reçue.
- Le dump frais sollicite la base de production à chaque `db-*-get` ou `db-*-import` (atténué
  par `nice`). Aucun garde-fou de fréquence n'existe.
- Rien ne vérifie que la base nommée est bien celle de l'environnement : une erreur de
  `<ENV>_DB_NAME` rapatrie une autre base, si le compte y a accès.
- La vérification de la ligne de fin décompresse tout le dump en local (quelques secondes pour
  150 Mo).

## Suivi

- **17/09/2026** : ADR écrite dans #11, sur le go de Kevin, à partir de la commande et des
  contraintes relevées par la session datafcid.
