--[[===============================================================================================
vButtonStrip
===============================================================================================]]--

--[[

A button strip - each button with configurable appearance 
.

which decides 

]]

--=================================================================================================

class 'vButtonStripMember' 

---------------------------------------------------------------------------------------------------

function vButtonStripMember:__init(...)

  local args = cLib.unpack_args(...)
  assert(type(args.weight)=="number","Expected 'weight' to be a number")

  --- number, determines relative size
  self.weight = args.weight
  --- number/boolean/string/table - can be freely specified [optional]
  self.value = args.value
  --- look & feel [optional]
  self.text = args.text 
  self.color = args.color 
  self.tooltip = args.tooltip 

end

---------------------------------------------------------------------------------------------------

function vButtonStripMember:__tostring()

  return type(self).."{"
    .."weight:"..tostring(self.weight)
    ..", value:"..tostring(self.value)
    ..", text:"..tostring(self.text)
    ..", color:"..tostring(self.color)
    ..", tooltip:"..tostring(self.tooltip)
    .."}"
end


--=================================================================================================

class 'vButtonStrip' (vControl)

vButtonStrip.MIN_SEGMENT_W = 5
vButtonStrip.DEFAULT_WIDTH = 100

---------------------------------------------------------------------------------------------------

function vButtonStrip:__init(...)

  -- properties -----------------------

  local args = cLib.unpack_args(...)

  if not args.width then 
    args.width = vButtonStrip.DEFAULT_WIDTH
  end 
  if not args.height then 
    args.height = renoise.ViewBuilder.DEFAULT_CONTROL_HEIGHT
  end 
  if not args.spacing then 
    args.spacing = vLib.NULL_SPACING
  end
  if not args.min_segment_size then 
    args.min_segment_size = vButtonStrip.MIN_SEGMENT_W
  end

  -- function, @param (number)
  self.pressed = args.pressed
  -- function, @param (number)
  self.released = args.released
  -- function, @param (number)
  self.notifier = args.notifier
  -- number 
  self.spacing = property(self.get_spacing,self.set_spacing)
  self.spacing_observable = renoise.Document.ObservableNumber(args.spacing)
  -- number 
  self.min_segment_size = property(self.get_min_segment_size,self.set_min_segment_size)
  self.min_segment_size_observable = renoise.Document.ObservableNumber(args.min_segment_size)

  -- table<vButtonStripMember>
  self.items = property(self.get_items,self.set_items)
  self._items = {}

  -- string, message to display when no items are available
  self.placeholder_message = args.placeholder_message or "No items"

  -- internal -------------------------

  -- button instances in strip
  self.vb_strip_bts = {}

  -- initialize -----------------------

  vControl.__init(self,...)
  self:build()

  if not table.is_empty(args.items) then
    self.items = args.items
  end

end

---------------------------------------------------------------------------------------------------
-- Getters & Setters
---------------------------------------------------------------------------------------------------

function vButtonStrip:get_items()
  return self._items
end

function vButtonStrip:set_items(items)
  self._items = {}
  if not table.is_empty(items) then
    for k,v in ipairs(items) do 
      self:add_item(v)
    end 
  end
  self:request_update()
  
end

---------------------------------------------------------------------------------------------------

function vButtonStrip:get_spacing()
  return self.spacing_observable.value
end

function vButtonStrip:set_spacing(val)
  TRACE("vButtonStrip:set_spacing",val)
  self.spacing_observable.value = val 
  self.vb_row.spacing = val
  self:request_update()
end

---------------------------------------------------------------------------------------------------

function vButtonStrip:get_min_segment_size()
  return self.min_segment_size_observable.value
end

function vButtonStrip:set_min_segment_size(val)
  TRACE("vButtonStrip:set_min_segment_size",val)
  self.min_segment_size_observable.value = val 
  self:request_update()
end

---------------------------------------------------------------------------------------------------
-- Super methods 
---------------------------------------------------------------------------------------------------

function vButtonStrip:set_width(val)
  vControl.set_width(self,val)
  --self.vb_space.width = val
  self:request_update()
end

---------------------------------------------------------------------------------------------------

function vButtonStrip:set_height(val)
  vControl.set_height(self,val)
  self:request_update()
end

---------------------------------------------------------------------------------------------------

