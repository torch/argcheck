if not bit then
   require 'bit'
end

local argcheckenv = {type=type, argtypes={}}
setmetatable(argcheckenv, {__index=_G})
setfenv(1, argcheckenv)

local function callfunc(funcname, vars, argdefs)
   local txt = {}
   if #vars > 0 then
      -- defaulta
      for _,argdef in ipairs(argdefs) do
         if argdef.defaulta then
            local isvalid = false
            for _,var in ipairs(vars) do
               if var == argdef.defaulta then
                  isvalid = true
                  break
               end
            end
            if not isvalid then
               error(string.format('argument <%s> has a defaulta <%s> which is not a valid argument', argdef.name, argdef.defaulta))
            end
            table.insert(txt, string.format('%s = %s or %s', argdef.name, argdef.name, argdef.defaulta))
         end
      end
      table.insert(txt, string.format('return %s(%s)', funcname, table.concat(vars, ', ')))
   else
      table.insert(txt, string.format('return %s()', funcname))
   end
   return table.concat(txt, '\n')
end

local function generateargcheck__(txt, argdefs, funcname, vars, named)
   local ndef = 0
   local nreq = 0
   for _,argdef in ipairs(argdefs) do
      if named or not argdef.named then -- those are ignored in ordered arguments anyways
         if argdef.opt or argdef.default ~= nil or argdef.defaulta then
            ndef = ndef + 1
         else
            nreq = nreq + 1
         end
      end
   end

   for defmask=0,2^ndef-1 do
      local argidx = 0
      local defidx = 0
      local checks = {''} -- we save a spot for the (narg == ...)
      local reads = {}
      local hasvararg = false
      for _,argdef in ipairs(argdefs) do
         local isvalid = false
         if named or not argdef.named then
            if argdef.opt or argdef.default ~= nil or argdef.defaulta then
               defidx = defidx + 1
               if bit.band(defidx, defmask) ~= 0 then
                  isvalid = true
               end
            else
               isvalid = true
            end
            if isvalid then
               argidx = argidx + 1
               if argdef.vararg then
                  hasvararg = true
               end
               argdef.luaname = named and string.format('arg.%s', argdef.name) or string.format('select(%d, ...)', argidx)
               if argdef.check and argdef:check() then
                  table.insert(checks, argdef:check())
               end
               if argdef.read then
                  if argdef:read() then
                     table.insert(reads, argdef:read())
                  end
               else
                  table.insert(reads, string.format('%s = %s', argdef.name, argdef.luaname))
               end
            end
         end
         -- default reads
         if not isvalid and argdef.default ~= nil then
            if argdef.initdefault and argdef:initdefault() then
               table.insert(reads, string.format(argdef:initdefault()))
            else
               error(string.format('no support for default argument <%s>', argdef.name))
            end
         end
      end
      if not named and hasvararg then
         checks[1] = string.format('narg >= %d', argidx)
      else
         checks[1] = string.format('narg == %d', argidx)
      end
      table.insert(txt, string.format('if %s then ', table.concat(checks, ' and ')))
      if #reads > 0 then
         table.insert(txt, table.concat(reads, '\n'))
      end
      table.insert(txt, callfunc(funcname, vars, argdefs))
      table.insert(txt, 'end')
   end
end

