local map = vim.keymap.set
local default_options = { silent = true }
local expr_options = { expr = true, silent = true }

-- Nop
map("n", "S", "<Nop>")

--Remap space as leader key
vim.g.mapleader = " "

vim.keymap.set("n", "<C-A-l>", vim.lsp.buf.format)
vim.keymap.set("n", "<C-q>", function() require("core.plugins.lsp.utils").hover_in_split() end, { silent = true })
vim.keymap.set("n", "<C-a>", "<cmd>lua vim.lsp.buf.hover()<cr>", { silent = true })
map("n", "<C-f>", "<cmd>silent !tmux neww tmux-sessionizer<CR>", default_options)

--Remap for dealing with visual line wraps
map("n", "k", "v:count == 0 ? 'gk' : 'k'", expr_options)
map("n", "j", "v:count == 0 ? 'gj' : 'j'", expr_options)

-- better indenting
map("v", "<", "<gv", default_options)
map("v", ">", ">gv", default_options)

-- paste over currently selected text without yanking it
map("v", "p", '"_dp', default_options)
map("v", "P", '"_dP', default_options)

-- Cancel search highlighting with ESC
map("n", "<esc>", ":nohlsearch<Bar>:echo<CR>", default_options)

-- Autocorrect spelling from previous error
map("i", "<c-f>", "<c-g>u<Esc>[s1z=`]a<c-g>u", default_options)


-- move over a closing element in insert mode
map("i", "<C-l>", function()
  return require("core.utils.functions").escapePair()
end, default_options)

-- DMA Mappings
map({ "n", "i", "v" }, ";j", "<ESC>", default_options)

-- Exit terminal mode with C-x or ;j (same as C-\ C-n): Claude Code, OpenCode, toggleterm...
map("t", "<C-x>", "<C-\\><C-n>", default_options)
map("t", ";j", "<C-\\><C-n>", default_options)

map("v", "J", ":m '>+1<CR>gv=gv")
map("v", "K", ":m '<-2<CR>gv=gv")

map("n", "J", "mzJ`z")
map("n", "<C-d>", "<C-d>zz")
map("n", "<C-u>", "<C-u>zz")
map("n", "n", "nzzzv")
map("n", "N", "Nzzzv")

