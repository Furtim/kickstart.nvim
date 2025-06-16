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

  local lines_before = vim.api.nvim_buf_get_lines(bufnr, math.max(0, row - 15), row, false)
  local lines_after = vim.api.nvim_buf_get_lines(bufnr, row, math.min(vim.api.nvim_buf_line_count(bufnr), row + 15), false)

  local context = table.concat(lines_before, '\n') .. '\n<CURSOR>\n' .. table.concat(lines_after, '\n')
  local filetype = vim.bo[bufnr].filetype

  vim.ui.input({
    prompt = 'What would you like to generate? ',
    default = 'Complete the code'
  }, function(user_prompt)
    if not user_prompt or user_prompt == '' then
      return
    end
    
    local prompt = string.format(
      "%s at <CURSOR>.\n\nContext:\n%s\n\nIMPORTANT: Return ONLY the raw code to insert. No explanations, no markdown formatting, no ```code blocks```, no comments about your changes, no extra text. Just the exact code that should be inserted.",
      user_prompt,
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
          vim.api.nvim_echo({ { 'Code generated', 'MoreMsg' } }, false, {})
        end)
      end
    end)
  end)
end

function M.replace_selection()
  local bufnr = vim.api.nvim_get_current_buf()
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  
  local start_row = start_pos[2] - 1
  local start_col = start_pos[3] - 1
  local end_row = end_pos[2] - 1
  local end_col = end_pos[3]
  
  local selected_lines = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row + 1, false)
  
  if #selected_lines == 0 then
    vim.notify('No text selected', vim.log.levels.WARN)
    return
  end
  
  if #selected_lines == 1 then
    selected_lines[1] = string.sub(selected_lines[1], start_col + 1, end_col)
  else
    selected_lines[1] = string.sub(selected_lines[1], start_col + 1)
    selected_lines[#selected_lines] = string.sub(selected_lines[#selected_lines], 1, end_col)
  end
  
  local selected_text = table.concat(selected_lines, '\n')
  local filetype = vim.bo[bufnr].filetype
  
  vim.ui.input({
    prompt = 'Enter your prompt: ',
    default = ''
  }, function(user_prompt)
    if not user_prompt or user_prompt == '' then
      return
    end
    
    local prompt = string.format(
      "%s\n\nHere is the %s code to work with:\n\n%s\n\nIMPORTANT: Return the COMPLETE modified code including all original lines. Return ALL the code after making the requested changes. No explanations, no markdown formatting, no ```code blocks```, no comments about your changes, no extra text before or after. Just the exact complete code.",
      user_prompt,
      filetype,
      selected_text
    )
    
    vim.api.nvim_echo({ { 'Processing selection...', 'MoreMsg' } }, false, {})
    
    call_ollama(prompt, function(response)
      if response then
        local clean_response = response
          :gsub('^%s*```[%w]*%s*', '') -- Remove opening code blocks
          :gsub('%s*```%s*$', '') -- Remove closing code blocks
          :gsub('^%s*', '') -- Remove leading whitespace
          :gsub('%s*$', '') -- Remove trailing whitespace
        
        local replacement_lines = vim.split(clean_response, '\n')
        
        vim.schedule(function()
          vim.api.nvim_buf_set_lines(bufnr, start_row, end_row + 1, false, replacement_lines)
          vim.api.nvim_echo({ { 'Code replaced', 'MoreMsg' } }, false, {})
        end)
      end
    end)
  end)
end

function M.setup()
  vim.keymap.set('n', '<leader>ag', M.generate_code, { desc = '[A]I [G]enerate code' })
  vim.keymap.set('v', '<leader>ar', M.replace_selection, { desc = '[A]I [R]eplace selection' })
end

return M
