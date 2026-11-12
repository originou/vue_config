-- HTTP requests in .http / .rest files with the httpyac CLI (MIT, https://httpyac.github.io), next
-- to kulala.nvim (kulala.lua: Enter and <Leader>r…, interactive, response tabs and history). Same
-- file format (JetBrains / VS Code REST Client); httpyac adds assertions (`?? status == 200`),
-- request chaining, OAuth2..., and runs the same way in CI. Install: `npm install -g httpyac`.
--
-- In a .http file, under <Leader>rh (h: httpyac):
--   <Leader>rhs  send the request under the cursor      <Leader>rha  send all the requests
--   <Leader>rhr  send the last one again                 <Leader>rhe  environment (dev, prod...)
--   <Leader>rhv  details on / off (request sent, timings)  <Leader>rhx  stop the running request
-- The response opens on the right (status, headers, body); q closes it, r sends again.
-- Environments: http-client.env.json, http-client.private.env.json (secrets), .env / <env>.env
-- files, read from the folder of the .http file and its parents; "dev" is used when it exists and
-- none was chosen (as kulala). httpyac has no "$shared" section (kulala has): repeat the values.
--
-- <Leader>rI in an OpenAPI spec (yaml / json) or a Postman collection: converts it to a .http file
-- next to it (kulala-fmt 2.10.0 through npx, MIT, standalone: no backend, no token).

local M = {
  env = nil, -- selected environment; nil: "dev" when it exists (as kulala), false: none
  verbose = false, -- output "exchange" (request + response + timings) instead of "response"
  last = nil, -- { file, line } or { file, all = true }
  job = nil, -- running vim.system object
}

local RESULT_NAME = "httpyac://response"

local function result_buf()
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_get_name(b) == RESULT_NAME then return b end
  end
  local b = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(b, RESULT_NAME)
  vim.bo[b].bufhidden = "hide"
  vim.bo[b].filetype = "http"
  vim.keymap.set("n", "q", "<Cmd>close<CR>", { buffer = b, desc = "Close the response" })
  vim.keymap.set("n", "r", function() M.replay() end, { buffer = b, desc = "Send the request again" })
  return b
end

-- show lines in the response window (opened on the right of the .http file, reused)
local function show(lines)
  local b = result_buf()
  vim.bo[b].modifiable = true
  vim.api.nvim_buf_set_lines(b, 0, -1, false, lines)
  vim.bo[b].modifiable = false
  local win = vim.fn.bufwinid(b)
  if win == -1 then
    local cur = vim.api.nvim_get_current_win()
    vim.cmd("botright vsplit")
    win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, b)
    vim.api.nvim_win_set_width(win, math.floor(vim.o.columns * 0.45))
    vim.wo[win].wrap = true
    vim.wo[win].number = false
    vim.wo[win].relativenumber = false
    vim.wo[win].signcolumn = "no"
    vim.api.nvim_set_current_win(cur)
  end
  vim.api.nvim_win_set_cursor(win, { 1, 0 })
end

