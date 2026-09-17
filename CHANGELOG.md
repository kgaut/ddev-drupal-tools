# Changelog

> 🇫🇷 [Version française](CHANGELOG.fr.md)

## 0.4.1 — 2026-09-17

- Stop `ddev start` from listing the add-on's global commands as custom configuration ("Remove unexpected '#ddev-generated' comments") in every project but the one used to install it: DDEV only recognizes add-on files through the current project's manifest, so the installed files now also carry `#ddev-silent-no-warn`. See ADR `0012-installation-marqueur-ddev-silent-no-warn` (#12)
- `db-{prod,preprod}-dump` checks `<ENV>_DRUSH` before `<ENV>_PATH`, so that a project in `<ENV>_DB_NAME` mode is pointed to `db-*-get` instead of being asked for a path it does not need; a failed `mysqldump` in `db-*-get` now also names `<ENV>_DB_NAME`, since MariaDB answers "Access denied" for a missing database (#14)

## 0.4.0 — 2026-09-17

- `db-{prod,preprod}-get` can dump without drush: with `<ENV>_DB_NAME` and no `<ENV>_DB_PATH`, it streams a gzipped `mysqldump` (credentials from the server's `~/.my.cnf`) straight to the local dumps directory, keeping the file only once the archive and mysqldump's final line are checked; `db-{prod,preprod}-import` follows, and `db-{prod,preprod}-dump` points there when drush is missing. See ADR `0011-commandes-dump-mysqldump-en-flux` (#11)

## 0.3.0 — 2026-09-17

- `db-import` and `db-export` follow the DDEV project type (`type` key of `.ddev/config.yaml`): unchanged `drush` steps for Drupal, `console cache:clear` after an import for Symfony, no automatic step for other types, whose own steps go into DDEV `post-import-db` hooks. See ADR `0009-commandes-etapes-selon-le-type-ddev` (#9)
- Read `.env.local` before `.env` for every project variable (`<ENV>_*`, `LOCAL_DB_PATH`, `DB_DUMP_DIR`), since Symfony projects commit their `.env` and keep local values in `.env.local`. See ADR `0009-config-env-local-avant-env` (#9)
- `db-{prod,preprod}-dump` explains that it relies on drush when `<ENV>_DRUSH` is missing on a non-Drupal project (#9)
- Fix the double slash in remote paths when `<ENV>_PATH` or `<ENV>_DB_PATH` ends with `/` (#13)

## 0.2.0 — 2026-09-17

- Fix `db-{prod,preprod}-dump` exiting with code 2 after a successful dump: the final listing of the dumps directory ran from the SSH home, where a relative `<ENV>_DB_PATH` does not exist. It now runs from `<ENV>_PATH`, like the dump itself (#10)
- Fix `ddev <command> -h` running the remote commands (`db-{prod,preprod}-{dump,get,import}`, `ssh-{prod,preprod}`) instead of showing their help: without a `## Flags:` annotation, DDEV passed `-h` on to the script. Unknown flags are now rejected too, e.g. `ddev db-prod-import -y` (#10)
- `db-{prod,preprod}-get` shows the date of the fetched dump and warns when it is more than 24 hours old, so that a `<ENV>_DB_PATH` pointing to a stale directory no longer goes unnoticed (#10)

## 0.1.3 — 2026-08-31

- Fix `db-{prod,preprod}-get` looking for dumps in the wrong remote directory: a relative `<ENV>_DB_PATH` was resolved from the SSH home, while `db-{prod,preprod}-dump` resolves it from `<ENV>_PATH`, so dumps were written to one directory and searched for in another. Both commands now agree, and `<ENV>_PATH` became a required variable for `db-*-get` (#8)

## 0.1.2 — 2026-08-06

- Fix `db-import` and its autocompletion on macOS: replace `mapfile` (bash 4+) and `find -printf` / `date -d` (GNU-only) with constructs that also work with the bash 3.2 and BSD tools shipped by macOS (#7)
- Fix `db-{prod,preprod}-dump` when the remote dump directory starts with `~`: the tilde was left unexpanded inside the quoted remote redirection, it now goes through `$HOME`, evaluated by the server shell (#7)
- README: recommend ignoring only the add-on manifest file (`.ddev/addon-metadata/drupal-tools/manifest.yaml`) rather than the whole `addon-metadata/` directory, whose project-level manifests are meant to be committed (#6)

## 0.1.1 — 2026-07-30

- README: document the update and removal process — always run from the project used to install the add-on, since DDEV records the installation per project (`.ddev/addon-metadata/`, DDEV limitation, see ddev/ddev#6145) (#5)
- README: note that `ddev add-on get` requires a DDEV project context (run it from a project directory or use `--project`) (#4)
- Switch the changelog to English, French version kept in `CHANGELOG.fr.md` and cross-linked from the header (#3)
- Main README translated into English, French version kept in `README.fr.md` and linked from the header (#2)

## 0.1.0 — 2026-07-29

- Initial implementation of the add-on: 10 global commands (`db-import`, `db-export`, `db-{prod,preprod}-{dump,get,import}`, `ssh-{prod,preprod}`) plus `db-import` autocompletion, installed via `global_files`, with bats tests in an isolated HOME (#1)
