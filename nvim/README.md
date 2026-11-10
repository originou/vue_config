# Neovim config (AstroNvim v6)

Needs Neovim >= 0.11, git, a C compiler (treesitter parsers), ripgrep, fd, node/npm (some
language servers), and a Nerd Font in the terminal. Plugins install on first start (lazy.nvim),
then Mason installs the language servers and tools (`:Mason` to follow, `:checkhealth` after).

- `lua/community.lua`: language packs (Lua, Go, Java, Python, Rust, Bash, TypeScript) + nvim-bqf
- `lua/plugins/`: one spec per topic
  - `projects.lua`: projects (`<Space>fp`) and named sessions per project, with a lock (one Neovim
    per session) and an automatic repair (`lua/session_repair.lua`, backups in
    `~/.local/share/nvim/session-backups`)
  - `statusline.lua`: LazyVim-like statusline, path relative to the git root, project › session
  - `neo-tree*.lua`: compact folders, `gd` git diff preview, `q` columns, `z` / `Z`
  - `which-key*.lua`: shorter menus with plain descriptions, Neo-tree-only keys in the tree
  - `keymaps.lua`: `;j` = Esc, no macro recording on `q`, `<Space>bl` buffer list
  - `formatting.lua`: no format on save (`<Space>lf` formats, `<Space>uF` turns it back on)
  - `mason.lua`: tools installed by Mason
