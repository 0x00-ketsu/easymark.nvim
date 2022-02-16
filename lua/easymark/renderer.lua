local config = require("easymark.config")
local utils = require("easymark.utils")

---@class Renderer
local Renderer = {}

---@param pane Pane
---@param opts table
Renderer.render = function(pane, opts)
  opts = opts or {}
  local items = opts.items

  if vim.tbl_count(items) == 0 then
    utils.warn("Easymark: no marks")
    return
  end

  local lines = Renderer.format(items)
  pane:render(lines)

  -- highlight title
  if vim.tbl_count(lines) > 0 then
    vim.api.nvim_buf_add_highlight(pane.buf, config.namespace, "EasymarkDir", 0, 0, -1)

    -- assign to items
  end

  if opts.focus then pane:focus() end
end

---Format and return lines showed in Easymark Pane
---@param items Item[]
---@return string[]
Renderer.format = function(items)
  items = items or {}
  local line_nr_lens, col_nr_lens = {}, {}

  for _, item in pairs(items) do
    line_nr_lens[#line_nr_lens + 1] = string.len(tostring(item.line_nr))
    col_nr_lens[#col_nr_lens + 1] = string.len(tostring(item.col_nr))
  end

  -- LuaFormatter off
  local max_line_nr_len = vim.tbl_count(line_nr_lens) == 0 and 4 or math.max(unpack(line_nr_lens), 4)
  local max_col_nr_len = vim.tbl_count(col_nr_lens) == 0 and 4 or math.max(unpack(col_nr_lens), 3)
  -- LuaFormatter on

  local title_line = string.format("%" .. max_line_nr_len .. "s", "line")
  local title_col = string.format("%" .. max_col_nr_len .. "s", "col")
  local title = title_line .. "  " .. title_col .. "  text"
  local lines = {}
  table.insert(lines, 1, title)
  for _, item in pairs(items) do
    local line = string.format("%" .. max_line_nr_len .. "d", tostring(item.line_nr))
    local col = string.format("%" .. max_col_nr_len .. "d ", item.col_nr)

    lines[#lines + 1] = line .. "  " .. col .. "  " .. item.line_content
  end

  return lines
end

return Renderer
