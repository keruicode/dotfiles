-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- ~/.config/lazyvim-tex/lua/config/keymaps.lua

---@diagnostic disable: undefined-global
local map = vim.keymap.set

-- 基础按键
map({ "n", "v" }, ";", ":", { desc = "进入命令行模式" })
map("n", "Q", ":q<CR>", { silent = true })
map("n", "S", ":w<CR>", { silent = true })

-- 你的自定义方向键 (非常激进的改动，会覆盖很多 Vim 默认操作)
map({ "n", "v" }, "u", "k", { silent = true })
map({ "n", "v" }, "n", "h", { silent = true })
map({ "n", "v" }, "e", "j", { silent = true })
map({ "n", "v" }, "i", "l", { silent = true })

map({ "n", "v" }, "U", "5k", { silent = true })
map({ "n", "v" }, "E", "5j", { silent = true })
map({ "n", "v" }, "N", "0", { silent = true })
map({ "n", "v" }, "I", "$", { silent = true })

-- 窗口管理
map("n", "su", ":set nosplitbelow<CR>:split<CR>:set splitbelow<CR>", { silent = true })
map("n", "se", ":set splitbelow<CR>:split<CR>", { silent = true })
map("n", "sn", ":set nosplitright<CR>:vsplit<CR>:set splitright<CR>", { silent = true })
map("n", "si", ":set splitright<CR>:vsplit<CR>", { silent = true })

-- 因为 u 被用作向上了，所以将撤销分配给 l
map({ "n", "v" }, "l", "u", { desc = "撤销 (原为 u)" })
-- 因为 i 被用作向右了，所以将进入插入模式分配给 k
map({ "n", "v" }, "k", "i", { desc = "进入插入模式 (原为 i)" })
map({ "n", "v" }, "K", "I", { desc = "在行首进入插入模式" })
map("v", "Y", '"+y', { desc = "复制到系统剪贴板" })

-- ==================== 搜索跳转 ====================
-- 因为原生的 n 被映射为了向左移动，这里将查找下一个/上一个分配给 = 和 -
map({ "n", "v", "o" }, "=", "n", { desc = "查找下一个匹配项" })
map({ "n", "v", "o" }, "-", "N", { desc = "查找上一个匹配项" })

-- 使用 <leader>w 作为前缀，配合原生的 <C-w> 窗口控制指令
-- (请根据你实际的 Colemak 习惯，微调后面对应的 h/j/k/l 方向)

map("n", "<leader>wn", "<C-w>h", { desc = "Go to the left window", remap = true })
map("n", "<leader>we", "<C-w>j", { desc = "Go to the down window", remap = true })
map("n", "<leader>wu", "<C-w>k", { desc = "Go to the up window", remap = true })
map("n", "<leader>wi", "<C-w>l", { desc = "Go to the right window", remap = true })

-- 如果你还需要关闭当前窗口，也可以加上这个
map("n", "<leader>q", "<C-w>q", { desc = "关闭当前窗口" })

-- 按 r 键调用 VimTeX 的编译功能
-- vim.keymap.set("n", "r", "<Cmd>VimtexCompile<CR>", { silent = true, desc = "VimTeX 编译" })
map("n", "r", function()
  -- 1. 无论什么类型，先自动保存文件
  vim.cmd("silent! write")

  -- 2. 获取当前文件类型、完整文件名和无后缀文件名
  local ft = vim.bo.filetype
  local filename = vim.fn.expand("%") -- 例如: main.c
  local filenoext = vim.fn.expand("%<") -- 例如: main

  -- 3. 根据不同的文件类型执行对应操作
  if ft == "tex" then
    vim.cmd("silent! VimtexCompile")
  elseif ft == "python" then
    vim.cmd("split")
    vim.cmd("term python3 " .. filename)
    vim.cmd("startinsert") -- 自动进入终端插入模式，方便查看输出
  elseif ft == "c" then
    vim.cmd("split")
    vim.cmd("resize -5")
    vim.cmd("term gcc " .. filename .. " -o " .. filenoext .. " && time ./" .. filenoext)
    vim.cmd("startinsert")
  elseif ft == "cpp" then
    vim.cmd("split")
    vim.cmd("resize -10")
    vim.cmd("term g++ -std=c++11 " .. filename .. " -Wall -o " .. filenoext .. " && ./" .. filenoext)
    vim.cmd("startinsert")
  elseif ft == "java" then
    vim.cmd("split")
    vim.cmd("resize -5")
    vim.cmd("term javac " .. filename .. " && time java " .. filenoext)
    vim.cmd("startinsert")
  elseif ft == "sh" then
    vim.cmd("split")
    vim.cmd("term time bash " .. filename)
    vim.cmd("startinsert")
  elseif ft == "ncl" then
    vim.cmd("split")
    vim.cmd("term ncl " .. filename)
    vim.cmd("startinsert")
  elseif ft == "go" then
    vim.cmd("split")
    vim.cmd("term go run .")
    vim.cmd("startinsert")
  elseif ft == "javascript" then
    vim.cmd("split")
    vim.cmd('term export DEBUG="INFO,ERROR,WARNING"; node --trace-warnings .')
    vim.cmd("startinsert")
  elseif ft == "racket" then
    vim.cmd("split")
    vim.cmd("resize -5")
    vim.cmd("term racket " .. filename)
    vim.cmd("startinsert")
  else
    -- 如果是没有定义的类型，在下方给个提示
    vim.notify("暂未配置针对该文件类型 (" .. ft .. ") 的一键运行操作", vim.log.levels.WARN)
  end
end, { silent = true, desc = "一键编译/运行 (自动识别语言)" })

-- ==================== 智能保存键 (LaTeX 专属) ====================
local map = vim.keymap.set

map("n", "S", function()
  -- 1. 保存文件（这会自动触发后台已有的 \ll 进程进行编译）
  vim.cmd("silent! write")

  -- 2. 如果当前是 tex 文件，立刻执行正向搜索（同步 Skim 位置）
  if vim.bo.filetype == "tex" then
    vim.cmd("silent! VimtexView")
  end
end, { silent = true, desc = "保存并同步 Skim" })
