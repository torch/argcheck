local argcheck = require 'torch.argcheck'
local argcheckenv = getfenv(argcheck)

function argcheckenv.istype(obj, typename)
   return type(ob) == typename
end

local argtypes = argcheckenv.argtypes

argtypes["__default"] = {
   check = function(self)
              return string.format("istype(%s, '%s')", self.luaname, self.type)
           end
}

argtypes["numbers"] = {
   vararg = true, -- if needed, one can override it to false
   
   check = function(self)
              local idx = self.luaname:match('select%((%d+), %.%.%.%)')
              if idx then -- ordered arguments
                 if self.vararg then -- can be (1, 2, 3) or {1, 2, 3}
                    return string.format([[
    (function(...)
        if %d == narg and type(select(%d, ...)) == 'table' then
           %s = select(%d, ...)
           if type(%s) ~= 'table' or #%s == 0 then
              %s = nil
              return false
           end
           for k,v in pairs(%s) do
              if type(k) ~= 'number' or type(v) ~= 'number' then
                 %s = nil
                 return false
              end
           end
        else -- here we have something anyways: only check it is a number
           %s = {}
           for i=%d,narg do
              local z = select(i, ...)
              if type(z) ~= 'number' then
                 %s = nil
                 return false
              end
              table.insert(%s, z)
           end
        end
        return true
     end)(...) ]], idx, idx, self.name, idx, self.name, self.name, self.name, self.name, self.name, self.name, idx, self.name, self.name)
                 else -- can only be {1, 2, 3}
                    return string.format([[
    (function(...)
        %s = select(%d, ...)
        if type(%s) ~= 'table' or #%s == 0 then
           %s = nil
           return false
        end
        for k,v in ipairs(%s) do
           if type(k) ~= 'number' or type(v) ~= 'number' then
              %s = nil
              return false
           end
        end
        return true
     end)(...) ]], self.name, idx, self.name, self.name, self.name, self.name, self.name)
                 end
              else -- named arguments
                 return string.format(
                    [[
  (function(...)
      if type(%s) ~= 'table' or #(%s) == 0 then
         return false
      end
      for k,v in ipairs(%s) do
         if type(k) ~= 'number' or type(v) ~= 'number' then
            return false
         end
      end
      %s = %s
      return true
   end)(...) ]], self.luaname, self.luaname, self.luaname, self.name, self.luaname)
              end
           end,

   read = function(self)
          end
}

argtypes["number"] = {
   check = function(self)
              return string.format("type(%s) == 'number'", self.luaname)
           end,

   initdefault = function(self)
                    assert(type(self.default) == 'number', string.format('argument <%s> default should be a number', self.name))
                    return string.format('%s = %s', self.name, self.default)
                 end
}

argtypes["boolean"] = {
   check = function(self)
              return string.format("type(%s) == 'boolean'", self.luaname)
           end,

   initdefault = function(self)
                    assert(type(self.default) == 'boolean', string.format('argument <%s> default should be a boolean', self.name))
                    return string.format('%s = %s', self.name, self.default)
                 end
}

argtypes["string"] = {
   check = function(self)
              return string.format("type(%s) == 'string'", self.luaname)
           end,

   initdefault = function(self)
                    assert(type(self.default) == 'string', string.format('argument <%s> default should be a string', self.name))
                    return string.format('%s = "%s"', self.name, self.default)
                 end
}

for _,Tensor in ipairs{'torch.ByteTensor',
                       'torch.CharTensor',
                       'torch.ShortTensor',
                       'torch.IntTensor',
                       'torch.LongTensor',
                       'torch.FloatTensor',
                       'torch.DoubleTensor'} do

   argtypes[Tensor] = {
      check = function(self)
                 if self.dim then
                    return string.format("type(%s) == '" .. Tensor .. "' and (%s).__nDimension == %d", self.luaname, self.luaname, self.dim)
                 else
                 return string.format("type(%s) == '" .. Tensor .. "'", self.luaname)
              end
           end,

      initdefault = function(self)
                       return string.format('%s = %s()', self.name, Tensor)
                    end
   }
end

for _,Storage in ipairs{'torch.ByteStorage',
                        'torch.CharStorage',
                        'torch.ShortStorage',
                        'torch.IntStorage',
                        'torch.LongStorage',
                        'torch.FloatStorage',
                        'torch.DoubleStorage'} do

   argtypes[Storage] = {
      check = function(self)
                 if self.size then
                    return string.format("type(%s) == '" .. Storage .. "' and (%s).__size == %d", self.luaname, self.luaname, self.size)
                 else
                 return string.format("type(%s) == '" .. Storage .. "'", self.luaname)
              end
           end,

      initdefault = function(self)
                       return string.format('%s = %s()', self.name, Storage)
                    end
   }
end
