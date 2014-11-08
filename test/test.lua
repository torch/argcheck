local argcheck = require 'argcheck'

function addfive(x)
   return string.format('%f + 5 = %f', x, x+5)
end

check = argcheck{
   {name="x", type="number"}
}

function addfive(...)
   local x = check(...)
   return string.format('%f + 5 = %f', x, x+5)
end

assert(addfive(5) == '5.000000 + 5 = 10.000000')
assert(not pcall(addfive))

check = argcheck{
   {name="x", type="number", default=0}
}

assert(addfive() == '0.000000 + 5 = 5.000000')


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
  return string.format('%f + 5 = %f [msg=%s]', x, x+5, msg)
end

assert(addfive(4, 'hello world') == '4.000000 + 5 = 9.000000 [msg=hello world]')
assert(addfive('hello world') == '0.000000 + 5 = 5.000000 [msg=hello world]')

check = argcheck{
  {name="x", type="number"},
  {name="y", type="number", defaulta="x"}
}

function mul(...)
   local x, y = check(...)
   return string.format('%f x %f = %f', x, y, x*y)
end

assert(mul(3,4) == '3.000000 x 4.000000 = 12.000000')
assert(mul(3) == '3.000000 x 3.000000 = 9.000000')

idx = 0
check = argcheck{
   {name="x", type="number"},
   {name="y", type="number", defaultf=function() idx = idx + 1 return idx end}
}

function mul(...)
   local x, y = check(...)
   return string.format('%f x %f = %f', x, y, x*y)
end

assert(mul(3) == '3.000000 x 1.000000 = 3.000000')
assert(mul(3) == '3.000000 x 2.000000 = 6.000000')
assert(mul(3) == '3.000000 x 3.000000 = 9.000000')

check = argcheck{
  {name="x", type="number", default=0, help="the age of the captain"},
  {name="msg", type="string", help="a message", opt=true}
}

function addfive(...)
   local x, msg = check(...)
   return string.format('%f + 5 = %f [msg=%s]', x, x+5, msg)
end

assert(addfive('hello world') == '0.000000 + 5 = 5.000000 [msg=hello world]')
assert(addfive() == '0.000000 + 5 = 5.000000 [msg=nil]')

check = argcheck{
  {name="x", type="number", help="a number between one and ten",
    check=function(x)
            return x >= 1 and x <= 10
          end}
}

function addfive(...)
   local x = check(...)
   return string.format('%f + 5 = %f', x, x+5)
end

assert(addfive(3) == '3.000000 + 5 = 8.000000')
assert( not pcall(addfive, 11))

check = argcheck{
  {name="x", type="number", default=0, help="the age of the captain"},
  {name="msg", type="string", help="a message", opt=true}
}

function addfive(...)
   local x, msg = check(...)
   return string.format('%f + 5 = %f [msg=%s]', x, x+5, msg)
end

assert(addfive(1, "hello world") == '1.000000 + 5 = 6.000000 [msg=hello world]')
assert(addfive{x=1, msg="hello world"} == '1.000000 + 5 = 6.000000 [msg=hello world]')

check = argcheck{
   pack=true,
   {name="x", type="number", default=0, help="the age of the captain"},
   {name="msg", type="string", help="a message"}
}

function addfive(...)
   local args = check(...) -- now arguments are stored in this table
   return(string.format('%f + 5 = %f [msg=%s]', args.x, args.x+5, args.msg))
end

assert(addfive(5, 'hello world') == '5.000000 + 5 = 10.000000 [msg=hello world]')

check = argcheck{
   nonamed=true,
   {name="x", type="number", default=0, help="the age of the captain"},
   {name="msg", type="string", help="a message"}
}

function addfive(...)
   local x, msg = check(...)
   return string.format('%f + 5 = %f [msg=%s]', x, x+5, msg)
end

assert(addfive('blah') == '0.000000 + 5 = 5.000000 [msg=blah]')
assert(not pcall(addfive, {msg='blah'}))

check = argcheck{
   quiet=true,
   {name="x", type="number", default=0, help="the age of the captain"},
   {name="msg", type="string", help="a message"}
}

assert(check(5, 'hello world'))
assert(not check(5))

addfive = argcheck{
   {name="x", type="number"},
   call = 
      function(x)
         return string.format('%f + 5 = %f', x, x+5)
      end
}

assert(addfive(5) == '5.000000 + 5 = 10.000000')
assert(not pcall(addfive))

checknum = argcheck{
   quiet=true,
   {name="x", type="number"}
}

checkstr = argcheck{
   quiet=true,
   {name="str", type="string"}
}

function addfive(...)

  -- first case
  local status, x = checknum(...)
  if status then
     return string.format('%f + 5 = %f', x, x+5)
  end

  -- second case
  local status, str = checkstr(...)
  if status then
    return string.format('%s .. 5 = %s', str, str .. '5')
  end

  -- note that in case of failure with quiet, the error is returned after the status
  error('invalid arguments')
end

assert(addfive(123) == '123.000000 + 5 = 128.000000')
assert(addfive('hi') == 'hi .. 5 = hi5')

addfive = argcheck{
  {name="x", type="number"},
  call =
     function(x) -- called in case of success
        return string.format('%f + 5 = %f', x, x+5)
     end
}

addfive = argcheck{
  {name="str", type="string"},
  overload = addfive, -- overload previous one
  call =
     function(str) -- called in case of success
        return string.format('%s .. 5 = %s', str, str .. '5')
     end
}

assert(addfive(5) == '5.000000 + 5 = 10.000000')
assert(addfive('hi') == 'hi .. 5 = hi5')

addfive = argcheck{
  {name="x", type="number"},
  call =
     function(x) -- called in case of success
        return string.format('%f + 7 = %f', x, x+7)
     end
}

assert(not pcall(argcheck,
                 {
                    {name="x", type="number"},
                    {name="msg", type="string", default="i know what i am doing"},
                    overload = addfive,
                    call =
                       function(x, msg) -- called in case of success
                          return string.format('%f + 5 = %f [msg = %s]', x, x+5, msg)
                       end
                 })
)

addfive = argcheck{
  {name="x", type="number"},
  {name="msg", type="string", default="i know what i am doing"},
  overload = addfive,
  force = true,
  call =
     function(x, msg) -- called in case of success
        return string.format('%f + 5 = %f [msg = %s]', x, x+5, msg)
     end
}

assert(addfive(5, 'hello') == '5.000000 + 5 = 10.000000 [msg = hello]')
assert(addfive(5) == '5.000000 + 5 = 10.000000 [msg = i know what i am doing]')

print('PASSED')
