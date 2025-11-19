-- Fuzzy picker for pages, routes, and components
local M = {}

local utils = require("nuxt-dx-tools.utils")

-- Parse route from page file path
function M.parse_route_from_path(file_path, pages_dir)
  local route = file_path:gsub(pages_dir, ""):gsub("%.vue$", ""):gsub("%.tsx$", ""):gsub("%.jsx$", "")

  -- Handle index routes
  route = route:gsub("/index$", "/")

  -- Handle dynamic routes
  route = route:gsub("%[%.%.%.(.-)%]", ":$1*")  -- [...slug] -> :slug*
  route = route:gsub("%[(.-)%]", ":$1")         -- [id] -> :id

  -- Clean up
  if route == "" then route = "/" end

  return route
end

-- Extract metadata from page file
-- @param file_path string: Path to the Vue page file
-- @return table: Metadata object with layout, middleware, name, etc.
function M.extract_page_metadata(file_path)
  if not file_path or file_path == "" then
    return {}
  end

  local content, err = utils.read_file(file_path)
  if not content then
    -- Don't error on metadata extraction failure, just return empty
    return {}
  end

  local metadata = {
    layout = nil,
    middleware = {},
    name = nil,
    auth = nil,
  }

  -- Safely extract layout
  local ok, layout = pcall(function() return content:match("layout%s*:%s*['\"]([^'\"]+)['\"]") end)
  if ok and layout then
    metadata.layout = layout
  end

  -- Safely extract middleware
  local ok_mw, middleware_matches = pcall(function()
    local matches = {}
    for middleware in content:gmatch("middleware%s*:%s*['\"]([^'\"]+)['\"]") do
      table.insert(matches, middleware)
    end
    return matches
  end)
  if ok_mw and middleware_matches then
    metadata.middleware = middleware_matches
  end

  -- Also check for middleware array
  local ok_arr, middleware_array = pcall(function() return content:match("middleware%s*:%s*%[([^%]]+)%]") end)
  if ok_arr and middleware_array then
    for middleware in middleware_array:gmatch("['\"]([^'\"]+)['\"]") do
      table.insert(metadata.middleware, middleware)
    end
  end

  -- Safely extract route name
  local ok_name, name = pcall(function() return content:match("name%s*:%s*['\"]([^'\"]+)['\"]") end)
  if ok_name and name then
    metadata.name = name
  end

  return metadata
end

-- Get all pages with metadata
-- @return table: List of page objects with path, route, metadata
-- @return string|nil: Error message if failed
function M.get_all_pages()
  local root, err = utils.find_nuxt_root()
  if not root then
    return {}, err or "No Nuxt project root found"
  end

  local pages_dirs, dir_err = utils.get_directory_paths("pages")
  if not pages_dirs or #pages_dirs == 0 then
    return {}, dir_err or "No pages directory found"
  end

  local pages = {}
  local found_pages_dir = false

  for _, pages_dir in ipairs(pages_dirs) do
    if vim.fn.isdirectory(pages_dir) == 1 then
      found_pages_dir = true
      -- Safely glob files
      local ok, files = pcall(vim.fn.glob, pages_dir .. "/**/*.vue", false, true)
      if ok and files and #files > 0 then
        for _, file in ipairs(files) do
          -- Validate file is readable
          if vim.fn.filereadable(file) == 1 then
            local route = M.parse_route_from_path(file, pages_dir)
            local metadata = M.extract_page_metadata(file)

            table.insert(pages, {
              file = file,
              route = route,
              layout = metadata.layout or "default",
              middleware = metadata.middleware,
              name = metadata.name,
              relative_path = file:gsub(vim.pesc(root) .. "/", ""),
            })
          end
        end
      end
    end
  end

  if not found_pages_dir then
    return {}, "Pages directory does not exist. Create pages/ or app/pages/ directory."
  end

  if #pages == 0 then
    return {}, "No .vue files found in pages directory"
  end

  return pages, nil
end

-- Get all components
function M.get_all_components()
  local root = utils.find_nuxt_root()
  if not root then return {} end

  local component_dirs = utils.get_directory_paths("components")
  local components = {}

  for _, comp_dir in ipairs(component_dirs) do
    if vim.fn.isdirectory(comp_dir) == 1 then
      local files = vim.fn.glob(comp_dir .. "/**/*.vue", false, true)

      for _, file in ipairs(files) do
        local name = vim.fn.fnamemodify(file, ":t:r")
        local relative_path = file:gsub(root .. "/", "")

        table.insert(components, {
          file = file,
          name = name,
          relative_path = relative_path,
        })
      end
    end
  end

  return components
end

