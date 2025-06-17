-- Personal utility functions
local M = {}

-- Replace non-ASCII characters with dashes
function M.replace_unicode()
  vim.cmd [[%s/[^\x00-\x7F]/-/g]]
end

function M.bbc_extract_episodes()
  vim.ui.input({ prompt = 'Enter BBC iPlayer episode URL: ' }, function(input)
    if not input or input == '' then
      print 'No URL provided'
      return
    end

    local cmd = string.format(
      [[curl -s "%s" | grep -oE 'href="/iplayer/episode/[^"]*"' | sed -E 's|href="(/iplayer/episode/[^"]*)"|https://www.bbc.co.uk\1|' | sort -u]],
      input
    )

    local output = vim.fn.systemlist(cmd)
    if vim.v.shell_error ~= 0 then
      print 'Error running command'
      return
    end

    -- Insert lines at the cursor position
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    vim.api.nvim_buf_set_lines(0, row, row, true, output)
  end)
end

return M

