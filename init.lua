--[[
-- TODO: Support for git dependency:
--  * New dependency properties such as `checkout`, `args`, etc.
-- TODO: Support for snippet (single file) dependency.
-- TODO: Prefer to separate specification of null dependency into a file (possibly `null.lua`).
-- TODO: Make modules have directory namespace and add option to also have modules without namespace.
-- TODO: Try detect Nelua files and add found paths to `config.add_path` if `.neluacfg.lua` isn't found.
--]]

---@class NeluaConfig
---@field debug boolean?
---@field sanitize boolean?
---@field release boolean?
---@field maximum_performance boolean?
---@field strip_bin boolean?
---@field timing boolean?
---@field more_timing boolean?
---@field verbose boolean?
---@field no_warning boolean?
---@field no_cache boolean?
---@field no_color boolean?
---@field runner string?
---@field output string?
---@field define string[]?
---@field pragma string[]?
---@field pragmas {string:any}?
---@field add_path string[]?
---@field cc string?
---@field cflags string?
---@field ldflags string?
---@field stripflags string?
---@field cache_dir string?
---@field path string?

---@class NullDependency
---@field url string? URL from which source the tarball should be downloaded
---@field hash string? SHA-256 checksum of the tarball
---@field path string? Local path to source, prioritized over `url` if exist.

---@class NullSpec : NeluaConfig
---@field name string
---@field version string
---@field dependencies {string:NullDependency}

local console = require('nelua.utils.console')
local executor = require('nelua.utils.executor')
local fs = require('nelua.utils.fs')
local lfs = require('lfs')
local platform = require('nelua.utils.platform')
local stringer = require('nelua.utils.stringer')
local tabler   = require('nelua.utils.tabler')
local types = require('nelua.thirdparty.tableshape').types
local inspect = require('nelua.thirdparty.inspect')

local colors = console.colors
local cachedir = fs.join(fs.getusercachepath('nelua'), 'null')
local tarball_cachedir = fs.join(cachedir, 'tarballs')

-- forward declaration
local module

---@param ... string
local function err(...)
    console.logex(io.stderr, colors.error, '[null] ' .. colors.reset .. table.concat({ ... }, ' '))
end

---@param ... string
local function warn(...)
    console.logex(io.stderr, colors.warn, '[null] ' .. colors.reset .. table.concat({ ... }, ' '))
end

---@param ... string
local function info(...)
    console.logex(io.stdout, colors.cyan .. colors.bright, '[null] ' .. colors.reset .. table.concat({ ... }, ' '))
end

---@param name string
---@param ... string
local function err_dep(name, ...)
    err(colors.cyan .. name .. ':' .. colors.reset, ...)
end

---@param name string
---@param ... string
local function warn_dep(name, ...)
    warn(colors.cyan .. name .. ':' .. colors.reset, ...)
end

---@param name string
---@param ... string
local function info_dep(name, ...)
    info(colors.cyan .. name .. ':' .. colors.reset, ...)
end

---@param file string
---@param n integer?
---@return integer
local function get_nth_strip(file, n)
    n = n or 0
    local _, _, stdout =
        executor.execex('tar', { '-atf', file, '--show-transformed-names', '--strip-components=' .. n })
    stdout = stdout or '/'
    if stdout:sub(1, 1) == '/' then
        return n
    else
        return get_nth_strip(file, n + 1)
    end
end

---@param path string
local function recursively_rm(path)
    if fs.isdir(path) then
        for name in lfs.dir(path) do
            recursively_rm(fs.join(path, name))
        end
        local _, merr = lfs.rmdir(path)
        if merr then
            err("can't delete directory: " .. merr)
        end
    else
        local _, merr = fs.deletefile(path)
        if merr then
            err("can't delete file: " .. merr)
        end
    end
end

---@param tmpfile string
---@param tmpdir string?
local function clean_up(tmpfile, tmpdir)
    local _, merr = fs.deletefile(tmpfile)
    if merr then
        err("can't delete file: " .. merr)
    end
    if tmpdir then
        recursively_rm(tmpdir)
    end
end

---@param file string
---@param hash string
---@return boolean
---@return string
local function check_sha256sum(file, hash)
    local _, _, file_hash = executor.execex('sha256sum', { file })
    file_hash = file_hash or '_'
    file_hash = stringer.split(file_hash)[1]
    return file_hash == hash, file_hash
end

---@param t string[]
local function absolute_all(t)
    for i, v in pairs(t) do
        t[i] = fs.abspath(v)
    end
end

---@param cmd string
---@return boolean
local function has_command(cmd)
    local found = not not fs.findbinfile(cmd)
    if not found then
        err("command not found: '" .. cmd .. "'")
    end
    return found
end

---@param name string?
---@param config NeluaConfig|NullSpec
---@return boolean
local function validate_prop(name, config)
    local function err_(...)
        return name and err_dep(name, ...) or err(...)
    end

    local spec_shape = types.shape({
        name = types.string,
        version = types.string,
        dependencies = types.shape({}, {
            extra_fields = types.map_of(types.string, types.shape{
                path = (types.string * types.custom(function(val)
                    if not fs.isdir(val) then
                        return nil, "'"..val.."' isn't a directory"
                    end
                    return true
                end)):is_optional(),
                url = types.string:is_optional(),
                hash = types.string:is_optional()
            })
        })
    }, {
        extra_fields = types.map_of(types.string, types.any),
    })

    local ok, merr = spec_shape(config)

    if not ok and merr then
        err_(merr)
        return false
    end

    for k, v in pairs(config.dependencies) do
        if types.shape {} (v) then
            err_("spec dependency '"..k.."' is empty")
            return false
        end
    end

    return true
