local M = {}

---Get cursor in win
---@param win "window"
---@return "(row, col) tuple" (1,0)-indexed cursor position
M.get_cursor = function(win) return vim.api.nvim_win_get_cursor(win) end

M.get_row = function(win) return M.get_cursor(win)[1] end

M.get_col = function(win) return M.get_cursor(win)[2] end

---Return the index of value in table
---If not exist return -1
---@param list table
---@param value any
---@return number
M.tbl_get_index = function(list, value)
  for index, v in ipairs(list) do if v == value then return index end end

  return -1
end

---Remove duplicate elements in list, it's inplace
---@param list table
M.tbl_remove_duplicate = function(list)
  local seen = {}
  for index, item in ipairs(list) do
    if seen[item] then
      table.remove(list, index)
    else
      seen[item] = true
    end
  end

  list = seen
end

---Print table structure
---@param list table
---@param level integer
---@param is_filter boolean
M.tbl_print = function(list, level, is_filter)
  if type(list) ~= "table" then
    print(list)
    return
  end

  is_filter = is_filter or true
  level = level or 1

  local indent_str = ""
  for _ = 1, level do indent_str = indent_str .. "  " end

  print(indent_str .. "{")
  for k, v in pairs(list) do
    if is_filter then
      if k ~= "_class_type" and k ~= "delete_me" then
        local item_str = string.format("%s%s = %s", indent_str .. " ", tostring(k),
                                       tostring(v))
        print(item_str)
        if type(v) == "table" then M.tbl_print(v, level + 1) end
      end
    else
      local item_str = string.format("%s%s = %s", indent_str .. " ", tostring(k),
                                     tostring(v))
      print(item_str)
      if type(v) == "table" then M.tbl_print(v, level + 1) end
    end
  end
  print(indent_str .. "}")
end

---INFO log
---@param msg string
M.info = function(msg) vim.notify(msg, vim.log.levels.INFO) end

---WARN log
---@param msg string
M.warn = function(msg) vim.notify(msg, vim.log.levels.WARN) end

return M
