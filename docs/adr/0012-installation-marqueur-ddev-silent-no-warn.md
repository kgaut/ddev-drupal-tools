# 0012 — Les fichiers installés portent `#ddev-silent-no-warn` en plus de `#ddev-generated`

- **Statut** : En vigueur
- **Date** : 17/09/2026
- **Ticket** : #12
- **Périmètre** : installation
- **Remplace** : —
- **Amende** : —

## Contexte

Mesuré le 17/09/2026, dans le source de DDEV v1.25.4 et en HOME isolé :

- À chaque `ddev start`, `CheckCustomConfig` (`pkg/ddevapp/config_custom.go`) liste la
  « configuration personnalisée ». Cela inclut tout fichier de `~/.ddev/commands` qui n'est pas
  un asset de DDEV.
- Les fichiers d'un addon ne sont exemptés que d'après `GatherAllManifests(app)`, c'est-à-dire
  les manifestes du **projet courant** (`.ddev/addon-metadata/*/manifest.yaml`). DDEV n'a pas de
  vrai addon global (ddev/ddev#6145) : le manifeste de `drupal-tools` n'existe que dans le
  projet qui a servi à l'installation.
- Dans tout autre projet, les 11 fichiers de l'addon sont donc listés « (unexpected
  #ddev-generated) », avec le conseil « Remove unexpected '#ddev-generated' comments from files
  to avoid possible overrides ». Constaté sur datafcid, reproduit en HOME isolé.
- Le risque d'écrasement évoqué ne nous concerne pas : `CopyEmbedAssets` ne réécrit que les
  fichiers qui portent le nom d'un asset DDEV, et nos noms n'en font pas partie.
- DDEV documente `#ddev-silent-no-warn` pour taire ces avertissements (FAQ, et
  `ddev debug check-custom-config`). Un fichier qui le porte n'est plus signalé, sauf avec
  `--all`, où il reste listé et annoté.
- `ddev add-on get` (mise à jour) et `ddev add-on remove` ne regardent que `#ddev-generated`.
  Vérifié en HOME isolé : mise à jour et suppression inchangées avec les deux marqueurs.

## Décision

- **Tout fichier installé** par l'addon porte, juste sous le shebang :
  - ligne 2 : `#ddev-generated` (inchangé : DDEV met le fichier à jour et le supprime) ;
  - ligne 3 : `#ddev-silent-no-warn` (DDEV ne le signale plus comme configuration
    personnalisée).
- Un test bats vérifie les deux marqueurs, dans cet ordre, pour chaque entrée de
  `global_files`. Un autre vérifie qu'un second projet, sans manifeste, ne signale rien.
- Limites :
  - le marqueur tait aussi un signalement légitime, par exemple un fichier de l'addon modifié à
    la main sans retirer `#ddev-generated` ;
  - le signalement reste visible avec `ddev debug check-custom-config --all`.

## Options écartées

- **Retirer `#ddev-generated`**, comme le suggère le message : DDEV ne mettrait plus les
  fichiers à jour et refuserait de les supprimer (`ddev add-on remove`).
- **Installer le manifeste dans chaque projet** (lancer `ddev add-on get` depuis chacun) :
  plusieurs manifestes pour un seul jeu de fichiers globaux, que `remove` gérerait mal, et une
  étape de plus à chaque nouveau projet.
- **Passer en `project_files`** : l'addon ne serait plus global.
- **Ne rien faire, en attendant un correctif upstream** : l'avertissement bruite chaque
  `ddev start` de chaque projet, et habitue à ignorer les signalements de configuration.
- **Documenter seulement** (« ignorer ce message ») : même défaut.

## Conséquences

- Interdit désormais :
  - ajouter un fichier installé sans les deux marqueurs ;
  - retirer `#ddev-generated` pour faire taire DDEV.
- Si DDEV reconnaît un jour les `global_files` indépendamment du projet, le marqueur deviendra
  inutile sans être nuisible. On pourra alors le retirer, par une nouvelle ADR.
- Rien ne garantit que le comportement de `CheckCustomConfig` reste le même d'une version de
  DDEV à l'autre : le test d'intégration le surveille sur la version installée.

## Suivi

- **17/09/2026** : ADR écrite dans #12, sur le go de Kevin, après lecture du source de DDEV
  v1.25.4 et vérification en HOME isolé.
