# nix-flake-template

A starter for Nix flakes that package **prebuilt applications**, with an auto-update pipeline that actually survives the internet. Synthesized from the Hy4ri flake fleet ([kimicode-flake], [opencode-flake], [antigravity-flake], [cheatengine-flake], [fluxer-flake], [Vivaldi-snapshot-flake]).

[kimicode-flake]: https://github.com/Hy4ri/kimicode-flake
[opencode-flake]: https://github.com/Hy4ri/opencode-flake
[antigravity-flake]: https://github.com/Hy4ri/antigravity-flake
[cheatengine-flake]: https://github.com/Hy4ri/cheatengine-flake
[fluxer-flake]: https://github.com/Hy4ri/fluxer-flake
[Vivaldi-snapshot-flake]: https://github.com/Hy4ri/Vivaldi-snapshot-flake

## Quickstart

1. **Create a repo from this template** (GitHub UI: *Use this template* → *Create a new repository*).
2. Clone it, then customize four things:
   - `scripts/check-update.sh` — set `REPO="owner/name"` (or swap in a different version source, see below)
   - `update-version.sh` — set `DOWNLOAD_URL_TEMPLATE`
   - `package.nix` — `pname`, `src` URL, `installPhase`, `meta`
   - `.github/workflows/update.yml` — the `schedule` cron if you want a different cadence
3. Generate the lockfile: `nix flake update` (the weekly `update-flake-lock` workflow also does this automatically).
4. Push. That's it — the daily workflow keeps version + hash + lockfile current.

## What the template gives you

| Piece | What it does |
|---|---|
| `scripts/check-update.sh` | **The only project-specific file.** Answers "what's the latest version?" (contract below). |
| `scripts/lib/network.sh` | Shared hardened fetch helpers: fail-fast connect, 3× retry with backoff, `max-time` cap, real error capture. |
| `update-version.sh` | Downloads the archive for a version, computes the SRI hash, updates `package.nix` + `version.json`. |
| `.github/workflows/update.yml` | Daily auto-update: check → update → **verify the flake builds** → commit → push. Auto-opens a deduped issue on failure, auto-closes it on recovery. |
| `.github/workflows/update-flake-lock.yml` | Weekly `nix flake update` so the lockfile stays fresh. |
| `flake.nix` / `package.nix` / `version.json` | Minimal package flake skeleton. |

## How the update pipeline works

```
scheduled run
   │
   ▼
check-update.sh ──► writes to $GITHUB_OUTPUT
   │                  update_needed=true/false
   │                  version=<new>
   │  (on failure)    fail_reason=<why>  + exit 1
   ▼
update-version.sh <new>        (only if update_needed)
   ▼
nix flake update
   ▼
nix flake check --no-build && nix build .#default --no-link   ← gate
   ▼
commit as github-actions[bot] + push
```

**Failure handling (the fleet's hardest-won lesson):** every network fetch fails fast (`--connect-timeout 10` instead of hanging 135s+), retries transient errors 3×, and the *real* error is captured into `fail_reason`. If the run still fails, a `report-failure` job opens an issue tagged `auto-failure` — while that issue is open, later failures **comment on it** instead of spamming (the cron runs daily; without dedupe you'd drown). When the workflow succeeds again, the issue is **closed automatically**. The run still goes red — the issue is extra visibility, not a replacement.

## check-update.sh contract

Write your version-check logic in this one file. It must:

- on update available: `echo "update_needed=true" >> $GITHUB_OUTPUT` and `echo "version=$NEW" >> $GITHUB_OUTPUT`
- on already-current: `echo "update_needed=false" >> $GITHUB_OUTPUT`
- on any failure: call `die "what went wrong"` (sources from `lib/network.sh`)

It sources `lib/network.sh`, which provides:

- `fetch_url <url>` — hardened curl (retries, timeouts), prints body or nothing
- `fetch_gh_api <gh api args...>` — GitHub API with a 3-attempt retry loop
- `die <reason>` — writes `fail_reason` + exits 1
- `$ERR_LOG` — last curl error, for building rich `die` messages

## Version-source patterns (from the fleet, pick one)

**GitHub Releases API** *(default — most reliable)*
```bash
LATEST_VERSION=$(fetch_gh_api "repos/OWNER/REPO/releases/latest" --jq '.tag_name | ltrimstr("v")')
```

**Plain HTTP endpoint** (kimicode: `code.kimi.com/kimi-code/latest`)
```bash
LATEST_VERSION=$(fetch_url "https://example.com/api/latest" | tr -d '[:space:]')
```
*Add a fallback endpoint if one exists — kimicode falls back from origin to its CDN edge.*

**Page scrape** (cheatengine: downloads page)
```bash
LATEST_VERSION=$(fetch_url "https://example.com/downloads" |
  grep -oP 'myapp_\K[0-9.]+(?=\.zip)' | sort -V | tail -n 1)
```

**Multi-channel / multi-component** (fluxer: stable+canary · Vivaldi: snapshot+stable · antigravity: cli/hub/ide/sdk)
Keep one fetch per channel/component, `die()` per failure, `update_needed=true` if *any* changed. For multi-component, store a nested `version.json` and emit one `version` output per component (the workflow's commit step can assemble a dynamic message like antigravity's `chore(cli): update to 1.0.3`).

## What the fleet taught us (design notes)

**Kept:**
1. **`version.json` as single source of truth** — every repo tracks the current version in one machine-readable file; CI, scripts and badges all read from it.
2. **SRI hashes via `nix hash convert`** — upstreams hand out hex sha256; convert once to SRI for `package.nix`.
3. **Verify before commit** — `nix flake check --no-build` + `nix build --no-link` gates every auto-commit. Never push a flake that doesn't build.
4. **Semver-aware comparisons** — `sort -V` everywhere, so a version bump can never silently regress.
5. **`workflow_dispatch` on every workflow** — a manual run button is always one click away.
6. **Bot identity for auto-commits** — `github-actions[bot]`; no human-author confusion in history.
7. **Hardened fetches + auto-issue on failure** — this template's namesake.

**Fixed:**
- 6 copies of the same curl-hardening logic → one shared `lib/network.sh`
- Inline version checks in workflow YAML → one pluggable `check-update.sh`
- Inconsistent default branches (`master` vs `main`) → template repos default to `main`
- Actions-version drift (`checkout@v4` vs `@v6`) → pinned latest at time of writing

## Notes

- `flake.lock` is intentionally **not** committed in the template — run `nix flake update` once (or let the weekly workflow do it).
- The verify step requires the package attribute `.#default`; `flake.nix` provides it.
- Local testing: `GITHUB_OUTPUT=/tmp/out ./scripts/check-update.sh` works fine — the helpers default to stdout when `GITHUB_OUTPUT` isn't set.