-- httpyac's text output without its separators and summary line
local function clean(text)
  local out = {}
  for _, line in ipairs(vim.split((text or ""):gsub("\27%[[%d;]*m", ""), "\n", { plain = true })) do
    if
      not line:match("^%-%-%-%-%-%-+$")
      and not line:match("^%d+ requests? processed")
      and not line:match("^Multiple files with environment") -- harmless: the env files are read twice
    then
      -- details view: a blank line between the request sent and the response
      if line:match("^HTTP/%d") and out[#out] and out[#out] ~= "" then table.insert(out, "") end
      table.insert(out, line)
    end
  end
  while out[1] == "" do table.remove(out, 1) end
  while out[#out] == "" do table.remove(out) end
  return out
end

-- environments found from the .http file's folder up to the root: http-client(.private).env.json
-- keys and <name>.env / .env.<name> files
local function env_names(file)
  local names, seen = {}, {}
  local function add(n)
    if n and n ~= "" and n ~= "$shared" and not seen[n] then seen[n] = true; table.insert(names, n) end
  end
  local dir = vim.fs.dirname(file)
  while dir do
    for _, f in ipairs({ "http-client.env.json", "http-client.private.env.json" }) do
      local ok, data = pcall(function() return vim.json.decode(table.concat(vim.fn.readfile(dir .. "/" .. f), "\n")) end)
      if ok and type(data) == "table" then
        for k in pairs(data) do add(k) end
      end
    end
    for name, kind in vim.fs.dir(dir) do
      if kind == "file" then add(name:match("^(.+)%.env$") or name:match("^%.env%.(.+)$")) end
    end
    local parent = vim.fs.dirname(dir)
    if parent == dir then break end
    dir = parent
  end
  table.sort(names)
  return names
end

-- environment passed to httpyac for this file
local function effective_env(file)
  if M.env == false then return nil end
  if M.env then return M.env end
  return vim.tbl_contains(env_names(file), "dev") and "dev" or nil
end

local function run(target)
  if M.job then return vim.notify("A request is already running (<Leader>rhx stops it)", vim.log.levels.WARN) end
  if vim.fn.executable("httpyac") == 0 then
    return vim.notify("httpyac not found: npm install -g httpyac", vim.log.levels.ERROR)
  end
  M.last = target
  local cmd = { "httpyac", "send", target.file, "--output", M.verbose and "exchange" or "response" }
  vim.list_extend(cmd, target.all and { "--all" } or { "--line", tostring(target.line) })
  local env = effective_env(target.file)
  if env then vim.list_extend(cmd, { "--env", env }) end
  local label = target.all and "all requests" or ("line " .. target.line)
  show({ ("# Sending %s of %s%s…"):format(label, vim.fn.fnamemodify(target.file, ":t"), env and (" (env " .. env .. ")") or "") })
  local start = vim.uv.hrtime()
  M.job = vim.system(cmd, { text = true, cwd = vim.fs.dirname(target.file), env = { NO_COLOR = "1", FORCE_COLOR = "0" } }, function(res)
    vim.schedule(function()
      M.job = nil
      local ms = math.floor((vim.uv.hrtime() - start) / 1e6)
      local lines = clean((res.stdout or "") .. (res.stderr ~= "" and ("\n" .. res.stderr) or ""))
      local status = res.signal ~= 0 and "stopped" or (res.code == 0 and "done" or ("failed, exit " .. res.code))
      table.insert(lines, 1, ("# %s · %s · %d ms%s"):format(label, status, ms, env and (" · env " .. env) or ""))
      table.insert(lines, 2, "")
      show(lines)
    end)
  end)
end

local function current_file()
  if vim.bo.filetype ~= "http" and vim.bo.filetype ~= "rest" then
    vim.notify("Not a .http file", vim.log.levels.WARN)
    return
  end
  if vim.bo.modified then vim.cmd("silent update") end -- httpyac reads the file on disk
  return vim.api.nvim_buf_get_name(0)
end

function M.send()
  local file = current_file()
  if file then run({ file = file, line = vim.api.nvim_win_get_cursor(0)[1] }) end
end

function M.send_all()
  local file = current_file()
  if file then run({ file = file, all = true }) end
end

function M.replay()
  if not M.last then return vim.notify("No request sent yet", vim.log.levels.INFO) end
  for _, b in ipairs(vim.api.nvim_list_bufs()) do -- save the .http file if it is open and changed
    if vim.api.nvim_buf_get_name(b) == M.last.file and vim.bo[b].modified then
      vim.api.nvim_buf_call(b, function() vim.cmd("silent update") end)
    end
  end
  run(M.last)
end

function M.stop()
  if M.job then M.job:kill(15) end
end

function M.toggle_verbose()
  M.verbose = not M.verbose
  vim.notify("httpyac details " .. (M.verbose and "on (request sent, timings)" or "off"), vim.log.levels.INFO)
end

function M.pick_env()
  local file = vim.api.nvim_buf_get_name(0)
  local names = env_names(file)
  local now = effective_env(file)
  table.insert(names, 1, "(none)")
  table.insert(names, "(other…)")
  vim.ui.select(names, { prompt = "httpyac environment (now: " .. (now or "none") .. ")" }, function(choice)
    if choice == "(none)" then
      M.env = false
    elseif choice == "(other…)" then
      return vim.ui.input({ prompt = "Environment name" }, function(n)
        if n and vim.trim(n) ~= "" then M.env = vim.trim(n) end
      end)
    elseif choice then
      M.env = choice
    end
  end)
end

-- OpenAPI spec / Postman collection -> .http file next to it (kulala-fmt through npx)
function M.import()
  local ft = vim.bo.filetype
  if ft ~= "yaml" and ft ~= "json" then
    return vim.notify("Open an OpenAPI spec (yaml / json) or a Postman collection first", vim.log.levels.WARN)
  end
  if vim.bo.modified then vim.cmd("silent update") end
  local from = ft == "yaml" and "openapi" or "postman"
  for _, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, 50, false)) do
    if line:match('^%s*"openapi"%s*:') or line:match('^%s*"swagger"%s*:') then from = "openapi" end
  end
  local file = vim.api.nvim_buf_get_name(0)
  vim.notify("Converting to .http (first time: npx downloads kulala-fmt)…", vim.log.levels.INFO)
  vim.system({ "npx", "--yes", "@mistweaverco/kulala-fmt@2.10.0", "convert", "--from", from, file }, { text = true }, function(res)
    vim.schedule(function()
      local out = vim.trim((res.stdout or ""):gsub("\27%[[%d;]*m", ""))
      local target = out:match("(%S+%.http)%s*$")
      if res.code ~= 0 or not target then
        return vim.notify("Conversion failed:\n" .. out .. "\n" .. (res.stderr or ""), vim.log.levels.ERROR)
      end
      if not target:match("^/") then target = vim.fs.dirname(file) .. "/" .. target end
      vim.cmd.edit(vim.fn.fnameescape(target))
    end)
  end)
