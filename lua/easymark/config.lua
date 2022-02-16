local M = {plug_name = "Easymark"}

M.namespace = vim.api.nvim_create_namespace("Easymark")

local function define_highlights()
  vim.cmd("highlight EasymarkDir ctermfg=159 guifg=#719cd6")
  vim.cmd("highlight EasymarkPreview cterm=reverse ctermfg=214 ctermbg=235 gui=reverse guifg=#fabd2f guibg=#282828")

end

---default options
local defaults = {
  position = "bottom", -- position choices: bottom|top|left|right
  height = 20,
  width = 30,
  pane_action_keys = {
    close = "q", -- close mark window
    cancel = "<esc>", -- close the preview and get back to your last position
    refresh = "r", -- manually refresh
    jump = {"<cr>", "<tab>"}, -- jump to the mark
    jump_close = {"o"}, -- jump to the mark and close mark window
    toggle_mode = "t", -- toggle mark between "marked" and "unmacked" mode
    next = "j", -- next item
    previous = "k" -- preview item
  },
  mark_opts = {
    virt_text = "🚩",
    virt_text_pos = 'eol', -- 'eol' | 'overlay' | 'right_align'
  },
  auto_preview = true,
}

---options for setup
M.setup = function(options)
  M.options = vim.tbl_deep_extend("force", {}, defaults, options or {})
  define_highlights()
end

M.setup()

return M
