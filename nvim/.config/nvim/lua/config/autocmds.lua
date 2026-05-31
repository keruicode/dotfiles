-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

---@diagnostic disable: undefined-global
-- 反向搜索后自动聚焦回 WezTerm 终端
vim.api.nvim_create_augroup("VimtexFocus", { clear = true })
vim.api.nvim_create_autocmd("User", {
  group = "VimtexFocus",
  pattern = "VimtexEventViewReverse",
  callback = function()
    -- 使用 macOS 的 open 命令唤醒 WezTerm 窗口
    os.execute("open -a 'WezTerm'")
  end,
})

-- ~/.config/lazyvim-tex/lua/config/autocmds.lua

-- NCL 文件类型识别
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = "*.ncl",
  command = "set filetype=ncl dictionary=~/.vim/dict/ncl.dict",
})

-- NCL 语法高亮
vim.api.nvim_create_autocmd("Syntax", {
  pattern = "newlang",
  command = "source ~/.vim/ncl.vim",
})

-- LaTeX 奇怪渲染字符 (Conceal Fix)
local tex_conceal_grp = vim.api.nvim_create_augroup("LaTeXConcealFix", { clear = true })
vim.api.nvim_create_autocmd("FileType", {
  group = tex_conceal_grp,
  pattern = "tex",
  callback = function()
    vim.opt_local.conceallevel = 0
    vim.opt_local.concealcursor = ""
    vim.g.vimtex_syntax_conceal_disable = 1
    -- 延迟执行兜底
    vim.defer_fn(function()
      vim.opt_local.conceallevel = 0
      vim.opt_local.concealcursor = ""
    end, 10)
  end,
})

-- ============================================================================
-- 终极同步流：编译成功后，自动让 Skim 跳转到当前光标位置
-- ============================================================================
local vimtex_sync_grp = vim.api.nvim_create_augroup("VimtexLiveSync", { clear = true })

-- 监听 VimTeX 的专属事件：编译成功 (VimtexEventCompileSuccess)
vim.api.nvim_create_autocmd("User", {
  group = vimtex_sync_grp,
  pattern = "VimtexEventCompileSuccess",
  callback = function()
    -- 确保当前启用了 VimTeX 并且阅读器已经就绪
    if vim.b.vimtex and vim.b.vimtex.viewer then
      -- 执行静默正向搜索 (相当于自动帮你按了 \ l v)
      vim.cmd("silent! VimtexView")
    end
  end,
})
