Bit = {}

-- LuaJIT provides global `bit` (BitOp). PUC Lua / OTC provide `bit32`.
-- Set on _G so every module env that indexes _G can see it.
if not _G.bit and _G.bit32 then
  _G.bit = _G.bit32
end

function Bit.bit(p)
  return 2 ^ p
end

function Bit.hasBit(x, p)
  return x % (p + p) >= p
end

function Bit.setbit(x, p)
  return Bit.hasBit(x, p) and x or x + p
end

function Bit.clearbit(x, p)
  return Bit.hasBit(x, p) and x - p or x
end