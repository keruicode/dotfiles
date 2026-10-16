-- Run from the repository root: lua yazi/tests/test_zoom.lua
local state, shown, emitted, convert_hook
local url_mt = {
 __eq = function(a, b)
  assert(not a.consumed and not b.consumed, "Url has been transferred")
  return a.value == b.value
 end,
}
Url = function(value)
 if type(value) == "table" then
  assert(not value.consumed, "Url has been transferred")
  value = value.value
 end
 return setmetatable({ value = value }, url_mt)
end
local area = { x = 30, y = 1, w = 60, h = 20 }
cx = { active = { current = { hovered = { url = Url("a.png") } } } }
ui = { area = function() return area end }
rt = {
 term = { cell_size = function() return 10, 20 end },
 preview = { max_width = 1600, max_height = 1600, image_quality = 90 },
}
ya = {
 sync = function(fn)
  return function(...)
   local args = table.pack(...)
   for i = 1, args.n do
    local value = args[i]
    if getmetatable(value) == url_mt then
     args[i] = Url(value)
     value.consumed = true
    end
   end
   return fn(state, table.unpack(args, 1, args.n))
  end
 end,
 clamp = function(low, value, high) return math.max(low, math.min(value, high)) end,
 image_info = function(url)
  assert(not url.consumed, "image_info received a transferred Url")
  return { w = 1200, h = 800 }
 end,
 image_show = function() shown = shown + 1 end,
 preview_widget = function() end,
 notify = function() end,
 emit = function(action, args) emitted = { action, args } end,
}
Command = function()
 return {
  arg = function(self) return self end,
  output = function()
   if convert_hook then convert_hook() end
   return { status = { success = true } }
  end,
 }
end
local plugin = dofile("yazi/.config/yazi/plugins/zoom.yazi/main.lua")
local function reset()
 state, shown, emitted, convert_hook = {}, 0, nil, nil
 area = { x = 30, y = 1, w = 60, h = 20 }
 cx.active.current.hovered.url = Url("a.png")
end
local function peek()
 plugin:peek({ file = { url = Url("a.png"), path = "a.png" }, area = area, args = {} })
end
reset()
peek()
assert(shown == 1, "current preview must render")
reset()
convert_hook = function() cx.active.current.hovered.url = Url("b.png") end
peek()
assert(shown == 0, "changed file must discard old conversion")
reset()
convert_hook = function() area = { x = 10, y = 2, w = 30, h = 10 } end
peek()
assert(shown == 0, "changed preview geometry must discard old conversion")
reset()
convert_hook = function() state.generation = state.generation + 1 end
peek()
assert(shown == 0, "superseded task must not render")
reset()
plugin:entry({ args = { "1" } })
assert(shown == 0 and emitted[1] == "peek" and emitted[2].force,
 "zoom must request a managed preview rather than draw independently")
peek()
local enlarged = state.level
plugin:entry({ args = { "-1" } })
peek()
assert(state.level < enlarged and shown == 2, "zoom out must render a smaller level")
print("zoom: 6 regression checks passed")
