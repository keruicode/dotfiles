# Global Codex Notes

## DOCX 兼容性

- 不直接交付手工修改 OOXML 后的 DOCX；压缩包可解压不等于 Word 兼容。
- 除非明确需要，移除域代码、`w:updateFields` 和外部关系，并保证绘图对象 ID 唯一。
- 交付前必须用 Microsoft Word 打开、保存、关闭并重新打开，确认无修复或更新域提示；随后渲染并检查全部页面。

## Figure Typography

For scientific and meteorological figures, use `Times New Roman` for English text and numerals, and `Songti SC` (宋体) for Chinese text. Configure mixed-language Matplotlib text with the font fallback order `Times New Roman`, then `Songti SC`; do not put a broad Unicode or sans-serif font ahead of these two.

## Scientific Figure Style

Use this house style for manuscript or presentation-ready scientific plots:

- Register font files explicitly when available: `/System/Library/Fonts/Supplemental/Times New Roman.ttf`, `Times New Roman Bold.ttf`, and `Songti.ttc`.
- Set Matplotlib font fallback as `["Times New Roman", "Songti SC"]`; use bold text by default for labels, tick labels, legends, panel letters, and titles.
- Use large readable type: axis labels `22 pt`, tick labels `18 pt`, subplot titles `20 pt`, figure titles `28 pt`, legends `16-18 pt`, and panel letters `(a)`, `(b)` at `24 pt`.
- Use heavy axes: all spines `3 pt`; major ticks width `3 pt`, length `8 pt`; minor ticks width `2 pt`, length `4 pt`; ticks point inward and should be visible on top/right unless a plot-specific reason prevents it.
- Use heavy data marks: primary curves `4 pt`, fitted or reference curves `3.5 pt`; avoid thin default Matplotlib lines.
- Prefer clean white backgrounds. Do not use light grid lines unless the plot requires quantitative reading; if grids are used, keep them visually secondary.
- Axis labels must be explicit and unambiguous, for example `Branch length, l (mm)` instead of only `l (mm)`.
- Save manuscript figures at `dpi >= 400` for PNG and set `pdf.fonttype = 42`, `ps.fonttype = 42` for vector outputs.
- After regenerating figures, visually inspect at least one representative image and verify dimensions/fonts/ticks are not clipped.

## Mandatory Resume Handoff Policy

For every Codex work thread, maintain a resume markdown so the user can recover after a network interruption or start a fresh Codex process and resume the exact work.

Required behavior:

1. At the start of every conversation, search the current working directory for `Codex_resume_*.md` files. If any exist, identify the most recently updated file, read it, and continue updating that same file for the current work. Do not create an additional resume file in that directory.
2. Only when no `Codex_resume_*.md` file exists in the current working directory may a new one be created before the final response of a work session.
3. Include the exact resume command:

   ```bash
   codex resume <thread-id>
   ```

   If the user uses a local `code` alias, include the same ID as:

   ```bash
   code resume <thread-id>
   ```

4. Include the thread ID, session log path under `/Users/xiaoxiaotu/.codex/sessions/`, working directory, important changed files, verification commands/results, current status, known pitfalls, and next recommended actions.
5. If a hard network/process interruption happens before the assistant can write the handoff, it cannot be guaranteed retroactively. As soon as the conversation resumes, find the latest applicable resume markdown and refresh it first.
6. Keep project-specific details in the project resume markdown. Keep this global file as a durable workflow rule only; do not add project-specific exceptions here.

## IAP SSH Recovery

When the user reports an IAP SSH interruption, treat IAP as the Earthlab/Tunnelblick VPN path to `10.64.201.2:22`, not the `iaplacs.xyz` website.

