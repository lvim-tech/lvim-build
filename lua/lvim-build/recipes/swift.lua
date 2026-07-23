-- lvim-build.recipes.swift: a Swift Package Manager project (Package.swift upward of the file/cwd) —
-- the standard SwiftPM verbs, grouped Build / Run / Test / Lint. Swift's compiler emits LLVM/clang-
-- style diagnostics (`file.swift:line:col: error: message`), so the shared `gcc` problem matcher
-- routes them to the quickfix list. When lvim-lang is installed and its Swift provider is active, the
-- `swift` binary is resolved through `lvim-lang.core.toolchain` first (honouring an explicit SDK / a
-- version manager), then PATH; lvim-build works fully without lvim-lang.
--
---@module "lvim-build.recipes.swift"

local context = require("lvim-build.context")

--- Resolve a tool ("swift" | "swiftformat"): the lvim-lang Swift toolchain when active for `root`,
--- else the bare name (found on PATH at run time by lvim-tasks).
---@param tool string
---@param root string
---@return string
local function bin(tool, root)
    local ok, tc = pcall(require, "lvim-lang.core.toolchain")
    if ok and tc and tc.resolve then
        local resolved = tc.resolve("swift", tool, root)
        if resolved and resolved ~= "" then
            return resolved
        end
    end
    return tool
end

---@type LvimBuildRecipe
return {
    name = "swift",
    kind = "project",
    markers = { "Package.swift" },
    ---@param ctx LvimBuildContext
    ---@return LvimBuildAction[]
    detect = function(ctx)
        local marker = context.marker(ctx, "Package.swift")
        if not marker then
            return {}
        end
        local cwd = vim.fs.dirname(marker)
        local swift = bin("swift", cwd)
        local function act(name, group, argv, matcher)
            return { name = name, group = group, cmd = argv, cwd = cwd, matcher = matcher }
        end
        return {
            act("swift build", "Build", { swift, "build" }, "gcc"),
            act("swift build -c release", "Build", { swift, "build", "-c", "release" }, "gcc"),
            act("swift run", "Run", { swift, "run" }, "gcc"),
            act("swift test", "Test", { swift, "test" }, "gcc"),
            act("swiftformat .", "Lint", { bin("swiftformat", cwd), "." }),
        }
    end,
}
