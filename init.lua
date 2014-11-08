local env = require 'argcheck.env'
local utils = require 'argcheck.utils'
local doc = require 'argcheck.doc'
local ACN = require 'argcheck.graph'

local setupvalue = utils.setupvalue
local getupvalue = utils.getupvalue
local loadstring = loadstring or load

-- If you are not use LuaJIT
if not bit then
   if _VERSION == "Lua 5.2" then
      require 'bit32'
   else
      require 'bit'
   end
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

   local graph
   if rules.chain or rules.overload then
      local status
      status, graph = pcall(getupvalue, rules.chain or rules.overload, 'graph')
      if not status then
         error('trying to overload a non-argcheck function')
      end
   else
      graph = ACN.new('@')
   end
   local upvalues = {istype=env.istype, graph=graph}

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
         graph:addpath(rules, rulemask)
      end

      if not rules.nonamed then
         graph:addpath(rules, rulemask, true)
      end
   end

   local code = graph:generate(upvalues)

   return code, upvalues
end

local function argcheck(rules)

   -- basic checks
   assert(not (rules.noordered and rules.nonamed), 'rules must be at least ordered or named')
   assert(rules.help == nil or type(rules.help) == 'string', 'rules help must be a string or nil')
   assert(rules.doc == nil or type(rules.doc) == 'string', 'rules doc must be a string or nil')
   assert(rules.chain == nil or type(rules.chain) == 'function', 'rules chain must be a function or nil')
   assert(rules.overload == nil or type(rules.overload) == 'function', 'rules overload must be a function or nil')
   assert(not (rules.chain and rules.overload), 'rules must have either overload [or chain (deprecated)]')
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
   if rules.debug then
      print(code)
   end
   local func, err = loadstring(code, 'argcheck')
   if not func then
      error(string.format('could not generate argument checker: %s', err))
   end
   func = func()

   for upvaluename, upvalue in pairs(upvalues) do
      setupvalue(func, upvaluename, upvalue)
   end

   if rules.debug then
      return func, upvalues.graph:print()
   else
      return func
   end
end

env.argcheck = argcheck

return argcheck
