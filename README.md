# Plezy RPM repository

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
