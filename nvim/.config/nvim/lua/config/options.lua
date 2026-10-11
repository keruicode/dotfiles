-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

local is_macos = vim.fn.has("macunix") == 1
local is_remote = vim.env.SSH_CONNECTION ~= nil or vim.env.SSH_TTY ~= nil

if is_remote then
  -- login02/login03 run inside tmux 1.8, which only advertises 256 colours.
  -- RGB output here is misinterpreted even when COLORTERM says truecolor.
  vim.opt.termguicolors = false

  -- HOME is shared by several IAP nodes. Keep ShaDa node-local so concurrent
  -- Neovim instances do not race while replacing the same ParaStor file.
  local hostname = (vim.uv or vim.loop).os_gethostname() or "iap"
  local username = vim.env.USER or tostring(vim.fn.getuid())
  local shada_dir = ("/tmp/nvim-%s-%s/shada"):format(username, hostname):gsub("[^%w%._/%-]", "_")
  vim.fn.mkdir(shada_dir, "p", 448)
  vim.opt.shadafile = shada_dir .. "/main.shada"
end

if is_macos then
  vim.g.vimtex_view_method = "skim"
else
  -- IAP is terminal-only. Compilation remains available, but GUI PDF viewing does not.
  vim.g.vimtex_view_enabled = 0
end

-- ~/.config/lazyvim-tex/lua/config/options.lua

-- LazyVim 已经默认开启了 number, relativenumber, ignorecase, smartcase 等，不用重复写
local opt = vim.opt

opt.tabstop = 2
opt.shiftwidth = 2
opt.softtabstop = 2
opt.expandtab = false -- 对应你原本的 set noexpandtab
opt.list = true
opt.listchars = { tab = "| ", trail = "▫" }
opt.scrolloff = 4
opt.timeoutlen = 0 -- 对应 set ttimeoutlen=0 和 notimeout 的调整
opt.wrap = true
opt.colorcolumn = "100"
opt.virtualedit = "block"

-- 禁用系统剪贴板同步，恢复内部剪贴板独立
vim.opt.clipboard = ""
