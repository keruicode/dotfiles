local wezterm = require('wezterm')
local gpu_adapters = require('utils.gpu_adapter')
local colors = require('colors.custom')

return {
   term = "xterm-256color",
   animation_fps = 60,
   max_fps = 60,
   front_end = 'WebGpu',
   webgpu_power_preference = 'HighPerformance',
   webgpu_preferred_adapter = gpu_adapters:pick_best(),

   -- color scheme
   colors = colors,

   -- background 使用全局变量 wezterm.GLOBAL.background 作为文件路径，可以动态加载背景图片
   background = {
      -- 启动时会加载图片
      --{
      --   source = { File = wezterm.GLOBAL.background },
      --   horizontal_align = 'Center',
      --},
      -- Color 选用 colors.background 设置的颜色作为背景色。
      {
         source = { Color = colors.background },
         -- 将背景的尺寸调整为窗口大小的 120%，让背景稍微超过窗口边界，避免边缘留白。
         height = '120%',
         width = '120%',
         -- 使背景向左上角偏移，确保图片和纯色背景的超出部分均匀分布。
         vertical_offset = '-10%',
         horizontal_offset = '-10%',
         opacity = 0.98,
      },
   },

   -- scrollbar 开启滚动条，方便在较长输出内容中滚动查看。
   enable_scroll_bar = true,

   -- tab bar
   enable_tab_bar = true, -- 启用标签栏，方便在多个标签页之间切换。
   hide_tab_bar_if_only_one_tab = true, -- 当仅有一个标签时自动隐藏标签栏，让界面更加简洁。
   use_fancy_tab_bar = false, -- 使用自绘标签栏，避免原生标签外框和自定义标题叠加造成顶部拥挤。
   tab_max_width = 38,  -- 给当前目录保留空间，同时避免单个标签过度拉长。
   -- tab_bar_at_bottom = true,               -- 将标签栏放在窗口底部
   -- tab_bar_edge = "bottom",                -- 设置标签栏的位置
   show_tab_index_in_tab_bar = false,  -- 自绘标签已经足够紧凑，不再显示额外编号。
   switch_to_last_active_tab_when_closing_tab = true,

   -- command palette / launcher
   command_palette_bg_color = '#242633',
   command_palette_fg_color = '#f8eaff',
   command_palette_font_size = 14,
   command_palette_rows = 18,

   -- window 设置窗口四周的边距。这里左右边距为 0，上边距为 10，下边距为 7.5，使窗口内容离顶部和底部略有空隙。
   window_padding = {
      left = 0,
      right = 0,
      top = 10,
      bottom = 7.5,
   },
   window_close_confirmation = 'NeverPrompt',  -- 关闭窗口时不显示确认提示，直接关闭，提高操作流畅性。
   window_decorations = "RESIZE", -- Hide the title bar, keep the resizable border
   adjust_window_size_when_changing_font_size = false,
   window_frame = {
      font = wezterm.font ({ family = 'JetBrains Mono', weight = 'DemiBold' }), -- 标题栏字体类型
      font_size = 15.0, --标题栏字体大小
      active_titlebar_bg = '#282a36',  -- 设置活动窗口的标题栏背景颜色为
      inactive_titlebar_bg = '#282a36', -- 设置非活动窗口的标题栏背景颜色
      -- font = fonts.font,
      -- font_size = fonts.font_size,
   },
   -- inactive_pane_hsb = {
   --    saturation = 0.9,
   --    brightness = 0.65,
   -- },
   -- 保持非活动窗格的饱和度和亮度不变，使得窗口切换时没有显著的亮度或色彩变化。如果你希望非活动窗格稍微暗一些，可以调整
   inactive_pane_hsb = {
      saturation = 1,
      brightness = 1,
   },
}
