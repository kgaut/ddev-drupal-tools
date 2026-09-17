# 0009 — Les étapes autour d'un import ou d'un export suivent le type DDEV du projet

- **Statut** : Complétée par `0011-commandes-dump-mysqldump-en-flux`
- **Date** : 17/09/2026
- **Ticket** : #9
- **Périmètre** : commandes
- **Remplace** : `0001-commandes-etapes-drupal-uniquement`
- **Amende** : —

## Contexte

Mesuré le 17/09/2026 :

- `db-import` enchaînait toujours `ddev drush deploy`, `ddev drush cr` et `ddev drush uli` après
  `ddev import-db`. `db-export` lançait `ddev drush cr` avant `ddev export-db`, sauf avec `--no-cr`.
- Sur un projet non Drupal, l'import passait, puis la commande échouait sur la première étape drush.
  DDEV ne fournit en effet `ddev drush` qu'aux types `drupal*` et `backdrop`, et `ddev console`
  qu'au type `symfony` (annotation `## ProjectTypes:` de ses commandes web, DDEV 1.25.4).
- DDEV transmet aux commandes host la clé `type` du `.ddev/config.yaml` dans
  `DDEV_PROJECT_TYPE`, surcharges `config.*.yaml` comprises, y compris projet arrêté (vérifié en
  HOME isolé).
- Le projet Symfony `datafcid.nikonclub.fr` (type `symfony`) contournait l'addon avec
  `ddev import-db`. Sa session de travail a relevé, le 17/09/2026 :
  - `ddev console cache:clear` suffit après un import (code 0, 2,2 s en Symfony 3.4) ;
  - aucune commande Doctrine ne doit jamais tourner, même en local (ADR 0204 de ce projet) ;
  - il n'y a pas d'équivalent à `drush uli` (les comptes admin sont en mémoire) ;
  - ses prérequis de base (base `datafcid`, utilisateur `DEFINER`) sont déjà assurés par un hook
    `post-start` du projet.
- DDEV propose nativement les hooks `pre-import-db` et `post-import-db`, déclenchés par
  `ddev import-db`, donc aussi quand `db-import` l'appelle.

Supposé : les caches des autres frameworks ne sont pas en base, et un export sans vidage préalable
n'y alourdit pas le dump.

## Décision

Décision de Kevin : **la clé `type` du `.ddev/config.yaml`** (lue dans `DDEV_PROJECT_TYPE`)
choisit les étapes.

| Type DDEV | `db-import`, après l'import | `db-export`, avant l'export |
|---|---|---|
| `drupal`, `drupal6` … `drupal12` | `drush deploy`, `drush cr`, `drush uli` | `drush cr` (`--no-cr` pour s'en passer) |
| `symfony` | `console cache:clear` | rien |
| tout autre type, ou type absent | rien, avec un message qui renvoie au hook `post-import-db` | rien |

- Les étapes **propres à un projet** passent par les hooks natifs de DDEV (`pre-import-db`,
  `post-import-db`), jamais par une configuration de l'addon.
- `db-{prod,preprod}-dump` reste fondé sur `drush sql-dump`. Sans `<ENV>_DRUSH` sur un projet
  non Drupal, son erreur le dit et donne le type du projet. Avec `<ENV>_DRUSH`, la commande
  s'exécute quel que soit le type : le drush du serveur ne dépend pas du type local.
- Limites :
  - `backdrop` est traité comme « autre type », car `drush deploy` n'y existe pas ;
  - `drupal6` et `drupal7` gardent les étapes Drupal, alors que `drush deploy` n'existe pas en
    drush 8. Le comportement est inchangé, et cette question n'est pas tranchée ici.

## Options écartées

- **Commandes surchargées dans le `.env`** (`DB_IMPORT_POST_CMD`, `DB_EXPORT_PRE_CMD`).
  - C'est plus général, mais une variable d'environnement deviendrait du code exécuté, ce qui va
    à l'encontre du principe « le `.env` n'est jamais exécuté ».
  - Cela doublonne les hooks de DDEV.
- **Détection par les fichiers du projet** (`vendor/bin/drush`, `bin/console`) : cela contredirait
  le découpage de DDEV. Un projet `php` qui contient drush n'a pas de `ddev drush`, et
  l'étape échouerait quand même.
- **Garder drush partout et ajouter une option `--no-drush`** : il faudrait y penser à chaque
  import sur un projet non Drupal, sans rien apporter à Symfony.
- **`doctrine:migrations:migrate` pour Symfony**, par analogie avec `drush deploy`. Tous les
  projets n'ont pas le bundle de migrations, et certaines bases ne doivent jamais migrer
  (datafcid). Un projet qui en veut le déclare dans un hook `post-import-db`.
- **Un équivalent d'`uli` pour Symfony** : il n'existe pas de mécanisme générique.

## Conséquences

- Interdit désormais :
  - ajouter une étape spécifique à un projet dans l'addon ;
  - lire une commande à exécuter dans un fichier `.env` ;
  - lancer `ddev drush` hors des types `drupal*`.
- Un nouveau type pris en charge (par exemple `laravel`) s'ajoute au même `case`, dans
  `db-import` et `db-export`, avec ses tests.
- Un projet dont le `type` DDEV est faux perd ses étapes automatiques, sans autre signal que le
  type affiché et le message de fin.
- Rien ne vérifie qu'une étape automatique convient à tous les projets d'un type donné : un
  `cache:clear` qui échoue interrompt `db-import` après un import réussi.
- Le nom de l'addon (`drupal-tools`) devient partiellement trompeur. Son renommage reste ouvert
  (#9).
- Le dump sans drush (mysqldump envoyé directement en local) est traité à part, dans #11.

## Suivi

- **17/09/2026** : ADR écrite dans #9, après la décision de Kevin (« base-toi sur la clé type du
  config.yaml de ddev ») et le retour de la session datafcid.
- **17/09/2026** : complétée par `0011-commandes-dump-mysqldump-en-flux` (#11). `db-*-get` sait
  désormais dumper sans drush (mysqldump envoyé directement en local), et l'erreur de
  `db-*-dump` sans `<ENV>_DRUSH` y renvoie. La règle de cette ADR sur `db-*-dump` reste en
  vigueur.
