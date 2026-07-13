# lvim-build

"Just compile/run/test THIS." lvim-build auto-detects what the current file or project is —
cargo, make, cmake, npm/pnpm/yarn/bun scripts, go, just, meson, gradle, maven, pyproject, or a
single c/c++/rust/python/lua/shell file — and offers every applicable action in ONE chooser,
grouped **Build / Run / Test / Bench / Lint** and ordered by **frecency** (the action you always
run floats to the top). Selecting an action executes it through
[lvim-tasks](https://github.com/lvim-tech/lvim-tasks) (a hard dependency: build detects and
DESCRIBES; tasks RUNS and displays — output panel, spinner, restart and problem-matcher →
quickfix all inherited), and remembers the choice so `:LvimBuild redo` re-runs it instantly with
no UI.

- **Detectors** ("recipes") — project-level, root-marker driven: `cargo` (Cargo.toml), `make`
  (one action per Makefile TARGET, tolerantly scanned), `cmake` (configure/build/ctest), `node`
  (one action per package.json script, run with the package manager the lockfile identifies),
  `go` (build/run/test/vet), `just` (one action per recipe), `meson` (setup/compile/test),
  `gradle` (wrapper-aware), `maven`, `python` (pyproject / setup.py / requirements.txt / Pipfile /
  tox.ini / noxfile.py / Django's manage.py — pytest, tox, nox, ruff, mypy, black, flake8, the
  build/sync/install actions, `manage.py runserver`; each command resolved through the project's
  own **virtualenv**, else its package manager (`uv` / `poetry` / `pipenv` / `hatch`), else the
  PATH — and offered ONLY when it actually resolves). And single-file fallbacks when no project
  marker owns the buffer: gcc / g++ / rustc compile (into
  `stdpath("cache")/lvim-build/`) and compile-and-run, `python <file>` (the project's interpreter
  when there is one — this one is offered inside a project too), `nvim -l <file>` for
  Lua, and shebang-aware shell run + `-n` syntax check.
- **Chooser** (`:LvimBuild`) — one collapsible section per group (each in its own accent), the
  current file's filetype icon on every action's lead box, the command preview dimmed after the
  name. The cursor opens on the project's most recent action. Detection is cached per project
  root and invalidated by marker mtime — retyping `:LvimBuild` re-parses nothing until a
  Makefile/package.json/… actually changes.
- **Frecency + redo** — every run is recorded (per project root) in the plugin's own SQLite
  usage store; usage count + recency order each group, `:LvimBuild redo` re-runs the most recent
  action (re-DETECTED, never replayed stale), `:LvimBuild last` just shows it in the statusline
  overlay. Without sqlite.lua the memory degrades to session-only (redo still works within the
  session; `:checkhealth` warns).
- **Problem matchers** — every built-in action carries the right lvim-tasks matcher (`rust`,
  `gcc`, `go`, `python`, `lua`, `generic`), so compile errors land in the quickfix list,
  clickable.
- Pre-run save: `save = "current" | "all" | false`.

## Requirements

