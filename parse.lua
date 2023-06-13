--[[
     I'm planning on making a chatcmd_parse_coords function to remedy the situation that
     everytime there are coords involved in a chatcommand it's a different syntax:
     sometimes it's x,y,z, sometimes it's x y z, sometimes it's (x,y,z)
     sometimes tilde notation is supported sometimes it isn't.
     I'm planning on making a function like this:
     local coords,param_rest=chatcmd_parse_coords(param,base_pos)
     on failure it should return nil,"remaining portion of param after failure"
     otherwise return with coords parsed and anything that is left behind in param after parsing the coords
     (therefore you can have further parameters to your chatcommand).

     ok so first version of the code, questions, suggestions etc are welcome, also where should be this inserted as a PR?

     please find the up-to-date version of the code here: aHR0cHM6Ly9naXRodWIuY29tL2ltcmU4NC9jaGF0Y21kX3BhcnNlX2Nvb3Jkcw==
--]]

-- copied from MT:

local is_pos = function(v)
	return type(v) == "table" and
		type(v.x) == "number" and type(v.y) == "number" and type(v.z) == "number"
end

-- to make me feel home:

minetest={}
function minetest.pos_to_string(c)
  local s="nil"
  if c then
    s='('..c.x..','..c.y..','..c.z..')'
  end
  return s
end

-- until further notice proposed library functions follow:

--used by _OLD code
function is_digit(c)
  return #c == 1 and
         c >= "0" and
         c <= "9"
end

function chatcmd_parse_ws(cmdparams)
  while(string.sub(cmdparams,1,1)==" ")
  do
    cmdparams=string.sub(cmdparams,2)
  end
  return cmdparams
end

function chatcmd_parse_expect(cmdparams,expected)
  cmdparams=chatcmd_parse_ws(cmdparams)
  while cmdparams~="" and expected~="" and string.sub(cmdparams,1,1)==string.sub(expected,1,1)
  do
    cmdparams=string.sub(cmdparams,2)
    expected=string.sub(expected,2)
  end
  return expected=="",cmdparams
end

--this one right now does only parse integer numbers (negative numbers and optional tilde notation included)
--TODO: could be improved to work with non-integer numbers as well
--_OLD* functions are not used, they serve as a drop in alternative
function chatcmd_parse_num_OLD(cmdparams,base_num)
  local parsed=0
  local sign
  local tilde
  local count_digit=0
  if base_num then
    tilde,cmdparams=chatcmd_parse_expect(cmdparams,"~")
  end
  sign,cmdparams=chatcmd_parse_expect(cmdparams,"-")

  while(is_digit(string.sub(cmdparams,1,1)))
  do
    parsed=parsed*10
    parsed=parsed+tonumber(string.sub(cmdparams,1,1))
    cmdparams=string.sub(cmdparams,2)
    count_digit=count_digit+1
  end
  
  parsed=parsed*(sign and -1 or 1)
  
  if tilde then
    parsed=base_num+parsed
  end

  if count_digit == 0 then
    parsed=nil
  end
  
  return parsed,cmdparams
end

function chatcmd_parse_num_OLD2(cmdparams,base_num)
  local tilde
  if base_num then
    tilde,cmdparams=chatcmd_parse_expect(cmdparams,"~")
  end

  cmdparams=chatcmd_parse_ws(cmdparams)

  if cmdparams=="" then
    return nil,""
  end

  local max=0
  local maxnum=nil

  for i=1,#cmdparams do
    local parsed=tonumber(string.sub(cmdparams,1,i))
    if parsed ~= nil then
      max=i
      maxnum=parsed
    end
  end

  if max == 0 then
    return nil,cmdparams
  end

  if tilde then
    maxnum=base_num+maxnum
  end

  return maxnum,string.sub(cmdparams,max+1)
end

