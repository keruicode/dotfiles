local wezterm = require('wezterm')
local platform = require('utils.platform')
local colors = require('colors.custom')

-- Seeding random numbers before generating for use
-- Known issue with lua math library
-- see: https://stackoverflow.com/questions/20154991/generating-uniform-random-numbers-in-lua
math.randomseed(os.time())
math.random()
math.random()
math.random()

local PATH_SEP = platform.is_win and '\\' or '/'
local DEFAULT_CATEGORY = 'public'
local CATEGORY_ORDER = { 'public', 'private', 'like' }
local CATEGORY_LABELS = {
   public = 'Public',
   private = 'Private',
   like = 'Like (Public + Private)',
   all = 'All',
}
local CATEGORY_DIRS = {
   public = {
      'backdrops/public',
      'backdrops/public/like',
   },
   private = {
      'backdrops/private',
      'backdrops/private/like',
   },
   like = { 'backdrops/public/like', 'backdrops/private/like' },
   all = {
      'backdrops/public',
      'backdrops/private',
      'backdrops/public/like',
      'backdrops/private/like',
      'backdrops',
      'backdrops_past',
   },
}
local GLOB_EXTENSIONS = {
   jpg = true,
   jpeg = true,
   png = true,
   gif = true,
   bmp = true,
   ico = true,
   tiff = true,
   pnm = true,
   dds = true,
   tga = true,
}

local function shell_quote(value)
   return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function is_readable_file(file)
   local handle = io.open(file, 'rb')
   if handle then
      handle:close()
      return true
   end
   return false
end

local function append_file(files, seen, file)
   local extension = file:match('%.([^.]+)$')
   if
      extension
      and GLOB_EXTENSIONS[extension:lower()]
      and not seen[file]
      and is_readable_file(file)
   then
      seen[file] = true
      table.insert(files, file)
   end
end

local function scan_dir(dir)
   local files = {}
   local seen = {}
   local abs_dir = wezterm.config_dir .. PATH_SEP .. dir

   for _, file in ipairs(wezterm.glob(abs_dir .. PATH_SEP .. '*')) do
      append_file(files, seen, file)
   end

   if #files == 0 then
      local pipe = io.popen(
         'find '
            .. shell_quote(abs_dir)
            .. [[ -maxdepth 1 \( -type f -o -type l \) 2>/dev/null]]
      )
      if pipe then
         for file in pipe:lines() do
            append_file(files, seen, file)
         end
         pipe:close()
      end
   end

   table.sort(files)
   return files
end

local function normalize_category(category)
   category = tostring(category or DEFAULT_CATEGORY):lower()
   local aliases = {
      pub = 'public',
      work = 'public',
      office = 'public',
      open = 'public',
      safe = 'public',
      pri = 'private',
      personal = 'private',
      home = 'private',
   }
   category = aliases[category] or category
   return CATEGORY_DIRS[category] and category or nil
end

local function category_label(category)
   return CATEGORY_LABELS[category] or category
end

---@class BackDrops
---@field current_idx number index of current image
---@field category string current backdrop category
---@field files string[] background images
---@field focus_color string background color when in focus mode. Default is `colors.custom.background`
---@field focus_on boolean focus mode on or off
local BackDrops = {}
BackDrops.__index = BackDrops

--- Initialise backdrop controller
---@private
function BackDrops:init()
   local inital = {
      current_idx = 1,
      category = wezterm.GLOBAL.backdrop_category or DEFAULT_CATEGORY,
      files = {},
      focus_color = colors.background,
      focus_on = true,
   }
   local backdrops = setmetatable(inital, self)
   wezterm.GLOBAL.background = nil
   return backdrops
end

