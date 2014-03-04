local env = {}

-- user configurable function
function env.isoftype(obj, typename)
   return type(obj) == typename
end

return env
