# 全局 Codex 说明

## 最终答复分组保存（适用于所有对话）

- 每轮最终答复保存到所属项目`tmp/`下，以清晰任务组命名固定Markdown文件；
  多个并行工作组分别维护，不混入一个总文件，也不按每个新对话重复建文件。
- 具体分组及文件名遵循项目AGENTS.md；没有既定分组时使用准确的任务名。
- 最新最终答复插在文件标题之后、所有旧答复之前；新内容始终置顶，历史内容向下保留。
  只保存最终答复及必要公式，不写入工具日志或过程更新；不能仅更新顶部摘要而把新答复追加末尾。
  这条置顶规则仅适用于 `tmp/` 中的最终答复分组文件；`Codex_resume_*.md` 的新记录按后文规则追加到文末。
- 默认只保存文件，不自动启动、激活或切换 Typora，不打开 Finder，不批量打开多个任务组文件。
  仅当本轮答复含大量公式、确需渲染阅读时，才自动打开本轮所属的一个 Markdown 文件并定位顶部；
  普通进度、表格、少量行内公式不触发。已有同一文件窗口时优先复用，避免重复打开。
  用户明确要求打开指定文件时按当次要求执行。
- 以上针对最终答复分组文件的置顶与按需打开规则自2026-09-12起适用于所有项目和新旧对话，替代旧的“末尾追加”
  和“每轮打开Typora”约定；遇到项目或续接文件中的旧约定，更新冲突条款，不沿用旧规则。
- 以上覆盖此前“根目录单一最终答复文件”的默认约定。仍必须维护项目续接Markdown，
  让后续对话直接接手，不能用最终答复替代工作交接。

## DOCX 兼容性

- 不直接交付手工修改 OOXML 后的 DOCX；压缩包可解压不等于 Word 兼容。
- 除非明确需要，移除域代码、`w:updateFields` 和外部关系，并保证绘图对象 ID 唯一。
- 交付前必须用 Microsoft Word 打开、保存、关闭并重新打开，确认无修复或更新域提示；随后渲染并检查全部页面。

## 图表字体

科学和气象图中，英文文字与数字使用 `Times New Roman`，中文使用 `Songti SC`（宋体）。Matplotlib 的中英混排字体回退顺序设为先 `Times New Roman`、后 `Songti SC`；不得把覆盖范围很广的 Unicode 字体或无衬线字体放在这两者之前。

## 科学图规范

论文或演示文稿级科学图遵循以下统一规范：

- 可用时显式注册字体文件：`/System/Library/Fonts/Supplemental/Times New Roman.ttf`、`Times New Roman Bold.ttf` 和 `Songti.ttc`。
- 将 Matplotlib 字体回退设为 `["Times New Roman", "Songti SC"]`；轴标签、刻度标签、图例、分图字母和标题默认使用粗体。
- 使用清晰易读的大字号：轴标签 `22 pt`、刻度标签 `18 pt`、子图标题 `20 pt`、图标题 `28 pt`、图例 `16-18 pt`、分图字母 `(a)`、`(b)` 为 `24 pt`。
- 使用粗轴：所有边框线 `3 pt`；主刻度线宽 `3 pt`、长度 `8 pt`；次刻度线宽 `2 pt`、长度 `4 pt`；刻度朝内，除非图形本身不适合，否则上方和右方也应显示刻度。
- 使用粗数据标记：主曲线 `4 pt`，拟合曲线或参考曲线 `3.5 pt`；避免 Matplotlib 默认的细线。
- 优先使用干净的白色背景。除非图形需要精确读数，否则不要使用浅色网格线；如必须使用，网格应保持次要视觉地位。
- 轴标签必须明确、无歧义，例如使用 `Branch length, l (mm)`，而不是只写 `l (mm)`。
- 论文图的 PNG 保存为 `dpi >= 400`；矢量输出设置 `pdf.fonttype = 42`、`ps.fonttype = 42`。
- 重绘后至少目视检查一张代表性图片，确认尺寸、字体和刻度没有被裁切。

## 强制续接交接规则

每个 Codex 工作线程都必须维护一份续接 Markdown，以便用户在网络中断后恢复，或启动新的 Codex 进程继续完全相同的工作。

必须遵守：

1. 每次对话开始时，在当前工作目录搜索 `Codex_resume_*.md`。如存在，找到最近更新的文件，读取后在同一文件中继续记录本次工作；不要在该目录新增另一份续接文件。
2. 仅当当前工作目录不存在 `Codex_resume_*.md` 时，才可在本次工作会话最终回复前创建新文件。
3. 文件开头必须适合在终端运行默认的 `head Codex*.md`：第 10 行必须是无缩进的
   `codex resume <thread-id>`，让它成为 `head` 输出的最后一行，便于在 tmux 中复制。
   用户使用本地 `code` 别名时，第 9 行写同一 ID 的 `code resume <thread-id>`；
   没有该别名时，第 9 行留空。
   头部固定为第 1 行标题、第 2 行空行、第 3 行线程 ID、第 4 行空行、
   第 5 行会话日志路径、第 6 行工作目录、第 7 行空行、第 8 行 `` ```bash ``、
   第 9 行 `code resume`、第 10 行 `codex resume`、第 11 行 `` ``` ``；
   随后才写 `## 当前状态` 等正文。每次更新续接文件时，把本轮新状态和结果追加到
   文件末尾，按时间顺序保留旧记录；不要置顶、插在头部之后或改写顶部摘要。
   前 11 行续接入口保持固定，尤其不得移动第 10 行的 `codex resume`。

