local M = {}

local function call_ollama(prompt, callback)
  local json_data = vim.json.encode {
    model = 'qwen2.5-coder:1.5b-instruct-q4_0',
    prompt = prompt,
    stream = false,
  }

  local cmd = {
    'curl',
    '-s',
    '-X',
    'POST',
    'http://localhost:11434/api/generate',
    '-H',
    'Content-Type: application/json',
    '-d',
    json_data,
  }

  vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if data and #data > 0 then
        local json_str = table.concat(data, '\n')
        local ok, result = pcall(vim.json.decode, json_str)
        if ok and result.response then
          callback(result.response)
        else
          vim.notify('Error parsing Ollama response', vim.log.levels.ERROR)
        end
      end
    end,
    on_stderr = function(_, data)
      -- Ignore stderr output as it's often not actual errors
    end,
  })
end

function M.generate_code()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local row = cursor_pos[1] - 1

  local lines_before = vim.api.nvim_buf_get_lines(bufnr, math.max(0, row - 10), row, false)
  local lines_after = vim.api.nvim_buf_get_lines(bufnr, row, math.min(vim.api.nvim_buf_line_count(bufnr), row + 10), false)

  local context = table.concat(lines_before, '\n') .. '\n<CURSOR>\n' .. table.concat(lines_after, '\n')
  local filetype = vim.bo[bufnr].filetype

  local prompt = string.format(
    "Complete the code at <CURSOR>. File type: %s\n\nContext:\n%s\n\nOutput ONLY the code to insert. No explanations, no markdown, no code blocks, no comments about what you're doing.",
    filetype,
    context
  )

  vim.api.nvim_echo({ { 'Generating code...', 'MoreMsg' } }, false, {})

  call_ollama(prompt, function(response)
    if response then
      local clean_response = response
        :gsub('^%s*```[%w]*%s*', '') -- Remove opening code blocks
        :gsub('%s*```%s*$', '') -- Remove closing code blocks
        :gsub('^%s*', '') -- Remove leading whitespace
        :gsub('%s*$', '') -- Remove trailing whitespace

      local completion_lines = vim.split(clean_response, '\n')

      vim.schedule(function()
        vim.api.nvim_buf_set_lines(bufnr, row + 1, row + 1, false, completion_lines)
        -- Use a less intrusive notification that doesn't require ENTER
        vim.api.nvim_echo({ { 'Code generated', 'MoreMsg' } }, false, {})
      end)
    end
  end)
end

function M.setup()
  vim.keymap.set('n', '<leader>ag', M.generate_code, { desc = '[A]I [G]enerate code' })
end

return M

