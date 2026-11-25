# Upstream sync (LIDR specboot fork)

This repository is a fork of [LIDR-academy/lidr-specboot](https://github.com/LIDR-academy/lidr-specboot). Retain uses a separate branch flow for releases; **`main` is reserved for tracking the upstream fork**, not for production deploys.

## Branch roles

| Branch | Purpose |
|--------|---------|
| `main` | Align with upstream `lidr-specboot`; merge or rebase updates from LIDR here first |
| `master` | Retain integration line (default for GitHub Actions / branch policy) |
| `test` | QA environment |
| `preprod` | Pre-production |

History: `main` was restored on the remote so it can diverge from `master` while Retain-specific changes (`.github`, branch templates, org workflow) live on `master` → `test` → `preprod`.

`master` is ahead of `main`; that is expected.

## One-time setup (new clone)

```bash
git remote add upstream git@github.com:LIDR-academy/lidr-specboot.git
git fetch origin
git fetch upstream   # requires read access to the LIDR repository
```

If `upstream` already exists (`git remote -v`), skip `git remote add`.

## Sync workflow

Run from the repository root:

```bash
git fetch upstream
git fetch origin
git checkout main
git merge upstream/main   # or: git rebase upstream/main
```

Resolve conflicts favouring intentional Retain customizations only where they must differ from upstream; prefer upstream for generic Specboot assets (`docs/`, `ai-specs/`, `setup-sdd.md`, etc.).

Publish the updated tracking branch:

```bash
git push origin main
```

Integrate into Retain’s release line (never skip review):

1. Open a pull request **`main` → `master`**.
2. After merge, promote through the usual flow (`master` → `test` → `preprod`) per Retain control-versiones policy.

## GitHub UI (optional)

If your account has fork sync enabled on GitHub, you can use **Sync fork** on `RetainTechnologiesSL/workspace-ia` targeting **`main`**. Still open a PR into `master` so Retain-only files are reviewed before they enter the integration branch.

## Troubleshooting

| Symptom | Action |
|---------|--------|
| `Repository not found` on `git fetch upstream` | Ensure your SSH key or token has read access to `LIDR-academy/lidr-specboot` |
| Local `main` tracks a missing `origin/main` | Run `git fetch origin --prune` and `git branch -u origin/main main` |
| Large diff only in `.github/` or branch policy | Keep those changes on `master`; do not blindly overwrite when merging upstream into `main` |

## Related

- Upstream source URL: `https://github.com/LIDR-academy/lidr-specboot`
- Automated import instructions: `setup-sdd.md` (repository root)
- Retain branch protections: configured via devX gestor (`app:github-configure-branches`)