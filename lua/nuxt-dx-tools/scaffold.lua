-- Scaffold generator for Nuxt files
local M = {}

local utils = require("nuxt-dx-tools.utils")

-- Templates for different file types
M.templates = {
  page = function(name, options)
    local template = [[<script setup lang="ts">
definePageMeta({
  ${page_meta}
})

${composables}
</script>

<template>
  <div>
    <h1>${title}</h1>
    ${content}
  </div>
</template>

<style scoped>
</style>
]]
    local page_meta = {}
    if options.layout then
      table.insert(page_meta, "layout: '" .. options.layout .. "'")
    end
    if options.middleware then
      table.insert(page_meta, "middleware: '" .. options.middleware .. "'")
    end
    if options.name then
      table.insert(page_meta, "name: '" .. options.name .. "'")
    end

    local composables = {}
    if options.use_async_data then
      table.insert(composables, "const { data } = await useAsyncData('" .. name .. "-data', () => {\n  // Fetch data here\n  return {}\n})")
    end

    template = template:gsub("${page_meta}", table.concat(page_meta, ",\n  "))
    template = template:gsub("${composables}", table.concat(composables, "\n\n"))
    template = template:gsub("${title}", name:gsub("^%l", string.upper))
    template = template:gsub("${content}", "<p>Page content</p>")

    return template
  end,

  component = function(name, options)
    local template = [[<script setup lang="ts">
${props}${emits}
</script>

<template>
  <div class="${class_name}">
    ${content}
  </div>
</template>

<style scoped>
.${class_name} {
  /* Component styles */
}
</style>
]]
    local props = ""
    if options.with_props then
      props = [[interface Props {
  // Define props here
}

const props = defineProps<Props>()

]]
    end

    local emits = ""
    if options.with_emits then
      emits = [[const emit = defineEmits<{
  // Define emits here
}>()

]]
    end

    template = template:gsub("${props}", props)
    template = template:gsub("${emits}", emits)
    template = template:gsub("${class_name}", name:gsub("([A-Z])", "-%1"):gsub("^%-", ""):lower())
    template = template:gsub("${content}", "<slot />")

    return template
  end,

  composable = function(name, options)
    local template = [[/**
 * ${description}
 */
export const ${function_name} = (${params}) => {
  ${state}

  ${logic}

  return {
    ${returns}
  }
}
]]
    template = template:gsub("${description}", options.description or ("Composable: " .. name))
    template = template:gsub("${function_name}", name)
    template = template:gsub("${params}", options.params or "")

    local state = ""
    if options.use_state then
      state = "const state = useState('" .. name .. "-state', () => ({}))\n  "
    end

    local logic = "// Composable logic here"

    local returns = ""
    if options.use_state then
      returns = "state"
    end

    template = template:gsub("${state}", state)
    template = template:gsub("${logic}", logic)
    template = template:gsub("${returns}", returns)

    return template
  end,

  api_route = function(name, options)
    local method = options.method or "GET"
    local template

    if method == "GET" then
      template = [[export default defineEventHandler(async (event) => {
  ${query_params}

  // Handle GET request
  return {
    message: "Success",
    data: ${return_data}
  }
})
]]
    elseif method == "POST" then
      template = [[export default defineEventHandler(async (event) => {
  const body = await readBody(event)

  ${validation}

  // Handle POST request
  return {
    message: "Created",
    data: body
  }
})
]]
    elseif method == "PUT" then
      template = [[export default defineEventHandler(async (event) => {
  const body = await readBody(event)
  ${params}

  // Handle PUT request
  return {
    message: "Updated",
    data: body
  }
})
]]
    elseif method == "DELETE" then
      template = [[export default defineEventHandler(async (event) => {
  ${params}

  // Handle DELETE request
  return {
    message: "Deleted"
  }
})
]]
    end

    template = template:gsub("${query_params}", "const query = getQuery(event)")
    template = template:gsub("${params}", "// Extract route params if needed")
    template = template:gsub("${validation}", "// Validate body here")
    template = template:gsub("${return_data}", "{}")

    return template
  end,

  middleware = function(name, options)
    local template = [[export default defineNuxtRouteMiddleware((to, from) => {
  ${auth_check}

  ${logic}
})
]]
    local auth_check = ""
    if options.auth then
      auth_check = [[// Check authentication
  const user = useState('user')
  if (!user.value) {
    return navigateTo('/login')
  }

  ]]
    end

    template = template:gsub("${auth_check}", auth_check)
    template = template:gsub("${logic}", "// Middleware logic here")

    return template
  end,

  plugin = function(name, options)
    local template = [[export default defineNuxtPlugin((nuxtApp) => {
  ${provides}

  ${hooks}

  return {
    provide: {
      ${provide_exports}
    }
  }
})
]]
    local provides = ""
    if options.provide then
      provides = [[// Provide utilities or services
  const myUtility = () => {
    // Utility logic
  }

  ]]
    end

    local hooks = ""
    if options.hooks then
      hooks = [[// Register hooks
  nuxtApp.hook('app:created', () => {
    console.log('App created')
  })

  ]]
    end

    template = template:gsub("${provides}", provides)
    template = template:gsub("${hooks}", hooks)
    template = template:gsub("${provide_exports}", options.provide and (name .. ": myUtility") or "")

    return template
  end,

  layout = function(name, options)
    local template = [[<script setup lang="ts">
${composables}
</script>

<template>
  <div class="layout-${name}">
    ${header}
    <main>
      <slot />
    </main>
    ${footer}
  </div>
</template>

<style scoped>
.layout-${name} {
  /* Layout styles */
}
</style>
]]
    local composables = ""
    if options.use_route then
      composables = "const route = useRoute()\n"
    end

    template = template:gsub("${composables}", composables)
    template = template:gsub("${name}", name)
    template = template:gsub("${header}", options.header and "<header><h1>Header</h1></header>" or "")
    template = template:gsub("${footer}", options.footer and "<footer><p>Footer</p></footer>" or "")

    return template
  end,
}

