local renderer = require("easymark.renderer")
local config = require("easymark.config")

---Find Easymark buffer
---
---@return string|nil
local function find_easymark_buffer()
  for _, v in ipairs(vim.api.nvim_list_bufs()) do
    if vim.fn.bufname(v) == config.plug_name then return v end
  end
  return nil
end

---Find pre-existing Easymark buffer, delete and wipe it
local function wipe_easymark_buffer()
  local buf = find_easymark_buffer()
  if buf then
    local win_ids = vim.fn.win_findbuf(buf)
    for _, id in ipairs(win_ids) do
      if vim.fn.win_gettype(id) ~= "autocmd" and vim.api.nvim_win_is_valid(id) then
        vim.api.nvim_win_close(id, true)
      end
    end

    vim.api.nvim_buf_set_name(buf, "")
    vim.schedule(function() pcall(vim.api.nvim_buf_delete, buf, {}) end)
  end
end

---@class Pane
---@field buf number
---@field win number
---@field group boolean
---@field items Item[]
---@field parent number
---@field float number
local Pane = {}
Pane.__index = Pane

Pane.create = function(opts)
  opts = opts or {}

  if opts.win then
    Pane.switch_to(opts.win)
    vim.cmd("enew")
  else
    vim.cmd("below new")
    local pos = {bottom = "J", top = "K", left = "H", right = "L"}
    vim.cmd("wincmd " .. (pos[config.options.position] or "K"))
  end
  local buffer = Pane:new(opts)
  buffer:setup(opts)

  if opts and opts.auto then buffer:switch_to_parent() end
  return buffer
end

---@param opts table
---@return table
function Pane:new(opts)
  opts = opts or {}

  local group
  if opts.group ~= nil then
    group = opts.group
  else
    group = config.options.group
  end

  local this = {
    buf = vim.api.nvim_get_current_buf(),
    win = opts.win or vim.api.nvim_get_current_win(),
    parent = opts.parent,
    items = opts.items or {},
    group = group
  }
  setmetatable(this, self)
  return this
end

---@param name string
---@param value string
---@param win string|nil
function Pane:set_option(name, value, win)
  if win then
    return vim.api.nvim_win_set_option(self.win, name, value)
  else
    return vim.api.nvim_buf_set_option(self.buf, name, value)
  end
end

function Pane:clear() return vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, {}) end

Pane.switch_to = function(win, buf)
  if win then
    vim.api.nvim_set_current_win(win)
    if buf then vim.api.nvim_win_set_buf(win, buf) end
  end
end

Pane.jump_to_item = function(win, precmd, item)
  Pane.switch_to(win)
  if precmd then vim.cmd(precmd) end

  if not vim.api.nvim_buf_get_option(item.bufnr, "buflisted") then
    vim.cmd("e #" .. item.bufnr)
  else
    vim.cmd("buffer " .. item.bufnr)
  end

  vim.api.nvim_win_set_cursor(win, {item.line_nr, item.col_nr - 1})
end

function Pane:lock()
  self:set_option("readonly", true)
  self:set_option("modifiable", false)
end

function Pane:unlock()
  self:set_option("modifiable", true)
  self:set_option("readonly", false)
end

---@param lines table
function Pane:render(lines)
  self:unlock()
  self:set_lines(lines)
  self:lock()
end

---@param lines table
---@param first integer
---@param last integer
---@param strict boolean
function Pane:set_lines(lines, first, last, strict)
  first = first or 0
  last = last or -1
  strict = strict or false
  return vim.api.nvim_buf_set_lines(self.buf, first, last, strict, lines)
end

function Pane:is_valid()
  return vim.api.nvim_buf_is_valid(self.buf) and vim.api.nvim_buf_is_loaded(self.buf)
end

function Pane:is_float(win)
  local opts = vim.api.nvim_win_get_config(win)
  return opts and opts.relative and opts.relative ~= ""
end

function Pane:is_valid_parent(win)
  if not vim.api.nvim_win_is_valid(win) then return false end

  if self:is_float(win) then return false end

  local buf = vim.api.nvim_win_get_buf(win)
  if vim.api.nvim_buf_get_option(buf, "buftype") ~= "" then return false end

  return true
end

---@param opts table
function Pane:update(opts) renderer.render(self, opts) end

function Pane:close()
  if vim.api.nvim_win_is_valid(self.win) then vim.api.nvim_win_close(self.win, {}) end

  if vim.api.nvim_buf_is_valid(self.buf) then vim.api.nvim_buf_delete(self.buf, {}) end
end

function Pane:close_preview()
  -- reset parent state
  local is_valid_win = vim.api.nvim_win_is_valid(self.parent)
  -- LuaFormatter off
    local is_valid_buf = self.parent_state and vim.api.nvim_buf_is_valid(self.parent_state.buf)
  -- LuaFormatter on

  if self.parent_state and is_valid_win and is_valid_buf then
    vim.api.nvim_win_set_buf(self.parent, self.parent_state.buf)
    vim.api.nvim_win_set_cursor(self.parent, self.parent_state.cursor)
  end

  self.parent_state = nil
end

