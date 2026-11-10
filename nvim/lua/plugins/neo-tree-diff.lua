-- Neo-tree: gd = git diff preview of the file under the cursor (Git tab and file tree).
-- The diff (vs HEAD: staged + unstaged; whole content for an untracked file) opens in a float next
-- to the tree and follows the cursor while it is open. gd again (or leaving the tree) closes it,
-- Ctrl-f / Ctrl-b scroll it (Neo-tree's own preview otherwise). Ctrl-d / Ctrl-u move in the tree,
-- as in any window.

local preview = { win = nil, buf = nil, tree_win = nil, path = nil }

local function is_open() return preview.win and vim.api.nvim_win_is_valid(preview.win) end

local function close()
  if is_open() then vim.api.nvim_win_close(preview.win, true) end
  preview.win, preview.path = nil, nil
  pcall(vim.api.nvim_del_augroup_by_name, "neotree_diff_preview")
end

local function git(args, cwd)
  local res = vim.system(vim.list_extend({ "git", "-C", cwd }, args), { text = true }):wait()
  return res.code, vim.split(res.stdout or "", "\n", { trimempty = true })
end

-- Diff lines of a file vs HEAD; untracked: the whole file as added; nil + message if no diff
local function diff_lines(path)
  local dir = vim.fn.fnamemodify(path, ":h")
  local code, root = git({ "rev-parse", "--show-toplevel" }, dir)
  if code ~= 0 then return nil, "not in a git repository" end
  root = root[1]
  local rel = path:sub(#root + 2)
  local _, lines = git({ "diff", "HEAD", "--", rel }, root)
  if #lines == 0 then
    local tracked = git({ "ls-files", "--error-unmatch", "--", rel }, root) == 0
    if not tracked then _, lines = git({ "diff", "--no-index", "--", "/dev/null", rel }, root) end
  end
  if #lines == 0 then return nil, "no change" end
  return lines, nil, rel
end

local function render(state)
  local node = state.tree:get_node()
  if not node or node.type ~= "file" then return end
  local path = node.path
  if path == preview.path and is_open() then return end
  preview.path = path

  local lines, err, rel = diff_lines(path)
  lines = lines or { "", "  " .. vim.fn.fnamemodify(path, ":t") .. ": " .. err }
  if not (preview.buf and vim.api.nvim_buf_is_valid(preview.buf)) then
    preview.buf = vim.api.nvim_create_buf(false, true)
    vim.bo[preview.buf].bufhidden = "hide"
  end
  vim.bo[preview.buf].modifiable = true
  vim.api.nvim_buf_set_lines(preview.buf, 0, -1, false, lines)
  vim.bo[preview.buf].modifiable = false
  vim.bo[preview.buf].filetype = "diff"

  -- right of the tree, rest of the screen
  local tree_pos = vim.api.nvim_win_get_position(state.winid)
  local col = tree_pos[2] + vim.api.nvim_win_get_width(state.winid) + 1
  local cfg = {
    relative = "editor",
    row = 1,
    col = col,
    width = math.max(vim.o.columns - col - 3, 20),
    height = math.max(vim.o.lines - 6, 5),
    border = "rounded",
    title = " diff: " .. (rel or vim.fn.fnamemodify(path, ":t")) .. " ",
    title_pos = "center",
    style = "minimal",
    focusable = false,
  }
  if is_open() then
    vim.api.nvim_win_set_config(preview.win, cfg)
    vim.api.nvim_win_set_cursor(preview.win, { 1, 0 })
  else
    preview.win = vim.api.nvim_open_win(preview.buf, false, cfg)
  end
end

local function toggle(state)
  if is_open() then return close() end
  local node = state.tree:get_node()
  if not node or node.type ~= "file" then return vim.notify("gd: put the cursor on a file") end
  render(state)
  -- follow the cursor, close when leaving the tree
  local group = vim.api.nvim_create_augroup("neotree_diff_preview", { clear = true })
  vim.api.nvim_create_autocmd("CursorMoved", {
    group = group,
    buffer = state.bufnr,
    callback = function() render(state) end,
  })
  vim.api.nvim_create_autocmd({ "WinLeave", "BufLeave" }, { group = group, buffer = state.bufnr, callback = close })
end

-- the diff preview when open, else Neo-tree's scroll_preview (its preview, or the key's default)
local function scroll(keys, direction)
  return {
    function(state)
      if is_open() then
        return vim.api.nvim_win_call(preview.win, function() vim.cmd("normal! " .. vim.keycode(keys)) end)
      end
      require("neo-tree.sources.common.preview").scroll(state)
    end,
    config = { direction = direction },
    desc = "Scroll the preview " .. (direction < 0 and "down" or "up"),
  }
end

local mappings = {
  ["gd"] = { toggle, desc = "Git: diff preview (toggle)" },
  ["<C-f>"] = scroll("<C-d>", -10),
  ["<C-b>"] = scroll("<C-u>", 10),
}

---@type LazySpec
return {
  "nvim-neo-tree/neo-tree.nvim",
  opts = function(_, opts)
    for _, source in ipairs({ "git_status", "filesystem" }) do
      opts[source] = opts[source] or {}
      opts[source].window = opts[source].window or {}
      opts[source].window.mappings = vim.tbl_extend("force", opts[source].window.mappings or {}, mappings)
    end
  end,
}
