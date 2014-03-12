local env = {}

-- user configurable function
function env.istype(obj, typename)
   return type(obj) == typename
end

return env
