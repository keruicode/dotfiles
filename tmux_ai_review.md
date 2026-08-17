# Tmux + Codex 工作流

> 当前状态：`tmux base`、自动快照恢复、Codex 续接和 IAP 远端 tmux 重连均已在本机启用。本文是配置说明和后续决策记录，不是 B 站视频逐字稿。

## 结论

当前方案吸收 theniceboy 配置里值得保留的部分，但不照搬整套 `agent-tracker`：

- 保留 `C-s` prefix、Colemak 方向键、编号 session、快速 window/pane 操作。
- 保留好看的 pane 标题和状态栏，并与当前 WezTerm Nebula 配色一致。
- 删除 Claude、agent-tracker、opencode 和未安装 TPM 插件的耦合。
- 第一阶段 base 已稳定；当前已加入会话快照、自动恢复、Codex thread 续接和 IAP 远端 tmux 重连。
- 配置由 `/Users/xiaoxiaotu/dotfiles/tmux/` 管理，通过 GNU Stow 链接到家目录。

## 资料来源

- 视频：[同时开 10 个 AI 写代码：AI 工作流中必备软件 TMUX](https://www.bilibili.com/video/BV1ePBHBCEcE/)
- theniceboy：[.tmux.conf](https://github.com/theniceboy/.config/blob/master/.tmux.conf)
- theniceboy：[agent-tracker](https://github.com/theniceboy/.config/tree/master/agent-tracker)
- tmux：[官方 wiki](https://github.com/tmux/tmux/wiki)
- tmux-resurrect：[官方仓库](https://github.com/tmux-plugins/tmux-resurrect)
- tmux-continuum：[官方仓库](https://github.com/tmux-plugins/tmux-continuum)
- WezTerm：[Keyboard Encoding](https://wezterm.org/config/key-encoding.html)

视频公开接口没有返回字幕，因此这里只整理可核查的配置和工作流，不冒充逐句视频总结。

## 当前机器状态

已确认：

```text
tmux       3.6a
WezTerm    20240203-110809-5046fc22
Codex CLI  0.147.0
GNU Stow   已安装
fzf        已安装
starship   已安装
rainbarf   已安装
jq         已安装
```

未安装：

```text
terminal-notifier
ccusage
Claude CLI
```

你只使用 Codex，因此后续不会增加 Claude 状态、Claude hooks 或 Claude 用量模块。

session 会继续使用 `1-name`、`2-name` 的内部命名，以支持 `Ctrl+数字` 切换；底栏保留 session 段，但只显示剥离编号后的 `name`。

当前生效入口：

```text
~/.tmux.conf -> /Users/xiaoxiaotu/dotfiles/tmux/.tmux.conf
~/.config/tmux/scripts/*.sh -> /Users/xiaoxiaotu/dotfiles/tmux/.config/tmux/scripts/
```

历史文件 `~/.config/.tmux.conf`、`~/.config/tmux-conf` 和 `~/.config/config/tmux/` 仍保留，但不是当前 tmux 的加载入口。

## Ctrl+1/2/3/4 为什么失效

不是 WezTerm 主配置抢占导致的。

运行态检查显示当前 tmux 客户端是：

```text
TERM=xterm-256color
terminal features: extkeys, RGB, clipboard, focus, sixel, title, ...
```

这说明 WezTerm 与 tmux 已经协商了扩展按键。旧配置真正的问题是：

```tmux
bind -n C-1 ...
# ... 省略 C-2 到 C-9
```

“省略”只是注释，不会创建绑定。当时当前 session 又是 `1-test`，所以 `Ctrl+1` 即便成功，也没有可见变化；`Ctrl+2/3/4` 则确实没有绑定。

新配置已创建完整的九条绑定：

```text
Ctrl+1 ... Ctrl+9 -> 切换第 1 ... 9 个 session
```

若实机复测仍有某个 `Ctrl+数字` 不能到达 tmux，再在 WezTerm 中增加显式 F13-F21 转发；现在没有必要先引入这层兼容代码。

## Session、Window、Pane

tmux 的层级是：

```text
tmux server
└── session：一个项目或工作上下文
    └── window：同一项目中的任务页
        └── pane：同一页中的终端分区
```

实用理解：

- session 类似工作区，例如 `forecast`、`paper`、`dotfiles`。
- window 类似工作区中的标签页，例如 `editor`、`server`、`logs`。
- pane 是一个 window 内并排显示的 shell、Codex、Yazi 或日志。

Codex 并行工作时，优先让一个项目对应一个 session，一个独立任务对应一个 window；只有需要同时观察的内容才拆成 pane。

## Zoom 是什么

tmux zoom 是“临时让当前 pane 占满整个 window”。它是开关，不是不断放大的缩放倍率：

```text
第一次按：当前 pane 暂时铺满 window
再按一次：恢复原来的 pane 布局和尺寸
```

它不会：

- 改变 WezTerm 字号；
- 删除或暂停其他 pane；
- 改变进程状态；
- 永久改写布局。

本配置提供两个完全相同的入口：

```text
Alt+f       zoom / unzoom
C-s z       zoom / unzoom
```

zoom 时 pane 顶部会显示 `ZOOM`。Yazi 图片预览有时会在 pane 尺寸变化后重新绘制，这只是 zoom 触发了终端重排，不代表图片本身被放大。配置已启用 `allow-passthrough`，便于 Yazi 在 tmux 中传递图像协议。

IAP pane 是本地 tmux 套远端 tmux。连接脚本使用前台 OpenSSH，让 SSH 直接从本地 PTY 接收窗口尺寸变化；远端启用 `aggressive-resize`。因此在本地 tmux 内执行 `iap` 后，`Alt+f` 放大和恢复会同步改变远端 client、window、pane 和 shell 的尺寸。

`Alt+f` 是本地 tmux 快捷键。若直接在普通 WezTerm shell 中执行 `iap`，进程链里没有本地 tmux，`Alt+f` 不具备 zoom 功能；应在本地 tmux pane 中运行 `iap` 才能使用该快捷键。终端已有的窄行不会因放大而重新换行，判断当前尺寸应看新输出或执行 `stty size`。

## 第一阶段快捷键

对用户而言，逻辑 `prefix` 是 `Ctrl+s`。tmux 的内建 prefix 已设为 `None`，这样裸 `Ctrl+s` 才能先打开提示面板；面板再把下一键送入原有 `prefix` key table。下文 `C-s x` 表示先按 `Ctrl+s`，松开后再按 `x`。

直接按 `Ctrl+s` 会在右下角打开一个类似 LazyVim which-key 的快捷键面板。面板打开后再按 `c`、`z`、`U` 等键，会关闭面板并执行原来的 tmux prefix 绑定；按 `Esc` 只关闭面板。没有列在面板中的旧绑定也会原样转发。LazyVim 的 `Space c` 会继续展开 `code` 子组，而当前 tmux 快捷键只有一层，所以 `C-s c` 会直接新建 window。

### Session

| 快捷键 | 功能 |
|---|---|
| `Ctrl+1...9` | 直接切换第 1...9 个 session |
| `Alt+s` | 打开 session 选择树 |
| `C-s s` | 打开 session 选择树 |
| `Alt+Shift+s` | 从当前目录新建 session |
| `C-s Ctrl+c` | 从当前目录新建 session |
| `C-s .` | 重命名当前 session |
| `C-s l / y` | session 向左 / 向右调整编号 |
| 鼠标左键点击底栏 Session | 直接切换到对应 session |
| `Alt+a` 或 `C-s a` | 右上角打开 Codex Tasks 面板 |

session 名会维护为 `1-name`、`2-name`、`3-name`，因此 `Ctrl+数字` 的顺序稳定；编号只用于内部定位，不在底栏展示。

### Codex Tasks 面板

`Alt+a` 或 `C-s a` 会在右上角打开一个临时面板，汇总所有 tmux session 中仍存在的 Codex pane。它不依赖 Claude、opencode 或常驻 agent-tracker 服务。

```text
● 运行中    当前 Codex turn 仍在推理、执行工具或等待后台命令
✓ 已完成    最近一个 turn 已完成，Codex 正在等待下一条输入
! 待处理    Codex 正在等待批准、确认或其他用户操作
○ 就绪      Codex 进程存在，但暂时没有可识别的 turn 记录
storage    该 Codex pane 的 cwd 位于 /Volumes/storage
```

面板操作：

| 按键 | 功能 |
|---|---|
| `Ctrl+u` / `Ctrl+e` 或方向键 | 上下选择 Codex |
| `Enter` 或鼠标双击 | 关闭面板并直接跳到对应 session/window/pane |
| 输入文字 | 按 session、window 或路径过滤 |
| `Esc` | 关闭面板 |

下半部分显示所选 pane 的最近输出，便于在跳转前判断任务内容。也可在 shell 中运行 `codex-status` 查看纯文字汇总，运行 `codex-panel` 打开面板。

状态优先读取对应 thread JSONL 中的 `task_started` / `task_complete`，再用 Codex TUI 的 `Working (... esc to interrupt)` 和交互提示作实时补充。因此它能区分“Codex 进程还开着但上一轮已经做完”和“当前仍在工作”。

## 当前视觉规则

- pane 顶部标题居中显示为胶囊；focus 只改变胶囊颜色。当前 pane 与当前 session 共用浅青色，非当前 pane 使用中性深灰。
- Codex 包装进程若被 tmux 报告为 `expect`，仅在标题显示层改写为 `codex`。
- active 和 inactive pane 使用相同的中性钢灰粗边框，不让整条边框随 focus 变色。
- 底栏左侧保留所有 session 段，只显示去掉排序前缀后的名称，不拼接 `index:name`。
- 每个 session 段都带真实 session ID 的鼠标范围，可以直接点击切换。
- session 当前项使用青色块；其后的 window 只显示名称，不显示 window 索引。
- 当前 window 使用珊瑚红文字强调，不使用整块高亮背景。
- window 之间使用低对比度圆点分隔。
- 右下角保留一个与当前 session 同色的 `mbp` 尾块：左侧尖角、右侧贴边；不显示完整主机名、日期或时间。恢复或自动保存期间，仅在 `mbp` 左侧临时显示灰紫色小字 `restore` 或 `save`。
- `C-s U`、`C-s I` 和 `C-s S` 的操作结果会在 `mbp` 左侧显示约 5 秒：绿色 `OK` 表示成功，金色 `!` 表示等待处理，珊瑚红 `ERR` 表示失败。它不会进入 tmux 全屏命令输出页。
- 按 `C-s` 时，快捷键总览固定在右下角临时弹出；按下下一键执行操作后自动关闭，不改变 pane 布局和 focus。
- 状态栏可见内容保持静态；Continuum 只追加不可见的保存检查，实际快照间隔为 5 分钟。

### Window

| 快捷键 | 功能 |
|---|---|
| `Alt+1...9` | 直接切换当前 session 的 window |
| `C-s 1...9` | 切换当前 session 的 window |
| `Alt+o` | 在当前目录新建 window |
| `Alt+l / y` | 上一个 / 下一个 window |
| `C-s Ctrl+p / Ctrl+n` | 上一个 / 下一个 window |
| `C-s ,` | 重命名 window |
| `C-s W` | window 选择树 |

### Pane

Colemak 方向约定：

```text
n = left    e = down    u = up    i = right
```

| 快捷键 | 功能 |
|---|---|
| `C-s n/e/u/i` | 向左/下/上/右分割 pane |
| `Alt+n/e/u/i` | 移动 pane 焦点 |
| `Alt+N/E/U/I` | 每次 3 格调整 pane 大小 |
| `Alt+f` 或 `C-s z` | zoom / 恢复当前 pane |
| `C-s Space` | 切换到下一个布局 |
| `C-s > / <` | 交换 pane |
| `Alt+Shift+q` | 关闭当前 pane |
| `C-s x` | 确认后关闭 pane |
| `C-s Ctrl+g` | 开关同步输入 |

### Copy mode

| 快捷键 | 功能 |
|---|---|
| `Alt+v` | 进入 copy mode |
| `n/e/u/i` | 左/下/上/右移动 |
| `v` | 开始选择 |
| `Ctrl+v` | 矩形选择 |
| `y` | 复制到 tmux buffer 和 macOS 剪贴板 |
| `U / E` | 向上 / 向下滚动 5 行 |
| `Ctrl+Shift+v` | 粘贴系统剪贴板 |

### 持久化

| 快捷键 / 命令 | 功能 |
|---|---|
| `C-s S` | 生成并校验一个版本化 checkpoint |
| `C-s P` | 在新鲜 tmux server 中恢复当前选定快照 |
| `tmux-save-all` | 与 `C-s S` 相同，供 Zsh 使用 |
| `tmux-snapshots` | 列出可恢复 checkpoint 及其拓扑数量 |

Continuum 每 5 分钟保存一次，当前保存内容包括：

- session、window、pane、布局、活动项和工作目录；
- 完整的 pane scrollback，不再只保存进程与布局；
- Codex 的准确 `resume <thread-id>` 命令、Yazi、Lazygit 和 IAP 重连命令；
- 最多 90 天的 Resurrect 布局快照。

`C-s S` 还会验证当前 session/window/pane 数量与保存结果完全一致，再把布局、匹配的 scrollback 压缩包、校验和及 storage 状态复制到：

```text
~/.local/share/tmux/resurrect/checkpoints/
```

这比只依赖 `last` 稳妥：中断后产生的缩水拓扑可能成为新的自动保存 `last`，但版本化 checkpoint 不会被后续自动保存覆盖。

自动保存的 scrollback 压缩包只保留最新一份；只有手动 `C-s S` 和弹盘前 checkpoint 会把“该时刻的布局 + 匹配的 scrollback”长期绑定保存。

tmux 仍不能冻结任意程序的内存。scrollback 恢复的是可查看文本，不是可继续交互的 TUI 状态；未保存的编辑器 buffer、程序内未落盘数据和已经退出且没有恢复策略的进程不能保证恢复。Codex 能续接是因为另存了 thread ID，真正进度仍以 Codex session JSONL 和已落盘文件为准。

普通关闭 WezTerm、client detach 或网络断开不会终止仍在运行的 tmux server，此时只需：

```bash
tmux attach
```

只有 tmux server 或机器进程真正退出时才需要 Resurrect。若自动恢复结果明显缩水，不要在已有多 pane server 上直接按 `C-s P`，否则可能产生重复 session。先运行 `tmux-snapshots` 找到正确 checkpoint；只有确认当前 server 没有需保留的进程，并重新进入仅含一个 pane 的新鲜 tmux 后，才执行：

```bash
~/.config/tmux/scripts/tmux_snapshot.py prepare <checkpoint-name>
# 然后按 C-s P
```

`prepare` 在已有多个 session 或 pane 时会拒绝执行。中断前的完整布局已额外固化为 `20260814T153053-pre-interruption-full-layout`，包含 4 session、15 window、32 pane；因为当时未启用内容捕获，它只有布局和恢复命令，没有 scrollback。不要把它直接恢复到目前仍运行 Codex 的 server 上。

### 外置硬盘 SR 工作区

`4-SR` 有五个固定 pane，并会记录后来拆分出的额外 pane。固定目录来自 `storage.json`，额外 pane 的实际目录保存在运行状态中。当前配置按“进入时恢复，显式弹盘时停车”管理：

```text
进入 4-SR：所有已记录的空闲 shell 回到各自 storage 目录
聚焦 Yazi pane：该 pane 首次获得真实 client 焦点后才启动 Yazi；隐藏 pane 不并发启动
切换 session / detach：目录、Yazi、Codex 和后台任务保持原状，不自动停车
C-s U：退出可安全结束的 Yazi/空闲子 shell，所有空闲 SR shell 回到 Home
磁盘未挂载：保持 Home，进入 SR 时在底栏提示，不向不存在的路径执行 cd
磁盘已连接但未挂载：按 C-s I 自动挂载，再切入并恢复
磁盘重新插入：按 C-s I；4-SR 丢失时会按固定映射自动重建
```

| 快捷键 / 命令 | 功能 |
|---|---|
| `C-s U` | 停车、保存 eject checkpoint、检查占用并弹出 storage |
| `C-s I` | 自动挂载已连接的 storage，切入 SR，恢复固定及额外 pane 路径；Yazi 随焦点启动；无需恢复时也提示 `SR already active` |
| `storage-eject` | 与 `C-s U` 相同，供普通 Zsh 使用 |
| `storage-restore` | 与 `C-s I` 的恢复逻辑相同，供 tmux 内 Zsh 使用 |

这些操作在 tmux 内只通过底栏 `mbp` 左侧的通知报告进度和结果，不再输出到覆盖整屏的 `run-shell` view。`C-s U` 会依次显示 `parking SR panes`、`saving checkpoint`、`checking open files` 和 `releasing disk`。流程运行期间不要重复按 `U`；重复请求会显示 `operation already running`，不会再启动一份 checkpoint 或弹盘任务。

若弹盘因其他进程占用而取消，通知中显示占用进程摘要，完整 `lsof` 结果写入 `~/.local/state/tmux/storage-eject-busy.log`。各阶段耗时与返回码追加到 `~/.local/state/tmux/storage-operations.log`，用于检查“长时间没反应”的具体位置。

正确拔盘流程：

1. 用 `Alt+a` 查看带 `storage` 标记的 Codex；保存工作，并让 Codex、编辑器、下载或计算任务正常结束。
2. 按一次 `C-s U`，等待底栏阶段提示。脚本依次执行“退出可安全结束的 Yazi/空闲子 shell、所有空闲 SR pane 回 Home、生成 `storage-before-eject` checkpoint、整盘 `lsof` 检查、`diskutil eject`”。
3. 只在看到 `storage ejected` 后拔线。看到 `still busy`、`snapshot failed` 或 `eject cancelled` 时不要强拔。

不需要杀掉 `4-SR`，保留停车后的 session 才能最快恢复。若 Codex 正在 storage 目录运行，脚本会拒绝自动终止它；先记录 thread ID，正常退出 Codex 并回到 shell，再执行 `C-s U`。

重新插入后按 `C-s I`。若卷已连接但处于未挂载状态，配置会按 UUID 找到设备并挂载到 `/Volumes/storage`，然后切到 `4-SR` 并恢复路径；如果 session 已因中断消失，会先重建 `云雷达 / 云雾课题 / AOSL / ERA5` 四个 window 和五个 pane。设备未连接时只给出离线提示，不创建假的目录。

安全边界：

- 直接运行的 Yazi 会正常退出；Yazi 打开的子 shell 只有在确认它处于前台、无子进程且空闲时才会先 `exit`。对没有响应的 Yazi，仅在核实 pane 前台进程确实为 `yazi` 后发送 `TERM`。
- 空闲 shell 才会自动 `cd`。若 pane 正在运行 Codex、编辑器、下载或计算任务，会报告 `still busy`，不会终止任务，也不会伪报已经停车。
- 自动切换 session 的 hook 始终返回成功，不再在顶部显示 `external_workspace.py switch "" returned 1`。进入离线或 busy 的 SR 时只在底栏提示；需要主动弹盘时，`C-s U` 会在底栏报告具体 busy pane。
- 五个目标目录以 `external-workspaces/storage.json` 为准，不再让陈旧运行状态覆盖配置；发送给 shell 的 `cd` 也带目录存在判断，即使命令因 TUI 退出而延迟执行，也不会对已卸载路径报错。
- 配置外拆分出的 pane 会按 `window:pane-index` 保存路径及 Yazi 恢复标记；插盘后同一 pane 仍会回到原目录。
- session 切换和 client detach 永远不停车，避免打断后台 Codex，也避免反复向 Yazi pane 注入 `cd`。因此拔盘必须显式使用 `C-s U`，不能把“已离开 SR”当成“可以拔盘”。
- Yazi 启动时会查询终端能力。恢复阶段只启动真实 client 当前可见的 Yazi pane，其他 pane 等获得焦点后再启动，避免 WezTerm 的 DA/DSR 响应混入另一个 shell。
- `C-s U` 在 SR 释放后、弹盘前强制生成一份路径已回到 Home 的 checkpoint；保存或校验失败会取消弹出。
- 从停车到 `diskutil eject` 的完整流程使用互斥锁；重复按 `U`、同时执行 `storage-restore`，或弹盘期间触发 SR 自动 hook，都不会启动冲突操作。
- checkpoint 成功后还会用 `lsof` 检查整块盘。Finder、百度网盘或其他应用仍在使用硬盘时会取消弹出；底栏显示占用进程摘要，完整结果保存在 `~/.local/state/tmux/storage-eject-busy.log`。
- `lsof` 最多等待 12 秒，`diskutil eject` 最多等待 45 秒。超时或无法可靠完成占用检查时会取消弹出并明确报错，不会把检查失败当成“无人占用”。

固定路径映射保存在 `external-workspaces/storage.json`，额外 pane 路径和运行状态保存在 `~/.local/state/tmux/storage-workspace.json`。状态文件独立于 Resurrect 快照，因此即使快照记录的是停车后的 Home，重新进入 `4-SR` 仍会恢复正确的硬盘路径。

Resurrect 原版会用全宽 `display-message` 反复显示 `Restoring...`，遮住底栏中的 session/window。当前配置由 `resurrect_status_activity.sh` 接管进度显示：只在 `mbp` 左侧显示紧凑状态，任务结束后立即消失；真正的错误仍使用醒目的 tmux message。

Codex 恢复保存完整 thread ID，并用 `command codex --yolo resume <thread-id>` 绕过 shell alias，避免 `--yolo` 被重复添加。自定义前台进程策略会穿过 Yazi 和嵌套 shell，避免把正在运行的 Codex 错记为 `yazi`。

`iap` 现在连接到 IAP 登录节点上的远端 `iap` tmux session：

```bash
iap
```

SSH 每 10 秒发送一次应用层心跳，连续两次无响应后断开；任何非主动停止的 SSH 退出都会在 3 秒后重连并 attach 原远端 session，不再只处理退出码 `255`。`iap` 支持最多 20 个并行实例：第一个使用远端 session `iap`，后续依次使用 `iap-2`、`iap-3`。每个实例有独立锁、远端 tmux session、尺寸和重连循环，因此可以多开，但不会让不同大小的窗口争抢同一个远端 client。

本地 pane 顶部会分别显示 `iap`、`iap-2` 等标签；`C-s t` 优先切换当前 IAP pane 对应的远端状态栏。关闭本地 pane 会停止该实例的重连并释放槽位；远端 session 保持 detached，下一次取得同一槽位后继续 attach。若父终端异常退出，wrapper 也会自行清理，不会遗留后台 SSH。

连接不再启用 X11 forwarding，因此不会出现 `xauth key data not generated`；远端配置命令也全部静默执行。IAP 上的长期计算仍应在计算节点、调度系统或远端 tmux 中运行，不能在登录节点直接跑作业。

远端 tmux 1.8 已启用 `mode-mouse` 和 `100000` 行历史。鼠标滚轮会进入内层 copy mode 并查看历史；按 `q` 返回当前输出。若不使用鼠标，也可按远端前缀 `Ctrl+b`，再按 `[` 进入 copy mode。

远端 tmux 的默认状态栏已隐藏，不再显示 `[iap] 0:bash*`、主机名、时间和日期。本地 pane 顶部显示 `iap · 当前目录`；需要查看远端窗口时，按本地前缀 `C-s`，再按 `t`，可立即显示/隐藏仅含窗口名的精简状态栏。这个操作由本地直接向已连接的 IAP pane 发送命令，不需要输入远端的 `Ctrl+b` 前缀，也不会额外建立 SSH 连接。

## 启动时报 `no current session`

`~/.tmux.conf:<行号>: no current session` 表示配置在没有当前 session 的 tmux server 中执行了一个需要 session 目标的命令。先按报错行号检查，不要直接删除 tmux socket，也不要用 `kill-server` 规避。

本机曾由下面的错误选项作用域触发：

```tmux
# 错误：repeat-time 不是 server option
set -s repeat-time 350

# 正确：设置所有 session 的全局默认值
set -g repeat-time 350
```

当前配置已经修正。即使 server 尚无 session，整份配置也能通过检查。若以后修改配置后再次出现类似错误：

```bash
# 查看报错行及上下文
nl -ba ~/.tmux.conf | sed -n '8,20p'

# tmux 仍可进入时，修正后重新加载并检查
tmux source-file ~/.tmux.conf
tmux source-file -n ~/.tmux.conf
```

如果错误导致完全进不了 tmux，先绕过配置建立一个救援 session：

```bash
tmux -f /dev/null new-session -d -s rescue
tmux source-file ~/.tmux.conf
tmux attach -t rescue
```

`-f /dev/null` 只在启动新 server 时跳过有问题的配置，不会删除 Resurrect 快照。进入后先确认 server 是否只有这个新鲜 pane；只有没有需要保留的运行任务时，才使用 `C-s P` 恢复快照。已有多个活跃 pane 时不要重复恢复，否则会产生重复 session 和 Codex 进程。

## tmux server 停止后恢复历史 session

先区分两种情况：client 断开但 server 仍在时，只需 `tmux attach`；`tmux list-sessions` 显示 `no server running` 时，才需要 Resurrect。冷恢复步骤：

```bash
tmux
# 进入新鲜的单 pane 后按 C-s P
```

当前配置也会在新 server 的第一个真实 client attach 后自动恢复最近快照。恢复期间会暂停 session 自动重编号，把新鲜的 `1-0` 临时改回 Resurrect 需要的 `0`；恢复结束后自动恢复编号 hook，因此 `1-IAP`、`2-Config`、`3-T_WORK`、`4-SR` 不会在创建途中被改乱。

Resurrect 能恢复 session/window/pane、布局、工作目录、保存的 pane scrollback，以及白名单中的 Codex、Yazi、lazygit 和 IAP 命令。它不能恢复进程的内存状态；Codex 依靠 thread ID 重新 `resume`。若同一个 thread 正在 Codex App 中运行，CLI pane 会看到 `already has an active writer` 并回到 shell，这是写入保护，不是历史丢失；结束当前任务后在该 pane 重新执行对应的 `codex resume <thread-id>` 即可。

检查最近快照：

```bash
readlink ~/.local/share/tmux/resurrect/last
python3 ~/.config/tmux/scripts/tmux_snapshot.py list --limit 10
```

不要为了恢复删除 `/private/tmp/tmux-*` socket，也不要先运行 `tmux kill-server`。`C-s P` 只应在新鲜单 pane 中执行一次；若已有重要任务，先保存当前 checkpoint，再决定是否合并恢复。

## Dotfiles 结构

```text
dotfiles/
└── tmux/
    ├── .stow-local-ignore
    ├── .tmux.conf
    ├── Codex_resume_tmux.md
    └── .config/tmux/
        ├── external-workspaces/
        │   └── storage.json
        ├── scripts/
        │   ├── codex_dashboard.py
        │   ├── copy_to_clipboard.sh
        │   ├── external_workspace.py
        │   ├── iap_remote_status.sh
        │   ├── iap_remote_tmux.sh
        │   ├── install_persistence_plugins.sh
        │   ├── new_session.sh
        │   ├── open_codex_dashboard.sh
        │   ├── paste_from_clipboard.sh
        │   ├── resurrect_foreground_process.sh
        │   ├── resurrect_session_hooks.sh
        │   ├── resurrect_status_activity.sh
        │   ├── restore_once_attached.sh
        │   ├── tmux_notice.py
        │   ├── tmux_snapshot.py
        │   ├── tmux_which_key.py
        │   └── session_manager.py
        └── tmux-status/
            └── left.sh
```

激活方式：

```bash
cd /Users/xiaoxiaotu/dotfiles
stow -t /Users/xiaoxiaotu tmux
~/.config/tmux/scripts/install_persistence_plugins.sh
tmux source-file ~/.tmux.conf
```

插件采用官方手动安装方式，位于 `~/.config/tmux/plugins/`，不提交进 dotfiles。安装脚本会为 Codex 恢复策略和紧凑恢复状态建立受管链接；升级后也会重新应用。首次安装执行上面的脚本；升级时执行：

```bash
~/.config/tmux/scripts/install_persistence_plugins.sh --update
```

自动快照保存在 `~/.local/share/tmux/resurrect/`，版本化 checkpoint 保存在其 `checkpoints/` 子目录。`Codex_resume_tmux.md` 留在仓库的 `tmux/` 目录，并由 `.stow-local-ignore` 阻止链接到家目录根部。

本次替换前的冲突文件保存在：

```text
/Users/xiaoxiaotu/dotfiles/.tmp/tmux-base-backup-20260811-205829/
```

## 第二阶段建议

### terminal-notifier

值得安装，但应在实现 Codex 完成/等待输入通知时一起安装和验证：

```bash
brew install terminal-notifier
```

通知应带 session/window/pane 标识，并允许点击后回到对应 WezTerm 窗口；只弹“任务完成”价值不大。

### Codex 用量

不要安装旧的 `@ccusage/codex` / `ccusage-codex`。该包已经废弃，官方项目已统一为 `ccusage`：

```bash
npm install -g ccusage
ccusage codex daily
```

若以后放进状态栏，应使用 30-60 秒缓存，不能跟随 tmux 状态刷新频繁扫描 Codex 日志。

### 暂不加入

- 完整 agent-tracker：规模过大，且包含 Claude/opencode 假设。
- 第二行 AI 状态栏：先确认通知和多 Codex pane 工作流，再决定是否值得占用屏幕。

## 当前验收重点

请在不同 session 中实测：

```text
Ctrl+1
Ctrl+2
Ctrl+3
Ctrl+4
```

然后创建两个 pane，测试：

```text
Alt+n/e/u/i
Alt+N/E/U/I
Alt+f（按两次）
```

如果这些正常，第一阶段即可视为稳定基线；第二阶段再加入纯 Codex 通知和用量模块。
