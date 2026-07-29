# Changelog

> 🇫🇷 [Version française](CHANGELOG.fr.md)

## Unreleased

- README: document the update and removal process — always run from the project used to install the add-on, since DDEV records the installation per project (`.ddev/addon-metadata/`, DDEV limitation, see ddev/ddev#6145) (#5)
- README: note that `ddev add-on get` requires a DDEV project context (run it from a project directory or use `--project`) (#4)
- Switch the changelog to English, French version kept in `CHANGELOG.fr.md` and cross-linked from the header (#3)
- Main README translated into English, French version kept in `README.fr.md` and linked from the header (#2)

## 0.1.0 — 2026-07-29

- Initial implementation of the add-on: 10 global commands (`db-import`, `db-export`, `db-{prod,preprod}-{dump,get,import}`, `ssh-{prod,preprod}`) plus `db-import` autocompletion, installed via `global_files`, with bats tests in an isolated HOME (#1)