function Pane:on_enter()
  self.parent = self.parent or vim.fn.win_getid(vim.fn.winnr("#"))

  if (not self:is_valid_parent(self.parent)) or self.parent == self.win then
    for _, win in pairs(vim.api.nvim_list_wins) do
      if self:is_valid_parent(win) and win ~= self.win then
        self.parent = win
        break
      end
    end
  end

  if not vim.api.nvim_win_is_valid(self.parent) then return self:close() end

  self.parent_state = {
    buf = vim.api.nvim_win_get_buf(self.parent),
    cursor = vim.api.nvim_win_get_cursor(self.parent)
  }
end

function Pane:on_leave() self:close_preview() end

function Pane:switch_to_parent() Pane.switch_to(self.parent) end

function Pane:on_win_enter()
  local parent = self.parent
  local current_win = vim.api.nvim_get_current_win()
  if vim.fn.winnr("$") == 1 and current_win == self.win then
    vim.cmd("q")
    return
  end

  if not self:is_valid_parent(current_win) then return end

  if current_win ~= parent and current_win ~= self.win then
    parent = current_win
    if self:is_valid() then vim.defer_fn(function() self:update() end, 100) end
  end

  local current_buf = vim.api.nvim_get_current_buf()
  if current_win == self.win and current_buf ~= self.buf then
    vim.api.nvim_win_set_buf(parent, current_buf)
    vim.api.nvim_win_set_option(parent, "winhl", "")
    vim.api.nvim_win_close(self.win, false)
    require("easymark").open()
    Pane.switch_to(parent, current_buf)
  end
end

function Pane:get_cusor() return vim.api.nvim_win_get_cursor(self.win) end

function Pane:get_line() return self:get_cusor()[1] end

function Pane:get_col() return self:get_cusor()[2] end

function Pane:current_item()
  local line = self:get_line()
  local item = self.items[line - 1]

  return item
end

function Pane:jump()
  local item = self:current_item()
  if not item then return end

  Pane.jump_to_item(item.win or self.parent, nil, item)
end

function Pane:next_item()
  local line = self:get_line()
  local line_count = vim.api.nvim_buf_line_count(self.buf)
  -- skip if only title
  if line_count == 1 then return end

  for i = line + 1, line_count do
    if self.items[i - 1] then
      vim.api.nvim_win_set_cursor(self.win, {i, 0})
      return
    end
  end
end

function Pane:prev_item()
  local line = self:get_line()
  local line_count = vim.api.nvim_buf_line_count(self.buf)
  -- skip if only title
  if line_count == 1 then return end

  -- print("line: ", line, " line_count: ", line_count)
  for i = line - 1, 1, -1 do
    if self.items[i - 1] then
      vim.api.nvim_win_set_cursor(self.win, {i, 0})
      return
    end
  end
end

function Pane:focus()
  Pane.switch_to(self.win, self.buf)

  local line = self:get_line()
  if line == 1 then self:next_item() end
end

---@param opts table
function Pane:setup(opts)
  opts = opts or {}
  vim.cmd("setlocal nonu")
  vim.cmd("setlocal nornu")
  vim.cmd('setlocal colorcolumn=""')

  if not pcall(vim.api.nvim_buf_set_name, self.buf, config.plug_name) then
    wipe_easymark_buffer()
    vim.api.nvim_buf_set_name(self.buf, config.plug_name)
  end

  self:set_option("filetype", config.plug_name)
  self:set_option("bufhidden", "wipe")
  self:set_option("buftype", "nofile")
  self:set_option("swapfile", false)
  self:set_option("buflisted", false)
  self:set_option("winfixwidth", true, true)
  self:set_option("wrap", false, true)
  self:set_option("spell", false, true)
  self:set_option("list", false, true)
  self:set_option("winfixheight", true, true)
  self:set_option("signcolumn", "no", true)
  self:set_option("fcs", "eob: ", true)

  local options = config.options
  for action, keys in pairs(options.pane_action_keys) do
    if type(keys) == "string" then keys = {keys} end

    for _, key in pairs(keys) do
      -- LuaFormatter off
      vim.api.nvim_buf_set_keymap(self.buf, "n", key,
                                  [[<cmd>lua require("easymark").do_action("]] .. action .. [[")<cr>]],
                                  {silent = true, noremap = true, nowait = true})
      -- LuaFormatter on
    end
  end

  if options.position == "top" or options.position == "bottom" then
    vim.api.nvim_win_set_height(self.win, options.height)
  else
    vim.api.nvim_win_set_width(self.win, options.width)
  end

  vim.api.nvim_exec([[
        augroup EasymarkActions
            autocmd! * <buffer>
            autocmd BufEnter <buffer> lua require("easymark").do_action("on_enter")
            autocmd CursorMoved <buffer> lua require("easymark").do_action("auto_preview")
            autocmd BufLeave <buffer> lua require("easymark").do_action("on_leave")
        augroup END
    ]], false)

  if not opts.parent then self:on_enter() end
  self:lock()
  self:update(opts)
end

function Pane:preview()
  if not vim.api.nvim_win_is_valid(self.parent) then return end

  local item = self:current_item()
  if not item then return end

  vim.api.nvim_win_set_cursor(self.parent, {item.line_nr, 0})
end

return Pane
