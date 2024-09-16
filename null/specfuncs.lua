local log = require("null.log")

local function spec_func(func)
  return assert(load(string.dump(func, true), nil, "bt", setmetatable({ warn = log.warn }, { __index = _ENV })))
end

local spec_funcs = {
  tarball = function(url)
    local info = { before_hooks = {}, after_hooks = {}, on_hooks = {} }
    info.url = url
    info.type = "tarball"
    Deps[#Deps + 1] = info
    Last = info
  end,

  git = function(url)
    local info = { before_hooks = {}, after_hooks = {}, on_hooks = {} }
    info.url = url
    info.type = "git"
    Deps[#Deps + 1] = info
    Last = info
  end,

  dir = function(path)
    local info = { before_hooks = {}, after_hooks = {}, on_hooks = {} }
    info.path = path
    info.type = "dir"
    Deps[#Deps + 1] = info
    Last = info
  end,

  custom = function()
    local info = { before_hooks = {}, after_hooks = {}, on_hooks = {} }
    info.type = "custom"
    Deps[#Deps + 1] = info
    Last = info
  end,

  as = function(name)
    if name:match("^%-") or name:match("^[^A-Za-z0-9._-]+$") then
    	error("invalid dependancy identifier: %{green}" .. name .. "%{reset}, must contain %{blue}[A-Za-z0.9_-]%{reset} character and does not start with %{blue}-%{reset} character!")
    end
    Last.name = name
  end,

  hash = function(spec)
    local type, hash = spec:match("(.-):(.+)")
    if not type then
      hash = spec
      type = "md5"
    end

    if Last.type ~= "tarball" then
      warn(
        ("using %{blue}hash%{reset} spec on %{green}%s%{reset} which is a %{cyan}%s%{reset} dependency, ignored..."):format(
          Last.name,
          Last.type
        )
      )
      return
    end

    Last.hash = hash
    Last.type = type
  end,

  branch = function(branch)
    if Last.type ~= "git" then
      warn(
        ("using %{blue}branch%{reset} spec on %{green}%s%{reset} which is a %{cyan}%s%{reset} dependency, ignored..."):format(
          Last.name,
          Last.type
        )
      )
      return
    end

    Last.checkout = "heads/" .. branch
  end,

  tag = function(tag)
    if Last.type ~= "git" then
      warn(
        ("using %{blue}tag%{reset} spec on %{green}%s%{reset} which is a %{cyan}%s%{reset} dependency, ignored..."):format(
          Last.name,
          Last.type
        )
      )
      return
    end

    Last.checkout = "tags/" .. tag
  end,

  commit = function(commit)
    if Last.type ~= "git" then
      warn(
        ("using %{blue}commit%{reset} spec on %{green}%s%{reset} which is a %{cyan}%s%{reset} dependency, ignored..."):format(
          Last.name,
          Last.type
        )
      )
      return
    end

    if not commit:match("^%x+$") then
      error("%{green}'" .. commit .. "'%{reset} is not a hash commit!")
    end

    Last.checkout = commit
  end,
}

for _, hook in pairs({ "fetch", "build", "install" }) do
  spec_funcs["before_" .. hook] = function(func)
    last.before_hooks[hook] = func
  end
  spec_funcs["after_" .. hook] = function(func)
    last.after_hooks[hook] = func
  end
  spec_funcs["on_" .. hook] = function(func)
    last.on_hooks[hook] = func
  end
end

return function()
  for k, v in pairs(spec_funcs) do
    spec_funcs[k] = spec_func(v)
  end
  return spec_funcs
end
