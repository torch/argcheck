local argcheck = require 'argcheck'
local env = require 'argcheck.env'

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

local foobar
if pcall(require, 'torch') then
   local ctors = {}
   torch.class('foobar', ctors)
   foobar = ctors.foobar()
else
   foobar = {}
   setmetatable(foobar, {__typename="foobar"})
end
foobar.checksum = 1234567

foobar.addnothing = argcheck{
   {name="self", type="foobar"},
   debug=true,
   call =
      function(self)
         return self.checksum
      end
}

assert(foobar:addnothing() == 1234567)

foobar.addfive = argcheck{
   {name="self", type="foobar"},
   {name="x", type="number"},
   {name="msg", type="string", default="i know what i am doing"},
   call =
      function(self, x, msg) -- called in case of success
         return string.format('%f + 5 = %f [msg = %s] [self.checksum=%s]', x, x+5, msg, self.checksum)
      end
}

assert(foobar:addfive(5, 'paf') == '5.000000 + 5 = 10.000000 [msg = paf] [self.checksum=1234567]')
assert(foobar:addfive{x=5, msg='paf'} == '5.000000 + 5 = 10.000000 [msg = paf] [self.checksum=1234567]')

assert(foobar:addfive(5) == '5.000000 + 5 = 10.000000 [msg = i know what i am doing] [self.checksum=1234567]')
assert(foobar:addfive{x=5} == '5.000000 + 5 = 10.000000 [msg = i know what i am doing] [self.checksum=1234567]')

foobar.addfive = argcheck{
   {name="self", type="foobar"},
   {name="x", type="number", default=5},
   {name="msg", type="string", default="wassup"},
   call =
      function(self, x, msg) -- called in case of success
         return string.format('%f + 5 = %f [msg = %s] [self.checksum=%s]', x, x+5, msg, self.checksum)
      end
}

assert(foobar:addfive() == '5.000000 + 5 = 10.000000 [msg = wassup] [self.checksum=1234567]')
assert(foobar:addfive('paf') == '5.000000 + 5 = 10.000000 [msg = paf] [self.checksum=1234567]')
assert(foobar:addfive(nil, 'paf') == '5.000000 + 5 = 10.000000 [msg = paf] [self.checksum=1234567]')
assert(foobar:addfive(6, 'paf') == '6.000000 + 5 = 11.000000 [msg = paf] [self.checksum=1234567]')
assert(foobar:addfive(6) == '6.000000 + 5 = 11.000000 [msg = wassup] [self.checksum=1234567]')
assert(foobar:addfive(6, nil) == '6.000000 + 5 = 11.000000 [msg = wassup] [self.checksum=1234567]')

assert(foobar:addfive{} == '5.000000 + 5 = 10.000000 [msg = wassup] [self.checksum=1234567]')
assert(foobar:addfive{msg='paf'} == '5.000000 + 5 = 10.000000 [msg = paf] [self.checksum=1234567]')
assert(foobar:addfive{x=6, msg='paf'} == '6.000000 + 5 = 11.000000 [msg = paf] [self.checksum=1234567]')
assert(foobar:addfive{x=6} == '6.000000 + 5 = 11.000000 [msg = wassup] [self.checksum=1234567]')

addstuff = argcheck{
   {name="x", type="number"},
   {name="y", type="number", default=7},
   {name="msg", type="string", opt=true},
   call =
      function(x, y, msg)
         return string.format('%f + %f = %f [msg=%s]', x, y, x+y, msg or 'NULL')
      end
}

assert(addstuff(3) == '3.000000 + 7.000000 = 10.000000 [msg=NULL]')
assert(addstuff{x=3} == '3.000000 + 7.000000 = 10.000000 [msg=NULL]')
assert(addstuff(3, 'paf') == '3.000000 + 7.000000 = 10.000000 [msg=paf]')
assert(addstuff{x=3, msg='paf'} == '3.000000 + 7.000000 = 10.000000 [msg=paf]')

assert(addstuff(3, 4) == '3.000000 + 4.000000 = 7.000000 [msg=NULL]')
assert(addstuff{x=3, y=4} == '3.000000 + 4.000000 = 7.000000 [msg=NULL]')
assert(addstuff(3, 4, 'paf') == '3.000000 + 4.000000 = 7.000000 [msg=paf]')
assert(addstuff{x=3, y=4, msg='paf'} == '3.000000 + 4.000000 = 7.000000 [msg=paf]')

assert(env.type('string') == 'string')
assert(env.type(foobar) == 'foobar')

if pcall(require, 'torch') then
   local t = torch.LongTensor()
   assert(env.type(t) == 'torch.LongTensor')
   assert(env.istype(t, 'torch.LongTensor') == true)
   assert(env.istype(t, 'torch.*Tensor') == true)
   assert(env.istype(t, '.*Long') == true)
   assert(env.istype(t, 'torch.IntTensor') == false)
   assert(env.istype(t, 'torch.Long') == false)

   -- test argcheck function serialization
   local f = argcheck{
      {name='arg', type='string'},
      call = function(arg)
         print(arg)
      end
   }
   local m = torch.MemoryFile()
   m:writeObject(f)
end

print('PASSED')
