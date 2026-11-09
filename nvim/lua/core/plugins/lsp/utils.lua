local utils = require("core.utils.functions")
M = {}

-- must be global or the initial state is not working
VIRTUAL_TEXT_ACTIVE = true
-- toggle displaying virtual text
M.toggle_virtual_text = function()
  VIRTUAL_TEXT_ACTIVE = not VIRTUAL_TEXT_ACTIVE
  utils.notify(string.format("Virtualtext %s", VIRTUAL_TEXT_ACTIVE and "on" or "off"), 1, "lsp/utils.lua")
  vim.diagnostic.show(nil, 0, nil, { virtual_text = VIRTUAL_TEXT_ACTIVE })
end

-- must be global or the initial state is not working
AUTOFORMAT_ACTIVE = true
-- toggle null-ls's autoformatting
M.toggle_autoformat = function()
  AUTOFORMAT_ACTIVE = not AUTOFORMAT_ACTIVE
  require("core.utils.functions").notify(
    string.format("Autoformatting %s", AUTOFORMAT_ACTIVE and "on" or "off"),
    1,
    "lsp.utils"
  )
end

-- detect python venv
-- https://github.com/neovim/nvim-lspconfig/issues/500#issuecomment-851247107
local util = require("lspconfig/util")
local path = util.path
function M.get_python_path(workspace)
  -- Use activated virtualenv.
  if vim.env.VIRTUAL_ENV then
    return path.join(vim.env.VIRTUAL_ENV, "bin", "python")
  end
  -- Find and use virtualenv in workspace directory (no root_dir: a lone script, take the cwd)
  workspace = workspace or vim.fn.getcwd()
  for _, pattern in ipairs({ "*", ".*" }) do
    local match = vim.fn.glob(path.join(workspace, pattern, "pyvenv.cfg"))
    if match ~= "" then
      return path.join(path.dirname(match), "bin", "python")
    end
  end
  -- Fallback to system Python.
  -- exepath returns "" (not nil) when not found
  local python = vim.fn.exepath("python3")
  if python == "" then python = vim.fn.exepath("python") end
  return python ~= "" and python or "python"
end

local function disable_diagnostics(bufnr, message)
  utils.notify("Disabling diagnostics for HelmRelease files", 1, "lsp/utils")
  vim.diagnostic.reset(bufnr)
  vim.diagnostic.enable(false, { bufnr = bufnr })
end

local function handle_helm_templates(bufnr)
  local bufferData = vim.api.nvim_buf_get_text(bufnr, 0, 0, -1, -1, {})
  local bufferString = table.concat(bufferData, "\n")
  -- usually Helm files are in a template folder
  -- TODO: more robust and elegant check
  if string.find(bufferString, "kind: HelmRelease") then
    disable_diagnostics(bufnr, "Disabling diagnostics for HelmRelease files")
  end
end

local function handle_docker_compose(bufnr)
  local bufName = vim.api.nvim_buf_get_name(bufnr)
  -- TODO: more robust and elegant check
  -- search dor docker-compose.yaml does not work!
  if string.find(bufName, "compose.yaml") then
    disable_diagnostics(bufnr, "Disabling diagnostics for docker-compose files")
  end
end

local function handle_helm_releases(bufnr)
  local bufName = vim.api.nvim_buf_get_name(bufnr)
  -- TODO: more robust and elegant check
  if string.find(bufName, "templates") then
    disable_diagnostics(bufnr, "Disabling diagnostics for Helm template files")
  end
end

local function handle_kustomization(bufnr)
  local bufName = vim.api.nvim_buf_get_name(bufnr)
  -- TODO: more robust and elegant check
  if string.find(bufName, "kustomization.yaml") then
    disable_diagnostics(bufnr, "Disabling diagnostics for kustomization.yaml")
  end
end