-- Main scaffold function
function M.scaffold(type, name, options)
  local template_fn = M.templates[type]
  if not template_fn then
    vim.notify("Unknown scaffold type: " .. type, vim.log.levels.ERROR)
    return
  end

  local content = template_fn(name, options or {})
  return content
end

-- Interactive scaffold generator
function M.new()
  local root = utils.find_nuxt_root()
  if not root then
    vim.notify("Not in a Nuxt project", vim.log.levels.ERROR)
    return
  end

  -- Step 1: Select type
  vim.ui.select({
    "Page",
    "Component",
    "Composable",
    "API Route",
    "Middleware",
    "Plugin",
    "Layout",
  }, {
    prompt = "Select file type to scaffold:",
  }, function(choice)
    if not choice then return end

    local type_lower = choice:lower():gsub(" ", "_")

    -- Step 2: Get name
    vim.ui.input({
      prompt = "Enter " .. choice .. " name: ",
    }, function(name)
      if not name or name == "" then return end

      -- Step 3: Get options based on type
      local options = {}

      local function create_file()
        local content = M.scaffold(type_lower, name, options)

        -- Determine file path
        local structure = utils.detect_structure()
        local base_dir = structure.has_app_dir and (root .. "/app") or root
        local file_path

        if type_lower == "page" then
          file_path = base_dir .. "/pages/" .. name .. ".vue"
        elseif type_lower == "component" then
          file_path = base_dir .. "/components/" .. name .. ".vue"
        elseif type_lower == "composable" then
          file_path = base_dir .. "/composables/" .. name .. ".ts"
        elseif type_lower == "api_route" then
          file_path = root .. "/server/api/" .. name .. ".ts"
        elseif type_lower == "middleware" then
          file_path = base_dir .. "/middleware/" .. name .. ".ts"
        elseif type_lower == "plugin" then
          file_path = base_dir .. "/plugins/" .. name .. ".ts"
        elseif type_lower == "layout" then
          file_path = base_dir .. "/layouts/" .. name .. ".vue"
        end

        -- Create directory if it doesn't exist
        local dir = vim.fn.fnamemodify(file_path, ":h")
        vim.fn.mkdir(dir, "p")

        -- Check if file already exists
        if utils.file_exists(file_path) then
          vim.ui.select({ "Yes", "No" }, {
            prompt = "File already exists. Overwrite?",
          }, function(overwrite)
            if overwrite == "Yes" then
              vim.fn.writefile(vim.split(content, "\n"), file_path)
              vim.cmd("edit " .. file_path)
              vim.notify("Created " .. choice .. ": " .. file_path, vim.log.levels.INFO)
            end
          end)
        else
          vim.fn.writefile(vim.split(content, "\n"), file_path)
          vim.cmd("edit " .. file_path)
          vim.notify("Created " .. choice .. ": " .. file_path, vim.log.levels.INFO)
        end
      end

      -- Collect options based on type
      if type_lower == "page" then
        vim.ui.input({ prompt = "Layout (optional): " }, function(layout)
          options.layout = layout ~= "" and layout or nil
          vim.ui.select({ "Yes", "No" }, {
            prompt = "Include useAsyncData?",
          }, function(async_choice)
            options.use_async_data = async_choice == "Yes"
            create_file()
          end)
        end)
      elseif type_lower == "component" then
        vim.ui.select({ "Yes", "No" }, {
          prompt = "Include props?",
        }, function(props_choice)
          options.with_props = props_choice == "Yes"
          vim.ui.select({ "Yes", "No" }, {
            prompt = "Include emits?",
          }, function(emits_choice)
            options.with_emits = emits_choice == "Yes"
            create_file()
          end)
        end)
      elseif type_lower == "composable" then
        vim.ui.select({ "Yes", "No" }, {
          prompt = "Use useState?",
        }, function(state_choice)
          options.use_state = state_choice == "Yes"
          create_file()
        end)
      elseif type_lower == "api_route" then
        vim.ui.select({ "GET", "POST", "PUT", "DELETE" }, {
          prompt = "HTTP Method:",
        }, function(method)
          options.method = method
          create_file()
        end)
      elseif type_lower == "middleware" then
        vim.ui.select({ "Yes", "No" }, {
          prompt = "Include auth check?",
        }, function(auth_choice)
          options.auth = auth_choice == "Yes"
          create_file()
        end)
      elseif type_lower == "plugin" then
        vim.ui.select({ "Yes", "No" }, {
          prompt = "Provide utilities?",
        }, function(provide_choice)
          options.provide = provide_choice == "Yes"
          create_file()
        end)
      else
        create_file()
      end
    end)
  end)
end

return M
