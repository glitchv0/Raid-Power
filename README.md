# RaidPower

Universal raid buff manager for **WoW: Forever** (interface 16001), PallyPower for the whole raid.

- **Paladin blessings** per class with per-player exceptions, plus Aura, Righteous Fury and Salvation
- **Priest / Mage / Druid group buffs** split per raid group (Fortitude, Spirit, Shadow Protection, Intellect, Mark, Thorns on tanks)
- **Self-buffs for every class**: armors, shouts, Inner Fire, aspects, shields, imbues, poisons
- **Click to buff**: each tile casts on whoever needs it most, using group or Greater versions when worth it
- **Smart Buff**: one key casts the next most urgent buff you owe
- **Sync**: everyone running RaidPower shares assignments; the leader and assists can edit all of them, and Auto-assign gives everyone the same split
- **Combat-safe**: while Forever hides auras in combat, the last known state is kept and timers keep counting down

Open with `/raidpower`, from **Options → AddOns → RaidPower**, from the **Esc game menu** (toggle in Appearance), or from the minimap addon list.

## Install

Download the latest `RaidPower-<version>.zip` from [Releases](https://github.com/glitchv0/Raid-Power/releases) and extract it to
`World of Warcraft/_forever_/Interface/AddOns/`, so you have `AddOns/RaidPower/RaidPower.toc`.

## Releasing

`.github/workflows/release.yml` runs on every push to `main`:

1. Picks the next version from the last `v*` tag. A commit mentioning `BREAKING` (or `feat!:`) bumps the major version, `feat...` bumps the minor, anything else bumps the patch. The first release is `v0.2.0`.
2. Tags the commit and runs [BigWigsMods/packager](https://github.com/BigWigsMods/packager), which fills `@project-version@` in the TOC, builds `RaidPower-vX.Y.Z.zip` and creates the GitHub release with a changelog.
3. Uploads to **CurseForge** and **Wago** if those are configured (see below).

Put `[skip release]` in a commit message to push without releasing. **Actions → Release → Run workflow** forces a patch, minor or major release. Pull requests build a test zip as a workflow artifact and don't upload anything.

### CurseForge auto-upload

1. Create the project at <https://authors.curseforge.com> (game: World of Warcraft, flavor: Forever).
2. Create an API token at <https://authors.curseforge.com/account/api-tokens>.
3. In the GitHub repo, go to **Settings → Secrets and variables → Actions** and add:
   - the secret `CF_API_TOKEN` (the token)
   - the variable `CURSEFORGE_PROJECT_ID` (the numeric Project ID from the project page's "About Project" box)

### Wago (optional)

Add the secret `WAGO_API_TOKEN` and the variable `WAGO_PROJECT_ID`.

## Development

`docs/mockup/index.html` is the UI mock-up. You can test the addon in the browser simulator at <https://uiforever.com/app?flavor=forever> (it does not cast spells, so it can't show a buff landing).