end

---@param name string
---@param config NeluaConfig|NullSpec
---@param depdir string
local function setup_dir(name, config, depdir)
    os.rename(depdir, fs.join(cachedir, name, config.version))
    local current_dir = fs.join(cachedir, name, 'current')
    if lfs.attributes(current_dir, 'mode') ~= 'link' then
        os.remove(current_dir)
    end
    lfs.link(fs.join(cachedir, name, config.version), fs.join(cachedir, name, 'current'), true)
end

---@param name string
---@param url string
---@param hash string
---@return boolean|NeluaConfig|NullSpec
---@return integer?
local function tarball_dep_require(name, url, hash)
    local depdir = fs.join(cachedir, name, 'current')
    local exist = lfs.attributes(fs.join(cachedir, name, 'current'), 'mode')
    if not exist or (exist and not exist ~= 'link') then
        fs.makepath(tarball_cachedir)

        info("installing dependency '" .. name .. "'")
        info_dep(name, "downloading '" .. url .. "'")
        local tmpfile = fs.join(tarball_cachedir, fs.basename(os.tmpname()))
        local success, code = executor.exec('curl', { '-fSL', '--progress-bar', '-o', tmpfile, url })

        if not success then
            err_dep(name, 'curl failed with exit code ' .. code)
            clean_up(tmpfile)
            return false, 2
        end

        info_dep(name, 'verifying tarball checksum')
        local match, file_hash = check_sha256sum(tmpfile, hash)
        if not match then
            err_dep(name, "provided hash '" .. hash .. "' does not match with tarball checksum '" .. file_hash .. "'")
            clean_up(tmpfile)
            return false, 2
        end

        local strip_n = get_nth_strip(tmpfile)
        depdir = fs.join(cachedir, name, 'temp')
        fs.makepath(depdir)

        info_dep(name, 'extracting tarball')
        success, code = executor.exec('tar', { '-axf', tmpfile, '--strip-components=' .. strip_n, '-C', depdir })
        if not success then
            err_dep(name, 'tar failed with exit code ' .. code)
            clean_up(tmpfile, depdir)
            return false, 2
        end

        os.remove(tmpfile)
    end

    local olddir = fs.curdir()
    lfs.chdir(depdir)

    local config, spec
    if not fs.isfile('./.neluacfg.lua') then
        warn_dep(name, 'cannot find neluacfg.lua')
        config = {}
        spec = { name = name, version = 'unknown', dependencies = {} }
    else
        local neluacfg = fs.readfile('./.neluacfg.lua')
        ---@cast neluacfg string
        local fn = assert(load(neluacfg, '@[null].'..name))
        config, spec = fn()
        config, spec = config or {}, spec or { name = name, version = 'unknown', dependencies = {} }
    end

    lfs.chdir(olddir)

    if not validate_prop(name, spec) then
        return false, 2
    end

    setup_dir(name, spec, depdir)

    lfs.chdir(fs.join(cachedir, name, spec.version))
    if config.add_path then
        absolute_all(config.add_path)
    end
    lfs.chdir(olddir)

    info('dependency', spec.name, 'version', spec.version, 'is loaded')
    return config
end

---@param name string
---@param path string
---@return boolean|NeluaConfig|NullSpec
---@return integer?
local function local_dep_require(name, path)
    if not fs.isdir(path) then
        err_dep(name, "'" .. path .. "' isn't a directory")
        return false, 1
    end

    local olddir = fs.curdir()
    lfs.chdir(path)

    local config, spec
    if not fs.isfile('./.neluacfg.lua') then
        warn_dep(name, 'cannot find neluacfg.lua')
        config = {}
        spec = { name = name, version = 'unknown', dependencies = {} }
    else
        local neluacfg = fs.readfile('./.neluacfg.lua')
        ---@cast neluacfg string
        local fn = assert(load(neluacfg, '@[null].'..name))
        config, spec = fn()
        config, spec = config or {}, spec or { name = name, version = 'unknown', dependencies = {} }
    end

    if config.add_path then
        absolute_all(config.add_path)
    end

    lfs.chdir(olddir)

    if not validate_prop(name, spec) then
        return false, 2
    end

    info('dependency', spec.name, 'version', spec.version, 'is loaded')
    return config
end

---@param spec NeluaConfig|NullSpec
---@return NeluaConfig
local function strip_spec(spec)
    spec.name = nil
    spec.version = nil
    spec.dependencies = nil
    return spec
end

---@param spec NullSpec
---@return NeluaConfig
---@return NullSpec?
function module(spec)
    if platform.is_windows then
        err('Windows platform is currently unsupported')
        return strip_spec(spec)
    end

    if not (has_command('curl') and has_command('sha256sum') and has_command('tar')) then
        return strip_spec(spec)
    end

    if not validate_prop(nil, spec) then
        return strip_spec(spec)
    end

    for name, depspec in pairs(spec.dependencies) do
        local config, lvl
        if depspec.path and fs.isdir(depspec.path) then
            config, lvl = local_dep_require(name, depspec.path)
        else
            config, lvl = tarball_dep_require(name, depspec.url, depspec.hash)
        end

        if not config and lvl > 1 then
            err('failed to install dependencies')
            return strip_spec(spec)
        end

        if config.add_path then
            spec.add_path = spec.add_path or {}
            tabler.insertvalues(spec.add_path, config.add_path)
        end
    end

    return strip_spec(tabler.copy(spec)), spec
end

return module
