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

### Default arguments defaulting to another argument

Arguments can have a default value coming from another argument, with the
`defaulta` option. In the following
```lua
mul = argcheck(
 {{name="x", type="number"},
  {name="y", type="number", defaulta="x"}},
  function(x, y)
    print(string.format('%f x %f = %f', x, y, x*y))
  end
)
```
argument `y` will take the value of `x` if it is not passed during the function call:
```lua
> mul(3,4)
3.000000 x 4.000000 = 12.000000
> mul(3)
3.000000 x 3.000000 = 9.000000
```

### Optional arguments

Arguments with a default value can be seen as optional. However, as they
have a default value, the underlying function will never receive a `nil`
value. In some situation, one might need to declare an optional argument
with no default value. You can do this with the `opt` option.
```lua
addfive = argcheck(
 {help=[[
 This function is going to do a stupid addition.
 Give a number, it adds 5. Amazing.]],
  {name="x", type="number", default=0, help="the age of the captain"},
  {name="msg", type="string", help="a message", opt=true}},
  function(x, msg)
     print(string.format('%f + 5 = %f', x, x+5))
     print(msg)
  end
)
```
In this example, one might call `addfive()` without the `msg` argument. Of
course, the underlying function must be able to handle `nil` values:
```lua
> addfive()
0.000000 + 5 = 5.000000
nil
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
are equivalent.

#### Named-only arguments

In the event of a function with many options, one might have some arguments
which can be only passed as named arguments ``{}``: having a lot of
optional arguments in the an ordered function call ``()`` can become
quickly messy. In the following example, `msg` is a named argument:
```lua
addfive = argcheck(
 {{name="x", type="number", default=0, help="the age of the captain"},
  {name="msg", type="string", help="a message", named=true}},
  function(x, msg)
     print(string.format('%f + 5 = %f', x, x+5))
     print(msg)
  end
)
```
Named arguments are optional, by definition. It is up to the programmer
to handle properly possible `nil` values received by the function:
```lua
> addfive(5)
5.000000 + 5 = 10.000000
nil
```
As mentioned earlier, the difference between a pure optional (`opt`) argument and
a named argument is that the named argument cannot be passed in an ordered argument call:
```lua
> addfive(5, "hello world")
> arguments:
{
  [x   = number]   -- the age of the captain [default=0]
  [msg = string]*  -- a message
}
```
Note that argcheck mentions named argument with a `*` in the help message.
Thus, the following works:
```lua
> addfive{x=5, msg="hello world"}
5.000000 + 5 = 10.000000
hello world
```

#### Disabling named-argument calls

In some very special cases (rare), one might want to disable named
calls. That might be to handle some ambiguous calls, e.g. when one has to
deal with table arguments. The option `nonamed` can be used for that purpose:
```lua
addfive = argcheck(
 {
  nonamed=true,
  {name="x", type="number", default=0, help="the age of the captain"},
  {name="msg", type="string", help="a message"}},
  function(x, msg)
     print(string.format('%f + 5 = %f', x, x+5))
     print(msg)
  end
)
```
Obviously, mixing the `nonamed` option with `named`-only arguments is a
non-sense, and not allowed by argcheck. With the above example, argcheck
would raise an error if called with named arguments:
```lua
> addfive{x=5, msg="hello world"}
> arguments:
(
  [x   = number]  -- the age of the captain [default=0]
   msg = string   -- a message
)
```
Note the subtile difference in the help display, where `{}` have been
replaced by `()`.

### Allowed types

Argcheck "knows" the following types (specified with the `type` option of any argument):
*   `number`
*   `boolean`
*   `string`
*   `numbers` -- a vararg argument, which can take several numbers (see below)

If no type is given, the argument can be anything but `nil` (if you want to allow the
`nil` value, use the `opt` option). E.g.:
```lua
> display = argcheck{
 {{name="value"}},
  function(value)
    print(value)
  end
}

> display(5)
5

> display("hello world")
hello world

> display()
> arguments:
{
   value  --
}
luajit: [string "return function()..."]:8: invalid arguments
```

### Methods with `self` argument

In Lua, the syntax sugar call `object:method(arg1, ...)` is often used when
writing object-oriented code. This call stands for
```lua
method(object, arg1, ...)
```
If one wants a named argument call, `object:method{name1=arg1, ...}` stands for
```lua
method(object, {name1=arg1, ...})
```
Note that handling such cases is not that trivial, because in normal
(non-method) named calls, only one table is allowed as argument (and not a
first argument followed by a table).

Argcheck handles nicely these type of calls, as long as the object argument is named
`self`. Here is a complete example:

```lua
-- the Rectangle class metatable
Rectangle = {}