- Neovim >= 0.11
- [lvim-tasks](https://github.com/lvim-tech/lvim-tasks) — **required**: the execution backend
- [lvim-utils](https://github.com/lvim-tech/lvim-utils) (palette / merge / store / icons)
- [lvim-ui](https://github.com/lvim-tech/lvim-ui) (the chooser)
- Optional: [sqlite.lua](https://github.com/kkharji/sqlite.lua) for the durable frecency/redo
  memory, [lvim-icons](https://github.com/lvim-tech/lvim-icons) for the filetype icons

## Installation

### lvim-installer (recommended)

Install and manage it from the LVIM package manager — open the **Plugins** tab and install /
update / pin it:

```vim
:LvimInstaller plugins
```

lvim-installer installs plugins through Neovim's built-in `vim.pack`, so no external plugin
manager is needed.

### Native (vim.pack)

```lua
vim.pack.add({
    { src = "https://github.com/lvim-tech/lvim-utils" },
    { src = "https://github.com/lvim-tech/lvim-ui" },
    { src = "https://github.com/lvim-tech/lvim-tasks" },
    { src = "https://github.com/lvim-tech/lvim-build" },
})
require("lvim-tasks").setup({})
require("lvim-build").setup({})
```

## Usage

```vim
:LvimBuild            " the chooser — every detected action, grouped + frecency-ordered
:LvimBuild redo       " re-run this project's most recent action, no UI (the daily driver)
:LvimBuild last       " show (not run) the redo target in the statusline overlay
:LvimBuild Test       " chooser restricted to one group (Build/Run/Test/Bench/Lint)
:LvimBuild bottom     " a layout token (float|area|bottom) anywhere in the args;
                      " a per-command layout is sticky for the session
```

Chooser keys: `j`/`k` move, `<CR>` on a section header folds it, `<CR>` on an action runs it,
`q`/`<Esc>` close.

### Custom recipes

A recipe is data + one `detect(ctx) → actions` function. `ctx` is
`{ file, ft, root }`; each action is
`{ name, group, cmd (argv or string), cwd, env?, matcher? }`. `kind = "project"` recipes are
cached per root (declare `markers` — their mtimes invalidate the cache; add an optional
`watch(ctx) -> string` when the actions depend on state the markers do not describe — the Python
recipe watches the virtualenv and lockfiles, so `uv sync` refreshes the chooser at once);
`kind = "file"` recipes
run fresh per buffer and are gated by `single_file`.

```lua
require("lvim-build").setup({
    recipes = {
        zig = {
            kind = "project",
            markers = { "build.zig" },
            detect = function(ctx)
                local marker = require("lvim-build.context").marker(ctx, "build.zig")
                if not marker then
                    return {}
                end
                local cwd = vim.fs.dirname(marker)
                return {
                    { name = "zig build", group = "Build", cmd = { "zig", "build" }, cwd = cwd },
                    {
                        name = "zig build test",
                        group = "Test",
                        cmd = { "zig", "build", "test" },
                        cwd = cwd,
                    },
                }
            end,
        },
    },
})
```

A user recipe with a built-in's name (`cargo`, `make`, …) replaces that built-in.

## Setup

The full default configuration (every option at its default):

```lua
require("lvim-build").setup({
    -- Where the action chooser opens (a quick modal pick — float by default). A layout token on
    -- the command (`:LvimBuild bottom`) overrides it for the session.
    layout = "float",
    -- Chooser border/overlay title and its alignment.
    title = "Build",
    title_pos = "left",
    -- Write before running: "current" updates the current buffer, "all" runs :wall, false skips.
    save = "current",
    -- Offer the single-file fallbacks (compile/run THIS buffer via gcc/g++/rustc/python/nvim -l/
    -- bash) when no project marker owns the file.
    single_file = true,
    -- Extra user detectors, merged over the built-ins by name (same recipe shape — see above).
    recipes = {},
    -- The group order in the chooser (groups a detection did not produce are skipped).
    order = { "Build", "Run", "Test", "Bench", "Lint" },
    -- Group accents: lvim-utils palette keys (track the live theme) or literal "#rrggbb".
    colors = {
        Build = "blue",
        Run = "green",
        Test = "yellow",
        Bench = "magenta",
        Lint = "cyan",
    },
    -- Chooser glyphs (single-width Nerd Font; the fold carets come from the shared section canon).
    icons = {
        build = "󰏗", -- the chooser / overlay lead glyph
        action = "󰐊", -- fallback lead glyph for an action row without a filetype icon
        expand_open = "", -- section caret, expanded
        expand_closed = "", -- section caret, collapsed
    },
})
```

## Persistence

The usage memory lives in the plugin's OWN database — `stdpath("data")/lvim-build/lvim-build.db`
(SQLite via the shared `lvim-utils.store` wrapper, versioned schema). One row per (project root,
action): count + last-used. Delete the file to reset the frecency; nothing else is touched.
Single-file compile outputs go to `stdpath("cache")/lvim-build/`.

## Highlights

Self-themed from the lvim-utils palette (re-derived on ColorScheme / palette sync); accents come
from `colors` above. Groups: `LvimBuild<Group>Badge` + `LvimBuild<Group>Name` per configured
group (e.g. `LvimBuildBuildBadge`, `LvimBuildTestName`), `LvimBuildText`, `LvimBuildDim`,
`LvimBuildEmpty`. The section headers use the shared fold-header accents.

## Health

```vim
:checkhealth lvim-build
```

Reports the lvim-tasks presence (required), lvim-ui / lvim-utils, the sqlite usage store
(warn-only), which toolchains are on PATH, what the current context detects, and validates the
config.

## License

BSD 3-Clause — see [LICENSE](LICENSE).