local function generateargcheck(argdefs, funcname)
   local txt = {}
   local vars = {}
   local hasvararg = false

   for _,argdef in ipairs(argdefs) do
      assert(type(argdef.name) == 'string', string.format('argument name must be a string'))

      -- defined only once?
      if vars[argdef.name] then
         error(string.format('argument %s is defined twice', argdef.name))
      end

      -- is name self? (in which case we consider it as a method)
      if argdef.name == 'self' then
         assert(not argdef.opt, 'self cannot be optional')
         assert(not argdef.default, 'self cannot have a default')
         assert(not argdef.defaulta, 'self cannot have a defaulta')
         assert(not argdef.named, 'self cannot be named-only')
         assert(#vars == 0, 'self must be the first argument')
      end

      -- nonamed inconsistency?
      if argdef.named and argdefs.nonamed then
         error(string.format('argument %s is defined as named, but named argument are not allowed', argdef.name))
      end

      -- default inconsistency?
      if argdef.default and argdef.defaulta then
         error(string.format('argument %s defines <default> and <defaulta>, which is not allowed', argdef.name))
      end

      -- is it a defined type?
      if argdef.type then
         -- note: it was too painful to debug code
         -- when this was not enforced
         if argtypes[argdef.type] then
            setmetatable(argdef, {__index=argtypes[argdef.type]})
         else
            setmetatable(argdef, {__index=argtypes.__default})
         end
      else
         setmetatable(argdef, {__index=argtypes.__any})
      end

      assert(not argdef.initdefault or type(argdef.initdefault) == 'function', string.format('argument <%s> initdefault member must be a function', argdef.name))
      assert(not argdef.read or type(argdef.read) == 'function', string.format('argument <%s> read member must be a function', argdef.name))
      assert(not argdef.check or type(argdef.check) == 'function', string.format('argument <%s> check member must be a function', argdef.name))

      -- is it a vararg?
      if argdef.vararg then
         if hasvararg then
            error('multiple variable arguments are not allowed')
         end
         hasvararg = true
      else
         -- makes no sense, as an vararg is supposed to eat up all the remaining arguments
         if hasvararg and not argdef.named then
            error(string.format('argument <%s> is defined after a variable argument, which is not allowed', argdef.name))
         end
      end
      vars[argdef.name] = argdef
      table.insert(vars, argdef.name)
   end

   -- we enclose into a do...end because we might have several variations
   -- of the call
   table.insert(txt, 'do')
   if #vars > 0 then
      table.insert(txt, string.format('local %s', table.concat(vars, ', ')))
   end

   -- handling of ordered arguments
   generateargcheck__(txt, argdefs, funcname, vars, false)

   -- handling of named arguments
   if not argdefs.nonamed then
      if vars.self then
         local argdef = vars.self
         argdef.luaname = 'select(1, ...)'
         if argdef.check and argdef:check() then
            table.insert(txt, string.format("if narg == 2 and (%s) and type(select(2, ...)) == 'table' then", argdef:check()))
         else
            table.insert(txt, "if narg == 2 and type(select(2, ...)) == 'table' then")
         end
         table.insert(txt, "local arg = select(2, ...)")
         table.insert(txt, "local narg = 0")
         table.insert(txt, "self = select(1, ...)")
      else
         table.insert(txt, "if narg == 1 and type(select(1, ...)) == 'table' then")
         table.insert(txt, "local arg = select(1, ...)")
         table.insert(txt, "local narg = 0")
      end
      table.insert(txt, [[
for k,v in pairs(arg) do
   narg = narg + 1
end]])
      generateargcheck__(txt, argdefs, funcname, vars, true)

      table.insert(txt, 'end') -- of named check
   end

   -- do...end
   table.insert(txt, 'end')

   return table.concat(txt, '\n')
end

local function generateusage(argdefs)
   local txt
   if argdefs.help then
      txt = {argdefs.help, '', '> arguments:', argdefs.nonamed and '(' or '{'}
   else
      txt = {'> arguments:', argdefs.nonamed and '(' or '{'}
   end
   local size = 0
   for _,argdef in ipairs(argdefs) do
      size = math.max(size, #argdef.name)
   end
   local arg = {}
   local hlp = {}
   for _,argdef in ipairs(argdefs) do
      table.insert(arg,
                   ((argdef.named or argdef.opt or argdef.default ~= nil or argdef.defaulta) and '[' or ' ')
                   .. argdef.name .. string.rep(' ', size-#argdef.name)
                   .. (argdef.type and (' = ' .. argdef.type) or '')
                .. ((argdef.named or argdef.opt or argdef.default ~= nil or argdef.defaulta) and ']' or '')
             .. (argdef.named and '*' or ''))
      
      local default
      if argdef.defaulta then
         default = string.format(' [defaulta=%s]', argdef.defaulta)
      elseif type(argdef.default) == 'nil' then
         default = ''
      elseif type(argdef.default) == 'string' then
         default = string.format(' [default=%s]', argdef.default)
      elseif type(argdef.default) == 'number' then
         default = string.format(' [default=%s]', argdef.default)
      elseif type(argdef.default) == 'boolean' then
         default = string.format(' [default=%s]', argdef.default and 'true' or 'false')
      else
         default = ' [has default value]'
      end
      table.insert(hlp, (argdef.help or '') .. default)
   end

   local size = 0
   for i=1,#arg do
      size = math.max(size, #arg[i])
   end

   for i=1,#arg do
      table.insert(txt, string.format("  %s %s -- %s", arg[i], string.rep(' ', size-#arg[i]), hlp[i]))
   end

   table.insert(txt, argdefs.nonamed and ')' or '}')
   return table.concat(txt, '\n')
end

local function argcheck__(argfuncs, ismethod)
   if ismethod then
      for i=1,#argfuncs/2 do
         local args = argfuncs[(i-1)*2+1]
         if args.self then
            for _,arg in ipairs(args) do
               if type(arg) == 'table' and arg.name == args.self then
                  arg.name = 'self'
                  break
               end
            end
         end
         for _,arg in ipairs(args) do
            if type(arg) == 'table' and arg.method then
               assert(type(arg.method) == 'table', 'method modifier must be a table')
               local methodsav = {}
               for k,v in pairs(arg.method) do
                  methodsav[k] = arg[k]
                  arg[k] = v
               end
               arg.methodsav = methodsav
            end
         end
      end
   end

   -- note: generateargcheck checks if the argdefs are valid in all possible ways
   -- so we start by that
   local code = {'return function(...)', "local narg = select('#', ...)"}
   for i=1,#argfuncs/2 do
      table.insert(code, generateargcheck(argfuncs[(i-1)*2+1], 'func' .. i))
   end
   table.insert(code, "usage()")
   table.insert(code, "end")

   -- ok, now we generate the usage
   -- this one is going to be an upvalue for argcheck
   local err
   local usage = {'return function()', 'print[['}
   if argfuncs.help then
      table.insert(usage, argfuncs.help)
      table.insert(usage, '')
   end
   local hlp = {}
   for i=1,#argfuncs/2 do
      table.insert(hlp, generateusage(argfuncs[(i-1)*2+1]))
   end
   table.insert(usage, table.concat(hlp, '\n\nor\n\n'))
   table.insert(usage, ']]')
   table.insert(usage, 'error("invalid arguments")')
   table.insert(usage, 'end')
   usage = table.concat(usage, '\n')
--   print(usage)
   usage, err = loadstring(usage)
   if not usage then
      error(err)
   end
   usage = usage()

   -- setup the environment properly
   -- type and select must be fast, so we put them as direct upvalues
   local env = {usage=usage}
   setmetatable(env, {__index=argcheckenv})

   for i=1,#argfuncs/2 do
      env['func' .. i] = argfuncs[(i-1)*2+2]
   end
   code = table.concat(code, '\n')
   if argfuncs.debug then
      print(code)
   end
   code, err = loadstring(code)
   if not code then
      error(err)
   end
   setfenv(code, env)

   -- put back things as they were before
   -- to avoid any kind of surprises
   if ismethod then
      for i=1,#argfuncs/2 do
         local args = argfuncs[(i-1)*2+1]
         if args.self then
            for _,arg in ipairs(args) do
               if type(arg) == 'table' and arg.name == 'self' then
                  arg.name = arg.self
                  break
               end
            end
         end
         for _,arg in ipairs(args) do
            if type(arg) == 'table' and arg.method then
               assert(type(arg.method) == 'table', 'method modifier must be a table')
               local methodsav = arg.methodsav
               for k,v in pairs(arg.method) do
                  arg[k] = methodsav[k]
               end
               arg.methodsav = nil
            end
         end
      end
   end

   return code()
end

local function argcheck(...)
   local argfuncs
   if select('#', ...) == 1 and type(select(1, ...)) == 'table' then
      argfuncs = select(1, ...)
   else
      argfuncs = {...}
   end

   local nargfuncs = #argfuncs/2
   local valid = (nargfuncs == math.floor(nargfuncs))
   local hasself = false
   if valid then
      for i=1,nargfuncs do
         if type(argfuncs[(i-1)*2+1]) ~= 'table' or type(argfuncs[(i-1)*2+2]) ~= 'function' then
            valid = false
            break
         end
         if argfuncs[(i-1)*2+1].self then
            hasself = true
         end
      end
   end
   if not valid then
      error('expecting (table, function, ...) | {table, function, table, function ... }')
   end
   if hasself then
      return argcheck__(argfuncs, false), argcheck__(argfuncs, true)
   else
      return argcheck__(argfuncs)
   end
end

package.loaded.argcheck = argcheck
require 'argcheck.argtypes'

return argcheck