---MUST BE RUN BEFORE ALL OTHER `BackDrops` functions
---Sets the `files` after instantiating `BackDrops`.
---
--- INFO:
---   During the initial load of the config, this function can only invoked in `wezterm.lua`.
---   WezTerm's fs utility `glob` (used in this function) works by running on a spawned child process.
---   This throws a coroutine error if the function is invoked in outside of `wezterm.lua` in the -
---   initial load of the Terminal config.
function BackDrops:set_files(category)
   category = normalize_category(category) or normalize_category(self.category) or DEFAULT_CATEGORY
   self.category = category
   wezterm.GLOBAL.backdrop_category = category
   local backdrop_dirs = CATEGORY_DIRS[category]

   self.files = {}
   for _, dir in ipairs(backdrop_dirs) do
      local files = scan_dir(dir)
      for _, file in ipairs(files) do
         table.insert(self.files, file)
      end
   end
-- 【修改这里】注释掉下面这行，防止启动时自动加载图片
   -- wezterm.GLOBAL.background = self.files[1]
   return self
end

function BackDrops:category_choices()
   return {
      { id = 'public', label = '󰖙 Public  公开场合' },
      { id = 'private', label = '󰌾 Private 私密' },
      { id = 'like', label = 'Like 收藏轮播（含 Public / Private）' },
      { id = 'favorite', label = '收藏当前图片 → like/' },
      { id = 'delete', label = '删除当前图片 → deleted/（可恢复）' },
   }
end

---Override the default `focus_color`
---Default `focus_color` is `colors.custom.background`
---@param focus_color string background color when in focus mode
function BackDrops:set_focus(focus_color)
   self.focus_color = focus_color
   return self
end

---Override the current window options for background
---@private
---@param window any WezTerm Window see: https://wezfurlong.org/wezterm/config/lua/window/index.html
function BackDrops:_set_opt(window)
   self.focus_on = false
   local opts = {
      background = {
         {
            source = { File = wezterm.GLOBAL.background },
            horizontal_align = 'Center',
         },
         {
            source = { Color = colors.background },
            height = '120%',
            width = '120%',
            vertical_offset = '-10%',
            horizontal_offset = '-10%',
            opacity = 0.96,
         },
      },
   }
   window:set_config_overrides(opts)
end

---Override the current window options for background with focus color
---@private
---@param window any WezTerm Window see: https://wezfurlong.org/wezterm/config/lua/window/index.html
function BackDrops:_set_focus_opt(window)
   self.focus_on = true
   local opts = {
      background = {
         {
            source = { Color = self.focus_color },
            height = '120%',
            width = '120%',
            vertical_offset = '-10%',
            horizontal_offset = '-10%',
            opacity = 0.96,
         },
      },
   }
   window:set_config_overrides(opts)
end

---Convert the `files` array to a table of `InputSelector` choices
---see: https://wezfurlong.org/wezterm/config/lua/keyassignment/InputSelector.html
function BackDrops:choices()
   local choices = {}
   for idx, file in ipairs(self.files) do
      table.insert(choices, {
         id = tostring(idx),
         label = string.format('[%s] %s', category_label(self.category), file:match('([^/]+)$')),
      })
   end
   return choices
end

function BackDrops:_notify(window, title, message)
   if window.toast_notification then
      window:toast_notification('WezTerm', title .. ': ' .. message, nil, 2500)
   end
end

-- Window overrides survive config reloads; GLOBAL may already hold another image.
function BackDrops:current_image(window)
   local opts = window:get_config_overrides() or {}
   local layers = opts.background
   if layers == nil then layers = window:effective_config().background end
   for _, layer in ipairs(layers or {}) do
      if layer.source and type(layer.source.File) == 'string' then
         return layer.source.File
      end
   end
end

function BackDrops:switch_category(window, category, randomize)
   category = normalize_category(category)
   if not category then
      self:_notify(window, 'Backdrop', 'unknown category')
      return
   end

   self:set_files(category)
   self.current_idx = 1
   if #self.files == 0 then
      wezterm.GLOBAL.background = nil
      self:_set_focus_opt(window)
      self:_notify(window, 'Backdrop', category_label(category) .. ': no images')
      return
   end

   if randomize ~= false then
      self:random(window)
   elseif #self.files > 0 then
      self:set_img(window, self.current_idx)
   end

   self:_notify(window, 'Backdrop', category_label(self.category))
end

