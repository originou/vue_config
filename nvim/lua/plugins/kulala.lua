-- kulala.nvim (HTTP requests in .http files, community.lua): pinned to v5.3.4, the last release
-- that only needs curl. Since v6 (2026-05) it runs a closed-source backend ("kulala-core"),
-- downloaded on first use, that asks for a license token.
-- Its "fmt" folder (kulala-fmt: formatter and importers) is a git submodule that lazy cannot
-- update when moving to the tag: the checkout fails and the plugin stays on the latest release.
-- So: no submodules, and the build step clones kulala-fmt at the commit the tag points to.
--
-- <Leader>rI in an OpenAPI spec (yaml / json) or a Postman collection (json): converts it to a
-- .http file next to it (one request per operation) and opens it. Done by kulala-fmt, built with
-- npm on first use (~/.cache/nvim/kulala/fmt).

-- format of the current buffer for kulala's importer: "openapi" (yaml, or json with an "openapi" /
-- "swagger" key), else nil (Postman)
local function import_format()
  if vim.bo.filetype == "yaml" then return "openapi" end
  for _, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, 50, false)) do
    if line:match('^%s*"openapi"%s*:') or line:match('^%s*"swagger"%s*:') then return "openapi" end
  end
end

-- clone kulala-fmt into <plugin>/fmt at the commit recorded by the plugin (submodule entry)
local function fetch_fmt(plugin)
  local dir = plugin.dir .. "/fmt"
  if vim.uv.fs_stat(dir .. "/package.json") then return end
  local tree = vim.system({ "git", "-C", plugin.dir, "ls-tree", "HEAD", "fmt" }, { text = true }):wait().stdout or ""
  local commit = tree:match("commit (%x+)")
  vim.fn.delete(dir, "rf")
  local clone = vim.system({ "git", "clone", "-q", "https://github.com/mistweaverco/kulala-fmt", dir }):wait()
  if clone.code ~= 0 then error("kulala-fmt clone failed: " .. (clone.stderr or "")) end
  if commit then vim.system({ "git", "-C", dir, "checkout", "-q", commit }):wait() end
end

---@type LazySpec
return {
  "mistweaverco/kulala.nvim",
  tag = "v5.3.4",
  submodules = false,
  build = fetch_fmt,
  keys = {
    {
      "<Leader>rI",
      function()
        if vim.bo.filetype ~= "yaml" and vim.bo.filetype ~= "json" then
          return vim.notify("Open an OpenAPI spec (yaml / json) or a Postman collection first", vim.log.levels.WARN)
        end
        if vim.bo.modified then vim.cmd.write() end
        require("kulala").import(import_format())
      end,
      desc = "Convert this OpenAPI spec / Postman collection to a .http file",
    },
  },
}
