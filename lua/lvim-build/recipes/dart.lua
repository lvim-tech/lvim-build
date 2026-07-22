-- lvim-build.recipes.dart: a Dart / Flutter project (pubspec.yaml upward of the file/cwd).
-- Offers the right verbs for the project TYPE — `flutter` when pubspec declares the Flutter SDK,
-- else plain `dart` — grouped Build / Run / Test / Lint. When lvim-lang is installed and its Dart
-- provider is active, the `flutter` / `dart` binary is resolved through `lvim-lang.core.toolchain`
-- first (honouring FVM / an explicit SDK), then PATH; lvim-build works fully without lvim-lang.
--
---@module "lvim-build.recipes.dart"

local context = require("lvim-build.context")

--- Whether a pubspec declares Flutter (the flutter SDK dependency / a `flutter:` section).
---@param pubspec string  absolute path to pubspec.yaml
---@return boolean
local function is_flutter(pubspec)
    local lines = context.readlines(pubspec)
    if not lines then
        return false
    end
    local content = table.concat(lines, "\n")
    return content:match("\n%s*flutter%s*:") ~= nil or content:match("sdk%s*:%s*flutter") ~= nil
end

--- Resolve `tool` ("flutter" | "dart"): the lvim-lang Dart toolchain when active for `root`, else the
--- bare name (found on PATH at run time by lvim-tasks).
---@param tool string
---@param root string
---@return string
local function bin(tool, root)
    local ok, tc = pcall(require, "lvim-lang.core.toolchain")
    if ok and tc and tc.resolve then
        local resolved = tc.resolve("dart", tool, root)
        if resolved and resolved ~= "" then
            return resolved
        end
    end
    return tool
end

---@type LvimBuildRecipe
return {
    name = "dart",
    kind = "project",
    markers = { "pubspec.yaml" },
    ---@param ctx LvimBuildContext
    ---@return LvimBuildAction[]
    detect = function(ctx)
        local marker = context.marker(ctx, "pubspec.yaml")
        if not marker then
            return {}
        end
        local cwd = vim.fs.dirname(marker)
        local function act(name, group, argv)
            return { name = name, group = group, cmd = argv, cwd = cwd }
        end

        if is_flutter(marker) then
            local flutter = bin("flutter", cwd)
            return {
                act("flutter run", "Run", { flutter, "run" }),
                act("flutter test", "Test", { flutter, "test" }),
                act("flutter pub get", "Build", { flutter, "pub", "get" }),
                act("flutter build apk", "Build", { flutter, "build", "apk" }),
                act("flutter build web", "Build", { flutter, "build", "web" }),
                act("flutter analyze", "Lint", { flutter, "analyze" }),
            }
        end

        local dart = bin("dart", cwd)
        return {
            act("dart run", "Run", { dart, "run" }),
            act("dart test", "Test", { dart, "test" }),
            act("dart pub get", "Build", { dart, "pub", "get" }),
            act("dart analyze", "Lint", { dart, "analyze" }),
        }
    end,
}
