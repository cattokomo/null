-- From Pluto scheduler library, modified to be compatible with PUC Lua

local time = require("posix.time")

return function()
  local self = {
    coros = {},
    yieldfunc = function()
      time.nanosleep({ tv_nsec = 1000000 })
    end,
  }

  local function internalresume(coro)
    if not self.errorfunc then
      if select("#", assert(coroutine.resume(coro))) ~= 0 then
        warn("Coroutine yielded values to scheduler. Discarding them.")
      end
    else
      local ok, val = coroutine.resume(coro)
      if ok then
        if val ~= nil then
          warn("Coroutine yielded values to scheduler. Discarding them.")
        end
      else
        self.errorfunc(val)
      end
    end
  end

  local function add(t)
    if type(t) ~= "thread" then
      t = coroutine.create(t)
    end
    table.insert(self.coros, t)
    internalresume(t)
    return t
  end

  local function addloop(f)
    return add(function()
      while f() ~= false do
        coroutine.yield()
      end
    end)
  end

  local function run()
    local all_dead
    repeat
      all_dead = true
      for i, coro in pairs(self.coros) do
        if coroutine.status(coro) == "suspended" then
          internalresume(coro)
          all_dead = false
        elseif coroutine.status(coro) == "dead" then
          self.coros[i] = nil
        end
      end
      self.yieldfunc()
    until all_dead
  end

  return setmetatable(self, {
    __index = {
      internalresume = internalresume,
      add = add,
      addloop = addloop,
      run = run,
    },
  })
end
