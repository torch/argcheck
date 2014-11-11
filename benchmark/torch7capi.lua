require 'torch'

local SZ  = tonumber(arg[1])
local N   = tonumber(arg[2])
local scale = tonumber(arg[3]) or 1

torch.manualSeed(1111)

local x = torch.rand(SZ,SZ)
local y = torch.rand(SZ,SZ)

print('x', x:norm())
print('y', x:norm())
print('running')

local clk = os.clock()
if scale == 1 then
   for i=1,N do
      torch.add(y, x, 5)
      torch.add(y, x, y)
   end
else
   for i=1,N do
      torch.add(y, x, 5)
      torch.add(y, x, scale, y)
   end
end
print('time (s)', os.clock()-clk)

print('x', x:norm())
print('y', y:norm())
