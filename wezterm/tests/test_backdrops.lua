-- Run from the repository root: lua wezterm/tests/test_backdrops.lua
local root = os.tmpname()
os.remove(root)
local function quote(s) return "'" .. s:gsub("'", "'\\''") .. "'" end
local function command(args)
   local parts = {}
   for _, arg in ipairs(args) do parts[#parts + 1] = quote(arg) end
   local pipe = assert(io.popen(table.concat(parts, ' ') .. ' 2>/dev/null'))
   local output = pipe:read('*a')
   local ok = pipe:close()
   return ok == true, output, ''
end
assert(command({ 'mkdir', '-p', root .. '/backdrops/public', root .. '/backdrops/private' }))
local function write(path)
   local handle = assert(io.open(root .. '/backdrops/' .. path, 'w'))
   handle:write('fixture')
   handle:close()
end
local w = {
   GLOBAL = {}, config_dir = root, target_triple = 'aarch64-apple-darwin',
   run_child_process = command, nerdfonts = {},
   action = { InputSelector = function(value) return value end },
   action_callback = function(fn) return fn end,
   glob = function() return {} end,
}
package.preload.wezterm = function() return w end
package.path = 'wezterm/.config/wezterm/?.lua;' .. package.path
local b = require('utils.backdrops')
local window = {
   set_config_overrides = function(self, opts) self.overrides = opts end,
   get_config_overrides = function(self) return self.overrides end,
   effective_config = function() return { background = {} } end,
   toast_notification = function() end,
   perform_action = function(self, action) self.selector = action end,
}
local ok, err = pcall(function()
   write('public/a.png')
   write('private/secret.png')
   b:set_files('public')
   assert(#b.files == 1)
   b:set_img(window, 1)
   -- Reloads/other windows may change GLOBAL without changing the visible image.
   w.GLOBAL.background = root .. '/backdrops/private/secret.png'
   b:move_current(window, 'like')
   assert(w.GLOBAL.background == root .. '/backdrops/public/like/a.png')
   b:set_files('like')
   assert(#b.files == 1)
   -- A relative symlink keeps its original target after moving down a level.
   assert(command({ 'ln', '-s', '../private/secret.png', root .. '/backdrops/public/link.png' }))
   w.GLOBAL.background = root .. '/backdrops/public/link.png'
   b:_set_opt(window)
   b:move_current(window, 'like')
   assert(io.open(root .. '/backdrops/public/like/link.png', 'r'))
   b:confirm_delete(window, nil)
   w.GLOBAL.background = root .. '/backdrops/private/secret.png'
   window.selector.action(window, nil, 'cancel')
   assert(#b:set_files('like').files == 2)
   window.selector.action(window, nil, 'delete')
   assert(#b:set_files('like').files == 1)
   b:set_img(window, 1)
   assert(command({ 'mkdir', '-p', root .. '/backdrops/public/deleted' }))
   write('public/deleted/a.png')
   b:move_current(window, 'deleted')
   assert(#b.files == 0 and w.GLOBAL.background == nil)
   assert(io.open(root .. '/backdrops/public/deleted/1-a.png', 'r'))
   b:set_files('all')
   assert(#b.files == 1 and b.files[1]:match('secret.png$'))
   b:switch_category(window, 'public')
   assert(#b.files == 0 and b.category == 'public' and w.GLOBAL.background == nil)
   w.GLOBAL.background = root .. '/backdrops/private/secret.png'
   b:move_current(window, 'like')
   assert(#b:set_files('private').files == 1, 'Focus mode must not favorite a hidden image')
end)
assert(command({ 'rm', '-rf', root }))
assert(ok, err)
print('backdrops: favorite, symlink, delete, collision, rotation and privacy checks passed')
