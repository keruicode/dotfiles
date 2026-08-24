# xiaoxiaotu's dotfiles

[中文说明](./README_cn.md)

Personal macOS terminal and editor configuration, managed as GNU Stow packages.
The setup is centered on WezTerm, tmux, Codex, Neovim/LazyVim, Yazi, and zsh,
with Colemak-oriented navigation where it improves daily use.

## Packages

| Package | Target | Purpose |
| --- | --- | --- |
| `wezterm` | `~/.config/wezterm` | Terminal UI, tabs, panes, GPU rendering, and local backdrops |
| `tmux` | `~/.tmux.conf`, `~/.config/tmux` | Persistent sessions, Codex dashboard, IAP reconnect, and recovery |
| `nvim` | `~/.config/nvim` | LazyVim, LaTeX/VimTeX, Skim integration, and scientific editing |
| `yazi` | `~/.config/yazi` | File manager, previews, themes, and image zoom |
| `zsh` | `~/.config/zsh` | Shared aliases and terminal color environment |
| `codex` | `~/.codex/AGENTS.md` | Global Codex workflow and scientific coding rules |

Detailed guides live in [tmux/README.md](./tmux/README.md),
[nvim/.config/nvim/README.md](./nvim/.config/nvim/README.md), and
[yazi/.config/yazi/README.md](./yazi/.config/yazi/README.md).

## Deploy

Install the main tools on macOS:

```bash
brew install stow tmux neovim yazi lazygit starship
brew install --cask wezterm
```

Clone the repository and link the selected packages into your home directory:

```bash
git clone git@github.com:keruicode/dotfiles.git ~/dotfiles
cd ~/dotfiles
stow codex nvim tmux wezterm yazi zsh
```

`stow` is safe to run again after adding files. If an unmanaged file already
occupies a target path, inspect it before using `stow --adopt`; that option moves
the target file into this repository.

## WezTerm

The active config is modular: `wezterm.lua` composes settings from `config/`,
UI events from `events/`, and reusable helpers from `utils/`. It uses the Nebula
palette, WebGPU/Metal, a JetBrains Mono and LXGW WenKai Mono fallback stack,
large scrollback, compact path-aware tab capsules, and Colemak-friendly movement.

### Main shortcuts

| Shortcut | Action |
| --- | --- |
| `Cmd+t` / `Shift+Cmd+D` | Open / close a tab |
| `Cmd+n` / `Cmd+i` | Previous / next tab |
| `Cmd+1` ... `Cmd+9` | Jump to a tab |
| `Cmd+\\` / `Shift+Cmd+\\` | Split vertically / horizontally |
| `Shift+Cmd+u/e/n/i` | Focus pane up/down/left/right |
| `Cmd+w` | Close the active pane |
| `F1` / `F2` / `F3` | Copy mode / command palette / launcher |
| `Ctrl+Cmd+Space`, then `f` | Font resize table (`k`, `j`, `r`) |
| `Ctrl+Cmd+Space`, then `p` | Pane resize table (`h`, `j`, `k`, `l`) |

### Backdrops

Backdrop files are deliberately not committed. Put public-safe images in
`~/.config/wezterm/backdrops/public/` and personal images in
`~/.config/wezterm/backdrops/private/`. PNG, JPEG, and other supported images
may be regular files or symlinks; the repository only keeps both directories.

| Shortcut | Action |
| --- | --- |
| `Cmd+/` | Random image |
| `Cmd+,` / `Cmd+.` | Previous / next image |
| `Ctrl+Cmd+/` | Search images in the current category |
| `Ctrl+Cmd+b` | Toggle public/private category |
| `Shift+Ctrl+Cmd+b` | Choose a category |
| `Cmd+b` | Toggle image/focus background |

The same controls are available from shells through `wezbg`, for example
`wezbg public`, `wezbg private`, `wezbg random`, and `wezbg focus`.

Machine-specific SSH domains belong in
`~/.config/wezterm/config/domains_local.lua`. Start from
[domains_local.example.lua](./wezterm/.config/wezterm/config/domains_local.example.lua);
the local file is ignored so hostnames, usernames, and key paths are not uploaded.

## Terminal workflow

- Start or attach tmux with `tmux`; the prefix is `Ctrl+s`.
- Use `C-s ?` for the tmux shortcut panel and `C-s T` for Codex task status.
- Run `ra` for Yazi and `lg` for Lazygit. Both preserve true color inside tmux.
- Use `nvim` for LazyVim. VimTeX opens compiled PDFs in Skim and keeps source/PDF
  synchronization available for LaTeX projects.
- Run `iap` from a real interactive terminal pane for the reconnecting remote tmux
  workflow. VPN and recovery details are documented in the tmux guide.

## Local-only data

The repository ignores `.tmp/`, background images, private WezTerm domains,
credentials, generated caches, and the legacy `Codex_resume.md`. The active
`Codex_resume_*.md` handoff remains versioned so interrupted Codex work can be
continued with the exact thread ID and local session log.

## Credits

The WezTerm modules retain the MIT license from
[KevinSilvester/wezterm-config](https://github.com/KevinSilvester/wezterm-config).
The bilingual repository layout follows the practical structure used by
[theniceboy/.config](https://github.com/theniceboy/.config). Yazi flavors and
plugins keep their own upstream licenses in their respective directories.
