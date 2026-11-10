# Prompt opencode : préparer le poste Debian 12

Lancer opencode à la racine du repo et lui coller le bloc ci-dessous.

---

```text
You are setting up my work Debian 12 (bookworm) VM for my dotfiles. Talk to me in French.

Context
- No Nix here. apt works, but its sources point to the company Artifactory mirror: NEVER edit
  /etc/apt/sources.list*, never add a repository, PPA or apt key. I have sudo.
- GitHub is reachable (maybe through a proxy: keep the http(s)_proxy variables you find).
- The repo is the current directory. Read README.md first. The package list is
  packages.txt ("package  # purpose"; a leading "?" = optional).
- Do not edit the files of the repo. If a config looks wrong for this machine, tell me.

Step 1. Look around (read-only)
- Debian version and arch (`cat /etc/debian_version`, `dpkg --print-architecture`), display
  manager in use, current shell, proxy variables, what is already installed among the packages.

Step 2. apt packages
- `sudo apt-get update`, then for every package of packages.txt `apt-cache policy <pkg>`:
  candidate version, or "not available".
- Show me ONE table: package | purpose | installed | candidate | optional. Point out what is
  missing from the mirror.
- Ask me which ones to install (default: every non optional package available). Then install
  them in a single `sudo apt-get install` command that I approve.

Step 3. Tools outside apt (bookworm versions are too old). For each: check what is there, tell
me what you propose, wait for my OK. Install them in my home, without sudo:
release archive of the official GitHub project (or nodejs.org) → ~/.local/opt/<tool>,
symlinks in ~/.local/bin. Pick the asset for the arch of step 1, verify the checksum when the
release publishes one.
- Neovim >= 0.11 (bookworm apt has 0.7, too old for my config: AstroNvim v6). First check
  if the mirror has a recent enough candidate (backports...); otherwise the latest stable
  release archive nvim-linux-<arch>.tar.gz of github.com/neovim/neovim.
- lazygit (not in bookworm): latest release of github.com/jesseduffield/lazygit.
- Node.js >= 22 if the apt candidate is older (language servers installed by Mason): latest LTS archive of
  nodejs.org → ~/.local/opt/node, links for node, npm, npx.
- Do not install anything for Java / Go / Python development: just report the versions found
  (jdtls wants Java 21+, gopls a recent Go). I will deal with it later.

Step 4. Dotfiles
- Run `./install.sh` and show me its warnings. Then remind me to set my git identity
  (`git config --global user.name / user.email`): do not set it yourself.
- If my login shell is not zsh, propose `chsh -s /bin/zsh` (I type my password myself).

Step 5. Checks, report each result
- `which nvim && nvim --version | head -1` (must be the ~/.local/bin one, >= 0.11)
- `nvim --headless "+Lazy! sync" +qa` (plugins install; then Mason installs ~25 tools on the
  first real start: tell me to wait for it (`:Mason` shows the progress) and to run
  :checkhealth; gopls and jdtls fail to install without a recent Go / Java 21+: expected)
- `i3 -C -c ~/.config/i3/config`
- `fc-list | grep -ci "nerd font"` (> 0)
- `alacritty --version` (0.11 reads alacritty.yml: expected)
- `tmux -f ~/.tmux.conf start-server \; kill-server` without error, TPM plugins present in
  ~/.tmux/plugins
- `node --version`, `lazygit --version`, `rg --version`, `fd --version`

Step 6. Final report
- What was installed (apt and ~/.local), what failed and why, what is missing from the mirror.
- What I still do by hand: log out and pick the "i3" session at login, set my git identity,
  check the Super key reaches the VM (else switch $mod in i3/config).

Rules: ask before every sudo command and before every download; never pipe a download into a
shell; stop and ask me if something does not match what this prompt expects.
```
