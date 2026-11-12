-- kulala.nvim (HTTP requests in .http files, community.lua): pinned to v5.3.4, the last release
-- that only needs curl. Since v6 (2026-05) it runs a closed-source backend ("kulala-core"),
-- downloaded on first use, that asks for a license token.
-- Its "fmt" folder (kulala-fmt: formatter and importers) is a git submodule that lazy cannot
-- update when moving to the tag: the checkout fails and the plugin stays on the latest release.
-- So: no submodules, and the build step clones kulala-fmt at the commit the tag points to.
--
-- Kept next to httpyac (httpyac.lua): kulala has Enter and <Leader>r…, httpyac <Leader>rh…;
-- <Leader>rI (OpenAPI → .http) is in httpyac.lua.
--
-- JSON responses: each one is formatted with jq, saved to
--   ~/.local/share/nvim/http-responses/<project>/<YYYY-MM-DD_HHMMSS>_<METHOD>_<path>.json
-- and opened in a window under the kulala result (reused for the next ones). Above NO_LSP_SIZE
-- the file opens without LSP and treesitter (plain syntax highlighting).
-- In the .http file, under each request: one line per JSON response of this session, newest
-- first (status, time, file); <Leader>rJ picks one of them to open. <Leader>rH: history of the saved responses,
-- newest first. Files older than KEEP_DAYS days are
-- deleted at startup. In the kulala result itself, [ and ] go through this session's responses.

local DIR = vim.fn.stdpath("data") .. "/http-responses"
local NO_LSP_SIZE = 512 * 1024
local KEEP_DAYS = 90

local json_win -- window showing the saved JSON (under the kulala result)

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

local function slug(s, max)
  s = (s or ""):gsub("[^%w%.]+", "-"):gsub("^%-+", ""):gsub("%-+$", "")
  return s:sub(1, max)
end

-- project folder: git root of the .http file, else its folder
local function project_name(file)
  if not file or file == "" then return "misc" end
  local root = vim.fs.root(file, ".git") or vim.fs.dirname(file)
  return slug(vim.fs.basename(root), 40)
end

-- show path in the window under the kulala result (created once, then reused)
local function open_json(path)
  local cur = vim.api.nvim_get_current_win()
  if not (json_win and vim.api.nvim_win_is_valid(json_win)) then
    local ui = vim.fn.bufwinid("kulala://ui")
    if ui ~= -1 then
      vim.api.nvim_set_current_win(ui)
      vim.cmd("belowright split")
    else
      vim.cmd("botright split")
    end
    json_win = vim.api.nvim_get_current_win()
  else
    vim.api.nvim_set_current_win(json_win)
  end
  local big = (vim.fn.getfsize(path) or 0) > NO_LSP_SIZE
  vim.g.kulala_json_no_lsp = big and vim.fn.fnamemodify(path, ":p") or nil
  vim.cmd("silent keepalt edit " .. vim.fn.fnameescape(path))
  if big then
    pcall(vim.treesitter.stop, vim.api.nvim_win_get_buf(json_win))
    vim.notify("Large JSON response: opened without LSP or treesitter", vim.log.levels.INFO)
  end
  if vim.api.nvim_win_is_valid(cur) then vim.api.nvim_set_current_win(cur) end
end

local function is_json(response)
  local ctype = (response.headers or ""):lower():match("content%-type:%s*([^\r\n]*)") or ""
  if ctype:find("json", 1, true) then return true end
  return (response.body_raw or ""):match("^%s*[%[{]") ~= nil
end

local NS = vim.api.nvim_create_namespace("kulala_json_file")

-- runs[buf][extmark id] = { { path, code, ms }, ... } (newest first): this session's JSON
-- responses of each request; the extmark sits on the request line and moves with it
local runs = {}

local function run_label(run)
  local ok = run.code >= 200 and run.code < 400
  return ("%s %s · %s ms · %s"):format(ok and "✔" or "✘", run.code > 0 and run.code or "?", run.ms, vim.fs.basename(run.path)), ok
end

-- under the request line in the .http file: one line per JSON response of this session
local function mark_request(buf, line, run)
  if not (buf and line and vim.api.nvim_buf_is_valid(buf)) or line > vim.api.nvim_buf_line_count(buf) then return end
  runs[buf] = runs[buf] or {}
  local found = vim.api.nvim_buf_get_extmarks(buf, NS, { line - 1, 0 }, { line - 1, -1 }, { limit = 1 })[1]
  local id = found and found[1]
  local list = id and runs[buf][id] or {}
  table.insert(list, 1, run)
  local virt_lines = {}
  for _, r in ipairs(list) do
    local text, ok = run_label(r)
    table.insert(virt_lines, { { "   󰘦 ", "Comment" }, { text, ok and "Comment" or "DiagnosticError" } })
  end
  id = vim.api.nvim_buf_set_extmark(buf, NS, line - 1, 0, { id = id, virt_lines = virt_lines })
  runs[buf][id] = list
end

