-- lvim-build.recipes.cmake: a CMake project (CMakeLists.txt) — the configure / build / ctest
-- triple against a conventional `build/` tree next to the top CMakeLists.
--
---@module "lvim-build.recipes.cmake"

local context = require("lvim-build.context")

---@type LvimBuildRecipe
return {
    name = "cmake",
    kind = "project",
    markers = { "CMakeLists.txt" },
    ---@param ctx LvimBuildContext
    ---@return LvimBuildAction[]
    detect = function(ctx)
        local marker = context.marker(ctx, "CMakeLists.txt")
        if not marker then
            return {}
        end
        local cwd = vim.fs.dirname(marker)
        return {
            {
                name = "cmake configure",
                group = "Build",
                cmd = { "cmake", "-S", ".", "-B", "build" },
                cwd = cwd,
                matcher = "gcc",
            },
            {
                name = "cmake build",
                group = "Build",
                cmd = { "cmake", "--build", "build" },
                cwd = cwd,
                matcher = "gcc",
            },
            {
                name = "ctest",
                group = "Test",
                cmd = { "ctest", "--test-dir", "build", "--output-on-failure" },
                cwd = cwd,
                matcher = "gcc",
            },
        }
    end,
}
