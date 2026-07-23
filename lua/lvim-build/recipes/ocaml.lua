-- lvim-build.recipes.ocaml: a dune project (dune-project upward of the file/cwd) — the standard dune
-- verbs, grouped Build / Test / Format. OCaml/dune diagnostics span a location line
-- (`File "f.ml", line L, characters C-C:`) then an `Error:` / `Warning N:` body, so a literal OCaml
-- errorformat folds them into one quickfix entry. When lvim-lang is installed and its OCaml provider
-- is active, the `dune` binary is resolved through `lvim-lang.core.toolchain` first (honouring the
-- active opam switch), then PATH; lvim-build works fully without lvim-lang.
--
---@module "lvim-build.recipes.ocaml"

local context = require("lvim-build.context")

-- OCaml / dune two-line diagnostics → one quickfix entry (matches lvim-lang's OCaml matcher).
---@type string
local OCAML_EFM = table.concat({
    [[%EFile "%f"\, line %l\, characters %c-%*\d:]],
    [[%WFile "%f"\, line %l\, characters %c-%*\d:]],
    [[%ZError: %m]],
    [[%ZWarning %*\d: %m]],
    [[%C%m]],
}, ",")

--- Resolve the `dune` binary: the lvim-lang OCaml toolchain when active for `root`, else the bare
--- name (found on PATH at run time by lvim-tasks).
---@param root string
---@return string
local function dune_bin(root)
    local ok, tc = pcall(require, "lvim-lang.core.toolchain")
    if ok and tc and tc.resolve then
        local resolved = tc.resolve("ocaml", "dune", root)
        if resolved and resolved ~= "" then
            return resolved
        end
    end
    return "dune"
end

---@type LvimBuildRecipe
return {
    name = "ocaml",
    kind = "project",
    markers = { "dune-project" },
    ---@param ctx LvimBuildContext
    ---@return LvimBuildAction[]
    detect = function(ctx)
        local marker = context.marker(ctx, "dune-project")
        if not marker then
            return {}
        end
        local cwd = vim.fs.dirname(marker)
        local dune = dune_bin(cwd)
        local function act(name, group, argv)
            return { name = name, group = group, cmd = argv, cwd = cwd, matcher = OCAML_EFM }
        end
        return {
            act("dune build", "Build", { dune, "build" }),
            act("dune build --profile release", "Build", { dune, "build", "--profile", "release" }),
            act("dune test", "Test", { dune, "test" }),
            act("dune fmt", "Format", { dune, "build", "@fmt", "--auto-promote" }),
        }
    end,
}
