local utils = require("core.plugins.lsp.utils")
local languages = require("core.plugins.lsp.languages")

-- Neovim 0.11 bug: nvim_exec_autocmds crashes when LSP sends progress data
-- with mixed integer/string keys. Intercept and suppress only that error.
do
  local orig = vim.api.nvim_exec_autocmds
  vim.api.nvim_exec_autocmds = function(event, opts)
    local ok, err = pcall(orig, event, opts)
    if not ok and type(err) == "string" and err:find("Cannot convert") then
      return
    elseif not ok then
      error(err, 2)
    end
  end
end

local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = require("cmp_nvim_lsp").default_capabilities(capabilities)

local servers = {
  "bashls",
  "dockerls",
  "jsonls",
  "marksman",
  "pyright",
  "lua_ls",
  "terraformls",
  "ts_ls",
  "yamlls",
  "nil_ls",
  "cssls",
  "html",
  "gopls",
  "rust_analyzer",
}

-- clangd configured separately.
-- NOTE: --query-driver is NOT used here because on NixOS the xtensa compiler
-- is wrapped and injects x86/glibc paths, which breaks cross-compilation.
-- Include paths are handled via the project's .clangd file instead.
vim.lsp.config("clangd", {
  autostart = true,
  capabilities = capabilities,
  flags = { debounce_text_changes = 150 },
  cmd = { "clangd" },
  on_attach = function(client, bufnr)
    utils.custom_lsp_attach(client, bufnr)
  end,
})
vim.lsp.enable("clangd")

local function is_file_too_large()
  return vim.fn.strwidth(vim.fn.getline(".")) > 300
    or vim.fn.getfsize(vim.fn.expand("%")) > 1024 * 1024
end

for _, server in ipairs(servers) do
  vim.lsp.config(server, {
    autostart = true,
    capabilities = capabilities,
    flags = { debounce_text_changes = 150 },

    on_attach = function(client, bufnr)
      utils.custom_lsp_attach(client, bufnr)
    end,

    before_init = function(_, config)
      if server == "pyright" then
        local python_path = utils.get_python_path(config.root_dir)
        vim.g.python3_host_prog = python_path
        config.settings = config.settings or {}
        config.settings.python = config.settings.python or {}
        config.settings.python.pythonPath = python_path
        -- Pass venv location so pyright resolves packages correctly
        if vim.env.VIRTUAL_ENV then
          config.settings.python.venvPath = vim.fn.fnamemodify(vim.env.VIRTUAL_ENV, ":h")
          config.settings.python.venv = vim.fn.fnamemodify(vim.env.VIRTUAL_ENV, ":t")
        end
      end
    end,

    settings = {
      json = languages.json,
      Lua = languages.lua,
      redhat = { telemetry = { enabled = false } },
      yaml = languages.yaml,
    },
  })

  -- 🔥 nouveau : activation explicite, only when the server is installed (a missing one errors on
  -- every file of its type, e.g. no nil in the Coder workspaces)
  local cmd = (vim.lsp.config[server] or {}).cmd
  if type(cmd) == "function" or (type(cmd) == "table" and vim.fn.executable(cmd[1]) == 1) then
    vim.lsp.enable(server)
  end
end
