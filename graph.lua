local usage = require 'argcheck.usage'
local utils = require 'argcheck.utils'

local function argname2idx(rules, name)
   for idx, rule in ipairs(rules) do
      if rule.name == name then
         return idx
      end
   end
   error(string.format('invalid defaulta name <%s>', name))
end

local function table2id(tbl)
   -- DEBUG: gros hack de misere
   return tostring(tbl):match('0x([^%s]+)')
end

local function func2id(func)
   -- DEBUG: gros hack de misere
   return tostring(func):match('0x([^%s]+)')
end

local function rules2maskedrules(rules, rulesmask, rulestype)
   local maskedrules = {}
   for ridx=1,#rulesmask do
      local rule = utils.duptable(rules[ridx])
      rule.__ridx = ridx
      if rulestype == 'O' then
         rule.name = nil
      elseif rulestype == 'M' and ridx == 1 then -- self?
         rule.name = nil
      end

      local rulemask = rulesmask:sub(ridx,ridx)
      if rulemask == '1' then
         table.insert(maskedrules, rule)
      elseif rulemask == '2' then
      elseif rulemask == '3' then
         rule.type = 'nil'
         rule.check = nil
         table.insert(maskedrules, rule)
      end
   end
   return maskedrules
end

local function rules2defaultrules(rules, rulesmask, rulestype)
   local defaultrules = {}
   for ridx=1,#rulesmask do
      local rule = utils.duptable(rules[ridx])
      rule.__ridx = ridx
      if rulestype == 'O' then
         rule.name = nil
      elseif rulestype == 'M' and ridx == 1 then -- self?
         rule.name = nil
      end

      local rulemask = rulesmask:sub(ridx,ridx)
      if rulemask == '1' then
      elseif rulemask == '2' then
         table.insert(defaultrules, rule)
      elseif rulemask == '3' then
      end
   end
   return defaultrules
end

local ACN = {}

function ACN.new(typename, name, check, rules, rulesmask, rulestype)
   assert(typename)
   local self = {}
   setmetatable(self, {__index=ACN})
   self.type = typename
   self.name = name
   self.check = check
   self.rules = rules
   self.rulesmask = rulesmask
   self.rulestype = rulestype
   self.next = {}
   self.n = 0
   return self
end

function ACN:add(node)
   table.insert(self.next, node)
   self.n = self.n + 1
end

function ACN:match(rules)
   local head = self
   for idx=1,#rules do
      local rule = rules[idx]
      local matched = false
      for n=1,head.n do
         if head.next[n].type == rule.type
         and head.next[n].check == rule.check
         and head.next[n].name == rule.name then
            head = head.next[n]
            matched = true
            break
         end
      end
      if not matched then
         return head, idx-1
      end
   end
   return head, #rules
end

function ACN:hasruletype(ruletype)
   local hasruletype
   self:apply(function(self)
                 if self.rulestype == ruletype then
                    hasruletype = true
                 end
              end)
   return hasruletype
end

