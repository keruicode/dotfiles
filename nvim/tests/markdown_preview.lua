local root = vim.fn.getcwd() .. "/nvim/.config/nvim"
local mode = arg[1] or "mapping"
local filename = vim.fn.tempname() .. " markdown preview.md"
local stopped = false

local ok, result = xpcall(function()
  local spec = dofile(root .. "/lua/plugins/markdown-preview.lua")[1]
  assert(spec.cmd[1] == "MarkdownPreview")
  spec.init()
  assert(vim.g.mkdp_auto_start == 0)
  assert(vim.g.mkdp_open_to_the_world == 0)

  dofile(root .. "/lua/config/keymaps.lua")
  vim.cmd.edit(vim.fn.fnameescape(filename))
  vim.bo.filetype = "markdown"
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "# Markdown preview test", "", "$x^2$" })
  local run = vim.fn.maparg("r", "n", false, true).callback
  assert(type(run) == "function")

  if mode == "server" then
    vim.cmd([[
      function! PreviewTestOpen(url)
        let g:preview_test_url = a:url
      endfunction
    ]])
    vim.g.mkdp_browserfunc = "PreviewTestOpen"
    run()
    assert(
      vim.wait(15000, function()
        return vim.g.preview_test_url ~= nil
      end, 100),
      "preview server did not open a URL"
    )
    local url = vim.g.preview_test_url
    assert(url:match("^http://localhost:%d+/page/%d+$"), "unexpected preview URL: " .. url)
    local response
    vim.system(
      { "curl", "--noproxy", "*", "--max-time", "5", "--fail", "--silent", "--show-error", url },
      { text = true },
      function(value)
        response = value
      end
    )
    assert(
      vim.wait(6000, function()
        return response ~= nil
      end, 50),
      "preview HTTP request timed out"
    )
    assert(response.code == 0 and response.stdout:find("<html"), "preview page is unavailable: " .. response.stderr)
    vim.cmd("MarkdownPreviewStop")
    stopped = true
    assert(vim.fn["mkdp#rpc#get_server_status"]() == -1, "preview service did not stop")
    print("PREVIEW_HTTP_AND_STOP_OK " .. url)
  else
    local previews, compiles = 0, 0
    vim.api.nvim_create_user_command("MarkdownPreview", function()
      previews = previews + 1
      assert(vim.fn.readfile(filename)[1] == "# Markdown preview test", "r did not save first")
    end, {})
    vim.api.nvim_create_user_command("VimtexCompile", function()
      compiles = compiles + 1
    end, {})
    run()
    assert(previews == 1)
    vim.bo.filetype = "tex"
    run()
    assert(compiles == 1 and previews == 1, "TeX dispatch changed")
    vim.bo.filetype = "markdown"
    vim.env.SSH_TTY = "/test/tty"
    local message
    vim.notify = function(text)
      message = text
    end
    run()
    assert(previews == 1 and message ~= nil, "remote guard failed")
    assert(dofile(root .. "/lua/plugins/markdown-preview.lua")[1].enabled == false)
    print("MARKDOWN_R_SAVE_TEX_AND_REMOTE_GUARD_OK")
  end
end, debug.traceback)

if mode == "server" and not stopped and vim.fn.exists(":MarkdownPreviewStop") == 2 then
  pcall(vim.cmd, "MarkdownPreviewStop")
end
vim.fn.delete(filename)
if not ok then
  io.stderr:write(result .. "\n")
  vim.cmd("cquit 1")
else
  vim.cmd("qa!")
end
