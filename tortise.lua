---a library that makes working with turtles a little bit easier
---provides wrappers around directional functions such as placeUp that allow you to pass a string direction instead IE place("up")
---provides more complex movement functions that can traverse multiple blocks, move to a vector, mine blocks recursively, and execute a callback before each step
local tor = {}

-- for some reason these aliases get a warning telling me i'm redefining them and i don't know how to fix it

---@diagnostic disable-next-line
---@alias turtleDirection "forward"|"up"|"down"
---@diagnostic disable-next-line
---@alias cardinalDirection "north"|"east"|"south"|"west"
tor.CARDINAL_DIRECTIONS = {"north","east","south","west"}
tor.CARDINAL_DIRECTIONS_INVERSE = {["north"] = 1,["east"] = 2,["south"] = 3,["west"] = 4}

---use a tortise-deny.lua file to prevent tortise functions from mining certain blocks
---chests, spawners, other computers, etc: anything you think it shouldn't be mining
tor.deny = require("tortise-deny")

---the cardinal direction the turtle is facing
---various functions will automatically update this
---however, it always starts as south, so you should call updateFacing at the start of your program to ensure it's always accurate
---@type cardinalDirection
tor.facing = "south"

---set this to true to have the turtle print its fuel level after every movement
---@type boolean
tor.fuelLogging = false

---set this to true to have the turtle ignore tortise-deny.lua
---@type boolean
tor.forceMine = false

---a direction agnostic version of tutrle.turn
---should be used in place of directly turning the turtle,
---because this function automatically updates the turtle's facing variable
---errors if dir is invalid
---@param dir? "left"|"right" the direction to turn, defaults to left
---@return boolean success if the turtle could turn
---@return string? errorMessage why the turtle couldn't turn
function tor.turn(dir)
  local diff,success,errmsg
  if dir == "left" or dir == nil then
    success,errmsg = turtle.turnLeft()
    diff = -1
  elseif dir == "right" then
    success,errmsg = turtle.turnRight()
    diff = 1
  else
    error(dir.." isn't a valid turn direction",2)
  end
  local newIdx = tor.CARDINAL_DIRECTIONS_INVERSE[tor.facing] + diff
  if newIdx < 1 then newIdx = 4
  elseif newIdx > 4 then newIdx = 1 end
  tor.facing = tor.CARDINAL_DIRECTIONS[newIdx]
  return success,errmsg
end

---direction agnostic version of turtle.detect
---errors if dir is invalid
---@param dir? turtleDirection the direction to detect in, defaults to forward
---@return boolean detected whether or not there is a block on side dir
function tor.detect(dir)
  local isBlock
  if dir == "up" then
    isBlock = turtle.detectUp()
  elseif dir == "down" then
    isBlock = turtle.detectDown()
  elseif dir == "forward" or dir == nil then
    isBlock = turtle.detect()
  else
    error(dir.." isn't a valid turtle direction",2)
  end
  return isBlock
end

---direction agnostic version of turtle.inspect
---errors if dir is invalid
---@param dir? turtleDirection the direction to inspect in, defaults to forward
---@return boolean blockPresent whether or not there is a block on side dir
---@return string|ccTweaked.turtle.inspectInfo|unknown info info about the block or a message explaining that there is no block
function tor.inspect(dir)
  local isBlock,block
  if dir == "up" then
    isBlock,block = turtle.inspectUp()
  elseif dir == "down" then
    isBlock,block = turtle.inspectDown()
  elseif dir == "forward" or dir == nil then
    isBlock,block = turtle.inspect()
  else
    error(dir.." isn't a valid turtle direction",2)
  end
  return isBlock,block
end

---direction agnostic version of turtle.dig that adheres to tortise-deny.lua
---errors if dir is invalid
---@param dir? turtleDirection the direction to dig in, defaults to forward
---@return boolean success whether or not a block was broken
---@return string? errorMessage the reason no block was broken
function tor.dig(dir)
  local isBlock,block = tor.inspect(dir)
  if not isBlock then return false,"no block to dig" end
  if not tor.forceMine and tor.checkDenylist(block.name) then return false,"mining of "..block.name.." is denied" end
  if dir == "up" then
    return turtle.digUp()
  elseif dir == "down" then
    return turtle.digDown()
  elseif dir == "forward" or dir == nil then
    return turtle.dig()
  else
    error(dir.." isn't a valid turtle direction",2)
  end
end

---direction agnostic version of turtle.place
---errors if dir is invalid
---@param dir? turtleDirection the direction to place in, defaults to forward
---@param text? string when placing a sign, set its contents to this text
---@return boolean success whether or not the block was placed
---@return string? errorMessage why the block wasn't placed
function tor.place(dir,text)
  if dir == "up" then
    return turtle.placeUp(text)
  elseif dir == "down" then
    return turtle.placeDown(text)
  elseif dir == "forward" or dir == nil then
    return turtle.place(text)
  else
    error(dir.." isn't a valid turtle direction",2)
  end
end

