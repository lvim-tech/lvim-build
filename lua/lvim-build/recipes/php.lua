-- lvim-build.recipes.php: a PHP / Composer project (composer.json upward of the file/cwd).
-- Offers Run / Test / Lint verbs: run the current file with the CLI runtime and the built-in web
-- server; test via `composer test` when composer.json declares that script, else the project's
-- `vendor/bin/phpunit`; lint via php-cs-fixer and phpstan. When lvim-lang is installed and its PHP
-- provider is active, each binary (php / phpunit / php-cs-fixer / phpstan) is resolved through
-- `lvim-lang.core.toolchain` first (honouring a version manager / project-local vendor bin), then
-- PATH; lvim-build works fully without lvim-lang.
--
---@module "lvim-build.recipes.php"

local context = require("lvim-build.context")

--- Resolve a tool through the lvim-lang PHP toolchain when active for `root`, else the bare name
--- (found on PATH at run time by lvim-tasks).
---@param tool string   the toolchain tool key ("php" | "phpunit" | "php-cs-fixer" | "phpstan")
---@param root string
---@return string
local function bin(tool, root)
    local ok, tc = pcall(require, "lvim-lang.core.toolchain")
    if ok and tc and tc.resolve then
        local resolved = tc.resolve("php", tool, root)
        if resolved and resolved ~= "" then
            return resolved
        end
    end
    return tool
end

--- Whether composer.json (at `path`) declares a `scripts.test` entry.
---@param path string  absolute path to composer.json
---@return boolean
local function has_composer_test(path)
    local lines = context.readlines(path)
    if not lines then
        return false
    end
    local ok, data = pcall(vim.json.decode, table.concat(lines, "\n"))
    return ok and type(data) == "table" and type(data.scripts) == "table" and data.scripts.test ~= nil
end

---@type LvimBuildRecipe
return {
    name = "php",
    kind = "project",
    markers = { "composer.json" },
    ---@param ctx LvimBuildContext
    ---@return LvimBuildAction[]
    detect = function(ctx)
        local marker = context.marker(ctx, "composer.json")
        if not marker then
            return {}
        end
        local cwd = vim.fs.dirname(marker)
        local function act(name, group, argv)
            return { name = name, group = group, cmd = argv, cwd = cwd, matcher = "generic" }
        end

        local php = bin("php", cwd)
        local out = {}

        -- Run: the current file (when the buffer is a .php file) + the built-in web server.
        if ctx.file ~= "" and ctx.ft == "php" then
            out[#out + 1] = act("php " .. vim.fs.basename(ctx.file), "Run", { php, ctx.file })
        end
        out[#out + 1] = act("php -S localhost:8000", "Run", { php, "-S", "localhost:8000" })

        -- Test: prefer the composer `test` script, else the project-local phpunit.
        if has_composer_test(marker) then
            out[#out + 1] = act("composer test", "Test", { bin("composer", cwd), "test" })
        else
            local phpunit = vim.fs.joinpath(cwd, "vendor", "bin", "phpunit")
            if vim.fn.filereadable(phpunit) == 1 then
                out[#out + 1] = act("vendor/bin/phpunit", "Test", { phpunit })
            else
                out[#out + 1] = act("phpunit", "Test", { bin("phpunit", cwd) })
            end
        end

        -- Lint: code-style fixing + static analysis.
        out[#out + 1] = act("php-cs-fixer fix", "Lint", { bin("php-cs-fixer", cwd), "fix" })
        out[#out + 1] = act("phpstan analyse", "Lint", { bin("phpstan", cwd), "analyse", "--no-progress" })

        return out
    end,
}