-- the constructor
Rectangle.new = argcheck{
   {{name='x', type='number'},
    {name='y', type='number'},
    {name='w', type='number'},
    {name='h', type='number'}},
   function(x, y, w, h)
      local rect = {x=x, y=y, w=w, h=h}
      setmetatable(rect, {__index=Rectangle})
      return rect
   end
}

-- a method:
Rectangle.display = argcheck{
   {help='display N times the object',
    {name='self'}, -- note the name of the first argument
    {name='N', type='number'}},
   function(self, N)
      for i=1,N do
         print(string.format('Rectangle x=%g y=%g w=%g h=%g',
                             self.x, self.y, self.w, self.h))
      end
   end
}

-- create a new Rectangle
rect = Rectangle.new(5, 7, 10, 20)

-- display it 3 times
> rect:display(3)

Rectangle x=5 y=7 w=10 h=20
Rectangle x=5 y=7 w=10 h=20
Rectangle x=5 y=7 w=10 h=20

-- show the help
> rect:display()

display N times the object

> arguments:
{
   self           -- 
   N    = number  -- 
}
      
luajit: [string "return function()..."]:11: invalid arguments
```

* * *
Note: in the above example we do not check the type of the object
`self`. There are ways to integrate you own types into argcheck, as it will
be explained later in the advanced usage section.
* * *

#### Generating both a function and a method at once

In an object-oriented settings, it is sometimes useful to provide a way to
call a method `object:method(arg1, ...)` as a function `method(object, arg1, ...)`. If
one does not use named argument calls, the function generated by argcheck for the method
should be fine. However, with named argument calls, for a given method
```lua
object:method{name1=arg1, ...}
```
one would probably like a function `func` which does the same with:
```lua
func{obj=object, name1=arg1, ...}
```lua
instead of
```lua
method(object, {name1=arg1, ...})
```
which looks more awkward.

Argcheck allows you to generate both these method and function at once, and even alter
the arguments (e.g. if they are optional or not) between the function and the method versions.

Following the previous Rectangle class example, here is what could be done:
```lua
display, Rectangle.display = argcheck{
   {help='display N times the object',
    self='obj', -- specify which argument is going to act as 'self' for the method
    {name='obj'},
    {name='N', type='number', opt=true, method={opt=false}}}, -- non-optional argument for the method version
   function(self, N)
      N = N or 1
      for i=1,N do
         print(string.format('Rectangle x=%g y=%g w=%g h=%g',
                             self.x, self.y, self.w, self.h))
      end
   end
}

-- create a new Rectangle
> rect = Rectangle.new(5, 7, 10, 20)

-- use the method
> rect:display(3)

Rectangle x=5 y=7 w=10 h=20
Rectangle x=5 y=7 w=10 h=20
Rectangle x=5 y=7 w=10 h=20

-- use the function
> display(rect)

Rectangle x=5 y=7 w=10 h=20

-- usage for the function
> display()

display N times the object

> arguments:
{
   obj            -- 
  [N   = number]  -- 
}
     
-- usage for the method
> rect:display()

display N times the object

> arguments:
{
   self           -- 
   N    = number  -- 
}   
```

### Handling multiple heterogeneous cases

Sometimes one would like that the same function handles several very
different cases. Take the example of a fictive `inc()` function, which
would add one to a number if a number is given as argument, or would
concatenate a letter to a string, if a string and a letter bytecode are
given as argument.

Argcheck can handle these kind of cases. In a call to `argcheck`, each
argument specifications is followed by a function which will be called if
the argument specifications are fulfilled.

Here is a concrete example:
```lua
inc = argcheck(

  {{name="x", type="number"}},
  function(x)
     return x+1
  end,
  
  {{name="str", type="string"},
   {name="letter", type="number"}},
  function(str, letter)
     return str .. string.char(letter)
  end
)

> = inc(5)
6

> = inc("hello worl", string.byte('d'))
hello world
```

Note that one can specify help for each function case. In fact, one can also provide a global help message,
by adding a `help=` field in a table containing all the arguments provided to argcheck:
```lua
inc = argcheck{ -- note the difference here
  help = [[Increment a number or a string.]], -- global help message

  {help="Increment a number by 1",
   {name="x", type="number"}},
  function(x)
     return x+1
  end,
  
  {help="Add a letter to a string",
   {name="str", type="string"},
   {name="letter", type="number"}},
  function(str, letter)
     return str .. string.char(letter)
  end
}

> = inc()

Increment a number or a string.

Increment a number by 1

> arguments:
{
   x = number  -- 
}

or

Add a letter to a string

> arguments:
{
   str    = string  -- 
   letter = number  -- 
}

```

