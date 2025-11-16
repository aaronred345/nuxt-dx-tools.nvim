-- Nuxt 4 code snippets
local M = {}

-- Snippet definitions for Nuxt 4
M.snippets = {
  -- Page snippets
  nuxt_page = {
    prefix = "npage",
    body = [[<script setup lang="ts">
definePageMeta({
  layout: 'default'
})
</script>

<template>
  <div>
    <h1>$1</h1>
  </div>
</template>

<style scoped>
</style>]],
    description = "Nuxt 4 page template"
  },

  -- Component snippets
  nuxt_component = {
    prefix = "ncomp",
    body = [[<script setup lang="ts">
interface Props {
  $1
}

const props = defineProps<Props>()
</script>

<template>
  <div>
    $0
  </div>
</template>

<style scoped>
</style>]],
    description = "Nuxt 4 component with TypeScript props"
  },

  -- Data fetching snippets
  use_async_data = {
    prefix = "nuad",
    body = [[const { data: $1, pending, error, refresh } = await useAsyncData('$2', async () => {
  $0
})]],
    description = "useAsyncData with all return values"
  },

  use_fetch = {
    prefix = "nufetch",
    body = [[const { data: $1, pending, error, refresh } = await useFetch('$2', {
  $0
})]],
    description = "useFetch with options"
  },

  use_lazy_fetch = {
    prefix = "nulazy",
    body = [[const { data: $1, pending, error } = useLazyFetch('$2', {
  $0
})]],
    description = "useLazyFetch for client-side data"
  },

  -- State management
  use_state = {
    prefix = "nustate",
    body = [[const $1 = useState('$2', () => $3)]],
    description = "useState with initial value"
  },

  -- Page meta
  define_page_meta = {
    prefix = "npmeta",
    body = [[definePageMeta({
  layout: '$1',
  middleware: '$2',
  $0
})]],
    description = "definePageMeta with common options"
  },

  -- Middleware
  nuxt_middleware = {
    prefix = "nmiddleware",
    body = [[export default defineNuxtRouteMiddleware((to, from) => {
  $0
})]],
    description = "Nuxt route middleware"
  },

  -- Plugin
  nuxt_plugin = {
    prefix = "nplugin",
    body = [[export default defineNuxtPlugin((nuxtApp) => {
  return {
    provide: {
      $1: $0
    }
  }
})]],
    description = "Nuxt plugin with provide"
  },

  -- API route (GET)
  api_get = {
    prefix = "napi-get",
    body = [[export default defineEventHandler(async (event) => {
  const query = getQuery(event)

  return {
    $0
  }
})]],
    description = "Nitro GET handler"
  },

  -- API route (POST)
  api_post = {
    prefix = "napi-post",
    body = [[export default defineEventHandler(async (event) => {
  const body = await readBody(event)

  return {
    $0
  }
})]],
    description = "Nitro POST handler"
  },

  -- Composable
  nuxt_composable = {
    prefix = "ncomposable",
    body = [[export const use$1 = () => {
  $0

  return {
  }
}]],
    description = "Nuxt composable template"
  },

  -- Head/SEO
  use_head = {
    prefix = "nuhead",
    body = [[useHead({
  title: '$1',
  meta: [
    { name: 'description', content: '$2' }
  ]
})]],
    description = "useHead for SEO"
  },

  use_seo_meta = {
    prefix = "nuseo",
    body = [[useSeoMeta({
  title: '$1',
  description: '$2',
  ogTitle: '$1',
  ogDescription: '$2',
  ogImage: '$3',
  twitterCard: 'summary_large_image',
})]],
    description = "useSeoMeta with common fields"
  },
}

-- Insert snippet at cursor
function M.insert_snippet(snippet_key)
  local snippet = M.snippets[snippet_key]
  if not snippet then
    vim.notify("Snippet not found: " .. snippet_key, vim.log.levels.ERROR)
    return
  end

  local lines = vim.split(snippet.body, "\n")
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] - 1

  -- Insert snippet
  vim.api.nvim_buf_set_lines(0, row, row, false, lines)

  -- Move cursor to first placeholder if exists
  local first_placeholder_line = nil
  for i, line in ipairs(lines) do
    if line:match("%$%d") then
      first_placeholder_line = row + i - 1
      break
    end
  end

  if first_placeholder_line then
    vim.api.nvim_win_set_cursor(0, { first_placeholder_line + 1, 0 })
  end

  vim.notify("Inserted snippet: " .. snippet.description, vim.log.levels.INFO)
end

-- Show snippet picker
function M.show_picker()
  local snippet_list = {}
  for key, snippet in pairs(M.snippets) do
    table.insert(snippet_list, {
      key = key,
      prefix = snippet.prefix,
      description = snippet.description,
    })
  end

  -- Sort by prefix
  table.sort(snippet_list, function(a, b)
    return a.prefix < b.prefix
  end)

  vim.ui.select(snippet_list, {
    prompt = "Select Nuxt snippet:",
    format_item = function(item)
      return string.format("%-20s %s", item.prefix, item.description)
    end,
  }, function(choice)
    if choice then
      M.insert_snippet(choice.key)
    end
  end)
end

-- Get snippets for completion (for snippet engines)
function M.get_completion_items()
  local items = {}

  for key, snippet in pairs(M.snippets) do
    table.insert(items, {
      label = snippet.prefix,
      kind = vim.lsp.protocol.CompletionItemKind.Snippet,
      detail = snippet.description,
      insertText = snippet.body,
      insertTextFormat = vim.lsp.protocol.InsertTextFormat.Snippet,
    })
  end

  return items
end

return M
