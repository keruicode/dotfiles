-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.g.vimtex_view_method = "skim"

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
