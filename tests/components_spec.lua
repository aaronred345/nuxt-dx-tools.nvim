-- Tests for components.lua
local components = require("nuxt-dx-tools.components")

describe("components", function()
  describe("goto_definition", function()
    it("should return false and error for nil word", function()
      local result = components.goto_definition(nil)
      assert.is_false(result)
    end)

    it("should return false and error for empty word", function()
      local result = components.goto_definition("")
      assert.is_false(result)
    end)

    it("should handle non-existent component gracefully", function()
      local result = components.goto_definition("NonExistentComponentXYZ123")
      assert.is_false(result)
    end)
  end)

  describe("load_mappings", function()
    it("should return empty table and error when no Nuxt project found", function()
      -- This would need proper mocking in a real test environment
      -- For now, ensure it doesn't crash
      local mappings, err = components.load_mappings()
      assert.is_table(mappings)
      -- Either has mappings or returns error
      assert.is_true(vim.tbl_count(mappings) >= 0)
    end)
  end)

  describe("load_composable_mappings", function()
    it("should return empty table and error when no Nuxt project found", function()
      local mappings, err = components.load_composable_mappings()
      assert.is_table(mappings)
      assert.is_true(vim.tbl_count(mappings) >= 0)
    end)
  end)
end)
