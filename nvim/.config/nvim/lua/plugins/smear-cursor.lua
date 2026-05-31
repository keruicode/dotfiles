return {
  {
    "sphamba/smear-cursor.nvim",
    opts = {
      -- 官方 "Faster smear" 配置
      stiffness = 0.8, -- 默认 0.6
      trailing_stiffness = 0.6, -- 默认 0.45
      stiffness_insert_mode = 0.7, -- 默认 0.5
      trailing_stiffness_insert_mode = 0.7, -- 默认 0.5
      damping = 0.95, -- 默认 0.85
      damping_insert_mode = 0.95, -- 默认 0.9
      distance_stop_animating = 0.5, -- 默认 0.1
    },
  },
}
