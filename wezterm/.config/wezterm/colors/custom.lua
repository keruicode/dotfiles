local nebula = {
   foreground = '#f8f8f2',
   background = '#282a36',
   cursor_bg = '#ffc2e5',
   cursor_border = '#9be7ff',
   cursor_fg = '#282a36',
   selection_bg = '#4a3d59',
   selection_fg = '#fff7fb',

   ansi = {
      '#2a2e38', -- black
      '#ff7fbd', -- red
      '#9be7c3', -- green
      '#ffd27d', -- yellow
      '#8ec8ff', -- blue
      '#d7a5ff', -- magenta
      '#88e5f2', -- cyan
      '#f0fdff', -- white
   },

   brights = {
      '#71798a', -- bright black
      '#ff9ad1', -- bright red
      '#b6f6d1', -- bright green
      '#ffe3a3', -- bright yellow
      '#acd8ff', -- bright blue
      '#e7c1ff', -- bright magenta
      '#aaf3fa', -- bright cyan
      '#ffffff', -- bright white
   },

   tab_bar = {
      background = '#282a36',
      active_tab = {
         bg_color = '#282a36',
         fg_color = '#fff2fb',
      },
      inactive_tab = {
         bg_color = '#282a36',
         fg_color = '#c79ab9',
      },
      inactive_tab_hover = {
         bg_color = '#282a36',
         fg_color = '#ffc2e5',
      },
      new_tab = {
         bg_color = '#282a36',
         fg_color = '#9be7ff',
      },
      new_tab_hover = {
         bg_color = '#282a36',
         fg_color = '#ffd7f1',
         italic = false,
      },
   },

   visual_bell = '#5a405d',
   scrollbar_thumb = '#4f5368',
   split = '#456a78',
   compose_cursor = '#ffc2e5',
}

return nebula