end

---@type LazySpec
return {
  {
    "AstroNvim/astrocore",
    ---@param opts AstroCoreOpts
    opts = function(_, opts)
      opts.treesitter = opts.treesitter or {}
      opts.treesitter.ensure_installed = opts.treesitter.ensure_installed or {}
      if type(opts.treesitter.ensure_installed) == "table" then table.insert(opts.treesitter.ensure_installed, "http") end

      local n = opts.mappings.n
      n["<Leader>r"] = { desc = "󰳘 HTTP requests" }
      n["<Leader>rh"] = { desc = "httpyac (CLI: assertions, chaining, as in CI)" }
      n["<Leader>rI"] = { M.import, desc = "OpenAPI spec / Postman collection → .http file" }

      opts.autocmds = opts.autocmds or {}
      opts.autocmds.httpyac_keys = {
        {
          event = "FileType",
          pattern = { "http", "rest" },
          desc = "httpyac keys in .http files",
          callback = function(args)
            if vim.api.nvim_buf_get_name(args.buf) == RESULT_NAME then return end
            local function map(lhs, fn, desc) vim.keymap.set("n", lhs, fn, { buffer = args.buf, desc = desc }) end
            map("<Leader>rhs", M.send, "Send the request under the cursor")
            map("<Leader>rha", M.send_all, "Send all the requests of the file")
            map("<Leader>rhr", M.replay, "Send the last request again")
            map("<Leader>rhe", M.pick_env, "Environment (dev, prod...)")
            map("<Leader>rhv", M.toggle_verbose, "Details on / off (request sent, timings)")
            map("<Leader>rhx", M.stop, "Stop the running request")
          end,
        },
      }
    end,
  },
}