function ACN:addpath(rules, rulesmask, rulestype) -- 'O', 'N', 'M'
   -- DEBUG: on peut aussi imaginer avoir d'abord mis
   -- les no-named, et ensuite les named!!

   assert(rules)
   assert(rulesmask)
   assert(rulestype)

   local maskedrules = rules2maskedrules(rules, rulesmask, rulestype)

   if rulestype == 'N' then
      table.insert(maskedrules, 1, {type='table'})
   end

   if rulestype == 'M' then
      table.insert(maskedrules, 2, {type='table'})
   end

   local head, idx = self:match(maskedrules)

   if idx == #maskedrules then
      -- check we are not overwriting something here
      if not rules.force and head.rules and rules ~= head.rules then
         error('argcheck rules led to ambiguous situations')
      end
      head.rules = rules
      head.rulesmask = rulesmask
      head.rulestype = rulestype
   end
   for idx=idx+1,#maskedrules do
      local rule = maskedrules[idx]
      local node = ACN.new(rule.type,
                           rule.name,
                           rule.check,
                           idx == #maskedrules and rules or nil,
                           idx == #maskedrules and rulesmask or nil,
                           idx == #maskedrules and rulestype or nil)
      head:add(node)
      head = node
   end

   -- special trick: mark self
   if rulestype == 'M' then
      local head, idx = self:match({maskedrules[1]}) -- find self
      assert(idx == 1, 'internal bug, please report')
      head.isself = true
   end

end

function ACN:id()
   return table2id(self)
end

function ACN:print(txt)
   local isroot = not txt
   txt = txt or {'digraph ACN {'}
   table.insert(txt, 'edge [penwidth=.3 arrowsize=0.8];')
   table.insert(txt, string.format('id%s [label="%s%s%s%s" penwidth=.1 fontsize=10 style=filled fillcolor="%s"];',
                                   self:id(),
                                   self.type,
                                   self.isself and '*' or '',
                                   self.check and ' <check>' or '',
                                   self.name and string.format(' (%s)', self.name) or '',
                                   self.rules and '#aaaaaa' or '#eeeeee'))

   for n=1,self.n do
      local next = self.next[n]
      next:print(txt) -- make sure its id is defined
      table.insert(txt, string.format('id%s -> id%s;',
                                      self:id(),
                                      next:id()))
   end

   if isroot then
      table.insert(txt, '}')
      txt = table.concat(txt, '\n')
      return txt
   end
end

function ACN:generate_ordered_or_named(code, upvalues, rulestype, depth)
   depth = depth or 0

   -- no need to go deeper if no rules found later
   if not self:hasruletype(rulestype) then
      return
   end

   if depth > 0 then
      local argname =
         (rulestype == 'N' or rulestype == 'M')
         and string.format('args.%s', self.name)
         or string.format('select(%d, ...)', depth)

      if self.check then
         upvalues[string.format('check%s', func2id(self.check))] = self.check
      end
      table.insert(code, string.format('%sif narg >= %d and istype(%s, "%s")%s then',
                                       string.rep('  ', depth),
                                       depth,
                                       argname,
                                       self.type,
                                       self.check and string.format(' and check%s(%s)', func2id(self.check), argname) or ''))
   end

   if self.rules and self.rulestype == rulestype then
      local rules = self.rules
      local rulesmask = self.rulesmask
      local id = table2id(rules)
      table.insert(code, string.format('  %sif narg == %d then', string.rep('  ', depth), depth))

      -- 'M' case (method: first arg is self)
      if rulestype == 'M' then
         rules = utils.duptable(self.rules)
         table.remove(rules, 1) -- remove self
         rulesmask = rulesmask:sub(2)
      end

      -- func args
      local argcode = {}
      for ridx, rule in ipairs(rules) do
         if rules.pack then
            table.insert(argcode, string.format('%s=arg%d', rule.name, ridx))
         else
            table.insert(argcode, string.format('arg%d', ridx))
         end
      end

      -- passed arguments
      local maskedrules = rules2maskedrules(rules, rulesmask)-- no, rulestype)
      for argidx, rule in ipairs(maskedrules) do

         local argname =
            (rulestype == 'N' or rulestype == 'M')
            and string.format('args.%s', rule.name)
            or string.format('select(%d, ...)', argidx)

         table.insert(code, string.format('    %slocal arg%d = %s',
                                          string.rep('  ', depth),
                                          rule.__ridx,
                                          argname))
      end

      -- default arguments
      local defaultrules = rules2defaultrules(rules, rulesmask)--no, rulestype)
      local defacode = {}
      for _, rule in ipairs(defaultrules) do
         if rule.default ~= nil then
            table.insert(code, string.format('    %slocal arg%d = arg%s_%dd', string.rep('  ', depth), rule.__ridx, id, rule.__ridx))
            upvalues[string.format('arg%s_%dd', id, rule.__ridx)] = rule.default
         elseif rule.defaultf then
            table.insert(code, string.format('    %slocal arg%d = arg%s_%df()', string.rep('  ', depth), rule.__ridx, id, rule.__ridx))
            upvalues[string.format('arg%s_%df', id, rule.__ridx)] = rule.defaultf
         elseif rule.opt then
            table.insert(code, string.format('    %slocal arg%d', string.rep('  ', depth), rule.__ridx))
         elseif rule.defaulta then
            table.insert(defacode, string.format('    %slocal arg%d = arg%d', string.rep('  ', depth), rule.__ridx, argname2idx(rules, rule.defaulta)))
         end
      end

      if #defacode > 0 then
         table.insert(code, table.concat(defacode, '\n'))
      end

      if rules.pack then
         argcode = table.concat(argcode, ', ')
         if rulestype == 'M' then
            argcode = string.format('self, {%s}', argcode)
         else
            argcode = string.format('{%s}', argcode)
         end
      else
         if rulestype == 'M' then
            table.insert(argcode, 1, 'self')
         end
         argcode = table.concat(argcode, ', ')
      end

      if rules.call and not rules.quiet then
         argcode = string.format('call%s(%s)', id, argcode)
         upvalues[string.format('call%s', id)] = rules.call
      end
      if rules.quiet and not rules.call then
         argcode = string.format('true%s%s', #argcode > 0 and ', ' or '', argcode)
      end
      if rules.quiet and rules.call then
         argcode = string.format('call%s%s%s', id, #argcode > 0 and ', ' or '', argcode)
         upvalues[string.format('call%s', id)] = rules.call
      end

      table.insert(code, string.format('    %sreturn %s', string.rep('  ', depth), argcode))
      table.insert(code, string.format('  %send', string.rep('  ', depth)))
   end

   for i=1,self.n do
      self.next[i]:generate_ordered_or_named(code, upvalues, rulestype, depth+1)
   end

   if depth > 0 then
      table.insert(code, string.format('%send', string.rep('  ', depth)))
   end

end

function ACN:apply(func)
   func(self)
   for i=1,self.n do
      self.next[i]:apply(func)
   end
end

function ACN:usage()
   local txt = {}
   local history = {}
   self:apply(
      function(self)
         if self.rules and not history[self.rules] then
            history[self.rules] = true
            table.insert(txt, usage(self.rules))
         end
      end)
   return table.concat(txt, '\n\nor\n\n')
end

function ACN:generate(upvalues)
   assert(upvalues, 'upvalues table missing')
   local code = {}
   table.insert(code, 'return function(...)')
   table.insert(code, '  local narg = select("#", ...)')
   self:generate_ordered_or_named(code, upvalues, 'O')

   if self:hasruletype('N') then -- is there any named?
      local selfnamed = self:match({{type='table'}})
      assert(selfnamed ~= self, 'internal bug, please report')
      table.insert(code, '  if narg == 1 and istype(select(1, ...), "table") then')
      table.insert(code, '    local args = select(1, ...)')
      table.insert(code, '    local narg = 0')
      table.insert(code, '    for k,v in pairs(args) do')
      table.insert(code, '      narg = narg + 1')
      table.insert(code, '    end')
      selfnamed:generate_ordered_or_named(code, upvalues, 'N')
      table.insert(code, '  end')
   end

   for _,head in ipairs(self.next) do
      if head.isself then -- named self method
         local selfnamed = head:match({{type='table'}})
         assert(selfnamed ~= head, 'internal bug, please report')

         if selfnamed.check then
            upvalues[string.format('check%s', func2id(selfnamed.check))] = selfnamed.check
         end
         table.insert(code,
                      string.format('  if narg == 2 and istype(select(2, ...), "table") and istype(select(1, ...), "%s")%s then',
                                    selfnamed.type,
                                    selfnamed.check and string.format(' and check%s(select(1, ...))', func2id(self.check)) or '')
         )
         table.insert(code, '    local self = select(1, ...)')
         table.insert(code, '    local args = select(2, ...)')
         table.insert(code, '    local narg = 0')
         table.insert(code, '    for k,v in pairs(args) do')
         table.insert(code, '      narg = narg + 1')
         table.insert(code, '    end')
         selfnamed:generate_ordered_or_named(code, upvalues, 'M')
         table.insert(code, '  end')
      end
   end

   for upvaluename, upvalue in pairs(upvalues) do
      table.insert(code, 1, string.format('local %s', upvaluename))
   end

   table.insert(code, '  assert(graph)') -- keep graph as an upvalue

   local quiet = true
   self:apply(
      function(self)
         if self.rules and not self.rules.quiet then
            quiet = false
         end
      end
   )
   if quiet then
      table.insert(code, '  return false, graph:usage()')
   else
      table.insert(code, '  error(string.format("%s\\ninvalid arguments!", graph:usage()))')
   end
   table.insert(code, 'end')
   return table.concat(code, '\n')
end

return ACN
