local env = require 'argcheck.env'
local utils = require 'argcheck.utils'
local doc = require 'argcheck.doc'
local ACN = require 'argcheck.graph'

local setupvalue = utils.setupvalue
local getupvalue = utils.getupvalue
local loadstring = loadstring or load

local sdascii
pcall(function()
         sdascii = require 'sundown.ascii'
      end)

-- If you are not use LuaJIT
if not bit then
   if _VERSION == "Lua 5.2" then
      require 'bit32'
   else
      require 'bit'
   end
end

local function countbits(n)
   local c = 0
   while n > 0 do
      n = bit.band(n, n-1)
      c = c + 1
   end
   return c
end

local function rule2arg(rule, aidx, named)
   if named then
      return string.format('arg.%s', rule.name)
   else
      return string.format('select(%d, ...)', aidx)
   end
end

local function generateargp(rules)
   local txt = {}
   for idx, rule in ipairs(rules) do
      local isopt = rule.opt or rule.default ~= nil or rules.defauta or rule.defaultf
      table.insert(txt,
                   (isopt and '[' or '')
                      .. ((idx == 1) and '' or ', ')
                      .. rule.name
                      .. (isopt and ']' or ''))
   end
   return table.concat(txt)
end

local function generateargt(rules)
   local txt = {}
   table.insert(txt, '```')

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
      table.insert(hlp, (rule.help or '') .. (rule.doc or '') .. default)
   end

   local size = 0
   for i=1,#arg do
      size = math.max(size, #arg[i])
   end

   for i=1,#arg do
      table.insert(txt, string.format("  %s %s -- %s", arg[i], string.rep(' ', size-#arg[i]), hlp[i]))
   end
   table.insert(txt, '```')

   txt = table.concat(txt, '\n')

   return txt
end

local function generateusage(rules)
   local doc = rules.help or rules.doc

   if doc then
      doc = doc:gsub('@ARGP',
                     function()
                        return generateargp(rules)
                     end)

      doc = doc:gsub('@ARGT',
                     function()
                        return generateargt(rules)
                     end)
   end

   if not doc then
      doc = '\n*Arguments:*\n' .. generateargt(rules)
   end

   if sdascii then
      doc = sdascii.render(doc)
   end

   return doc
end

local function generaterules(rules)

   local nopt = 0   
   local nrule = 0
   for _, rule in ipairs(rules) do
      if rule.default ~= nil or rule.defaulta or rule.defaultf or rule.opt then
         nopt = nopt + 1
      end
      nrule = nrule + 1
   end

   local root = ACN.new('ROOT')
   local upvalues = {istype=env.istype}

   for optmask=0,2^nopt-1 do
      local rulemask = {}
      local ridx = 1
      local optidx = 0
      while ridx <= nrule do
         local rule = rules[ridx]
         local skiprule = false

         if rule.default ~= nil or rule.defaulta or rule.defaultf or rule.opt then
            optidx = optidx + 1
            if bit.band(2^(optidx-1), optmask) == 0 then
               skiprule = true
            end
         end
         
         if not skiprule then
            table.insert(rulemask, ridx)
         end
            
         ridx = ridx + 1
      end

      if not rules.noordered then
         root:addpath(rules, rulemask)
      end

      if not rules.nonamed then
         root:addpath(rules, rulemask, true)
      end
   end

   local code = root:generate(upvalues)

   local stuff = root:print()
   f = io.open('zozo.dot', 'w')
   f:write(stuff)
   f:close()

   return code, upvalues

end

local function argcheck(rules)

   -- basic checks
   assert(not (rules.noordered and rules.nonamed), 'rules must be at least ordered or named')
   assert(rules.help == nil or type(rules.help) == 'string', 'rules help must be a string or nil')
   assert(rules.doc == nil or type(rules.doc) == 'string', 'rules doc must be a string or nil')
   assert(not (rules.doc and rules.help), 'choose between doc or help, not both')
   for _, rule in ipairs(rules) do
      assert(rule.name, 'rule must have a name field')
      assert(rule.type == nil or type(rule.type) == 'string', 'rule type must be a string or nil')
      assert(rule.help == nil or type(rule.help) == 'string', 'rule help must be a string or nil')
      assert(rule.doc == nil or type(rule.doc) == 'string', 'rule doc must be a string or nil')
      assert(rule.check == nil or type(rule.check) == 'function', 'rule check must be a function or nil')
      assert(rule.defaulta == nil or type(rule.defaulta) == 'string', 'rule defaulta must be a string or nil')
      assert(rule.defaultf == nil or type(rule.defaultf) == 'function', 'rule defaultf must be a function or nil')
   end

   local code, upvalues = generaterules(rules)
   print(code)
   local func, err = loadstring(code, 'argcheck')
   if not func then
      error(string.format('could not generate argument checker: %s', err))
   end
   func = func()

   for upvaluename, upvalue in pairs(upvalues) do
      setupvalue(func, upvaluename, upvalue)
   end

   return func
end

env.argcheck = argcheck

return argcheck
