--[[============================================================================
vLib
============================================================================]]--

--[[--

This class provides static members and methods for the vLib library


--]]


--==============================================================================

cLib.require (_clibroot.."cString")
cLib.require (_clibroot.."cConfig")

class 'vLib'


--------------------------------------------------------------------------------

--- (int) when you instantiate a vLib component, it will register itself
-- with a unique viewbuilder ID. This is the global incrementer
vLib.uid_counter = 0

--- (bool) when true, complex widgets will schedule their updates, 
-- possibly saving a little CPU along the way
vLib.lazy_updates = false

--- (table) set once we access the XML configuration 
vLib.config = nil

--- (string) location of images
vLib.imageroot = _vlibroot .. "/images/"

-- (table) provide a default color for selected items
vLib.COLOR_SELECTED = {218,96,45}

-- (table) provide a default color for normal (not selected) items
vLib.COLOR_NORMAL = {0x00,0x00,0x00}

--- specify a bitmap which is *guaranteed* to exist (required when 
-- creating bitmap views before assigning the final value)
vLib.DEFAULT_BMP = "Icons/ArrowRight.bmp"

vLib.BITMAP_STYLES = {
  "plain",        -- bitmap is drawn as is, no recoloring is done             
  "transparent",  -- same as plain, but black pixels will be fully transparent
  "button_color", -- recolor the bitmap, using the theme's button color       
  "body_color",   -- same as 'button_back' but with body text/back color      
  "main_color",   -- same as 'button_back' but with main text/back colors     
}

--- (number), standard height for controls
vLib.CONTROL_H = 18

-- (number), special value that nullifies spacing 
vLib.NULL_SPACING = -3

---------------------------------------------------------------------------------------------------
--- generate a unique string that you is used as viewbuilder id for widgets
-- (avoids clashes in names between multiple instances of the same widget)
-- @return string, e.g. "vlib12"

function vLib.generate_uid()
  
  vLib.uid_counter = vLib.uid_counter + 1
  return ("_vlib%i"):format(vLib.uid_counter)

end

---------------------------------------------------------------------------------------------------
-- given a list of fractional sizes, calculate the closest values
-- e.g. with a target size of 28, {9.33333,9.33333,9.33333} could become {9,9,10} 
-- * enlarge items that are smaller than the minimum size (subtract from others)
-- * automatically adjusts items according to the specified amount of spacing  
-- @param sizes (table<number>)
-- @param target (number), the "combined" target size 
-- @param spacing (number), amount of spacing applied to/between items (default to 0)
-- @param min_width (number), the minimum for a single size (default to 1)

function vLib.distribute_sizes(sizes,target,spacing,min_width)
  TRACE("vLib.distribute_sizes(sizes,target,spacing,min_width)",sizes,target,spacing,min_width)

  if not spacing then 
    spacing = 0
  end

  -- adjust size by the ratio between target size and combined size w. spacing 
  local combined = 0
  for k,v in ipairs(sizes) do 
    combined = combined + v
  end 
  local ratio = math.abs(spacing/target)
  if (spacing < 0) then
    ratio = target/combined - ratio
  else 
    ratio = target/combined + ratio
  end  

  local min_w = min_width or 1
  local tmp_fract = 0
  local enlarged_by = 0
  local fracts = {}
  for k,v in ipairs(sizes) do 
    v = v * ratio
    local fract = cLib.fraction(v)
    v = cLib.round_value(v) 
    -- "carry over" fractional value - apply 
    -- to item once fraction is higher than 1 
    if (fract >= 0.5) then 
      enlarged_by = enlarged_by + (1-fract)
      tmp_fract = tmp_fract - fract
    else
      tmp_fract = tmp_fract + fract
    end
    if (tmp_fract > 1) then 
      tmp_fract = tmp_fract - 1 
      v = v + 1
      table.insert(fracts,k)
    end 
    v = v - spacing 
    -- ensure minimum size - and memorize the additional
    -- pixels we add (subtracted in the next step)
    if (v < min_w) then 
      enlarged_by = enlarged_by + (min_w - v)
      v = min_w
    end 
    sizes[k] = v
  end 

  -- if we have enlarged items, subtract 
  -- until we reach the same total as before
  local do_subtract = function(k,v) 
    if (v > min_w) then 
      v = v - 1 
      sizes[k] = v
      enlarged_by = enlarged_by - 1
      if (enlarged_by < 1) then 
        return false
      end
    end
    return true
  end
  while (enlarged_by > 1) do
    -- start with items that got expanded with fractions
    -- (will ensure a more even-looking distribution)
    for k,v in ipairs(fracts) do 
      if not do_subtract(v,sizes[v]) then 
        break
      end
    end
    for k,v in ipairs(sizes) do
      if not do_subtract(k,sizes[k]) then 
        break
      end
    end
  end

  return sizes

end 

---------------------------------------------------------------------------------------------------
-- retrieve values from the default skin/theme

function vLib.get_skin_color(name)
  TRACE("vLib.get_skin_color(name)",name)

  assert(type(name)=="string")

  local default_color = cConfig:get_value("RenoisePrefs/SkinColors/"..name)
  if default_color then
    vLib.COLOR_SELECTED = cString.split(default_color,",")
  end

end