function M.hover_in_split()
  local client = vim.lsp.get_clients({ bufnr = 0 })[1]
  local params = vim.lsp.util.make_position_params(0, client and client.offset_encoding or "utf-16")
  vim.lsp.buf_request(0, "textDocument/hover", params, function(err, result)
    if err or not result or not result.contents then return end
    local lines = vim.lsp.util.convert_input_to_markdown_lines(result.contents)
    lines = vim.lsp.util.trim_empty_lines(lines)
    if vim.tbl_isempty(lines) then return end
    vim.cmd("rightbelow vnew")
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].filetype = "markdown"
    vim.bo[buf].modifiable = false
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, silent = true })
  end)
end

local _wk_lsp_registered = false

function M.custom_lsp_attach(client, bufnr)
  -- disable formatting for LSP clients as this is handled by null-ls
  client.server_capabilities.documentFormattingProvider = false
  client.server_capabilities.documentRangeFormattingProvider = false
  -- TODO: this workaround is not sufficient and bugyy
  -- handle_helm_templates(bufnr)
  -- handle_kustomization(bufnr)
  -- handle_docker_compose(bufnr)
  -- handle_helm_releases(bufnr)
  if _wk_lsp_registered then return end
  _wk_lsp_registered = true
  local wk = require("which-key")
  wk.add({
    { "<leader>l",    group = "LSP",                       mode = "n" },
    { "<leader>lD",   "<cmd>lua vim.lsp.buf.declaration()<cr>",                             desc = "Go To Declaration" },
    { "<leader>lI",   "<cmd>lua vim.lsp.buf.implementation()<cr>",                          desc = "Show implementations" },
    { "<leader>lR",   "<cmd>lua vim.lsp.buf.rename()<cr>",                                  desc = "Rename" },
    { "<leader>la",   "<cmd>lua vim.lsp.buf.code_action()<cr>",                             desc = "Code Action" },
    { "<leader>ld",   "<cmd>lua vim.lsp.buf.definition()<cr>",                              desc = "Go To Definition" },
    { "<leader>le",   "<cmd>Telescope diagnostics bufnr=0<cr>",                             desc = "Document Diagnostics" },
    { "<leader>li",   "<cmd>LspInfo<cr>",                                                   desc = "Connected Language Servers" },
    { "<leader>lk",   "<cmd>lua vim.lsp.buf.hover()<cr>",                                   desc = "Hover Commands" },
    { "<leader>lK", function() M.hover_in_split() end, desc = "Hover in split" },
    { "<leader>ll",   "<cmd>lua vim.diagnostic.open_float()<CR>",                           desc = "Line Diagnostics" },
    { "<leader>ln",   "<cmd>lua vim.diagnostic.goto_next()<cr>",                            desc = "Next Diagnostic" },
    { "<leader>lp",   "<cmd>lua vim.diagnostic.goto_prev()<cr>",                            desc = "Prev Diagnostic" },
    { "<leader>lq",   "<cmd>lua vim.diagnostic.setloclist()<cr>",                           desc = "Quickfix Diagnostics" },
    { "<leader>lr",   "<cmd>lua vim.lsp.buf.references()<cr>",                              desc = "References" },
    { "<leader>ls",   "<cmd>Telescope lsp_document_symbols<cr>",                            desc = "Document Symbols" },
    { "<leader>lt",   "<cmd>lua vim.lsp.buf.type_definition()<cr>",                         desc = "Type Definition" },
    { "<leader>lw",   group = "workspaces" },
    { "<leader>lwa",  "<cmd>lua vim.lsp.buf.add_workspace_folder()<cr>",                    desc = "Add Workspace Folder" },
    { "<leader>lwd",  "<cmd>Telescope diagnostics<cr>",                                     desc = "Workspace Diagnostics" },
    { "<leader>lwl",  "<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<cr>", desc = "List Workspace Folders" },
    { "<leader>lwr",  "<cmd>lua vim.lsp.buf.remove_workspace_folder()<cr>",                 desc = "Remove Workspace Folder" },
    { "<leader>lws",  "<cmd>Telescope lsp_dynamic_workspace_symbols<cr>",                   desc = "Workspace Symbols" },
  })
end

return M
