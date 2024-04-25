local lfs = require("lfs")
local fs = require("nelua.utils.fs")
local executor = require("nelua.utils.executor")
local logger = require("null.logger")
local utils = require("null.utils")
local spec = require("null.spec")
local exception = require("null.exception")
local easyhttp  = require("easyhttp")

local cachedir = fs.join(fs.getusercachepath('nelua'), 'null')
local tarball_cachedir = fs.join(cachedir, 'tarballs')

local dep_handler = {}

---@param tmpfile string
---@param tmpdir string?
local function clean_up(tmpfile, tmpdir)
    local _, merr = fs.deletefile(tmpfile)
    if merr then
        logger.err("can't delete file: " .. merr)
    end
    if tmpdir then
        utils.recursively_rm(tmpdir)
    end
end

---@param name string
---@param config NeluaConfig|NullSpec
---@param depdir string
local function setup_dir(name, config, depdir)
    os.rename(depdir, fs.join(cachedir, name, config.version))
    lfs.link(fs.join(cachedir, name, config.version), fs.join(cachedir, name, 'current'), true)
end

---@param name string
---@param url string
---@param hash string
---@return boolean|NeluaConfig|NullSpec
---@return integer?
function dep_handler.url(name, url, hash)
    local depdir = fs.join(cachedir, name, 'current')


    local tmpfile = assert(io.open(fs.join(tarball_cachedir, fs.basename(os.tmpname())), "w+b"))
    local ok, code, headers = easyhttp.request(url, {
        timeout = 10,
        output_file = tmpfile,
        on_progress = function(total, current)
        
        end
    })

    local olddir = fs.curdir()
    lfs.chdir(depdir)

    local config, spec
    if not fs.isfile('./.neluacfg.lua') then
        logger.warn_dep(name, 'cannot find neluacfg.lua')
        config = {}
        spec = { name = name, version = 'unknown', dependencies = {} }
    else
        local neluacfg = fs.readfile('./.neluacfg.lua')
        ---@cast neluacfg string
        local fn = assert(load(neluacfg, '@[null].' .. name))
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

    return config
end

---@param name string
---@param path string
---@return string[]?
function dep_handler.path(name, path)
    local olddir = fs.curdir()

    local depspec
    if fs.isfile(path) then
        local content = fs.readfile(path) or ""
        depspec = spec.parse(content, name)
        if not depspec then
            return
        end
    elseif fs.isdir(path) then
        lfs.chdir(path)
        local content = fs.readfile(".neluacfg.lua")
        if not content then
            logger.warn_dep(name, "'"..path.."' does not contain neluacfg")
            return
        end
        lfs.chdir(olddir)
    else
        logger.err_dep(name, "'"..path.."' is neither a file or directory")
        error({ exit = true })
    end

    spec.lint(depspec)
    return depspec.paths
end

return dep_handler