1. Check `route -n get 10.64.201.2` (the interface should be `utun*`) and `nc -G 5 -vz 10.64.201.2 22` before changing SSH settings.
2. If either check fails, run `python3 -B "/Users/xiaoxiaotu/Library/Application Support/Übersicht/widgets/keep_online/earthlab_vpn_control.py" connect offsite`; use `connect campus` instead only on `colemak`/`colemak-5G` or `192.168.5.*`.
3. Connect by running `iap` in a real interactive Terminal/iTerm TTY. Do not launch it from a widget, Codex noninteractive shell, or background automation; `/dev/tty: Device not configured` means the launcher lacks a TTY, not that the VPN is down.
4. `/opt/homebrew/bin/iap` points to `~/.config/tmux/scripts/iap_remote_tmux.sh`, which assigns separate remote tmux sessions and automatically retries interrupted SSH every three seconds. A lone `[detached]` is a tmux event; confirm route/port failure before diagnosing it as VPN loss.
5. If the route and port are healthy but `iap` still exits, run `bash -n ~/.config/tmux/scripts/iap_remote_tmux.sh`, inspect its current process/session state, and preserve its per-instance locking and reconnect loop when repairing it.
6. A Tunnelblick alert about failing to query the public IP is only an auxiliary-check warning. Inspect the OpenVPN state/log: `CONNECTED` plus a working IAP port means the VPN is usable; `WAIT`/`RECONNECTING` with `TLS key negotiation failed` means the VPN itself failed.
7. For repeated UDP `1194` TLS timeouts, verify Heysocks is in `customize`, not `global`, and that OpenVPN/Tunnelblick traffic is `DIRECT`. With user confirmation, temporarily stop Heysocks or disable its TUN and reconnect Earthlab; if the timeout remains, test another physical network. If the same full IAP address pool times out on a previously working phone hotspot, treat it as an IAP/Earthlab server-side outage and stop changing local settings.



## Fortran

### 实例模板

- 新建或重构 Fortran 前，先阅读
  `~/.codex/scripts/fortran_templates/gmcore/parallel_types_mod.F90` 和同目录的
  `SOURCE.md`。以它们作为模块布局、默认私有 API、派生类型、类型绑定过程、
  `intent` 和纯查询函数的实例参考。
- 模板只用于结构和书写方式参考，不构成项目依赖；除非目标程序确有需要，不复制
  MPI 符号、GMCORE 领域类型或命名。项目级 `AGENTS.md`、数值行为保持、科学验证
  和隔离试验要求优先。

### 结构与接口

- 使用现代自由格式 Fortran。新源码使用小写 `.f90`；仅需要预处理时用 `.F90`。
- 一个职责一个模块，模块名以 `_mod` 结尾。模块默认 `private`，显式列出
  `public` API。
- 主程序保持很薄，只负责 CLI/配置、初始化、调用和退出；物理公式、数值算法和
  文件 I/O 分属不同模块。
- 所有作用域使用 `implicit none`；所有过程参数声明 `intent`。
- 相关状态和配置使用派生类型；可用类型绑定过程管理初始化、验证和清理。
- 可无副作用的计算过程声明为 `pure`。禁止用全局可变变量隐式传递模型状态。

### 精度、命名与单位

- 使用 `iso_fortran_env` 的 `real64`/`int32`，在单一 kinds 模块定义工作精度；
  禁止在新生产代码中使用 `real*8`、裸 `real(8)` 或重复的
  `selected_real_kind`。
- 所有实数字面量带 kind 后缀；`pi` 和物理常量只定义一次。
- 变量、过程和模块使用小写 `snake_case`。避免无上下文的单字母接口。
- 对外变量名或元数据标明单位；内部同一物理量只允许一种单位，转换集中在边界。
- 每个经验式注明来源、方程、单位、适用范围和必要的数值保护。

### 数值安全与 I/O

- 根求解、插值、除法、幂、指数、时间推进和数组索引必须检查有效域、有限值、
  括区间、收敛和迭代上限。
- 对零尺寸、近零分母、负质量、越界温度和不可物理解给出明确错误，不静默裁剪；
  若物理上必须裁剪，记录理由和诊断量。