function vButtonStrip:set_active(b)
  for k,v in ipairs(self.vb_strip_bts) do 
    v.active = b
  end 
  vControl.set_active(self,b)
end

---------------------------------------------------------------------------------------------------
-- Class methods 
---------------------------------------------------------------------------------------------------

function vButtonStrip:build()
  TRACE("vButtonStrip:build()",self)

	local vb = self.vb  
  if not self.view then
    --self.vb_space = vb:space{width = self.width}
    self.vb_row = vb:row{
      spacing = self.spacing
    }
    self.view = vb:column{
      id = self.id,
      --self.vb_space,
      self.vb_row,
    }
  end

  --self:clear()  
  self:update()

  --vControl.build(self)

end

---------------------------------------------------------------------------------------------------

function vButtonStrip:press(idx)
  TRACE("vButtonStrip:press(idx)",idx)
  if self.pressed then
    self.pressed(idx,self)
  end
end

---------------------------------------------------------------------------------------------------

function vButtonStrip:release(idx)
  TRACE("vButtonStrip:release(idx)",idx)

  if self.released then
    self.released(idx,self)
  end
  if self.notifier then
    self.notifier(idx,self)
  end
end

---------------------------------------------------------------------------------------------------

function vButtonStrip:_clear()
  for k,v in ipairs(self.vb_strip_bts) do 
    self.vb_row:remove_child(v)
  end 
  self.vb_strip_bts = {};

end

---------------------------------------------------------------------------------------------------

function vButtonStrip:show_placeholder(str_msg)
  TRACE("vButtonStrip:show_placeholder(str_msg)",str_msg)

  self:_clear()

	local vb = self.vb  
  local bt = self.vb:button{
    text = str_msg,
    width = self.width,
    height = self.height,
    active = false,
  }
  self.vb_row:add_child(bt)
  table.insert(self.vb_strip_bts,bt)    
end  

---------------------------------------------------------------------------------------------------

function vButtonStrip:update()
  TRACE("vButtonStrip:update()")

  self:_clear()

  if (#self.items == 0) then 
    self:show_placeholder(self.placeholder_message)
  elseif ((self.width/self.min_segment_size) < #self.items) then 
    self:show_placeholder("Not able to display this many items")
  else
    local vb = self.vb
    -- weights are computed/OK, now calculate width of items 
    local combined = self:get_combined_weight()
    local unit_w = self.width/combined
    local widths = {}
    for k,v in ipairs(self.items) do 
      table.insert(widths,v.weight*unit_w)
    end 
    --print("widths PRE",rprint(widths))
    widths = vLib.distribute_sizes(widths,self.width,self.spacing,self.min_segment_size)
    --print("widths POST",rprint(widths))
    -- we have our widths, now render...
    for k,v in ipairs(self.items) do
        local bt = self.vb:button{
        text = v.text,
        color = v.color,
        tooltip = v.tooltip,
        pressed = function()
          self:press(k)
        end,
        released = function()
          self:release(k)
        end,
      }
      -- note: setting size after text to retain dimensions
      bt.width = widths[k]
      bt.height = self.height
      self.vb_row:add_child(bt)
      table.insert(self.vb_strip_bts,bt)
    end


  end        

end

---------------------------------------------------------------------------------------------------
-- get combined weights until provided item 
-- @return number 

function vButtonStrip:get_item_offset(item_idx)
  TRACE("vButtonStrip:get_item_offset(item_idx)",item_idx)

  local offset = 0
  item_idx = item_idx - 1

  for k = 1,item_idx do
    local item = self.items[k]
    if item then
      offset = offset + item.weight
    else
      break
    end
  end 
  return offset

end

---------------------------------------------------------------------------------------------------
-- return combined size of strip weights 

function vButtonStrip:get_combined_weight()
  local combined = 0
  for k,v in ipairs(self.items) do
    combined = combined + v.weight
  end 
  return combined
end
 
---------------------------------------------------------------------------------------------------
-- add item 

function vButtonStrip:add_item(member,at_idx)
  TRACE("vButtonStrip:add_item(member,at_idx)",member,at_idx)
  if at_idx then
    table.insert(self._items,at_idx,member)
  else
    table.insert(self._items,member)
  end

end
