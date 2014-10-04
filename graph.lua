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

if false then

   print('===== ARGCHECK: luajit inside man')

   local ffi = require 'ffi'

   ffi.cdef[[

void free(void *ptr);
void *malloc(size_t size);
void *realloc(void *ptr, size_t size);

typedef struct argcheck_node_ {
  char *type;
  int checkidx;
  int outidx;
  int n; /* # of next */
  struct argcheck_node_ **next;
} argcheck_node;

]]

   local ACN = {}
   ACN.__index = ACN

   function ACN.new(typename, checkidx, outidx)
      assert(typename)
      local self = ffi.cast('argcheck_node*', ffi.C.malloc(ffi.sizeof('argcheck_node')))
      self.type = ffi.cast('char*', ffi.C.malloc(#typename+1))
      ffi.copy(self.type, typename, #typename)
      self.type[#typename] = 0
      self.checkidx = checkidx or 0
      self.outidx = outidx or 0
      self.next = nil
      self.n = 0
      return self
   end

   function ACN:add(node)
      assert(node ~= nil)
      if self.n == 0 then
         self.next = ffi.cast('argcheck_node**', ffi.C.malloc(ffi.sizeof('argcheck_node*')))
      else
         self.next = ffi.cast('argcheck_node**', ffi.C.realloc(self.next, ffi.sizeof('argcheck_node*')*(self.n+1)))
      end
      self.next[self.n] = node
      self.n = self.n + 1
   end

   function ACN:free()
      for n = 0,self.n-1 do
         self.next[n]:free()
      end
      if self.next ~= nil then
         ffi.C.free(self.next)
      end
      ffi.C.free(self.type)
      ffi.C.free(self)
   end

   function ACN:match(tbl)
      local head = self
      local nmatched = 0
      for idx,arg in ipairs(tbl) do
         local matched = false
         for n=0,head.n-1 do
            if ffi.string(head.next[n].type) == arg.type and head.next[n].checkidx == arg.checkidx then
               head = head.next[n]
               nmatched = nmatched + 1
               matched = true
               break
            end
         end
         if not matched then
            break
         end
      end
      return head, nmatched
   end

   function ACN:addpath(tbl, outidx)
      local head, n = self:match(tbl)
      for n=n+1,#tbl do
         local node = ACN.new(tbl[n].type, tbl[n].checkidx, n == #tbl and outidx or 0)
         head:add(node)
         head = node
      end
   end

   function ACN:print(txt)
      local isroot = not txt
      txt = txt or {'digraph ACN {'}
      table.insert(txt, string.format('id%d [label="%s%s" style=filled fillcolor=%s];',
                                      tonumber(ffi.cast('intptr_t', self)),
                                      ffi.string(self.type),
                                      self.checkidx > 0 and string.format('+%d', self.checkidx) or '',
                                      self.outidx > 0 and 'red' or 'blue'))

      for n=0,self.n-1 do
         local next = self.next[n]
         next:print(txt) -- make sure its id is defined
         table.insert(txt, string.format('id%d -> id%d;',
                                         tonumber(ffi.cast('intptr_t', self)),
                                         tonumber(ffi.cast('intptr_t', next))))
      end

      if isroot then
         table.insert(txt, '}')
         txt = table.concat(txt, '\n')
         return txt
      end
   end

   ffi.metatype('struct argcheck_node_', ACN)

   return ACN

else

   print('===== ARGCHECK: pure lua inside man')

   local ACN = {}
   
   function ACN.new(typename, check, rules, rulemask)
      assert(typename)
      local self = {}
      setmetatable(self, {__index=ACN})
      self.type = typename
      self.check = check
      self.rules = rules
      self.rulemask = rulemask
      self.next = {}
      self.n = 0
      return self
   end

   function ACN:add(node)
      table.insert(self.next, node)
      self.n = self.n + 1
   end

   function ACN:match(rules, rulemask)
      local head = self
      local nmatched = 0
      for _,idx in ipairs(rulemask) do
         local rule = rules[idx]
         local matched = false
         for n=1,head.n do
            if head.next[n].type == rule.type and head.next[n].check == rule.check then
               head = head.next[n]
               nmatched = nmatched + 1
               matched = true
               break
            end
         end
         if not matched then
            break
         end
      end
      return head, nmatched
   end

   function ACN:addpath(rules, rulemask)
      if #rulemask == 0 then
         self.rules = self.rules or rules
         self.rulemask = self.rulemask or rulemask
      else
         local head, n = self:match(rules, rulemask)
         for n=n+1,#rulemask do
            local rule = rules[rulemask[n]]
            local node = ACN.new(rule.type, rule.check, n == #rulemask and rules or nil, n == #rulemask and rulemask or nil)
            head:add(node)
            head = node
         end
      end
   end

   function ACN:id()
      return table2id(self)
   end

   function ACN:print(txt)
      local isroot = not txt
      txt = txt or {'digraph ACN {'}
      table.insert(txt, string.format('id%s [label="%s%s" style=filled fillcolor=%s];',
                                      self:id(),
                                      self.type,
                                      self.check and '<check>' or '',
                                      self.rules and 'red' or 'blue'))
      
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

   function ACN:generate(upvalues, depth)
      assert(upvalues, 'upvalues table missing')
      local code = {}
      depth = depth or 0

      if depth == 0 then
         table.insert(code, 'return function(...)')
         table.insert(code, '  local narg = select("#", ...)')
      else
         -- DEBUG: check() is missing
         table.insert(code, string.format('%sif narg >= %d and istype(select(%d, ...), "%s") then', string.rep('  ', depth), depth, depth, self.type))
      end

      if self.rules then
         local rules = self.rules
         local id = table2id(rules)
         table.insert(code, string.format('  %sif narg == %d then', string.rep('  ', depth), depth))
         local argcode = {}
         local defacode = {}
         for ridx, rule in ipairs(rules) do
            table.insert(argcode, string.format('arg%d', ridx))
            if rules.pack then
               table.insert(argcode, string.format('%s=arg%d', rule.name, ridx))
            else
               table.insert(argcode, string.format('arg%d', ridx))
            end

            local argidx
            for i=1,#self.rulemask do -- DEBUG: bourrin
               if ridx == self.rulemask[i] then
                  argidx = i
                  break
               end
            end
            if argidx then
               table.insert(code, string.format('    %slocal arg%d = select(..., %d)', string.rep('  ', depth), ridx, argidx))
            else
               if rule.default then
                  table.insert(code, string.format('    %slocal arg%d = arg%s_%dd', string.rep('  ', depth), ridx, id, ridx))
                  upvalues[string.format('arg%s_%dd', id, ridx)] = rule.default
               elseif rule.defaultf then
                  table.insert(code, string.format('    %slocal arg%d = arg%s_%df()', string.rep('  ', depth), ridx, id, ridx))
                  upvalues[string.format('arg%s_%df', id, ridx)] = rule.defaultf
               elseif rule.opt then
                  table.insert(code, string.format('    %slocal arg%d', string.rep('  ', depth), ridx))
               elseif rule.defaulta then
                  table.insert(defacode, string.format('    %slocal arg%d = arg%d', string.rep('  ', depth), ridx, argname2idx(rules, rule.defaulta)))
               end
            end
         end
         if #defacode > 0 then
            table.insert(code, table.concat(defacode, '\n'))
         end
         argcode = table.concat(argcode, ', ')
         if rules.pack then
            argcode = string.format('{%s}', argcode)
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
         table.insert(code, self.next[i]:generate(upvalues, depth+1))
      end

      if depth == 0 then
         for upvaluename, upvalue in pairs(upvalues) do
            table.insert(code, 1, string.format('local %s', upvaluename))
         end
         table.insert(code, '  error("invalid arguments")')
         table.insert(code, 'end')
      else
         table.insert(code, string.format('%send', string.rep('  ', depth)))
      end

      return table.concat(code, '\n')
   end

   return ACN
end
