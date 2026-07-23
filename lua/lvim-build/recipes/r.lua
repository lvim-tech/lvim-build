-- lvim-build.recipes.r: an R package (DESCRIPTION upward of the file/cwd) — `R CMD build` / `R CMD
-- check` and the testthat suite via `Rscript -e "devtools::test()"`. When lvim-lang is installed and
-- its R provider is active, `R` is resolved through `lvim-lang.core.toolchain` first, then PATH;
-- lvim-build works fully without lvim-lang.
--
---@module "lvim-build.recipes.r"

local context = require("lvim-build.context")

--- Resolve the `R` binary: the lvim-lang R toolchain when active for `root`, else PATH.
---@param root string
---@return string
local function r_bin(root)
    local ok, tc = pcall(require, "lvim-lang.core.toolchain")
    if ok and tc and tc.resolve then
        local resolved = tc.resolve("r", "R", root)
        if resolved and resolved ~= "" then
            return resolved
        end
    end
    local p = vim.fn.exepath("R")
    return p ~= "" and p or "R"
end

---@type LvimBuildRecipe
return {
    name = "r",
    kind = "project",
    markers = { "DESCRIPTION" },
    ---@param ctx LvimBuildContext
    ---@return LvimBuildAction[]
    detect = function(ctx)
        local marker = context.marker(ctx, "DESCRIPTION")
        if not marker then
            return {}
        end
        local cwd = vim.fs.dirname(marker)
        local R = r_bin(cwd)
        -- Rscript sits beside R in the same bin dir; fall back to the PATH name.
        local rscript = R:gsub("R$", "Rscript")
        if rscript == R or vim.fn.executable(rscript) ~= 1 then
            rscript = "Rscript"
        end
        local function act(name, group, argv)
            return { name = name, group = group, cmd = argv, cwd = cwd }
        end
        return {
            act("R CMD build", "Build", { R, "CMD", "build", "." }),
            act("R CMD check", "Lint", { R, "CMD", "check", "." }),
            act("devtools::test", "Test", { rscript, "-e", "devtools::test()" }),
        }
    end,
}
