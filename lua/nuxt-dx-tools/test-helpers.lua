-- Test helper navigation and stub generation
local M = {}

local utils = require("nuxt-dx-tools.utils")

-- Common test file patterns
M.test_patterns = {
  { from = "%.vue$", to = ".spec.ts", dir_change = nil },
  { from = "%.vue$", to = ".test.ts", dir_change = nil },
  { from = "%.ts$", to = ".spec.ts", dir_change = nil },
  { from = "%.ts$", to = ".test.ts", dir_change = nil },
  { from = "%.js$", to = ".spec.js", dir_change = nil },
  { from = "%.js$", to = ".test.js", dir_change = nil },
  -- With __tests__ directory
  { from = "%.vue$", to = ".spec.ts", dir_change = "__tests__" },
  { from = "%.ts$", to = ".spec.ts", dir_change = "__tests__" },
}

-- Find test file for current file
function M.find_test_file(file_path)
  file_path = file_path or vim.api.nvim_buf_get_name(0)

  -- Try each pattern
  for _, pattern in ipairs(M.test_patterns) do
    local test_file

    if pattern.dir_change then
      -- Look for test in __tests__ directory
      local dir = vim.fn.fnamemodify(file_path, ":h")
      local filename = vim.fn.fnamemodify(file_path, ":t")
      local test_filename = filename:gsub(pattern.from, pattern.to)
      test_file = dir .. "/" .. pattern.dir_change .. "/" .. test_filename
    else
      -- Look for test file in same directory
      test_file = file_path:gsub(pattern.from, pattern.to)
    end

    if utils.file_exists(test_file) then
      return test_file
    end
  end

  return nil
end

-- Find source file from test file
function M.find_source_file(test_file)
  test_file = test_file or vim.api.nvim_buf_get_name(0)

  -- Try to reverse patterns
  for _, pattern in ipairs(M.test_patterns) do
    if pattern.dir_change then
      -- Remove __tests__ directory
      local source_file = test_file:gsub("/" .. pattern.dir_change .. "/", "/")
      source_file = source_file:gsub(pattern.to, pattern.from)
      if utils.file_exists(source_file) then
        return source_file
      end
    else
      local source_file = test_file:gsub(pattern.to, pattern.from)
      if utils.file_exists(source_file) then
        return source_file
      end
    end
  end

  return nil
end

-- Jump to test file or source file
function M.toggle_test_file()
  local current_file = vim.api.nvim_buf_get_name(0)

  -- Check if current file is a test file
  if current_file:match("%.spec%.") or current_file:match("%.test%.") then
    -- Jump to source file
    local source_file = M.find_source_file(current_file)
    if source_file then
      vim.cmd("edit " .. source_file)
    else
      vim.notify("Source file not found", vim.log.levels.WARN)
    end
  else
    -- Jump to test file
    local test_file = M.find_test_file(current_file)
    if test_file then
      vim.cmd("edit " .. test_file)
    else
      -- Offer to create test file
      vim.ui.select({ "Yes", "No" }, {
        prompt = "Test file not found. Create one?",
      }, function(choice)
        if choice == "Yes" then
          M.create_test_file(current_file)
        end
      end)
    end
  end
end

-- Generate test stub for a component
function M.generate_component_test(file_path)
  local filename = vim.fn.fnamemodify(file_path, ":t:r")
  local component_name = filename

  local template = [[import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'
import ${component_name} from '${import_path}'

describe('${component_name}', () => {
  it('renders properly', () => {
    const wrapper = mount(${component_name}, {
      props: {
        // Add props here
      }
    })

    expect(wrapper.exists()).toBe(true)
  })

  it('emits events correctly', async () => {
    const wrapper = mount(${component_name})

    // Test emit
    // await wrapper.vm.$emit('event-name', payload)
    // expect(wrapper.emitted('event-name')).toBeTruthy()
  })

  it('handles user interactions', async () => {
    const wrapper = mount(${component_name})

    // Test interactions
    // await wrapper.find('button').trigger('click')
  })
})
]]

  local relative_import = "./" .. filename .. ".vue"
  template = template:gsub("${component_name}", component_name)
  template = template:gsub("${import_path}", relative_import)

  return template
