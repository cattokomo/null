---@class NullDependency
---@field url string? URL from which source the tarball should be downloaded
---@field hash string? SHA-256 checksum of the tarball
---@field path string? Local path to source, prioritized over `url` if exist.

---@class NullSpec
---@field name string
---@field version string
---@field dependencies {string:NullDependency}
---@field paths string[]

---@alias spec.DependencyType
---| "tarball"
---| "git"
---| "snippet"
---| "local"

local logger = require("null.logger")
local fs = require("nelua.utils.fs")
local types = require("nelua.thirdparty.tableshape").types

---@param name string?
---@param config NeluaConfig|NullSpec
---@return boolean
local function validate_prop(name, config)
    local err_ = function(...)
        return name and logger.err_dep(name, ...) or logger.err(...)
    end

    local spec_shape = types.shape({
        name = types.string,
        version = types.string,
        dependencies = types.shape({}, {
            extra_fields = types.map_of(
                types.string,
                types.shape({
                    path = (types.string * types.custom(function(val)
                        if not fs.isdir(val) then
                            return nil, "'" .. val .. "' isn't a directory"
                        end
                        return true
                    end)):is_optional(),
                    url = types.string:is_optional(),
                    hash = types.string:is_optional(),
                    cloneopts = types.array_of(types.string):is_optional(),
                    branch = types.string:is_optional(),
                    tag = types.string:is_optional(),
                    commit = types.string:is_optional(),
                })
            ),
        }),
        paths = types.array_of(types.string:is_optional()),
    }, {
        extra_fields = types.map_of(types.string, types.any),
    })

    local ok, merr = spec_shape(config)

    if not ok and merr then
        err_(merr)
        return false
    end

    for _, v in pairs(config.dependencies) do
        ok, merr = types.shape({}, { extra_fields = types.map_of(types.string, types.string) })(v)
        if not ok and merr then
            err_(merr)
            return false
        end
    end

    return true
end

local function getfenv(fn)
    local i = 1
    while true do
        local name, val = debug.getupvalue(fn, i)
        if name == "_ENV" then
            return val
        elseif not name then
            break
        end
        i = i + 1
    end
end

local spec = {}

---@param str string
---@param name string?
---@return NullSpec?
function spec.parse(str, name)
    local err_ = function(...)
        return name and logger.err_dep(name, ...) or logger.err(...)
    end
    local warn_ = function(...)
        return name and logger.warn_dep(name, ...) or logger.warn(...)
    end

    local pass, code_err = load(str, "@"..name, "t", {})
    if not pass and code_err then
        err_(code_err)
        error({ exit = true })
    end

    local spec_string = str:match("%-%-%[=*%[null%-spec%s([^%]]+)%]=*%]")
    if not spec_string then
        warn_("cannot find null spec field")
        return
    end

    local fn, err = load(spec_string, "@null-spec"..(name and ":"..name or ""), "t", {})
    if fn then
        local ok, fnerr = pcall(fn)
        if not ok and fnerr then
            err_(fnerr)
            error({ exit = true })
        end
    else
        err_(err)
        error({ exit = true })
    end
    return getfenv(fn)
end

---@param spec_tbl NullSpec
---@param name string?
---@return boolean
function spec.lint(spec_tbl, name)
    if not validate_prop(name, spec_tbl) then
        error({ exit = true })
    end
    return true
end

return spec
