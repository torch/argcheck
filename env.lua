local env = {}

-- user configurable function
function env.istype(obj, typename)
   local mt = getmetatable(obj)
   if type(mt) == 'table' then
      local objtype = rawget(mt, '__typename')
      if objtype then
         return objtype == typename
      end
   end
   return type(obj) == typename
end

return env
