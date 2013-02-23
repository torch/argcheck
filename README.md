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
  print(string.format('%f + 5 = %f', x, x+5))
end
```
You can make sure everything goes fine by doing:
```lua
addfive = argcheck(
 {{name="x", type="number"}},
 function(x)
   print(string.format('%f + 5 = %f', x, x+5))
 end
)
```
If a user try to pass a wrong argument, too many arguments, or no arguments
at all, `argcheck` will complain:
```lua
> arguments:
{
  x = number  -- 
}
   
[string "return function()..."]:8: invalid arguments
```

### Default arguments
Simple argument types like `number`, `string` or `boolean` can have defaults:
```lua
addfive = argcheck(
 {{name="x", type="number", default=0}},
 function(x)
   print(string.format('%f + 5 = %f', x, x+5))
 end
)
```
In which case, if the argument is missing, `argcheck` will pass the default
one to your function:
```lua
> addfive()
0.000000 + 5 = 5.000000
```

### Help
Argcheck encourages you to add help to your function. You can document each argument:
```lua
addfive = argcheck(
 {{name="x", type="number", default=0, help="the age of the captain"}},
 function(x)
   print(string.format('%f + 5 = %f', x, x+5))
 end
)
```
Or even document the function:
```lua
addfive = argcheck(
 {help=[[
This function is going to do a stupid addition.
Give a number, it adds 5. Amazing.]],
 {name="x", type="number", default=0, help="the age of the captain"}},
 function(x)
   print(string.format('%f + 5 = %f', x, x+5))
 end
)
```
Then, if the user makes a mistake in the arguments, the error message
becomes more clear:
```lua
> addfive('')
                                                                                                     
This function is going to do a stupid addition.                                                               
Give a number, it adds 5. Amazing.

> arguments:
{
   [x = number]  -- the age of the captain [default=0]
}

[string "return function()..."]:12: invalid arguments
```

### Multiple arguments

Until now, our function had only one argument. Obviously, argcheck can
handle as many as you wish:
```lua
addfive = argcheck(
 {help=[[
This function is going to do a stupid addition.
Give a number, it adds 5. Amazing.]],
 {name="x", type="number", default=0, help="the age of the captain"},
 {name="msg", type="string", help="a message"}},
 function(x, msg)
   print(string.format('%f + 5 = %f', x, x+5))
   print(msg)
 end
)
```
Argcheck handles well various cases, including those where some arguments
with defaults values might be missing:
```lua
> addfive(4, 'hello world')
4.000000 + 5 = 9.000000
hello world
>
> addfive('hello world')
0.000000 + 5 = 5.000000
hello world
>
> addfive(4)

This function is going to do a stupid addition.
Give a number, it adds 5. Amazing.

> arguments:
{
  [x   = number]  -- the age of the captain [default=0]
   msg = string   -- a message
}

[string "return function()..."]:13: invalid arguments
```
