vim.g.mapleader = " "
vim.g.maplocalleader = " "

local opt = vim.opt

opt.termguicolors = false
opt.number = true
opt.relativenumber = true
opt.mouse = "a"
opt.hidden = true
opt.wrap = true
opt.linebreak = true
opt.breakindent = true
opt.scrolloff = 4
opt.sidescrolloff = 4
opt.splitbelow = true
opt.splitright = true
opt.ignorecase = true
opt.smartcase = true
opt.incsearch = true
opt.hlsearch = true
opt.tabstop = 2
opt.shiftwidth = 2
opt.softtabstop = 2
opt.expandtab = false
opt.autoindent = true
opt.smartindent = true
opt.foldenable = false
opt.conceallevel = 0
opt.concealcursor = ""
opt.list = false
opt.signcolumn = "no"
opt.colorcolumn = ""
opt.laststatus = 2
opt.showtabline = 0
opt.showmode = true
opt.timeoutlen = 500
opt.updatetime = 300
opt.clipboard = ""
opt.swapfile = true
opt.undofile = false
opt.backup = false
opt.writebackup = false
opt.statusline = " %f %m %= %y  %l:%c  %p%% "

local hostname = (vim.uv or vim.loop).os_gethostname() or "iap"
local username = vim.env.USER or tostring(vim.fn.getuid())
local state_root = ("/tmp/nvim-iap-%s-%s"):format(username, hostname):gsub("[^%w%._/%-]", "_")
vim.fn.mkdir(state_root .. "/shada", "p", 448)
opt.shadafile = state_root .. "/shada/main.shada"

vim.cmd("filetype plugin indent on")
vim.cmd("syntax enable")
vim.cmd.colorscheme("retrobox")

vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    vim.cmd("redraw!")
  end,
})

local map = vim.keymap.set
local silent = { silent = true }

map({ "n", "v" }, ";", ":", { desc = "Command line" })
map("n", "Q", "<Cmd>quit<CR>", silent)
map("n", "S", "<Cmd>write<CR>", silent)

map({ "n", "v" }, "u", "k", silent)
map({ "n", "v" }, "n", "h", silent)
map({ "n", "v" }, "e", "j", silent)
map({ "n", "v" }, "i", "l", silent)
map({ "n", "v" }, "U", "5k", silent)
map({ "n", "v" }, "E", "5j", silent)
map({ "n", "v" }, "N", "0", silent)
map({ "n", "v" }, "I", "$", silent)

map({ "n", "v" }, "l", "u", { desc = "Undo" })
map({ "n", "v" }, "k", "i", { desc = "Insert" })
map({ "n", "v" }, "K", "I", { desc = "Insert at line start" })
map({ "n", "v", "o" }, "=", "n", { desc = "Next search result" })
map({ "n", "v", "o" }, "-", "N", { desc = "Previous search result" })

map("n", "su", "<Cmd>aboveleft split<CR>", silent)
map("n", "se", "<Cmd>belowright split<CR>", silent)
map("n", "sn", "<Cmd>aboveleft vsplit<CR>", silent)
map("n", "si", "<Cmd>belowright vsplit<CR>", silent)
map("n", "<leader>wn", "<C-w>h", { desc = "Left window" })
map("n", "<leader>we", "<C-w>j", { desc = "Lower window" })
map("n", "<leader>wu", "<C-w>k", { desc = "Upper window" })
map("n", "<leader>wi", "<C-w>l", { desc = "Right window" })
map("n", "<leader>q", "<C-w>q", { desc = "Close window" })
map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Leave terminal mode" })

local runners = {
  python = function(file)
    return "python3 " .. vim.fn.shellescape(file)
  end,
  sh = function(file)
    return "bash " .. vim.fn.shellescape(file)
  end,
  ncl = function(file)
    return "ncl " .. vim.fn.shellescape(file)
  end,
  tex = function(file)
    return "latexmk -pdf -interaction=nonstopmode " .. vim.fn.shellescape(file)
  end,
}

map("n", "r", function()
  vim.cmd.write()
  local runner = runners[vim.bo.filetype]
  if not runner then
    vim.notify("No lightweight runner for " .. vim.bo.filetype, vim.log.levels.WARN)
    return
  end

  local command = runner(vim.fn.expand("%:p"))
  vim.cmd("botright 12split")
  vim.fn.termopen({ "bash", "-lc", command })
  vim.cmd.startinsert()
end, { desc = "Save and run current file" })

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = "*.ncl",
  callback = function()
    vim.bo.filetype = "ncl"
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "markdown", "tex", "plaintex" },
  callback = function()
    vim.opt_local.conceallevel = 0
    vim.opt_local.concealcursor = ""
    vim.opt_local.foldenable = false
  end,
})
