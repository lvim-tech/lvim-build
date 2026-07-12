-- lvim-build.context: what the detectors look AT — the current file, its filetype, and the
-- project root (the shared root canon: the nearest `.git` ancestor, else the cwd). Also the
-- marker-search helper every recipe uses (`Cargo.toml` / `Makefile` / … found UPWARD from the
-- file, falling back to the cwd), and the single-file compile cache dir.
--
---@module "lvim-build.context"

local uv = vim.uv or vim.loop

local M = {}

---@class LvimBuildContext
---@field file string  absolute path of the current buffer ("" when unnamed)
---@field ft   string  the buffer's filetype
---@field root string  project root (nearest .git ancestor of the file/cwd, else the cwd), normalized

--- The detection context for the current buffer.
---@return LvimBuildContext
function M.get()
    local file = vim.api.nvim_buf_get_name(0)
    return {
        file = file,
        ft = vim.bo.filetype,
        root = vim.fs.normalize(vim.fs.root(0, ".git") or vim.fn.getcwd()),
    }
end

--- Find the nearest of `names` UPWARD from the context's file directory (or the cwd for an
--- unnamed buffer). Returns the marker FILE's absolute path, or nil.
---@param ctx LvimBuildContext
---@param names string|string[]
---@return string?
function M.marker(ctx, names)
    local start = ctx.file ~= "" and vim.fs.dirname(ctx.file) or vim.fn.getcwd()
    local found = vim.fs.find(names, { upward = true, path = start, limit = 1 })[1]
    return found and vim.fs.normalize(found) or nil
end

--- Read a file's lines (nil when unreadable) — the tolerant input for the Makefile / justfile /
--- package.json line scanners.
---@param path string
---@return string[]?
function M.readlines(path)
    if vim.fn.filereadable(path) == 0 then
        return nil
    end
    local ok, lines = pcall(vim.fn.readfile, path)
    return ok and lines or nil
end

--- A file's mtime seconds (0 when absent) — the detect-cache stamp input.
---@param path string
---@return integer
function M.mtime(path)
    local st = uv.fs_stat(path)
    return st and st.mtime.sec or 0
end

--- The single-file compile output dir (`stdpath("cache")/lvim-build/`), created on demand.
---@return string
function M.cache_dir()
    local dir = vim.fs.normalize(vim.fn.stdpath("cache") .. "/lvim-build")
    if vim.fn.isdirectory(dir) == 0 then
        pcall(vim.fn.mkdir, dir, "p")
    end
    return dir
end

return M