4. 记录线程 ID、`/Users/xiaoxiaotu/.codex/sessions/` 下的会话日志路径、工作目录、重要改动文件、验证命令及结果、当前状态、已知问题和下一步建议。
5. 若在写入交接记录前发生硬性网络或进程中断，无法事后保证已记录；一旦对话恢复，应先找到最新适用的续接 Markdown 并更新它。
6. 项目细节写在项目的续接 Markdown 中；本全局文件仅保留可长期复用的工作规则，不添加项目专属例外。

## 目录、命名与报告交付

- 优先使用浅层、密集、可直接浏览的目录。一个独立试验应直接位于其工作根，例如
  `WRF_LEAF_YYYYMMDD/`，不要无必要地再套 `runs/experiment_name/`、`output/pdf/`、
  `results/figures/` 等纯分类层；只有确有多次可独立复跑的子试验时才增加一层。
- 目录名默认使用准确、简洁的英文 ASCII 名称，优先采用小写 `snake_case`；已有
  专业缩写、项目约定或第三方固定目录名按其规范保留。中文含义写在 README 或说明中，
  不以中文目录名或额外中文入口代替清晰的英文命名。
- 脚本、数据及图件的文件名仍按项目既定规范命名；Python import 模块、Fortran module
  和第三方工具要求的固定文件名使用兼容的 ASCII 名称。报告标题与正文语言不受此规则限制。
- 现有目录不因本规则自动批量重命名。确需迁移时，先检查依赖并同步更新路径引用；
  正在运行或排队的作业继续使用原兼容路径，待结束后再迁移，绝不因改名破坏作业。
- LaTeX 报告以可编辑源为中心：`.tex`、同名 `.pdf`、必要的 `.bib` 与图件放在同一
  试验/论文目录；禁止为了“归类”把最终 PDF 再放进 `output/pdf/`。图件可放在同级
  `figures/`，但仅在确有多张图时使用。
- 创建目录前先展示或检查目标目录树；避免仅因日期或格式不同复制整个已有树。目录
  名必须说明方法和个例/日期，不能使用 `new`、`final`、`output` 这类无语义名称。

## IAP SSH 恢复

当用户报告 IAP SSH 中断时，将 IAP 视为通向 `10.64.201.2:22` 的 Earthlab/Tunnelblick VPN 路径，而不是 `iaplacs.xyz` 网站。

1. 修改 SSH 设置前，先检查 `route -n get 10.64.201.2`（接口应为 `utun*`）以及 `nc -G 5 -vz 10.64.201.2 22`。
2. 若任一检查失败，运行 `python3 -B "/Users/xiaoxiaotu/Library/Application Support/Übersicht/widgets/keep_online/earthlab_vpn_control.py" connect offsite`；仅当连接 `colemak`/`colemak-5G` 或 IP 为 `192.168.5.*` 时，改用 `connect campus`。
3. 在真实的交互式 Terminal/iTerm TTY 中运行 `iap` 连接。不要从 widget、Codex 非交互 shell 或后台自动化中启动它；`/dev/tty: Device not configured` 表示启动器没有 TTY，并不代表 VPN 已断开。
4. `/opt/homebrew/bin/iap` 指向 `~/.config/tmux/scripts/iap_remote_tmux.sh`，它会分配独立的远程 tmux 会话，并每三秒自动重试中断的 SSH。单独出现的 `[detached]` 是 tmux 事件；在判定为 VPN 断开前，先确认路由或端口确实失败。
5. 如果路由和端口正常但 `iap` 仍退出，运行 `bash -n ~/.config/tmux/scripts/iap_remote_tmux.sh`，检查当前进程和会话状态；修复时保留其按实例加锁与重连循环。
6. Tunnelblick 提示无法查询公网 IP 只是辅助检查警告。检查 OpenVPN 状态/日志：`CONNECTED` 加上可用 IAP 端口说明 VPN 可用；`WAIT`/`RECONNECTING` 且出现 `TLS key negotiation failed` 才说明 VPN 本身失败。
7. 对反复出现的 UDP `1194` TLS 超时，确认 Heysocks 处于 `customize` 而非 `global`，并确认 OpenVPN/Tunnelblick 流量为 `DIRECT`。获得用户确认后，可临时停止 Heysocks 或关闭其 TUN 并重连 Earthlab；若仍超时，测试另一张物理网络。若此前可用的手机热点上同一完整 IAP 地址池仍超时，则按 IAP/Earthlab 服务端故障处理，停止继续修改本地设置。



## 学习者档案提炼

- 面向用户提供较完整的技术教程前，先阅读
  `~/.codex/skills/learingmyself/references/learner-profile.md`，再决定讲解深度。除非正确性或安全性需要，否则省略标记为 `熟悉` 的主题。
- 当用户调用 `@learingmyself` 或 `$learingmyself`，或明确说明自己了解、不懂或不再需要解释的内容时，使用 `learingmyself` skill 更新基于证据的档案。记录必须针对具体任务；不得推断用户的智力、人格、教育经历或广泛掌握程度。
- 项目指令、数值验证、安全检查和用户当前请求，始终优先于由该档案推断出的简略程度。

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
