argcheck
========

A powerful argument checker library for your lua functions.

Argcheck generates specific code for checking arguments of a function. This
allows complex argument checking (possibly with optional values), with almost
no overhead.

Installation
------------

The easiest is to use [luarocks](http://www.luarocks.org).

If you use Torch, simply do
```sh
luarocks install argcheck
```
else
```sh
luarocks build https://raw.github.com/torch/argcheck/master/rocks/argcheck-scm-1.rockspec
```

You can also copy the `argcheck` directory where `luajit` (or `lua`) will
find it.

* * *

Note: argcheck requires a `bit` library. If you are not using `luajit` (you
are seriously encouraged to switch to it), please install first the
`luabitop` library or `bitlib`:
```sh
luarocks install luabitop
```
* * *

Introduction
------------

To use `argcheck`, you have to first `require` it:
```lua
local argcheck = require 'argcheck'
```
In the following, we assume this has been done in your script.
Note that `argcheck` does not import anything globally, to avoid cluttering
the global namespace.  The value returned by the require is a function: for
most usages, it will be the only thing you need.

The `argcheck()` function creates a fast pre-compiled function for checking
arguments, according to rules provided by the user. Assume you have a
function which requires a unique number argument:
```lua
function addfive(x)
  print(string.format('%f + 5 = %f', x, x+5))
end
```
You can make sure everything goes fine by doing creating the rule:
```lua
check = argcheck{
   {name="x", type="number"}
}

function addfive(...)
   local x = check(...)
   print(string.format('%f + 5 = %f', x, x+5))
end
```
If a user try to pass a wrong argument, too many arguments, or no arguments
at all, `argcheck` will complain:
```lua
arguments:
{
  x = number  -- 
}
   
stdin:2: invalid arguments
```

A rule must at least take a `name` field. The `type` field is optional
(even though it is highly recommended!). If `type` is not provided, `argcheck` will make
sure the given argument is not `nil`. If you want also to accept `nil` arguments, see the
[`opt` option](#argcheck.opt).

### Default arguments
Simple argument types like `number`, `string` or `boolean` can have defaults:
```lua
check = argcheck{
   {name="x", type="number", default=0}
}
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
check = argcheck{
   {name="x", type="number", default=0, help="the age of the captain"}
}
```
Or even document the function:
```lua
check = argcheck{
   help=[[
This function is going to do a simple addition.
Give a number, it adds 5. Amazing.
]],
   {name="x", type="number", default=0, help="the age of the captain"}
}
```
Then, if the user makes a mistake in the arguments, the error message
becomes more clear:
```lua
> addfive('')
stdin:2: invalid arguments
                                                                                                     
This function is going to do a simple addition.                                                               
Give a number, it adds 5. Amazing.

arguments:
{
   [x = number]  -- the age of the captain [default=0]
}
```

### Multiple arguments

Until now, our function had only one argument. Obviously, argcheck can
handle as many as you wish:
```lua
check = argcheck{
   help=[[
This function is going to do a simple addition.
Give a number, it adds 5. Amazing.
]],
   {name="x", type="number", default=0, help="the age of the captain"},
   {name="msg", type="string", help="a message"}
}

function addfive(...)
  local x, msg = check(...)
  print(string.format('%f + 5 = %f', x, x+5))
  print(msg)
end
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

stdin:2: invalid arguments
                                                                                                     
This function is going to do a simple addition.                                                               
Give a number, it adds 5. Amazing.                                                                            

arguments:
{
  [x   = number]  -- the age of the captain [default=0]
   msg = string   -- a message
}
```

### Default argument defaulting to another argument

Arguments can have a default value coming from another argument, with the
`defaulta` option. In the following
```lua

check = argcheck{
  {name="x", type="number"},
  {name="y", type="number", defaulta="x"}
}

function mul(...)
   local x, y = check(...)
   print(string.format('%f x %f = %f', x, y, x*y))
end
```
argument `y` will take the value of `x` if it is not passed during the function call:
```lua
> mul(3,4)
3.000000 x 4.000000 = 12.000000
> mul(3)
3.000000 x 3.000000 = 9.000000
```

### Default arguments function

In some more complex cases, sometimes one needs to run a particular function when
the given argument is not provided. The option `defaultf` is here to help.
```lua

idx = 0

check = argcheck{
   {name="x", type="number"},
   {name="y", type="number", defaultf=function() idx = idx + 1 return idx end}
}

function mul(...)
   local x, y = check(...)
   print(string.format('%f x %f = %f', x, y, x*y))
end
```

This will output the following:
```lua
> mul(3)
3.000000 x 1.000000 = 3.000000
> mul(3)
3.000000 x 2.000000 = 6.000000
> mul(3)
3.000000 x 3.000000 = 9.000000
```

<a name="argcheck.opt"/>
### Optional arguments

Arguments with a default value can be seen as optional. However, as they
do have a default value, the underlying function will never receive a `nil`
value. In some situations, one might need to declare an optional argument
with no default value. You can do this with the `opt` option.
```lua
check = argcheck{
  {name="x", type="number", default=0, help="the age of the captain"},
  {name="msg", type="string", help="a message", opt=true}
}

function addfive(...)
   local x, msg = check(...)
   print(string.format('%f + 5 = %f', x, x+5))
   print(msg)
end
```
In this example, one might call `addfive()` without the `msg` argument. Of
course, the underlying function must be able to handle `nil` values:
```lua
> addfive('hello world')
0.000000 + 5 = 5.000000
hello world
> addfive()
0.000000 + 5 = 5.000000
nil
```

### Specific per-rule check

It is possible to add an extra specific checking function for a given checking
rule, with the `check` option. This function will be called (with the corresponding argument)
in addition to the standard type checking. This can be useful for refined argument selection:
```lua
check = argcheck{
  {name="x", type="number", help="a number between one and ten",
    check=function(x)
            return x >= 1 and x <= 10
          end}
}

function addfive(...)
   local x = check(...)
   print(string.format('%f + 5 = %f', x, x+5))
end

> addfive(3)
3.000000 + 5 = 8.000000

> addfive(11)
stdin:2: invalid arguments

arguments:
{
   x = number  -- a number between one and ten
}
```

### Named arguments

Argcheck handles named argument calls. Following the previous example, both
```lua
addfive(1, "hello world")
```
and
```lua
addfive{x=1, msg="hello world"}
```
are valid. However, ordered arguments are handled *much faster* than named
arguments.

### Options global to all rules

Argcheck has several interesting global options, as the `help` one we have introduced already.
Those global options are simply set in the main `argcheck` table:
```lua
check = argcheck{
   help = "blah blah", -- global help option
...
}
```
Other global options are described in the following.

#### Restrict to named-only or ordered-only arguments

In some very special (rare) cases, one might want to disable named calls
like `addfive{x=1, msg='blah'}`, and stick to only ordered arguments like
`addfive(1, 'blah'), or vice-versa. That might be to handle some ambiguous
calls, e.g. when one has to deal with table arguments. The options
`nonamed` and `noordered` can be used for that purpose:

```lua
check = argcheck{
   nonamed=true,
   {name="x", type="number", default=0, help="the age of the captain"},
   {name="msg", type="string", help="a message"}
}

function addfive(...)
   local x, msg = check(...)
   print(string.format('%f + 5 = %f', x, x+5))
   print(msg)
end

> addfive('blah')
0.000000 + 5 = 5.000000
blah

> addfive{msg='blah'}
stdin:2: invalid arguments

arguments:
{
   [x   = number]  -- the age of the captain [default=0]
   msg = string   -- a message
}
```

#### Debug

Adding `debug=true` as global option will simply dump the corresponding code
for the given checking argument function.

```lua
check = argcheck{
   debug=true,
   {name="x", type="number", default=0, help="the age of the captain"},
   {name="msg", type="string", help="a message"}
}

-- check
local isoftype
local usage
local arg1d
return function(...)
   local arg1 = arg1d
   local arg2
   local narg = select("#", ...)
   if narg == 1 and isoftype(select(1, ...), "string") then
      arg2 = select(1, ...)
   elseif narg == 2 and isoftype(select(1, ...), "number") and isoftype(select(2, ...), "string") then
      arg1 = select(1, ...)
      arg2 = select(2, ...)
   elseif narg == 1 and isoftype(select(1, ...), "table") then
      local arg = select(1, ...)
      local narg = 0
      if arg.x then narg = narg + 1 end
      if arg.msg then narg = narg + 1 end
      if narg == 1 and isoftype(arg.msg, "string") then
         arg2 = arg.msg
      elseif narg == 2 and isoftype(arg.x, "number") and isoftype(arg.msg, "string") then
         arg1 = arg.x
         arg2 = arg.msg
      else
         error(usage, 2)
      end
      return arg1, arg2
   else
      error(usage, 2)
   end
   return arg1, arg2
end
```

As you can see, for a simple example like this one, the code is already not that trivial.

### Advanced usage

By default, `argcheck` uses the standard `type()` Lua function to determine the type of your
arguments. In some cases, like if you are handling your own class system, you might want to
specify how to check types. This can be simply done by overriding the `isoftype()` function
available in the `argcheck` environment.
```lua
env = require 'argcheck.env' -- retrieve argcheck environement

-- this is the default type function
-- which can be overrided by the user
function env.isoftype(obj, typename)
   return type(obj) == typename
end
```
Note that if you change the `isoftype()` function, it will *not* affect previously defined
argument checking functions: `isoftype()` is passed as an upvalue for each created argument
function.
