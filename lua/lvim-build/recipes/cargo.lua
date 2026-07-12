-- lvim-build.recipes.cargo: a Rust cargo project (Cargo.toml upward of the file/cwd) — the
-- standard cargo verbs, all parsed with the rustc problem matcher.
--
---@module "lvim-build.recipes.cargo"

local context = require("lvim-build.context")

---@type LvimBuildRecipe
return {
    name = "cargo",
    kind = "project",
    markers = { "Cargo.toml" },
    ---@param ctx LvimBuildContext
    ---@return LvimBuildAction[]
    detect = function(ctx)
        local marker = context.marker(ctx, "Cargo.toml")
        if not marker then
            return {}
        end
        local cwd = vim.fs.dirname(marker)
        local function act(name, group, argv)
            return { name = name, group = group, cmd = argv, cwd = cwd, matcher = "rust" }
        end
        return {
            act("cargo build", "Build", { "cargo", "build" }),
            act("cargo build --release", "Build", { "cargo", "build", "--release" }),
            act("cargo run", "Run", { "cargo", "run" }),
            act("cargo test", "Test", { "cargo", "test" }),
            act("cargo bench", "Bench", { "cargo", "bench" }),
            act("cargo clippy", "Lint", { "cargo", "clippy" }),
        }
    end,
}
