-- Cross-platform path utilities
local M = {}

-- Get platform-specific path separator
-- @return string: "/" on Unix, "\" on Windows
function M.separator()
  return package.config:sub(1,1)
end

-- Join path components with platform-specific separator
-- @param ... string: Path components to join
-- @return string: Joined path
function M.join(...)
  local parts = {...}
  if #parts == 0 then return "" end
  if #parts == 1 then return parts[1] end

  local sep = M.separator()
  local result = parts[1]

  for i = 2, #parts do
    -- Remove trailing separator from previous part
    result = result:gsub("[/\\]+$", "")
    -- Remove leading separator from current part
    local part = parts[i]:gsub("^[/\\]+", "")
    result = result .. sep .. part
  end

  return result
end

-- Escape path for use in Lua patterns
-- @param path string: Path to escape
-- @return string: Escaped path
function M.escape(path)
  return vim.pesc(path)
end

-- Normalize path separators for current platform
-- @param path string: Path with any separators
-- @return string: Path with platform-specific separators
function M.normalize(path)
  local sep = M.separator()
  return path:gsub("[/\\]+", sep)
end

return M
