local doc = {__args=false}

function doc.showargs()
   doc.__args = true
end

function doc.hideargs()
   doc.__args = true
end

function doc.record()
   doc.__record = {}
end

function doc.stop()
   local md = table.concat(doc.__record)
   doc.__record = nil
   return md
end

function doc.doc(str)
   if doc.__record then
      table.insert(doc.__record, str)
   end
end

setmetatable(doc, {__call=
                      function(self, ...)
                         return self.doc(...)
                      end})

return doc
