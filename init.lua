local console = require("nelua.utils.console")

local function spec_func(func)
	return load(func, nil, nil, _ENV)
end

local spec_funcs = {
  tarball = function(url)
  	local info = {}
  	info.url = url
  	info.type = "tarball"
  	deps[#deps+1] = info
  	last = info
  end,

  git = function(url)
  	local info = {}
  	info.url = url
  	info.type = "git"
  	deps[#deps+1] = info
  	last = info
  end,

  dir = function(path)
  	local info = {}
  	info.path = path
  	info.type = "dir"
  	deps[#deps+1] = info
  	last = info
  end,

  hash = function(spec)
  	local type, hash = spec:match("(.-):(.+)")
  	if not type then
    	hash = spec
    	type = "md5"
    end

    if last.type ~= "tarball" then
      warn("using %{bright blue}`hash`${reset} on %{bright green}" .. last.type .. "%{reset} dependency, ignored...")
      return
    end

    last.hash = hash
    last.type = type
  end,

  branch = function(branch)
  	if last.type ~= "git" then
    	warn("using %{light blue}`branch`%{reset} on %{bright green}" .. last.type .. "%{reset} dependency, ignored...")
    end

    last.checkout = branch
  end,
}
