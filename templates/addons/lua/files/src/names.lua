local M = {}

--- Joins the parts of a name with single spaces, leaving out blank parts.
---@param ... string
---@return string
function M.display_name(...)
  local parts = {}
  for _, part in ipairs({ ... }) do
    local trimmed = part:match("^%s*(.-)%s*$")
    if trimmed ~= "" then
      parts[#parts + 1] = trimmed
    end
  end
  return table.concat(parts, " ")
end

return M
