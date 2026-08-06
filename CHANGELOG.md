# Changelog

> 🇫🇷 [Version française](CHANGELOG.fr.md)

## Unreleased

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