---direction agnostic version of turtle.drop
---errors if dir or count are invalid
---@param dir? turtleDirection the direction to drop towards, defaults to forward
---@param count? integer the number of items to drop, defaults to an entire stack
---@return boolean success whether or not items were dropped
---@return string? errorMessage why the items weren't dropped
function tor.drop(dir,count)
  if dir == "up" then
    return turtle.dropUp(count)
  elseif dir == "down" then
    return turtle.dropDown(count)
  elseif dir == "forward" or nil then
    return turtle.drop(count)
  else
    error(dir.." isn't a valid turtle direction")
  end
end

---direction agnostic version of turtle.compare
---errors if dir is invalid
---@param dir? turtleDirection the direction of the block to compare with
---@return boolean areSame whether or the held item and the block we're comparing are the same
function tor.compare(dir)
  if dir == "up" then
    return turtle.compareUp()
  elseif dir == "down" then
    return turtle.compareDown()
  elseif dir == "forward" or dir == nil then
    return turtle.compareDown()
  else
    error(dir.." isn't a valid turtle direction")
  end
end

---move the turtle dist blocks in dir direction
---errors if
--- - dir is invalid
--- - the turtle cannot move at any individual step
---@param dist integer number of blocks to move
---@param dir? turtleDirection|"back"|"left"|"right"|cardinalDirection the direction to move
---@param callback? function a function to run before every step of the movement, which takes the step number as an argument
function tor.move(dist,dir,callback)
  if dir == "north" or dir == "south" or dir == "east" or dir == "west" then
    ---@diagnostic disable-next-line we already checked that dir is valid here
    tor.orient(dir)
    dir = "forward"
  elseif dir == "left" or dir == "right" then
    ---@diagnostic disable-next-line
    tor.turn(dir)
    dir = "forward"
  elseif dir == nil then
    dir = "forward"
  end
  for i = 1,dist do
    if callback ~= nil then callback(i) end
    if tor.fuelLogging then print(turtle.getFuelLevel()) end
    local success,errmsg = turtle[dir]()
    if not success then
      error(errmsg.." (step "..i.."/"..dist..")",2)
    end
  end
end

---direction agnostic movement function with distance and recursive block mining
---errors if
--- - dist is less than 0
--- - dir is invalid
--- - the turtle runs out of fuel
--- - any attempted block mining fails
---@param dist integer number of blocks to mine
---@param dir? turtleDirection|"back"|"left"|"right"|cardinalDirection direction to mine
---@param callback function? a function to run before every step of the movement, which takes the step number as an argument
function tor.mine(dist,dir,callback)
  if dist < 0 then error("dist cannot be less than 0",2)
  elseif dist == 0 then return end

  local function tryMove(i)
    if turtle[dir]() then return end
    if turtle.getFuelLevel() == 0 then error("Out of fuel (step "..i.."/"..dist..")",3) end

    ---@diagnostic disable-next-line by this point we have already ensured dir ~= back
    local isBlock,block = tor.inspect(dir)
    if isBlock then
      if not tor.forceMine and tor.checkDenylist(block.name) then error("Mining of "..block.name.." is denied",3) end

      local success,errmsg
      if dir == "up" then
        success,errmsg = turtle.digUp()
      elseif dir == "down" then
        success,errmsg = turtle.digDown()
      elseif dir == "forward" or dir == nil then
        success,errmsg = turtle.dig()
      else
        error(dir.." isn't a valid turtle direction",3)
      end

      if not success then
        error(errmsg.." (step "..i.."/"..dist..")",3)
      end

      tryMove()
    end
  end

  if dir == "north" or dir == "south" or dir == "east" or dir == "west" then
    ---@diagnostic disable-next-line we already checked that dir is valid here
    tor.orient(dir)
    dir = "forward"
  elseif dir == "back" then
    tor.turn()
    tor.turn()
    dir = "forward"
  elseif dir == "left" or dir == "right" then
    ---@diagnostic disable-next-line
    tor.turn(dir)
    dir = "forward"
  elseif dir == nil then
    dir = "forward"
  end

  for i = 1,dist do
    if callback ~= nil then callback(i) end
    if tor.fuelLogging then print(turtle.getFuelLevel()) end
    tryMove(i)
  end
end

---checks the tortise-deny.lua patterns and exceptions
---@param blockId string
---@return boolean denied whether or not the blockId is found on the denylist and isn't on the exceptions list
function tor.checkDenylist(blockId)
  for _,v in ipairs(tor.deny.exceptions) do
    if blockId == v then return false end
  end
  for _,v in ipairs(tor.deny.patterns) do
    if string.find(blockId,v) ~= nil then return true end
  end
  return false
end

