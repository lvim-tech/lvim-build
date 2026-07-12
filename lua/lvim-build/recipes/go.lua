-- lvim-build.recipes.go: a Go module (go.mod) — build/run/test/vet over `./...`, parsed with the
-- go problem matcher.
--
---@module "lvim-build.recipes.go"

local context = require("lvim-build.context")

---@type LvimBuildRecipe
return {
    name = "go",
    kind = "project",
    markers = { "go.mod" },
    ---@param ctx LvimBuildContext
    ---@return LvimBuildAction[]
    detect = function(ctx)
        local marker = context.marker(ctx, "go.mod")
        if not marker then
            return {}
        end
        local cwd = vim.fs.dirname(marker)
        local function act(name, group, argv)
            return { name = name, group = group, cmd = argv, cwd = cwd, matcher = "go" }
        end
        return {
            act("go build ./...", "Build", { "go", "build", "./..." }),
            act("go run .", "Run", { "go", "run", "." }),
            act("go test ./...", "Test", { "go", "test", "./..." }),
            act("go vet ./...", "Lint", { "go", "vet", "./..." }),
        }
    end,
}