-- Show page picker using vim.ui.select (fallback) or Telescope
function M.show_page_picker()
  local pages, err = M.get_all_pages()

  if not pages or #pages == 0 then
    local msg = err or "No pages found in project"
    vim.notify(
      "[Nuxt] " .. msg .. "\n\nMake sure you have:\n• A pages/ or app/pages/ directory\n• At least one .vue file in it",
      vim.log.levels.WARN
    )
    return
  end

  -- Check if Telescope is available
  local has_telescope, telescope = pcall(require, "telescope.builtin")
  local has_pickers, pickers = pcall(require, "telescope.pickers")
  local has_finders, finders = pcall(require, "telescope.finders")
  local has_conf, conf = pcall(require, "telescope.config")
  local has_actions, actions = pcall(require, "telescope.actions")
  local has_action_state, action_state = pcall(require, "telescope.actions.state")

  if has_telescope and has_pickers and has_finders and has_conf and has_actions and has_action_state then
    -- Use Telescope
    pickers.new({}, {
      prompt_title = "Nuxt Pages",
      finder = finders.new_table {
        results = pages,
        entry_maker = function(entry)
          local display = string.format(
            "%-40s %-20s %s",
            entry.route,
            entry.layout,
            table.concat(entry.middleware, ", ")
          )
          return {
            value = entry,
            display = display,
            ordinal = entry.route .. " " .. entry.relative_path,
          }
        end,
      },
      sorter = conf.values.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          vim.cmd("edit " .. selection.value.file)
        end)
        return true
      end,
    }):find()
  else
    -- Fallback to vim.ui.select
    vim.ui.select(pages, {
      prompt = "Select page:",
      format_item = function(page)
        local middleware_str = #page.middleware > 0 and (" [" .. table.concat(page.middleware, ", ") .. "]") or ""
        return string.format("%s (layout: %s)%s", page.route, page.layout, middleware_str)
      end,
    }, function(choice)
      if choice then
        vim.cmd("edit " .. choice.file)
      end
    end)
  end
end

-- Show component picker
function M.show_component_picker()
  local components = M.get_all_components()

  if #components == 0 then
    vim.notify("No components found in project", vim.log.levels.WARN)
    return
  end

  -- Check if Telescope is available
  local has_telescope, telescope = pcall(require, "telescope.builtin")
  local has_pickers, pickers = pcall(require, "telescope.pickers")
  local has_finders, finders = pcall(require, "telescope.finders")
  local has_conf, conf = pcall(require, "telescope.config")
  local has_actions, actions = pcall(require, "telescope.actions")
  local has_action_state, action_state = pcall(require, "telescope.actions.state")

  if has_telescope and has_pickers and has_finders and has_conf and has_actions and has_action_state then
    -- Use Telescope
    pickers.new({}, {
      prompt_title = "Nuxt Components",
      finder = finders.new_table {
        results = components,
        entry_maker = function(entry)
          return {
            value = entry,
            display = string.format("%-30s %s", entry.name, entry.relative_path),
            ordinal = entry.name .. " " .. entry.relative_path,
          }
        end,
      },
      sorter = conf.values.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          vim.cmd("edit " .. selection.value.file)
        end)
        return true
      end,
    }):find()
  else
    -- Fallback to vim.ui.select
    vim.ui.select(components, {
      prompt = "Select component:",
      format_item = function(comp)
        return string.format("%s (%s)", comp.name, comp.relative_path)
      end,
    }, function(choice)
      if choice then
        vim.cmd("edit " .. choice.file)
      end
    end)
  end
end

-- Combined picker for pages, components, and routes
function M.show_combined_picker()
  local pages = M.get_all_pages()
  local components = M.get_all_components()

  local all_items = {}

  -- Add pages
  for _, page in ipairs(pages) do
    table.insert(all_items, {
      type = "page",
      file = page.file,
      display = "[PAGE] " .. page.route,
      detail = "Layout: " .. page.layout,
      ordinal = "page " .. page.route .. " " .. page.relative_path,
    })
  end

  -- Add components
  for _, comp in ipairs(components) do
    table.insert(all_items, {
      type = "component",
      file = comp.file,
      display = "[COMPONENT] " .. comp.name,
      detail = comp.relative_path,
      ordinal = "component " .. comp.name .. " " .. comp.relative_path,
    })
  end

  if #all_items == 0 then
    vim.notify("No pages or components found", vim.log.levels.WARN)
    return
  end

  -- Check if Telescope is available
  local has_telescope, telescope = pcall(require, "telescope.builtin")
  local has_pickers, pickers = pcall(require, "telescope.pickers")
  local has_finders, finders = pcall(require, "telescope.finders")
  local has_conf, conf = pcall(require, "telescope.config")
  local has_actions, actions = pcall(require, "telescope.actions")
  local has_action_state, action_state = pcall(require, "telescope.actions.state")

  if has_telescope and has_pickers and has_finders and has_conf and has_actions and has_action_state then
    -- Use Telescope
    pickers.new({}, {
      prompt_title = "Nuxt Pages & Components",
      finder = finders.new_table {
        results = all_items,
        entry_maker = function(entry)
          return {
            value = entry,
            display = string.format("%-50s %s", entry.display, entry.detail),
            ordinal = entry.ordinal,
          }
        end,
      },
      sorter = conf.values.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          vim.cmd("edit " .. selection.value.file)
        end)
        return true
      end,
    }):find()
  else
    -- Fallback to vim.ui.select
    vim.ui.select(all_items, {
      prompt = "Jump to:",
      format_item = function(item)
        return string.format("%s - %s", item.display, item.detail)
      end,
    }, function(choice)
      if choice then
        vim.cmd("edit " .. choice.file)
      end
    end)
  end
end

return M