-- Move, rather than copy: one image has one location and cannot reappear in rotation.
function BackDrops:move_current(window, folder)
   if folder ~= 'like' and folder ~= 'deleted' then return end
   local source = self:current_image(window)
   if not source then
      self:_notify(window, 'Backdrop', 'No current image')
      return
   end
   local root = wezterm.config_dir .. PATH_SEP .. 'backdrops' .. PATH_SEP
   local relative = source:sub(1, #root) == root and source:sub(#root + 1) or ''
   local category = relative:match('^(public)/') or relative:match('^(private)/')
   if not category then
      self:_notify(window, 'Backdrop', 'Only Public / Private images can be moved')
      return
   end
   if relative:match('^[^/]+/like/') and folder == 'like' then
      self:_notify(window, 'Backdrop', 'Already in Like')
      return
   end
   local dir = root .. category .. PATH_SEP .. folder
   local ok = wezterm.run_child_process({ 'mkdir', '-p', dir })
   if not ok then
      self:_notify(window, 'Backdrop', 'Cannot create ' .. dir)
      return
   end
   local name = source:match('([^/]+)$')
   local destination = dir .. PATH_SEP .. name
   local index = 1
   local function exists(path)
      local link = wezterm.run_child_process({ 'test', '-L', path })
      return is_readable_file(path) or link
   end
   while exists(destination) do
      destination = dir .. PATH_SEP .. index .. '-' .. name
      index = index + 1
   end
   local is_link, target = wezterm.run_child_process({ 'readlink', source })
   local moved, err
   if is_link then
      target = target:gsub('\n$', '')
      if target:sub(1, 1) ~= '/' then
         target = source:match('^(.*)/[^/]+$') .. '/' .. target
      end
      local output
      moved, output, err = wezterm.run_child_process({ 'ln', '-s', target, destination })
      if moved then
         moved, err = os.remove(source)
         if not moved then os.remove(destination) end
      end
   else
      moved, err = os.rename(source, destination)
   end
   if not moved then
      self:_notify(window, 'Backdrop', 'Move failed: ' .. tostring(err))
      return
   end
   self:set_files(self.category)
   if folder == 'like' then
      wezterm.GLOBAL.background = destination
      for idx, file in ipairs(self.files) do
         if file == destination then self.current_idx = idx; break end
      end
      self:_set_opt(window)
   elseif #self.files > 0 then
      self:set_img(window, math.min(self.current_idx, #self.files))
   else
      wezterm.GLOBAL.background = nil
      self:_set_focus_opt(window)
   end
   self:_notify(window, 'Backdrop', folder .. '/' .. name)
end

function BackDrops:confirm_delete(window, pane)
   local source = self:current_image(window)
   if not source then return self:_notify(window, 'Backdrop', 'No current image') end
   window:perform_action(wezterm.action.InputSelector({
      title = 'Move to deleted/: ' .. source:match('([^/]+)$'),
      choices = { { id = 'cancel', label = '取消' }, { id = 'delete', label = '删除（可从 deleted/ 恢复）' } },
      action = wezterm.action_callback(function(win, _pane, choice)
         if choice == 'delete' and self:current_image(win) == source then
            self:move_current(win, 'deleted')
         end
      end),
   }), pane)
end

function BackDrops:toggle_category(window)
   local next_category = CATEGORY_ORDER[1]
   for idx, category in ipairs(CATEGORY_ORDER) do
      if self.category == category then
         next_category = CATEGORY_ORDER[idx % #CATEGORY_ORDER + 1]
         break
      end
   end
   self:switch_category(window, next_category, true)
end

---Select a random file and redefine the global `wezterm.GLOBAL.background` variable
---Pass in `Window` object to override the current window options
---@param window any? WezTerm `Window` see: https://wezfurlong.org/wezterm/config/lua/window/index.html
function BackDrops:random(window)
   if #self.files == 0 then
      self:set_files(self.category)
      if #self.files == 0 then
         return
      end
   end

   self.current_idx = math.random(#self.files)
   wezterm.GLOBAL.background = self.files[self.current_idx]

   if window ~= nil then
      self:_set_opt(window)
   end
end

---Cycle the loaded `files` and select the next background
---@param window any WezTerm `Window` see: https://wezfurlong.org/wezterm/config/lua/window/index.html
function BackDrops:cycle_forward(window)
   if #self.files == 0 then
      self:set_files(self.category)
      if #self.files == 0 then
         return
      end
   end

   if self.current_idx == #self.files then
      self.current_idx = 1
   else
      self.current_idx = self.current_idx + 1
   end
   wezterm.GLOBAL.background = self.files[self.current_idx]
   self:_set_opt(window)
end

---Cycle the loaded `files` and select the previous background
---@param window any WezTerm `Window` see: https://wezfurlong.org/wezterm/config/lua/window/index.html
function BackDrops:cycle_back(window)
   if #self.files == 0 then
      self:set_files(self.category)
      if #self.files == 0 then
         return
      end
   end

   if self.current_idx == 1 then
      self.current_idx = #self.files
   else
      self.current_idx = self.current_idx - 1
   end
   wezterm.GLOBAL.background = self.files[self.current_idx]
   self:_set_opt(window)
end

---Set a specific background from the `files` array
---@param window any WezTerm `Window` see: https://wezfurlong.org/wezterm/config/lua/window/index.html
---@param idx number index of the `files` array
function BackDrops:set_img(window, idx)
   if #self.files == 0 then
      self:set_files(self.category)
      if #self.files == 0 then
         return
      end
   end

   if idx > #self.files or idx < 1 then
      wezterm.log_error('Index out of range')
      return
   end

   self.current_idx = idx
   wezterm.GLOBAL.background = self.files[self.current_idx]
   self:_set_opt(window)
end

---Toggle the focus mode
---@param window any WezTerm `Window` see: https://wezfurlong.org/wezterm/config/lua/window/index.html
function BackDrops:toggle_focus(window)
   if self.focus_on then
      self:set_img(window, self.current_idx)
      self.focus_on = false
   else
      self:_set_focus_opt(window)
      self.focus_on = true
   end
end

function BackDrops:show_image_selector(window, pane)
   self:set_files(self.category)
   window:perform_action(
      wezterm.action.InputSelector({
         title = 'Background',
         choices = self:choices(),
         fuzzy = true,
         fuzzy_description = (wezterm.nerdfonts.md_image_filter_hdr or wezterm.nerdfonts.md_image or '󰋩')
            .. ' '
            .. category_label(self.category)
            .. ': ',
         action = wezterm.action_callback(function(selector_window, _pane, idx)
            if not idx then
               return
            end
            self:set_img(selector_window, tonumber(idx))
         end),
      }),
      pane
   )
end

function BackDrops:show_category_selector(window, pane)
   local source = self:current_image(window)
   window:perform_action(
      wezterm.action.InputSelector({
         title = 'Backdrop: ' .. (source and source:match('([^/]+)$') or 'No image'),
         choices = self:category_choices(),
         fuzzy = true,
         fuzzy_description = 'Backdrop mode: ',
         action = wezterm.action_callback(function(selector_window, _pane, category)
            if not category then
               return
            end
            if category == 'favorite' then
               self:move_current(selector_window, 'like')
               return
            elseif category == 'delete' then
               self:confirm_delete(selector_window, _pane)
               return
            end
            self:switch_category(selector_window, category, true)
         end),
      }),
      pane
   )
end

function BackDrops:setup_events()
   wezterm.on('user-var-changed', function(window, pane, name, value)
      if name == 'backdrop_mode' then
         if value == 'toggle' then
            self:toggle_category(window)
         elseif value == 'select' then
            self:show_category_selector(window, pane)
         else
            self:switch_category(window, value, true)
         end
      elseif name == 'backdrop_action' then
         if value == 'random' then
            self:random(window)
         elseif value == 'next' then
            self:cycle_forward(window)
         elseif value == 'prev' or value == 'previous' then
            self:cycle_back(window)
         elseif value == 'select' then
            self:show_image_selector(window, pane)
         elseif value == 'focus' then
            self:toggle_focus(window)
         elseif value == 'favorite' then
            self:move_current(window, 'like')
         elseif value == 'delete' then
            self:confirm_delete(window, pane)
         end
      end
   end)
   return self
end

return BackDrops:init()
