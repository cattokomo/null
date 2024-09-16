#!/usr/bin/env bash

task.amalg() {
  set -s nullglob dotglob

  [[ -f ./luarocks && -f ./lua ]] || bake.die 'initialize luarocks project first (hint: `luarocks init --lua-version=5.4`)'
  local files=(./deps/lua-amalg/*)
  (( ${#files[@]} )) || bake.die 'initialize git submodules first (hint: `git submodule init --update --recursive`)'

  lua() { ./lua "$@"; }
  luarocks() { ./luarocks "$@"; }
  amalg() { lua ./deps/lua-amalg/src/amalg.lua "$@"; }

  luarocks install --deps-only null-dev-1.rockspec

  lua -ldeps.lua-amalg.src.amalg main.lua
  amalg -S "$(lua -e 'print(arg[0])')" -x -s main.lua -o null.lua -c
}

task.build() {
  ./bake amalg

  ./luarocks install luastatic
  luastatic() { ./lua_modules/bin/luastatic "$@"; }

  luastatic null.lua "${LUA_STATICLIB}" "${LUA_INCDIR}"
}
