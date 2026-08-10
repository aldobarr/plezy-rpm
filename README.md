# Plezy RPM repository

An unofficial RPM repository for Plezy. This repository mirrors official Plezy releases from the [upstream Plezy repository](https://github.com/edde746/plezy). The RPMs from an official release are only ever signed by our repository, never modified.

## Repository signing key

**Fingerprint:** `9B26 8739 1070 7538 573F  3882 6D30 3557 9252 4EF8`

## Installation

### DNF v5

```bash
sudo dnf config-manager addrepo --from-repofile=https://aldobarr.github.io/plezy-rpm/plezy.repo
sudo dnf install plezy
```

### DNF v4

```bash
sudo dnf config-manager --add-repo https://aldobarr.github.io/plezy-rpm/plezy.repo
sudo dnf install plezy
```

## Updating

```bash
sudo dnf upgrade plezy
```

## Removing

```bash
sudo dnf remove plezy
sudo rm /etc/yum.repos.d/plezy.repo
```