---moves the turtle along a vector, first moving up/down,
---then moving along the axis it's already aligned with,
---then turning to move along the remaining axis
---@param x integer the x coordinate to move to
---@param y integer the y coordinate to move to
---@param z integer the z coordinate to move to
---@param callback function? the callback to pass to the move function
function tor.vecMove(x,y,z,callback)
  if y > 0 then
    tor.move(y,"up",callback)
  elseif y < 0 then
    tor.move(math.abs(y),"down",callback)
  end

  local function zmove()
    if z > 0 then
      if tor.facing == "north" then
        tor.move(z,"back",callback)
      else
        tor.orient("south")
        tor.move(z,"forward",callback)
      end
    elseif z < 0 then
      if tor.facing == "south" then
        tor.move(math.abs(z),"back",callback)
      else
        tor.orient("north")
        tor.move(math.abs(z),"forward",callback)
      end
    end
  end
  local function xmove()
    if x > 0 then
      if tor.facing == "west" then
        tor.move(x,"back",callback)
      else
        tor.orient("east")
        tor.move(x,"forward",callback)
      end
    elseif x < 0 then
      if tor.facing == "east" then
        tor.move(math.abs(x),"back",callback)
      else
        tor.orient("west")
        tor.move(math.abs(x),"forward",callback)
      end
    end
  end
  if tor.facing == "south" or tor.facing == "north" then
    zmove()
    xmove()
  else
    xmove()
    zmove()
  end
end

---moves the turtle along a vector, first moving up/down,
---then moving along the axis it's closest to being aligned with,
---then turning to move along the remaining axis
---mines blocks along the way
---because it mines blocks, this function will never move the turtle backwards, unlike vecMove
---@param x integer the x coordinate to mine to
---@param y integer the y coordinate to mine to
---@param z integer the z coordinate to mine to
---@param callback function? the callback to pass to the move function
function tor.vecMine(x,y,z,callback)
  if y > 0 then
    tor.mine(y,"up",callback)
  elseif y < 0 then
    tor.mine(math.abs(y),"down",callback)
  end

  local function zmove()
    if z > 0 then
      tor.orient("south")
      tor.mine(z,"forward",callback)
    elseif z < 0 then
      tor.orient("north")
      tor.mine(math.abs(z),"forward",callback)
    end
  end
  local function xmove()
    if x > 0 then
      tor.orient("east")
      tor.mine(x,"forward",callback)
    elseif x < 0 then
      tor.orient("west")
      tor.mine(math.abs(x),"forward",callback)
    end
  end
  if tor.facing == "south" and z > 0 or tor.facing == "north" and z < 0 then
    zmove()
    xmove()
  elseif tor.facing == "east" and x > 0 or tor.facing == "west" and x < 0 then
    xmove()
    zmove()
  elseif tor.facing == "south" or tor.facing == "north" then
    xmove()
    zmove()
  else
    zmove()
    xmove()
  end
end

---updates the turtle's facing variable using gps
---@param reset? boolean whether or not to have the turtle move back into its previous position after the second gps ping
function tor.updateFacing(reset)
  local function isModem(id)
    return id == "computercraft:wireless_modem"
      or id == "computercraft:wireless_modem_advanced"
  end

  local leftTool = turtle.getEquippedLeft()
  if leftTool ~= nil and isModem(leftTool.name) then
    rednet.open("left")
  else
    local rightTool = turtle.getEquippedRight()
    if rightTool ~= nil and isModem(rightTool.name) then
      rednet.open("right")
    else
      error("tried to find gps location without a modem equipped",2)
    end
  end

  local x,y,z = gps.locate(0.5)
  if x == nil or y == nil or z == nil then error("gps.locate timed out",2) end
  local loc1 = vector.new(x,y,z)

  local success,errmsg = pcall(function() tor.mine(1,"forward") end)
  if not success then
    assert(errmsg,"errmsg should never be nil if success is false")
    local _,colon = string.find(errmsg,":%d+:")
    error("failed to get the turtle's facing ("..string.sub(errmsg,colon+2)..")",2)
  end

  x,y,z = gps.locate(0.5)
  if x == nil or y == nil or z == nil then error("gps.locate timed out",2) end
  local loc2 = vector.new(x,y,z)

  local dirvec = loc2:sub(loc1)
  if dirvec.x == 1 then tor.facing = "east"
  elseif dirvec.x == -1 then tor.facing = "west"
  elseif dirvec.z == 1 then tor.facing = "south"
  elseif dirvec.z == -1 then tor.facing = "north"
  else error("impossible code path; turtle tried to update its facing but didn't move") end
  if reset then tor.move(1,"back") end
end

---orient the turtle towards a specific cardinal direction
---relies on the facing variable, which will only be accurate if you call updateFacing
---or if the program starts when the turtle is facing south
---@param dir cardinalDirection
function tor.orient(dir)
  if tor.facing == dir then return end
  local diff = tor.CARDINAL_DIRECTIONS_INVERSE[dir] - tor.CARDINAL_DIRECTIONS_INVERSE[tor.facing]
  if diff == 3 then diff = -1
  elseif diff == -3 then diff = 1 end
  for _ = 1,math.abs(diff) do
    if diff < 0 then tor.turn("left")
    else tor.turn("right") end
  end
end

---places the peripheral from the current slot and wraps it
---@return ccTweaked.peripheral.wrappedPeripheral?
function tor.placePeripheral()
  if not turtle.place() then
    turtle.dig()
  end
  sleep(0.1)
  return peripheral.wrap("front")
end

return tor
