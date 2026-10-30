# user-setup (works-os/user-setup)

Staff onboarding for WorksOS: `setup.sh` bootstraps a Mac so a read-only staff member
(content editor) can make edits through the Claude app's Code tab, and `README.md` is the
staff-facing walkthrough. A staff member runs the script, or Claude in Cowork runs it for
them, via `curl -fsSL https://raw.githubusercontent.com/works-os/user-setup/main/setup.sh | bash`.
Whatever is on `main` is live for every new run, so a merge here ships immediately.

Owner-set (Winston, 2026-10-27). These apply to every Claude session on Works OS,
whoever is driving it. The Notion page "Works OS: how we work" carries the same rules
for department heads.

- **Who approves.** Winston and Nick approve big changes (CODEOWNERS). A department's
  system switches on only after its department head approves with Winston and Nick.
  Access, View As, finance, commissions and caps always need Winston or Nick; Fernan
  reviews security.
- **Protect first.** Winston, Works, agents, staff and clients are always protected;
  protection beats speed. No agent or client personal data in docs, chat, logs or URLs.
  View As is read-only and never mixes two people's data.
- **Nothing sends by itself.** Works OS drafts; a person approves and sends. No client
  messages, money or commission changes, or access changes by implication. Caps and
  commissions must be 100% accurate; Finance (Sandra) sets commission plans.
- **Use what we have.** Reconcile against the shared board (works-os project 5) before
  building. Don't rebuild what exists; every PR names its board item.
- **No gates, no loops.** Build ready, ship default-off where approval is needed; keep
  only real safety gates.
- **Voice.** Neutral Works voice: declarative, no exclamation points, no outside coaching
  programs named. Every next step says why it helps the agent (encourage, never gate).
  Everything Works offers lives in the OS: no agent-resources site, office app or
  careers links.
- **Retired tools.** No SkySlope (BoldTrail), no Cypher (Works Education), no Zapier for
  ICAs (Brokerage OS → Send ICA). Cloud CMA, Prophetic and Ylopo retire only once ours
  works better.
- **Core is activation,** owned by Onboarding (Elle, Dave, Josiah). The Works Education
  library is measured separately. Nothing is locked.
- **Brand.** Works 0.5: forest #244432, action #31543E, pure white. Keep the W logo; no
  text stand-in for it.
- **Know them day one.** Prefill from recruiting and intake (FUB is the contact source);
  the agent can edit and save their own context.
- **Requests.** Department heads file requests in the Notion "Works OS requests" database;
  they become board items. Meeting transcripts are read weekly, and Works Assist suggests
  improvements for the department head to approve.

## Tooling: prefer CLIs

## What setup.sh does

macOS only (arm64 or x86_64). Sudo-free and idempotent: at each human step it explains,
exits 1, and expects to be re-run; it never waits on a typed prompt.

1. **Command Line Tools.** If `xcode-select -p` fails, triggers `xcode-select --install` and exits.
2. **Node 22+.** Uses an existing `node` if its major is >= 22; otherwise installs nvm
   (pinned `v0.40.1`) and runs `nvm install 22` + `nvm alias default 22`.
3. **GitHub CLI.** If `gh` is missing, downloads the latest release zip into `~/.local/bin`
   and appends that directory to `PATH` in `~/.zshrc` (once).
4. **GitHub login.** If `gh auth status` fails, prints the `gh auth login --web` command and exits.
5. **Fork + clone.** Only one repo: `works-os/frontend`, into `~/dev/works-os/frontend`.
   New: `gh repo fork works-os/frontend --clone` (origin = the user's fork, upstream = the
   real repo). Existing clone: adds `upstream` if missing; a wrong `origin` is left for Claude to repair in-session.
6. **Dependencies.** `npm install` in the clone, every run.
7. **Validate.** Checks gh auth, access to `works-os/frontend`, node, and `node_modules`.

Prerequisites: a GitHub account with read access to `works-os/frontend` (the
`content-editors` team, per `hub/setup/claude-setup.md`), and the Claude desktop app.
There are no flags or env-var overrides; `REPO`, `WORKDIR`, `NODE_MAJOR` and `NVM_PIN`
are constants at the top of the script.

## Changing it safely

- **Stay idempotent and re-runnable.** Every stage checks state before acting; any human
  step prints instructions and exits. No `read` prompts, no `sudo`.
- **Test.** There is no dry-run mode. Run `bash -n setup.sh` (and `shellcheck` if
  installed), then do a full run on a Mac, twice, to confirm the second run is a no-op
  through stage 5. Open question: there is no documented way to test in a throwaway
  `HOME`; gh auth lives in the real `~/.config/gh`.
- **Keep `README.md` in step with the script** whenever behavior changes.
- **Repo coverage.** The script handles only `frontend`. The org also has backend, hub,
  recruiting, recruitment-landing-page, user-setup, web-agent, works-library and more.
  Add a repo only when staff are meant to edit it.

## Branching

`task/` or `fix/` branch off `main` → PR to `main`. No direct pushes. Merging is
the release, so review carefully.

## Cross-repo links

- `hub/setup/claude-setup.md` — the collaboration-workflow design: two-tier access
  (staff fork, engineers write), hooks, and an engineer reference for this script.
- `frontend` — the repo the script sets up; staff PRs go from their fork to its `dev`.

## Don't

- Never put tokens, passwords or org secrets in the script or README. Auth is browser-only (`gh auth login --web`).
- Don't add `sudo` or anything that asks for the Mac password.
- Don't make it wait on input; Cowork-driven runs cannot answer prompts.
- Don't write to the user's files beyond `~/.nvm`, `~/.local/bin`, `~/.zshrc` and `~/dev/works-os`.

## Open questions

- `README.md` is stale: it names the `works-real-estate` org and URL, `~/dev/wre-dashboards`,
  Write access, and a Mac-password prompt. The script uses `works-os`, `~/dev/works-os/frontend`,
  a read-only fork, and no sudo.
- `hub/setup/claude-setup.md` describes the old sudo `.pkg` installers, calls the fork rework
  pending (it has landed), and says to "push to main" (now branch → PR).
- `claude-setup.md` lists `recruitment-landing-page` as staff-editable; the script does not set it up.
- PR #3 (`task/setup-path-and-wording`) is open against `setup.sh`.
- The gh CLI version is unpinned (latest release), unlike nvm.
