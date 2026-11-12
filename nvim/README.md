# Neovim config (AstroNvim v6)

Needs Neovim >= 0.11, git, a C compiler (treesitter parsers), ripgrep, fd, node/npm (some
language servers), and a Nerd Font in the terminal. Plugins install on first start (lazy.nvim),
then Mason installs the language servers and tools (`:Mason` to follow, `:checkhealth` after).

- `lua/community.lua`: language packs (Lua, Go, Java, Python, Rust, Bash, TypeScript), nvim-bqf,
  kulala (`.http` files: HTTP requests with curl, `<Space>r`), yaml / json (yamlls / jsonls)
- `lua/plugins/`: one spec per topic
  - `projects.lua`: projects (`<Space>fp`) and named sessions per project, with a lock (one Neovim
    per session) and an automatic repair (`lua/session_repair.lua`, backups in
    `~/.local/share/nvim/session-backups`)
  - `statusline.lua`: LazyVim-like statusline, git branch on a green (clean) / yellow (changes)
    background with the lines added / removed over the repository, path relative to the git root,
    project › session
  - `neo-tree*.lua`: compact folders, `gd` git diff preview, `q` columns, `z` / `Z`, one tree for
    all tab pages
  - `which-key*.lua`: shorter menus with plain descriptions, Neo-tree-only keys in the tree
  - `keymaps.lua`: `;j` = Esc, no macro recording on `q`, `<Space>bl` buffer list, `:q` closes the
    file (not the window), the last file closed shows the home screen, `<Space>Q` asks before quitting
  - `bookmarks.lua`: line bookmarks (icon in the sign column, optional name, numbers 1-4 for
    `<Space>1`…`4`), list per project `<Space>mm` (`Ctrl-e` rename, `Ctrl-x` remove, `Alt-1…4` number)
  - `undo.lua`: persistent undo (1000 changes per file, histories unused for 90 days deleted)
  - `kulala.lua`: kulala pinned to v5.3.4 (later versions need a licensed backend). Enter sends
    the request under the cursor; a JSON response is formatted with jq, saved to
    `~/.local/share/nvim/http-responses/<project>/<date>_<time>_<METHOD>_<path>.json` and shown
    under the kulala result; each run is listed under its request (status, ms, file),
    `<Space>rJ` picks one, `<Space>rH` = history of all saved responses (kept 90 days)
  - `httpyac.lua`: httpyac CLI next to kulala (`npm install -g httpyac`), keys `<Space>rh…`;
    `<Space>rI` converts an OpenAPI spec / Postman collection to a `.http` file (kulala-fmt
    through npx)
  - `schemastore.lua`: SchemaStore schemas for yamlls / jsonls: completion and validation of
    OpenAPI specs (`openapi.yaml`, `*.openapi.yaml`), GitHub Actions, docker-compose...
  - `formatting.lua`: no format on save (`<Space>lf` formats, `<Space>uF` turns it back on)
  - `mason.lua`: tools installed by Mason
