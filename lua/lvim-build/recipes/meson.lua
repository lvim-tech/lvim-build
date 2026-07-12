-- lvim-build.recipes.meson: a Meson project — setup / compile / test against a conventional
-- `builddir` next to the meson.build that owns the file. (A subdirectory's meson.build is a
-- fragment of the same project; the nearest one upward still resolves to a usable -C dir only at
-- the top, so the marker search prefers the HIGHEST meson.build with a sibling
-- meson_options.txt / .git, falling back to the nearest.)
--
---@module "lvim-build.recipes.meson"

local context = require("lvim-build.context")

---@type LvimBuildRecipe
return {
    name = "meson",
    kind = "project",
    markers = { "meson.build" },
    ---@param ctx LvimBuildContext
    ---@return LvimBuildAction[]
    detect = function(ctx)
        local marker = context.marker(ctx, "meson.build")
        if not marker then
            return {}
        end
        -- climb: the project TOP is the meson.build at ctx.root (or the highest ancestor found)
        local top = ctx.root .. "/meson.build"
        local cwd = vim.fn.filereadable(top) == 1 and ctx.root or vim.fs.dirname(marker)
        return {
            {
                name = "meson setup",
                group = "Build",
                cmd = { "meson", "setup", "builddir" },
                cwd = cwd,
                matcher = "gcc",
            },
            {
                name = "meson compile",
                group = "Build",
                cmd = { "meson", "compile", "-C", "builddir" },
                cwd = cwd,
                matcher = "gcc",
            },
            {
                name = "meson test",
                group = "Test",
                cmd = { "meson", "test", "-C", "builddir" },
                cwd = cwd,
                matcher = "gcc",
            },
        }
    end,
}
