local argcheck = require 'argcheck'
local ffi = require 'ffi'
local class = require 'class'

local SZ  = tonumber(arg[1])
local N   = tonumber(arg[2])
local scale = tonumber(arg[3]) or 1
local dbg = arg[4] == '1'
local named = arg[5] == '1'

if named then
   print('warning: using named arguments!')
end

ffi.cdef[[

typedef struct THLongStorage THLongStorage;
THLongStorage* THLongStorage_newWithSize2(long, long);
void THLongStorage_free(THLongStorage *storage);

typedef struct THGenerator THGenerator;
THGenerator* THGenerator_new();
void THRandom_manualSeed(THGenerator *_generator, unsigned long the_seed_);

typedef struct THDoubleTensor THDoubleTensor;
THDoubleTensor *THDoubleTensor_new(void);
void THDoubleTensor_free(THDoubleTensor *self);
void THDoubleTensor_rand(THDoubleTensor *r_, THGenerator *_generator, THLongStorage *size);
void THDoubleTensor_add(THDoubleTensor *r_, THDoubleTensor *t, double value);
void THDoubleTensor_cadd(THDoubleTensor *r_, THDoubleTensor *t, double value, THDoubleTensor *src);
double THDoubleTensor_normall(THDoubleTensor *t, double value);

]]

local status, C = pcall(ffi.load, 'TH')
if not status then
   error('please specify path to libTH in your (DY)LD_LIBRARY_PATH')
end

local DoubleTensor = class('torch.DoubleTensor', ffi.typeof('THDoubleTensor&'))

function DoubleTensor.new()
   local self = C.THDoubleTensor_new()
   self = ffi.cast('THDoubleTensor&', self)
   ffi.gc(self, C.THDoubleTensor_free)
   return self
end

function DoubleTensor:norm(l)
   l = l or 2
   return tonumber(C.THDoubleTensor_normall(self, l))
end

ffi.metatype('THDoubleTensor', getmetatable(DoubleTensor))

local _gen = C.THGenerator_new()
C.THRandom_manualSeed(_gen, 1111)

local function rand(a, b)
   local size = C.THLongStorage_newWithSize2(a, b)
   local self = DoubleTensor()
   C.THDoubleTensor_rand(self, _gen, size)
   C.THLongStorage_free(size)
   return self
end

local add
local dotgraph

for _, RealTensor in ipairs{--'torch.ByteTensor', 'torch.ShortTensor', 'torch.FloatTensor',
--'torch.LongTensor', 'torch.IntTensor', 'torch.CharTensor',
'torch.DoubleTensor'} do

   add = argcheck{
      chain = add,
      {name="res", type=RealTensor, opt=true},
      {name="src", type=RealTensor},
      {name="value", type="number"},
      call =
         function(res, src, value)
            res = res or DoubleTensor()
            C.THDoubleTensor_add(res, src, value)
            return res
         end
   }

   add, dotgraph = argcheck{
      debug = dbg,
      overload = add,
      {name="res", type=RealTensor, opt=true},
      {name="src1", type=RealTensor},
      {name="value", type="number", default=1},
      {name="src2", type=RealTensor},
      call =
         function(res, src1, value, src2)
            res = res or torch.DoubleTensor()
            C.THDoubleTensor_cadd(res, src1, value, src2)
            return res
         end
   }

end

if dotgraph then
   local f = io.open('argtree.dot', 'w')
   f:write(dotgraph)
   f:close()
end

local x = rand(SZ, SZ)
local y = rand(SZ, SZ)

print('x', x:norm())
print('y', x:norm())
print('running')

if named then
   local clk = os.clock()
   if scale == 1 then
      for i=1,N do
         add{res=y, src=x, value=5}
         add{res=y, src1=x, src2=y}
      end
   else
      for i=1,N do
         add{res=y, src=x, value=5}
         add{res=y, src1=x, value=scale, src2=y}
      end
   end
   print('time (s)', os.clock()-clk)
else
   local clk = os.clock()
   if scale == 1 then
      for i=1,N do
         add(y, x, 5)
         add(y, x, y)
      end
   else
      for i=1,N do
         add(y, x, 5)
         add(y, x, scale, y)
      end
   end
   print('time (s)', os.clock()-clk)
end

print('x', x:norm())
print('y', y:norm())
