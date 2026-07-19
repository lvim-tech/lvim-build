-- lvim-build.recipes.meson: a Meson project — setup / compile / test against a conventional
-- `builddir` next to the meson.build that owns the file. The -C directory is ctx.root when a
-- meson.build sits there (the usual project top), otherwise the directory of the nearest
-- meson.build found upward.
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
        -- prefer the meson.build at ctx.root (the project top) as the -C dir; else the nearest one
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
