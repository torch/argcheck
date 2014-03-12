local env = require 'argcheck.env'
local setupvalue = env.setupvalue
local getupvalue = env.getupvalue

-- If you are not use LuaJIT
if not bit then
   require 'bit'
end

local function countbits(n)
   local c = 0
   while n > 0 do
      n = bit.band(n, n-1)
      c = c + 1
   end
   return c
end

local function argname2idx(rules, name)
   for idx, rule in ipairs(rules) do
      if rule.name == name then
         return idx
      end
   end
   error(string.format('invalid defaulta name <%s>', name))
end

local function rule2arg(rule, aidx, named)
   if named then
      return string.format('arg.%s', rule.name)
   else
      return string.format('select(%d, ...)', aidx)
   end
end

local function generateusage(rules)
   local txt = {}
   if rules.help then
      table.insert(txt, rules.help)
   end
   table.insert(txt, 'arguments:')
   table.insert(txt, '{')

   local size = 0
   for _,rule in ipairs(rules) do
      size = math.max(size, #rule.name)
   end
   local arg = {}
   local hlp = {}
   for _,rule in ipairs(rules) do
      table.insert(arg,
                   ((rule.opt or rule.default ~= nil or rule.defaulta or rule.defaultf) and '[' or ' ')
                   .. rule.name .. string.rep(' ', size-#rule.name)
                   .. (rule.type and (' = ' .. rule.type) or '')
                .. ((rule.opt or rule.default ~= nil or rule.defaulta or rule.defaultf) and ']' or '')
          )
      
      local default = ''
      if rule.defaulta then
         default = string.format(' [defaulta=%s]', rule.defaulta)
      elseif rule.defaultf then
         default = string.format(' [has default]')
      elseif type(rule.default) ~= 'nil' then
         if type(rule.default) == 'string' then
            default = string.format(' [default=%s]', rule.default)
         elseif type(rule.default) == 'number' then
            default = string.format(' [default=%s]', rule.default)
         elseif type(rule.default) == 'boolean' then
            default = string.format(' [default=%s]', rule.default and 'true' or 'false')
         else
            default = ' [has default value]'
         end
      end
      table.insert(hlp, (rule.help or '') .. default)
   end

   local size = 0
   for i=1,#arg do
      size = math.max(size, #arg[i])
   end

   for i=1,#arg do
      table.insert(txt, string.format("  %s %s -- %s", arg[i], string.rep(' ', size-#arg[i]), hlp[i]))
   end

   table.insert(txt, '}')
   return table.concat(txt, '\n')
end

local function generaterules(rules, named, hasordered)
   local txt = {}

   local nopt = 0   
   local nrule = 0
   for _, rule in ipairs(rules) do
      if rule.default or rule.defaulta or rule.defaultf or rule.opt then
         nopt = nopt + 1
      end
      nrule = nrule + 1
   end

   local indent = '  '
   if named then
      table.insert(txt, string.format('  %sif narg == 1 and isoftype(select(1, ...), "table") then', hasordered and 'else' or ''))
      table.insert(txt, '    local arg = select(1, ...)')
      table.insert(txt, '    local narg = 0')
      for _, rule in ipairs(rules) do
         table.insert(txt, string.format('    if arg.%s then narg = narg + 1 end', rule.name))
      end
--      table.insert(txt, '    for _, __ in pairs(arg) do narg = narg + 1 end') NYI
--      table.insert(txt, '    table.foreach(arg, function() narg = narg + 1 end)') NYI
      indent = '    '
   end

   for optmask=0,2^nopt-1 do
      local ruletxt = {}
      local assntxt = {}
      local defatxt = {}
      table.insert(ruletxt, string.format('%s%sif narg == %d', indent, optmask == 0 and '' or 'else', nrule-nopt+countbits(optmask)))

      local narg = nrule-nopt+countbits(optmask)
      local ridx = 1
      local aidx = 1
      local optidx = 0
      while ridx <= nrule do
         local rule = rules[ridx]
         local skiprule = false

         if rule.default or rule.defaulta or rule.defaultf or rule.opt then
            optidx = optidx + 1
            if bit.band(optidx, optmask) == 0 then
               if rule.defaulta then
                  table.insert(defatxt, string.format('%s  arg%d = arg%d', indent, ridx, argname2idx(rules, rule.defaulta)))
               end
               skiprule = true
            end
         end
         
         if not skiprule and aidx <= narg then
            local checktxt
            if rule.opt and rule.type then
               checktxt = string.format('(isoftype(%s, "%s") or isoftype(%s, "nil"))', rule2arg(rule, aidx, named), rule.type, rule2arg(rule, aidx, named))
            elseif rule.opt and not rule.type then -- can be anything
            elseif rule.type then
               checktxt = string.format('isoftype(%s, "%s")', rule2arg(rule, aidx, named), rule.type)
            else
               checktxt = string.format('not isoftype(%s, "nil")', rule2arg(rule, aidx, named))
            end
            if rule.check then
               checktxt = string.format('%s%s%sarg%dc(%s)%s',
                                        checktxt and '(' or '',
                                        checktxt and checktxt or '',
                                        checktxt and ' and ' or '',
                                        ridx,
                                        rule2arg(rule, aidx, named),
                                        checktxt and ')' or '')
            end
            table.insert(ruletxt, checktxt)
            table.insert(assntxt, string.format('%s  arg%d = %s', indent, ridx, rule2arg(rule, aidx, named)))
            aidx = aidx + 1
         end
            
         ridx = ridx + 1
      end
      table.insert(txt, table.concat(ruletxt, ' and ') .. ' then')
      if #assntxt > 0 then
         table.insert(txt, table.concat(assntxt, '\n'))
      end
      if #defatxt > 0 then
         table.insert(txt, table.concat(defatxt, '\n'))
      end
   end
   return table.concat(txt, '\n')
end

local function argcheck(rules)
   local txt = {'-- check'}

   -- basic checks
   assert(not (rules.noordered and rules.nonamed), 'rules must be at least ordered or named')
   assert(rules.help == nil or type(rules.help) == 'string', 'rules help must be a string or nil')
   for _, rule in ipairs(rules) do
      assert(rule.name, 'rule must have a name field')
      assert(rule.type == nil or type(rule.type) == 'string', 'rule type must be a string or nil')
      assert(rule.help == nil or type(rule.help) == 'string', 'rule help must be a string or nil')
      assert(rule.check == nil or type(rule.check) == 'function', 'rule check must be a function or nil')
      assert(rule.defaulta == nil or type(rule.defaulta) == 'string', 'rule defaulta must be a string or nil')
      assert(rule.defaultf == nil or type(rule.defaultf) == 'function', 'rule defaultf must be a function or nil')
   end

   -- upvalues
   table.insert(txt, 'local isoftype')
   table.insert(txt, 'local usage')
   table.insert(txt, 'local chain')
   if rules.call then
      table.insert(txt, 'local call')
   end
   for ridx, rule in ipairs(rules) do
      if rule.default or rule.defaultf then
         table.insert(txt, string.format('local arg%dd', ridx))
      end
      if rule.check then
         table.insert(txt, string.format('local arg%dc', ridx))
      end
   end

   table.insert(txt, 'return function(...)')
   local ret = {}
   for ridx, rule in ipairs(rules) do
      if rule.default then
         table.insert(txt, string.format('  local arg%d = arg%dd', ridx, ridx))
      elseif rule.defaultf then
         table.insert(txt, string.format('  local arg%d = arg%dd()', ridx, ridx))
      else
         table.insert(txt, string.format('  local arg%d', ridx))
      end
      if rules.pack then
         table.insert(ret, string.format('%s=arg%d', rule.name, ridx))
      else
         table.insert(ret, string.format('arg%d', ridx))
      end
   end
   ret = table.concat(ret, ', ')
   if rules.pack then
      ret = '{' .. ret .. '}'
   end
   if rules.call then
      ret = 'call(' .. ret .. ')'
   end
   if rules.quiet then
      ret = 'true' .. (#ret > 0 and ', ' or '') .. ret
   end

   table.insert(txt, '  local narg = select("#", ...)')

   if not rules.noordered then
      table.insert(txt, generaterules(rules, false, not rules.noordered))
   end
   if not rules.nonamed then
      table.insert(txt, generaterules(rules, true, not rules.noordered))
      table.insert(txt, '    elseif chain then')
      table.insert(txt, '      return chain(...)')
      table.insert(txt, '    else')
      if rules.quiet then
         table.insert(txt, '      return false, usage')
      else
         table.insert(txt, '      error(usage, 2)')
      end
      table.insert(txt, '    end')
      table.insert(txt, string.format('    return %s', ret))
   end
   table.insert(txt, '  elseif chain then')
   table.insert(txt, '    return chain(...)')
   table.insert(txt, '  else')
   if rules.quiet then
         table.insert(txt, '    return false, usage')
   else
      table.insert(txt, '    error(usage, 2)')
   end
   table.insert(txt, '  end')
   table.insert(txt, string.format('  return %s', ret))
   table.insert(txt, 'end')

   if rules.debug then
      print(table.concat(txt, '\n'))
   end

   local func, err = loadstring(table.concat(txt, '\n'), 'argcheck')
   if not func then
      error(string.format('could not generate argument checker: %s', err))
   end
   func = func()

   for ridx, rule in ipairs(rules) do
      if rule.default or rule.defaultf then
         setupvalue(func, string.format('arg%dd', ridx), rule.default or rule.defaultf)
      end
      if rule.check then
         setupvalue(func, string.format('arg%dc', ridx), rule.check)
      end
   end

   setupvalue(func, 'isoftype', env.isoftype)
   setupvalue(func, 'usage', generateusage(rules))
   if rules.call then
      setupvalue(func, 'call', rules.call)
   end

   if rules.chain then
      local tail = rules.chain
      while true do
         local next = getupvalue(tail, 'chain')
         if next then
            tail = next
         else
            break
         end
      end
      setupvalue(tail, 'chain', func)

      local chainusage = {}
      local tail = rules.chain
      repeat
         local usage = getupvalue(tail, 'usage')
         if usage then
            table.insert(chainusage, usage)
            setupvalue(tail, 'usage', nil)
         end
         tail = getupvalue(tail, 'chain')
      until not tail
      setupvalue(func, 'usage', table.concat(chainusage, '\n\nor\n\n'))

      return rules.chain
   end

   return func
end

env.argcheck = argcheck

return argcheck