function chatcmd_parse_num(cmdparams,base_num)
  local tilde
  if base_num then
    tilde,cmdparams=chatcmd_parse_expect(cmdparams,"~")
  end

  cmdparams=chatcmd_parse_ws(cmdparams)

  if cmdparams=="" then
    return nil,""
  end

  local parse_cases={
    string.match(cmdparams,"^%-?[0-9.]*e%-?[1-9][0-9]*"),
    string.match(cmdparams,"^-?[0-9.]*"),
    string.match(cmdparams,"^-?[1-9][0-9]*")                }

  for i = 1,3 do
    local s=parse_cases[i]
    local parsed=tonumber(s)
    if parsed ~= nil then
      cmdparams=string.sub(cmdparams,#s+1)
      if tilde then
        parsed=base_num+parsed
      end
      return parsed,cmdparams
    end
  end

  return nil,cmdparams
end

function chatcmd_parse_comma(cmdparams)
  local l
  l,cmdparams=chatcmd_parse_expect(cmdparams,",")
  return (l and "," or ""),cmdparams
end

function chatcmd_parse_parentheses(cmdparams)
  local l
  l,cmdparams=chatcmd_parse_expect(cmdparams,"(")
  if l then
    return "(",cmdparams
  else
    return nil,cmdparams
  end
end

function chatcmd_parse_matching_parentheses(cmdparams,par)
  if par=="" or par==nil then
    return true,cmdparams
  end
  if par=="(" then
    return chatcmd_parse_expect(cmdparams,")")
  end
  return false,cmdparams
end

-- all chatcmd_parse_ routines assume the cmdparams to start with optional whitespaces
-- all chatcmd_parse_ routines return with parsed_result,remaining_cmdparams
function chatcmd_parse_coords(cmdparams,base_pos)
  local x,y,z
  if is_pos(base_pos) then
    x=base_pos.x
    y=base_pos.y
    z=base_pos.z
  end
  cmdparams=chatcmd_parse_ws(cmdparams)
  local par
  par,cmdparams=chatcmd_parse_parentheses(cmdparams)
  local result={}
  result.x,cmdparams=chatcmd_parse_num(cmdparams,x)
  if not result.x then
    return nil,cmdparams
  end
  local comma
  comma,cmdparams=chatcmd_parse_comma(cmdparams)
  result.y,cmdparams=chatcmd_parse_num(cmdparams,y)
  if not result.y then
    return nil,cmdparams
  end
  local comma2
  comma2,cmdparams=chatcmd_parse_comma(cmdparams)
  if comma2~=comma then
    return nil,cmdparams
  end
  result.z,cmdparams=chatcmd_parse_num(cmdparams,z)
  if not result.z then
    return nil,cmdparams
  end
  par,cmdparams=chatcmd_parse_matching_parentheses(cmdparams,par)
  if not par then
    return nil,cmdparams
  end
  return result,cmdparams
end

-- until further notice example code to test the library functions (user code, mod code) follows:

local function test0(s,base_pos)
  local output="input=\""..s.."\", output: "
  local c0,c1
  c0,s=chatcmd_parse_coords(s,base_pos)
  if c0 then
    c1,s=chatcmd_parse_coords(s,base_pos)
  end
  if c1 then
    s=chatcmd_parse_ws(s)
  end
  if c0 and c1 and s=="" then
  --[[ if you were to -- for example -- work on a chat command
       /myawesomechatcmd <pos1> <pos2> somerandomparam3,
       at this point your s string would only contain somerandomparam3.
       Given the fact that in this case you only wrote test0 (as a chatcmd handler)
       It took you zero efforts to parse 2 coordinates in one string,
       and position yourself to the start of your next parameter --]]
    output=output.."parsing of 2 coordinates succeeded: "
    output=output..minetest.pos_to_string(c0)..", "
    output=output..minetest.pos_to_string(c1)
  else
    -- also take note of the awesome parsing error presented here:
    output=output.."parsing failed somewhere near \""..s.."\""
  end
  return output
end

local function test(s)
  local output="  tilde "..test0(s,{x=3,y=6,z=5})
  print(output)
  local output="notilde "..test0(s              )
  print(output)
end

test(" ( 1x1 , 2 , 3 ) (~1,~-1,~1)    ")
test(" ( 1   , 2 ; 3 ) (~1,~-1,~1)    ")
test(" ( 1   , 2   3 ) (~1,~-1,~1)    ")
test(" ( 1   , 2 , 3   (~1,~-1,~1)    ")
test(" ( 1   , 2 , 3 ) (~1,~-1,~1)    ")
test(" ( 1  f, 2 , 3 ) (~1,~-1,~1)    ")
test(" ( 1   ,g2 , 3 ) (~1,~-1,~1)    ")
test(" ( 1     2   3 )  ~1,~-1,~1     ")
test(" ( 1     2   3 )  ~1,~-1,~1   k ")
test(" ( 1     2   3 ) u   ~-1,~1   k ")
test(" ( 1  h  2   3 )  ~1,~-1,~1     ")
test("abc                             ")
test(" ( 1     2   3 )   4,  5, 6     ")
test("   123 456 789 111 -222 333     ")
test("                                ")
test("")
test("1.111 -2.22222e3 3e-2 .4 .5e2 6e-4")