end

-- Generate test stub for a composable
function M.generate_composable_test(file_path)
  local filename = vim.fn.fnamemodify(file_path, ":t:r")
  local composable_name = filename

  local template = [[import { describe, it, expect } from 'vitest'
import { ${composable_name} } from '${import_path}'

describe('${composable_name}', () => {
  it('returns expected shape', () => {
    const result = ${composable_name}()

    expect(result).toBeDefined()
    // Add specific assertions
  })

  it('handles state changes', () => {
    const result = ${composable_name}()

    // Test state changes
    // result.someMethod()
    // expect(result.state.value).toBe(expected)
  })
})
]]

  local relative_import = "./" .. filename
  template = template:gsub("${composable_name}", composable_name)
  template = template:gsub("${import_path}", relative_import)

  return template
end

-- Generate test stub for an API route
function M.generate_api_route_test(file_path)
  local filename = vim.fn.fnamemodify(file_path, ":t:r")
  local route_path = file_path:match("/server/api/(.+)%.%w+$")

  local template = [[import { describe, it, expect } from 'vitest'
import { $fetch } from '@nuxt/test-utils'

describe('API: /api/${route_path}', () => {
  it('returns successful response', async () => {
    const response = await $fetch('/api/${route_path}')

    expect(response).toBeDefined()
    // Add specific assertions
  })

  it('handles errors correctly', async () => {
    // Test error cases
    await expect(
      $fetch('/api/${route_path}', {
        method: 'POST',
        body: { /* invalid data */ }
      })
    ).rejects.toThrow()
  })
})
]]

  template = template:gsub("${route_path}", route_path or "route")

  return template
end

-- Create test file
function M.create_test_file(source_file)
  source_file = source_file or vim.api.nvim_buf_get_name(0)

  -- Determine test file path
  local test_file = source_file:gsub("%.vue$", ".spec.ts")
  test_file = test_file:gsub("%.ts$", ".spec.ts")
  test_file = test_file:gsub("%.js$", ".spec.js")

  -- Generate test content based on file type
  local content
  if source_file:match("%.vue$") then
    content = M.generate_component_test(source_file)
  elseif source_file:match("/composables/") then
    content = M.generate_composable_test(source_file)
  elseif source_file:match("/server/api/") then
    content = M.generate_api_route_test(source_file)
  else
    content = [[import { describe, it, expect } from 'vitest'

describe('Test Suite', () => {
  it('should pass', () => {
    expect(true).toBe(true)
  })
})
]]
  end

  -- Create directory if needed
  local dir = vim.fn.fnamemodify(test_file, ":h")
  vim.fn.mkdir(dir, "p")

  -- Write file
  vim.fn.writefile(vim.split(content, "\n"), test_file)
  vim.cmd("edit " .. test_file)
  vim.notify("Created test file: " .. test_file, vim.log.levels.INFO)
end

-- Run test for current file
function M.run_current_test()
  local current_file = vim.api.nvim_buf_get_name(0)

  -- Check if it's a test file
  if not (current_file:match("%.spec%.") or current_file:match("%.test%.")) then
    local test_file = M.find_test_file(current_file)
    if test_file then
      current_file = test_file
    else
      vim.notify("No test file found for current file", vim.log.levels.WARN)
      return
    end
  end

  local relative_path = current_file:gsub(utils.find_nuxt_root() .. "/", "")

  -- Open terminal and run test
  vim.cmd("botright split")
  vim.cmd("terminal")

  vim.defer_fn(function()
    local chan_id = vim.b.terminal_job_id
    if chan_id then
      vim.fn.chansend(chan_id, "npm run test " .. relative_path .. "\r")
    end
  end, 100)
end

-- Run all tests
function M.run_all_tests()
  vim.cmd("botright split")
  vim.cmd("terminal")

  vim.defer_fn(function()
    local chan_id = vim.b.terminal_job_id
    if chan_id then
      vim.fn.chansend(chan_id, "npm run test\r")
    end
  end, 100)
end

return M