- 使用 `open(newunit=..., iostat=..., iomsg=...)`，检查 read/write/close 状态；
  禁止固定 unit 号和无信息的 `stop`。
- 路径来自参数或配置，不依赖当前工作目录，不写死用户 Home 或远端路径。
- 生产文件中不保留大段注释掉的旧实现；旧公式存入 Git 历史或只读 `legacy/`。

### 构建、格式与测试

- 使用 target 级 CMake 配置；源码、app、test、data、output 和 build 分离。
- Fortran 缩进 2 空格，建议行宽 100；按物理项换行，不依赖无限行长选项阅读。
- 严格检查至少包括 `-std=f2018 -Wall -Wextra -Wconversion-extra
  -Wimplicit-interface -Wsurprising`。
- Debug 测试启用 `-fcheck=all -ffpe-trap=invalid,zero,overflow -fbacktrace`。
- 修复错误时增加能复现该错误的测试。行为保持型重构先通过原始数值回归；科学
  修改使用新的试验 ID、输出目录和基线，不覆盖旧结果。

## Python

### 格式与模块边界

- 目标 Python 3.11+；4 空格缩进，禁止 tab。使用 Black 默认 88 字符，并以
  Flake8 或 Ruff 作为静态门禁。
- import 按标准库、第三方、本项目分组；显式导入，禁止 `import *` 和运行时修改
  `sys.path`。
- 库模块导入时不得解析参数、打开数据、运行计算或生成文件。
- CLI 提供 `build_parser()`、`main(argv=None) -> int`，并使用
  `if __name__ == "__main__": raise SystemExit(main())`。
- 公共函数/类写类型标注；复杂科学数组的 docstring 写明维度、单位和返回语义。
- 计算、I/O、绘图和命令行编排分层。重复逻辑提取到模块，脚本入口保持简短。

### 路径、进程与异常

- 使用 `pathlib.Path`；输入/输出路径显式传入，禁止写死用户绝对路径或依赖当前
  工作目录。
- 外部命令优先 `subprocess.run([...], check=True, text=True)`；禁止
  `os.system()`。仅确实需要 shell 语法时允许 `shell=True`，并解释原因、限制输入。
- 捕获具体异常并补充上下文，禁止裸 `except` 和无说明地屏蔽 warning。
- 文本 I/O 使用上下文管理器和显式编码。权威 JSON/CSV/配置采用临时文件加原子
  替换，失败不得遗留半文件。
- 日志使用 `logging`；库函数不得随意 `print` 或直接 `exit()`。

### 科学数据和绘图

- 读入后检查列、shape、dtype、单位、排序、重复坐标、范围和有限值。
- NumPy/xarray 明确 axis/dim；防止共享 view 意外修改源数据。NetCDF/xarray
  使用上下文管理或明确 `close()`，需脱离文件时先 `load()`。
- 插值、外推、平滑和随机过程必须声明边界行为；随机过程固定并记录 seed。
- 输出记录代码版本、配置和输入哈希；同一物理量只使用一种内部单位。
- 绘图函数接收 `Axes`/数据/配置并返回对象；CLI 负责保存与关闭。库函数中不调用
  `plt.show()`。
- 科学图使用 Times New Roman、中文 Songti SC 回退、粗轴/粗曲线、明确轴名、
  白底；PNG 至少 400 dpi，PDF/PS 字体类型 42。生成后目视检查代表图的字体、
  尺寸、图例和裁切。

### 测试与交付

- 使用 pytest 覆盖正常、边界和失败路径。数值回归检查列、行数、有限值、容差和
  关键物理不变量；图形测试检查尺寸、格式和代表渲染，不只检查文件存在。
- 交付前运行 `python3 -m py_compile`、Black check、Flake8/Ruff 和 pytest。
- 冻结历史源码先保留哈希，不自动格式化；新生产代码必须通过全部门禁。
