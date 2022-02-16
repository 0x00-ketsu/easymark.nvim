local Pane = require("easymark.pane")
local mark = require("easymark.mark")
local config = require("easymark.config")
local utils = require("easymark.utils")
-- instance of Easymark Pane
local pane

local function get_opts(...)
  local args = {...}
  if vim.tbl_islist(args) and #args == 1 and type(args[1]) == "table" then args = arg[1] end

  local opts = {}
  for key, val in pairs(args) do
    if type(key) == "number" then
      local k, v = val:match("^(.*)=(.*)$")
      if k then
        opts[k] = v
      elseif opts.mode then
        utils.error("unknown option " .. val)
      else
        opts.mode = val
      end
    else
      opts[key] = val
    end
  end

  opts = opts or {}
  config.options.cmd_options = opts
  return opts
end

local function is_open() return pane and pane:is_valid() end

-- ********** Easymark **********
local Easymark = {}
Easymark.setup = function(options)
  local version = vim.version()
  local release = tonumber(version.major .. "." .. version.minor)
  if release < 0.6 then error("extmark requires neovim 0.6 or higher") end

  config.setup(options)
end

-- ================ Mark ===================
Easymark.toggle_mark = function()
  local filetype = vim.bo.filetype
  if filetype == "nerdtree" then return end

  local pos = vim.api.nvim_win_get_cursor(0)
  local line_nr = pos[1]
  local col_nr = pos[2] + 1

  local m = mark:get_by_line_nr(line_nr)
  if m ~= nil then
    mark:del(line_nr)
  else
    mark:set(line_nr, col_nr)
  end

  -- refresh pane
end

Easymark.clear_mark = function() mark:del_all() end

Easymark.next_mark = function() mark:jump_to(0, "next") end

Easymark.prev_mark = function() mark:jump_to(0, "prev") end

-- ================= Pane ==================
Easymark.open_pane = function(...)
  local opts = get_opts(...)
  opts.focus = true

  -- assign to items
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_get_current_buf()
  local all_marks = mark:get_all()
  local items = {}
  for line_nr, mark in pairs(all_marks) do
    items[#items + 1] = {
      win = win,
      bufnr = buf,
      line_nr = line_nr,
      col_nr = mark.col_nr,
      line_content = mark.line_content
    }
  end
  opts.items = items

  if is_open() then
    Easymark.refresh(opts)
  else
    pane = Pane.create(opts)
  end
end

Easymark.close_pane = function() if is_open() then pane:close() end end

Easymark.toggle_pane = function(...)
  local opts = get_opts(...)
  opts = opts or {}
  if opts.mode and (opts.mode ~= config.options.mode) then
    config.options.mode = opts.mode
    Easymark.open(...)
    return
  end

  if is_open() then
    Easymark.close_pane()
  else
    Easymark.open_pane(...)
  end
end

Easymark.refresh_pane = function(opts) opts = opts or {} end

Easymark.do_action = function(action)
  if config.options.auto_preview and action == "auto_preview" then pane:preview() end

  if action == "jump" then pane:jump() end
  if action == "jump_close" then
    pane:jump()
    Easymark.close_pane()
  end
  if action == "next" then pane:next_item() end
  if action == "previous" then pane:prev_item() end
end

Easymark.get_items = function()
  if pane ~= nil then
    return pane.items
  else
    return {}
  end
end

return Easymark
