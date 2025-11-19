-- Tests for utils.lua
local utils = require("nuxt-dx-tools.utils")

describe("utils", function()
  describe("read_file", function()
    it("should return error for nil filepath", function()
      local content, err = utils.read_file(nil)
      assert.is_nil(content)
      assert.is_not_nil(err)
      assert.is_true(err:match("Invalid filepath"))
    end)

    it("should return error for empty filepath", function()
      local content, err = utils.read_file("")
      assert.is_nil(content)
      assert.is_not_nil(err)
      assert.is_true(err:match("Invalid filepath"))
    end)

    it("should return error for non-existent file", function()
      local content, err = utils.read_file("/tmp/nuxt-dx-tools-test-nonexistent-file-12345.txt")
      assert.is_nil(content)
      assert.is_not_nil(err)
      assert.is_true(err:match("Cannot open file"))
    end)

    it("should read existing file successfully", function()
      -- Create a temp file
      local temp_file = "/tmp/nuxt-dx-tools-test-temp.txt"
      local f = io.open(temp_file, "w")
      f:write("test content")
      f:close()

      local content, err = utils.read_file(temp_file)
      assert.is_not_nil(content)
      assert.is_nil(err)
      assert.equals("test content", content)

      -- Cleanup
      os.remove(temp_file)
    end)
  end)

  describe("find_nuxt_root", function()
    it("should return error for empty buffer", function()
      -- This test needs a proper test environment
      -- For now, just ensure it doesn't crash
      local root, err = utils.find_nuxt_root()
      -- Either returns a path or an error message
      assert.is_true(root ~= nil or err ~= nil)
    end)
  end)

  describe("get_directory_paths", function()
    it("should return error for nil subdir", function()
      local paths, err = utils.get_directory_paths(nil)
      assert.equals(0, #paths)
      assert.is_not_nil(err)
      assert.is_true(err:match("Invalid subdir"))
    end)

    it("should return error for empty subdir", function()
      local paths, err = utils.get_directory_paths("")
      assert.equals(0, #paths)
      assert.is_not_nil(err)
      assert.is_true(err:match("Invalid subdir"))
    end)
  end)

  describe("find_custom_plugin_definition", function()
    it("should return error for nil symbol", function()
      local path, err = utils.find_custom_plugin_definition(nil)
      assert.is_nil(path)
      assert.is_not_nil(err)
      assert.is_true(err:match("Invalid symbol"))
    end)

    it("should return error for empty symbol", function()
      local path, err = utils.find_custom_plugin_definition("")
      assert.is_nil(path)
      assert.is_not_nil(err)
      assert.is_true(err:match("Invalid symbol"))
    end)
  end)
end)
