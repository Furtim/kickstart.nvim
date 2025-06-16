-- Personal utility functions
local M = {}

-- Replace non-ASCII characters with dashes
function M.replace_unicode()
  vim.cmd [[%s/[^\x00-\x7F]/-/g]]
end

return M