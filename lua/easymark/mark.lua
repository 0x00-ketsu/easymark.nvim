local config = require("easymark.config")
local utils = require("easymark.utils")

---@class Mark
---@field marks table: an array of tables to store extmark items, indexed by `bufnr`
---@field mark_idx integer
---@field bufnr "Buffer handle"
---@field ns_id "Namespace id"
local Mark = {marks = {}}

function Mark:init()
  self.bufnr = vim.api.nvim_get_current_buf()
  self.ns_id = config.namespace
  -- Fill `self.marks` with existed `marks` in `namespace`
  local all_marks = vim.api.nvim_buf_get_extmarks(self.bufnr, self.ns_id, 0, -1, {})
  if vim.tbl_count(all_marks) == 0 then return end

  local buf_marks = {}
  for _, mark in pairs(all_marks) do
    local id = mark[1]
    local line_nr = mark[2] + 1
    local col_nr = mark[3] + 1
    local line_content = vim.fn.getline(line_nr)
    -- LuaFormatter off
        buf_marks[line_nr] = {
            mark_id = id,
            col_nr = col_nr,
            line_content = line_content
        }
        -- LuaFormatter on
  end
  self.marks[self.bufnr] = buf_marks
end

---Set an extmark in a buffer
---NOTE: In `nvim_buf_set_extmark()` both `{line}` and `{col}` are 0-based indexing
---
---@return integer
function Mark:set(line_nr, col_nr)
  self:init()

  local buf_marks = self:get_all()
  -- If same line is added extmark, skip
  if buf_marks[line_nr] ~= nil then return buf_marks[line_nr] end

  local mark_idx = os.time(os.date("!*t"))
  local opts = {
    id = mark_idx,
    virt_text = {{config.options.mark_opts.virt_text}},
    virt_text_pos = config.options.mark_opts.virt_text_pos
  }

  local bufnr = self.bufnr
  local row, col = line_nr - 1, col_nr - 1
  local mark_id = vim.api.nvim_buf_set_extmark(bufnr, self.ns_id, row, col, opts)

  local line_content = vim.fn.getline(line_nr)
  buf_marks[line_nr] = {mark_id = mark_id, col_nr = col_nr, line_content = line_content}
  -- Update
  self.marks[bufnr] = buf_marks

  return mark_id
end

---Get an custom setted extmark by line_nr in a buffer
---
---@param line_nr integer
---@return table
function Mark:get_by_line_nr(line_nr)
  self:init()

  local buf_marks = self:get_all()
  local mark = buf_marks[line_nr]
  if mark == nil then return end

  return mark
end

---Get all custom setted extmarks in a buffer
---
---@return table
function Mark:get_all()
  self:init()

  return self.marks[self.bufnr] or {}
end

---Get custom extmark line_nr list in a buffer
---@return table
function Mark:get_line_nrs()
  self:init()

  local marks = self:get_all()
  return vim.tbl_keys(marks)
end

---Delete an extmark in a buffer
---
---@param line_nr integer
---@return boolean
function Mark:del(line_nr)
  self:init()

  local buf_marks = self:get_all()
  local mark = buf_marks[line_nr]
  if mark == nil then return false end

  local bufnr = self.bufnr
  local mark_id = mark.mark_id
  local is_deleted = vim.api.nvim_buf_del_extmark(bufnr, self.ns_id, mark_id)
  if is_deleted then
    buf_marks[line_nr] = nil
    self.marks[bufnr] = buf_marks
  end

  return is_deleted
end

---Delete all extmarks in a buffer by namespace
---@return nil
function Mark:del_all()
  self:init()

  local marks = self:get_all()
  if vim.tbl_count(marks) == 0 then
    utils.warn("Easymark: No marks to delete.")
    return
  end

  for _, mark in pairs(marks) do
    local mark_id = mark.mark_id
    vim.api.nvim_buf_del_extmark(self.bufnr, self.ns_id, mark_id)
  end
  self.marks = {}
end

---Get setted extmark col number by line_nr
---Return 0 if not find
---@param line_nr number
function Mark:get_col_by_line_nr(line_nr)
  local all_marks = self.marks
  for index, item in pairs(all_marks) do if index == line_nr then return item.col_nr end end
  return 0
end

---Jump to (1,0)-indexed cursor position in the window.
---@param win "window"
---@param row integer
---@param col integer
function Mark:jump(win, row, col) vim.api.nvim_win_set_cursor(win, {row, col}) end

---Jump to next or previous mark, support loop move
---If no mark setted in window, return
---@param win "window"
---@param direction string: support next|prev, default is "next"
---@return nil
function Mark:jump_to(win, direction)
  direction = direction or "next"
  self:init()

  local cur_row = utils.get_row(win)
  local line_nrs = self:get_line_nrs()
  table.insert(line_nrs, #line_nrs, cur_row)

  table.sort(line_nrs)
  utils.tbl_remove_duplicate(line_nrs)
  local cur_row_index = utils.tbl_get_index(line_nrs, cur_row)
  if cur_row_index == -1 then
    utils.warn("Easymark: No marks to move to.")
    return
  end

  local line_nrs_count = vim.tbl_count(line_nrs)
  local to_mark_row
  if direction == "next" then
    if cur_row_index + 1 <= line_nrs_count then
      to_mark_row = line_nrs[cur_row_index + 1]
    else
      to_mark_row = line_nrs[1]
    end
  elseif direction == "prev" then
    if cur_row_index - 1 >= 1 then
      to_mark_row = line_nrs[cur_row_index - 1]
    else
      to_mark_row = line_nrs[line_nrs_count]
    end
  end

  local to_mark_col = self:get_col_by_line_nr(to_mark_row)
  self:jump(win, to_mark_row, to_mark_col)
end

return Mark
