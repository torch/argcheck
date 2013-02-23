argcheck
========

A powerful argument checker for your lua functions.

Argcheck produces specific code for each function. This code is compiled
once, which implies the checks will not add much overheads to your original
function.

Installation
------------

The easiest is to use [luarocks](http://www.luarocks.org).

```sh
luarocks build https://raw.github.com/andresy/argcheck/master/rocks/argcheck-scm-1.rockspec
```

You can also copy the `argcheck` directory where `luajit` will find it.

Introduction
------------

To use `argcheck`, you have to first `require` it:
```lua
local argcheck = require 'argcheck'
```
Note that `argcheck` does not import anything globally, to avoid cluttering
the global namespace.  The value returned by the require is a function: for
most usages, it will be the only thing you need.

The `argcheck()` function creates a wrapper around any function you wish to
check arguments. Assume you have a function which requires a unique number
argument:
```lua
function addfive(x)
  print(string.format('%f + 5 = %f', x, x+5)
end
```
You can make sure everything goes fine by doing:
```lua
addfive = argcheck(
 {{name="x", type="number"}},
 function(x)
   print(string.format('%f + 5 = %f', x, x+5)
 end
)
```
