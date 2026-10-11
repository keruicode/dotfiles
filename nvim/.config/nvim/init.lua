local is_iap = vim.env.SSH_CONNECTION ~= nil or vim.env.SSH_TTY ~= nil
local explicitly_requested_full = vim.env.NVIM_APPNAME == "nvim"

if is_iap and not explicitly_requested_full then
  local light_init = vim.fn.fnamemodify(vim.fn.stdpath("config") .. "/../nvim-iap/init.lua", ":p")
  if vim.fn.filereadable(light_init) == 1 then
    dofile(light_init)
    return
  end
end

-- Bootstrap lazy.nvim, LazyVim and plugins. IAP reaches here only through
-- `nvim-lazy`, which explicitly exports NVIM_APPNAME=nvim.
require("config.lazy")
