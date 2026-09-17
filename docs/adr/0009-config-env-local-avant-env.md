# 0009 — La configuration des projets se lit dans `.env.local`, puis dans `.env`, sans jamais les sourcer

- **Statut** : En vigueur
- **Date** : 17/09/2026
- **Ticket** : #9
- **Périmètre** : config
- **Remplace** : —
- **Amende** : `0001-config-env-du-projet`

## Contexte

Mesuré le 17/09/2026 :

- Les variables `<ENV>_*` (hôte, utilisateur, chemins des serveurs) et `LOCAL_DB_PATH` n'étaient
  lues que dans le `.env` du projet. `DB_DUMP_DIR` l'était dans `.env`, puis dans `.ddev/.env`.
- Sous Symfony 4 et plus, le `.env` est **versionné**, et les valeurs propres à un poste vont dans
  `.env.local`, qui est ignoré. Lues seulement dans le `.env`, les variables d'accès aux serveurs
  finiraient dans le dépôt, parfois celui d'un client.
- Le type `symfony` de DDEV 1.25.4 génère un `.env.local` (`DATABASE_*`, `MAILER_*`), et
  **conserve les clés qu'on y ajoute** au redémarrage (vérifié par la session datafcid).
- datafcid (Symfony 3.4) ignore encore son `.env`, mais le versionnera à sa montée en Symfony 7.4.
  Sa session mettrait alors ses `<ENV>_*` dans `.env.local`.

## Décision

- Les commandes lisent chaque variable dans cet ordre, et retiennent la première valeur non vide :
  - `<ENV>_*` et `LOCAL_DB_PATH` : environnement, puis `.env.local`, puis `.env` ;
  - `DB_DUMP_DIR` : environnement, puis `.env.local`, puis `.env`, puis `.ddev/.env`.
- Ce principe de l'ADR amendée reste en vigueur : ces fichiers ne sont **jamais sourcés**, chaque
  variable est extraite par `grep` (helper `read_env_var`, dupliqué dans chaque commande).
- L'ordre vaut pour tous les projets, Drupal compris : un `.env.local` y est rare, et il prime alors
  comme dans la convention dotenv.
- Limites :
  - pas de lecture de `.env.<APP_ENV>` ni de `.env.<APP_ENV>.local` ;
  - pas d'interpolation (`${VAR}`) ;
  - une variable vide dans `.env.local` ne masque pas celle du `.env`.

## Options écartées

- **Lire seulement le `.env`** : sur un projet Symfony récent, les accès serveurs y seraient
  versionnés.
- **Lire `.env` avant `.env.local`** : cela inverserait la convention dotenv que les projets
  Symfony appliquent déjà.
- **Mettre les variables dans `.ddev/.env`** : DDEV injecte ce fichier dans les conteneurs, et
  la configuration serveur n'a rien à y faire. Il reste lu pour le seul `DB_DUMP_DIR`, par
  compatibilité.
- **Sourcer les fichiers** : un `.env` exécuté pourrait lancer n'importe quelle commande.
- **Reproduire toute la cascade dotenv de Symfony** (`.env.<env>`, `.env.<env>.local`) : il
  faudrait connaître `APP_ENV`, pour un besoin qui n'est pas constaté.

## Conséquences

- Interdit désormais :
  - lire une variable de projet dans le seul `.env` ;
  - sourcer un de ces fichiers.
- Toute nouvelle variable passe par `read_project_var` (ou par la même cascade pour `DB_DUMP_DIR`),
  dans chaque commande et dans le script d'autocomplétion.
- Une valeur oubliée dans `.env.local` masque silencieusement celle du `.env`.
- Rien ne vérifie automatiquement que les 10 commandes appliquent le même ordre : ce sont des
  copies. Seuls les tests bats en couvrent une partie.

## Suivi

- **17/09/2026** : ADR écrite dans #9, d'après la proposition du ticket et le retour de la session
  datafcid.