-- <Leader>rJ: pick one of the JSON responses of the request under the cursor (marked line at or
-- above it)
local function open_request_json()
  local buf = vim.api.nvim_get_current_buf()
  local mark = vim.api.nvim_buf_get_extmarks(buf, NS, { vim.fn.line(".") - 1, -1 }, 0, { limit = 1 })[1]
  local list = mark and runs[buf] and runs[buf][mark[1]]
  if not list or #list == 0 then return vim.notify("No saved JSON for this request", vim.log.levels.INFO) end
  if #list == 1 then return open_json(list[1].path) end
  local items = {}
  for i, r in ipairs(list) do
    local text, ok = run_label(r)
    table.insert(items, { idx = i, file = r.path, text = text, ok = ok })
  end
  Snacks.picker({
    title = "JSON responses of this request",
    items = items,
    format = function(item) return { { item.text, item.ok and "SnacksPickerFile" or "DiagnosticError" } } end,
    preview = "file",
    sort = { fields = { "score:desc", "idx" } },
    confirm = function(picker, item)
      picker:close()
      if item then open_json(item.file) end
    end,
  })
end

-- kulala "after_request" hook: jq-format the JSON body, save it, show it
local function on_response(data)
  local response = data.response or {}
  local body = response.body_raw
  if not body or body == "" or not is_json(response) then return end
  if vim.fn.executable("jq") == 0 then return vim.notify("jq not found: JSON response not saved", vim.log.levels.WARN) end

  local url_path = (response.url or ""):gsub("^%a+://[^/]*", ""):gsub("[?#].*", "")
  local name = ("%s_%s_%s"):format(
    os.date("%Y-%m-%d_%H%M%S"),
    (response.method or "REQ"):upper(),
    slug(url_path ~= "" and url_path or response.name, 60)
  )
  local dir = DIR .. "/" .. project_name(response.file)
  vim.fn.mkdir(dir, "p")
  local path, n = dir .. "/" .. name .. ".json", 1
  while vim.uv.fs_stat(path) do -- same second: suffix
    n = n + 1
    path = ("%s/%s-%d.json"):format(dir, name, n)
  end

  vim.system({ "jq", "." }, { stdin = body, text = true }, function(res)
    vim.schedule(function()
      if res.code ~= 0 then return end -- not valid JSON after all
      local f = io.open(path, "w")
      if not f then return vim.notify("Cannot write " .. path, vim.log.levels.ERROR) end
      f:write(res.stdout)
      f:close()
      local line = response.line and math.max(response.line - 1, 1) -- request line, as kulala's icons
      mark_request(response.buf, line, {
        path = path,
        code = tonumber(response.response_code) or 0,
        ms = math.floor((response.duration or 0) / 1e6 + 0.5), -- hrtime: ns
      })
      open_json(path)
    end)
  end)
end

-- <Leader>rH: saved responses, newest first (all projects; the current one first)
local function history()
  local current = project_name(vim.api.nvim_buf_get_name(0))
  local items = {}
  for name, kind in vim.fs.dir(DIR, { depth = 2 }) do
    if kind == "file" and name:match("%.json$") then
      local path = DIR .. "/" .. name
      local stat = vim.uv.fs_stat(path)
      local project = name:match("^([^/]+)/")
      table.insert(items, {
        file = path,
        text = name,
        mtime = stat and stat.mtime.sec or 0,
        current = project == current,
      })
    end
  end
  if #items == 0 then return vim.notify("No saved HTTP response yet", vim.log.levels.INFO) end
  table.sort(items, function(a, b)
    if a.current ~= b.current then return a.current end
    return a.mtime > b.mtime
  end)
  Snacks.picker({
    title = "HTTP responses (JSON)",
    items = items,
    format = function(item)
      return { { item.text, item.current and "SnacksPickerFile" or "SnacksPickerDimmed" } }
    end,
    preview = "file",
    sort = { fields = { "score:desc", "idx" } }, -- keep our order when not filtering
    confirm = function(picker, item)
      picker:close()
      if item then open_json(item.file) end
    end,
  })
end

local function cleanup()
  local limit = os.time() - KEEP_DAYS * 24 * 3600
  for name, kind in vim.fs.dir(DIR, { depth = 2 }) do
    local path = DIR .. "/" .. name
    local stat = kind == "file" and vim.uv.fs_stat(path)
    if stat and stat.mtime.sec < limit then os.remove(path) end
  end
end

---@type LazySpec
return {
  {
    "mistweaverco/kulala.nvim",
    tag = "v5.3.4",
    submodules = false,
    build = fetch_fmt,
    init = function()
      -- register the hook once kulala is loaded (keeps the community spec's config)
      vim.api.nvim_create_autocmd("User", {
        pattern = "LazyLoad",
        callback = function(ev)
          if ev.data ~= "kulala.nvim" then return end
          require("kulala.api").on("after_request", on_response)
          return true -- once
        end,
      })
      -- large saved responses: detach any LSP client from them
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(ev)
          local big = vim.g.kulala_json_no_lsp
          if big and vim.api.nvim_buf_get_name(ev.buf) == big then
            vim.schedule(function() pcall(vim.lsp.buf_detach_client, ev.buf, ev.data.client_id) end)
          end
        end,
      })
      vim.defer_fn(cleanup, 3000)
    end,
  },
  {
    "AstroNvim/astrocore",
    ---@param opts AstroCoreOpts
    opts = function(_, opts)
      opts.mappings.n["<Leader>rH"] = { history, desc = "History of JSON responses" }
      opts.mappings.n["<Leader>rJ"] = { open_request_json, desc = "JSON response of this request" }
    end,
  },
}
