local lfs = require('lfs')

local function get_contents_in_dirs(d)
    local i = 0
    for _ in lfs.dir(d) do
        i = i + 1
    end
    return i
end

local function non_empty(...)
    for i = 1, select('#', ...) do
        local v = select(i, ...)

        if get_contents_in_dirs(v) == 0 then
            return false
        end
    end
    return true
end

local function map(t, f)
    for k, v in pairs(t) do
        t[k] = f(v) or v
    end
    return t
end

if not non_empty('./deps/easy-http', './deps/lua-amalg', './deps/pure_lua_SHA') then
    quit("to build null, you'll need to have submodules cloned. run `git submodule update --init --recursive`")
end

local amalg = './deps/lua-amalg/src/amalg.lua'

Easyhttp = c.shared({ 'easyhttp', src = './deps/easy-http/src/* ./deps/easy-http/src/extern/*', needs = 'libcurl' })

local files = {}
path.get_files(files, './src/null/', '%.lua$')

Null = target('null.lua', table.concat(files, ' '), function(t)
    map(t.deps, function(v)
        print(v)
        local module = path.basename(path.splitext(v))
        return 'null.' .. module
    end)
    package.path = package.path
        .. ';'
        .. table.concat({
            './src/?.lua',
            './deps/pure_lua_SHA/?.lua',
        }, ';')
    local fn, err = loadfile(amalg, 't')
    if fn then
        fn(
            '--c-libs',
            '--script=./src/main.lua',
            '--output=' .. t.target,
            '--',
            'sha2',
            'easyhttp',
            table.unpack(t.deps)
        )
    else
        quit(err)
    end
end)

default({ Easyhttp, Null })
