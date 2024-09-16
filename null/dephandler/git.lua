local path = require("path")
local ppoll = require("posix.poll")
local shell = require("null.utils.shell")

local git = {}

function git.fetch(sched, project_info, gitdeps)
  for _, dep in pairs(gitdeps) do
    dep.fetching = true
    dep.fd =
      io.popen("git clone " .. shell.quote(dep[1]) .. " " .. shell.quote(path.join(project_info.dir, gitdeps[1])))
    sched.addloop(function()
      local r = ppoll.rpoll(dep.fd)
      if r == 1 then
        dep.info = dep.fd:read("l")
        coroutine.yield()
      end
      return r == 1
    end)
  end
end

function git.build(sched, gitdeps) end

return git
