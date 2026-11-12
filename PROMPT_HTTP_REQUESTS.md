# Prompt Claude : requêtes HTTP dans Neovim (kulala + httpyac)

À donner à la session Claude du poste (à la racine du repo, après `git pull`) : elle met à jour,
vérifie et explique le fonctionnement. Coller le bloc ci-dessous.

---

```text
My Neovim config (AstroNvim v6) comes from this repo: nvim/ is linked to ~/.config/nvim by
install.sh. Talk to me in French. Do not edit the files of the repo: if something looks wrong
for this machine, tell me. Ask before installing anything.

What changed (read nvim/lua/plugins/kulala.lua and nvim/lua/plugins/httpyac.lua first)

1. kulala.nvim stays pinned to tag v5.3.4 on purpose. It is MIT and only needs curl. Since v6
   (2026-05), kulala runs a closed-source backend ("kulala-core") that asks for a license
   token: that is the "token" problem. Never upgrade it, never set a token. Its "fmt" folder
   (kulala-fmt) is a git submodule lazy.nvim cannot check out at the tag, so the spec says
   `submodules = false` and its build step clones kulala-fmt at the right commit.
2. New: every JSON response of kulala is formatted with jq and saved to
   ~/.local/share/nvim/http-responses/<project>/<YYYY-MM-DD_HHMMSS>_<METHOD>_<path>.json
   (<project> = git root of the .http file), then opened in a window under the kulala result
   (reused for the next responses). Above 512 KB it opens without LSP nor treesitter.
   Files older than 90 days are deleted at startup.
3. New: in the .http file, under each request, one line per run of this session, newest
   first: "✔ 200 · 278 ms · <file>.json" (red ✘ for 4xx / 5xx). They live as long as the
   buffer; the files stay.
4. New: httpyac (CLI, MIT) next to kulala, keys under <Space>rh (s send, a all, r replay,
   e environment, v details, x stop). Needs `npm install -g httpyac`. <Space>rI (OpenAPI spec
   or Postman collection → .http file) runs kulala-fmt 2.10.0 through npx.

Keys in a .http file
- Enter: send the request under the cursor (kulala), result on the right
- <Space>rJ: pick one of the saved JSON responses of the request under the cursor
- <Space>rH: history of all saved JSON responses (current project first, preview)
- <Space>re: kulala environment (default "dev"); in the kulala result: [ and ] go through
  this session's responses
- <Space>rhe: httpyac environment (default "dev" when it exists)

Environments (both tools): http-client.env.json (one object per environment, committed) and
http-client.private.env.json (secrets, same shape, git-ignored), searched from the .http file's
folder upwards. kulala supports a "$shared" section, httpyac does not: when both tools are
used, repeat the values in each environment.

Step 1. Update (show me each command before running it)
- In the repo: `git pull`.
- Check jq (`jq --version`) and httpyac (`httpyac --version`). If httpyac is missing: propose
  `npm install -g httpyac` (npm global prefix in my home, no sudo).
- Check kulala: `git -C ~/.local/share/nvim/lazy/kulala.nvim describe --tags` must print
  v5.3.4 and ~/.local/share/nvim/lazy/kulala.nvim/fmt/package.json must exist. If not (an
  older install pulled v6+): `rm -rf ~/.local/share/nvim/lazy/kulala.nvim`, then
  `nvim --headless "+Lazy! restore" +qa` and check again.

Step 2. Test in a scratch folder (outside any project), then delete it
- A file api.http with:
    ### small json
    GET https://httpbin.org/json
- Tell me to open it in Neovim, put the cursor on the GET line and press Enter: the kulala
  result opens on the right, the formatted JSON under it, and a line
  "󰘦 ✔ 200 · … ms · …_GET_json.json" appears under the request. Press Enter twice more:
  three lines. <Space>rJ lists the three runs.
- Check that the file exists in ~/.local/share/nvim/http-responses/.
- If the company proxy blocks httpbin.org, use an internal URL that answers JSON.

Step 3. Report what works, what does not, and the exact errors (:messages in Neovim).
```