-- Copy without lose the current buffer
map("x", "<leader>p", [["_dP]])

-- Copy to system clip
map({ "n", "v" }, "<leader>y", [["+y]])
map("n", "<leader>Y", [["+Y]])

map("n", "<leader>S", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]])

-- windows split
map("n", "sq", ":q<CR>")
map("n", "sv", ":sp<CR>")
map("n", "se", ":vsp<CR>")

-- Smart semicolon: uses Treesitter query to detect missing ";" on current line
local function smart_semicolon()
  local lang = vim.treesitter.language.get_lang(vim.bo.filetype)
  if not lang then return end
  local parser = vim.treesitter.get_parser(0, lang)
  if not parser then return end
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1
  local ok, query = pcall(vim.treesitter.query.parse, lang, '((MISSING ";") @semi)')
  if not ok then return end
  local tree = parser:parse()[1]
  for _, node in query:iter_captures(tree:root(), 0, row, row + 1) do
    if (node:start()) == row then
      local line = vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1]
      vim.api.nvim_buf_set_lines(0, row, row + 1, false, { line .. ";" })
      return
    end
  end
end

map({ "n", "i" }, "<C-CR>", smart_semicolon, { silent = true, desc = "Smart semicolon" })

local wk = require("which-key")

-- Non-leader mappings descriptions
wk.add({
  { "sa", desc = "Add surrounding" },
  { "sd", desc = "Delete surrounding" },
  { "sn", desc = "Surround update n lines" },
  { "sr", desc = "Replace surrounding" },
  { "sF", desc = "Find left surrounding" },
  { "sf", desc = "Find right surrounding" },
  { "ss", "<cmd>lua MiniJump2d.start(MiniJump2d.builtin_opts.single_character)<cr>", desc = "Jump to character" },
})

-- Leader mappings
wk.add({
  { "<leader><tab>", "<cmd>e#<cr>",                                                                          desc = "Prev buffer" },
  { "<leader><leader>", "<cmd>tab split<cr>",                                                                desc = "Open in new tab" },
  { "<leader>c",     "<cmd>tabclose<cr>",                                                                    desc = "Close tab" },
  { "<leader>p",     hidden = true },
  { "<leader>S",     hidden = true },
  { "<leader>y",     hidden = true },
  { "<leader>Y",     hidden = true },

  -- Tabs
  { "<leader>t",     group = "tab" },
  { "<leader>tt",    "<cmd>tabnew<cr>",                                                                      desc = "New tab" },
  { "<leader>tc",    "<cmd>tabclose<cr>",                                                                    desc = "Close tab" },
  { "<leader>tj",    "<cmd>tabprev<cr>",                                                                     desc = "Prev tab" },
  { "<leader>tk",    "<cmd>tabnext<cr>",                                                                     desc = "Next tab" },
  { "<leader>tl",    function()
      local pickers      = require("telescope.pickers")
      local finders      = require("telescope.finders")
      local conf         = require("telescope.config").values
      local actions      = require("telescope.actions")
      local action_state = require("telescope.actions.state")
      local previewers   = require("telescope.previewers")

      -- Build tab entries: each tab shows all its windows
      local tabs = {}
      for i = 1, vim.fn.tabpagenr("$") do
        local wins   = vim.fn.tabpagebuflist(i)
        local focused = vim.fn.tabpagewinnr(i)
        local bufnr  = wins[focused]
        local name   = vim.fn.bufname(bufnr)
        local short  = name ~= "" and vim.fn.fnamemodify(name, ":t") or "[No Name]"
        -- collect all window filenames for display
        local win_names = {}
        for _, b in ipairs(wins) do
          local n = vim.fn.bufname(b)
          table.insert(win_names, n ~= "" and vim.fn.fnamemodify(n, ":t") or "[No Name]")
        end
        table.insert(tabs, {
          index    = i,
          bufnr    = bufnr,
          bufname  = name,
          label    = string.format("tab %-2d  %s  [%s]", i, short, table.concat(win_names, "  ")),
        })
      end

      local tab_previewer = previewers.new_buffer_previewer({
        title = "Tab preview",
        define_preview = function(self, entry)
          local e = entry.value
          if e.bufname ~= "" then
            -- reuse the buffer previewer logic
            conf.buffer_previewer_maker(e.bufname, self.state.bufnr, {
              bufname = self.state.bufname,
              winid   = self.state.winid,
            })
          else
            vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, { "[No file]" })
          end
        end,
      })

      pickers.new({}, {
        prompt_title = "Tabs",
        finder = finders.new_table({
          results = tabs,
          entry_maker = function(e)
            return { value = e, display = e.label, ordinal = e.label }
          end,
        }),
        sorter   = conf.generic_sorter({}),
        previewer = tab_previewer,
        attach_mappings = function(buf)
          actions.select_default:replace(function()
            actions.close(buf)
            vim.cmd("tabn " .. action_state.get_selected_entry().value.index)
          end)
          return true
        end,
      }):find()
    end,                                                                                                    desc = "List tabs" },

  -- Undotree
  { "<leader>u",     "<cmd>UndotreeToggle<cr>",                                                              desc = "Undotree" },

  -- Buffers
  { "<leader>b",     group = "Buffers" },
  { "<leader>bb",    "<cmd>Telescope buffers<cr>",                                                           desc = "Find buffer" },
  { "<leader>bD",    "<cmd>%bd|e#|bd#<cr>",                                                                  desc = "Close all but current buffer" },
  { "<leader>bd",    "<cmd>Bdelete<cr>",                                                                     desc = "Close buffer" },

  -- Files
  { "<leader>f",     group = "Files" },
  { "<leader>fb",    "<cmd>Telescope file_browser grouped=true<cr>",                                         desc = "File browser" },
  { "<leader>ff",    "<cmd>" .. require("core.utils.functions").telescope_find_files() .. "<cr>",            desc = "Find File" },
  { "<leader>fp",    "<cmd>Neotree reveal toggle<cr>",                                                       desc = "Toggle Filetree" },
  { "<leader>fr",    "<cmd>Telescope oldfiles<cr>",                                                          desc = "Open Recent File" },
  { "<leader>fs",    "<cmd>w<cr>",                                                                           desc = "Save Buffer" },
  { "<leader>fz",    "<cmd>Telescope zoxide list<CR>",                                                       desc = "Zoxide" },

  -- Misc
  { "<leader>m",     group = "Misc" },
  { "<leader>mc",    "<cmd>lua require('core.utils.functions').toggle_colorcolumn()<cr>",                    desc = "Toggle Colorcolumn" },
  { "<leader>mC",    "<cmd>:CBcatalog<cr>",                                                                  desc = "Commentbox Catalog" },
  { "<leader>md",    "<cmd>lua require('core.plugins.lsp.utils').toggle_virtual_text()<cr>",                 desc = "Toggle Virtualtext" },
  { "<leader>ml",    "<cmd>source ~/.config/nvim/snippets/*<cr>",                                            desc = "Reload snippets" },
  { "<leader>mo",    desc = "Options" },
  { "<leader>mp",    "<cmd>Lazy check<cr>",                                                                  desc = "Lazy check" },
  { "<leader>ms",    "<cmd>Outline<cr>",                                                                     desc = "Toggle Outline" },
  { "<leader>mm",    group = "Session" },
  { "<leader>mms",   "<cmd>SessionSave<cr>",                                                                 desc = "Save session" },
  { "<leader>mml",   "<cmd>SessionRestore<cr>",                                                              desc = "Restore session" },
  { "<leader>mmx",   "<cmd>SessionDelete<cr>",                                                               desc = "Delete session" },

  -- Git
  { "<leader>gL",    "<cmd>LazyGit<cr>",                                                                     desc = "LazyGit" },
  { "<leader>gn",    "<cmd>Neogit<cr>",                                                                      desc = "Neogit" },
  { "<leader>gv",    "<cmd>DiffviewOpen<cr>",                                                                desc = "Diff view" },
  { "<leader>gH",    "<cmd>DiffviewFileHistory %<cr>",                                                       desc = "File history" },
  { "<leader>gx",    "<cmd>DiffviewClose<cr>",                                                               desc = "Close diff" },

  -- Quickfix
  { "<leader>q",     group = "Quickfix" },
  { "<leader>qj",    "<cmd>cnext<cr>",                                                                       desc = "Next Quickfix Item" },
  { "<leader>qk",    "<cmd>cprevious<cr>",                                                                   desc = "Previous Quickfix Item" },
  { "<leader>qq",    "<cmd>lua require('core.utils.functions').toggle_qf()<cr>",                             desc = "Toggle quickfix list" },
  { "<leader>qt",    "<cmd>TodoQuickFix<cr>",                                                                desc = "Show TODOs" },

  -- Hydra heads (group labels only)
  { "<leader>s",     group = "Telescope" },
  { "<leader>w",     group = "Windows" },
  { "<leader>z",     group = "Spelling" },
})
