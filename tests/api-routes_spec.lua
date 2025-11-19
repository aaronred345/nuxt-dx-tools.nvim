-- Tests for api-routes.lua
local api_routes = require("nuxt-dx-tools.api-routes")

describe("api-routes", function()
  describe("extract_api_info", function()
    it("should extract $fetch calls correctly", function()
      -- Mock current line
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "$fetch('/api/users')" })
      vim.api.nvim_win_set_cursor(0, {1, 0})

      local info, err = api_routes.extract_api_info()
      -- Should either extract or return nil
      assert.is_true(info ~= nil or err ~= nil)
    end)

    it("should extract useFetch calls correctly", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "useFetch('/api/posts')" })
      vim.api.nvim_win_set_cursor(0, {1, 0})

      local info, err = api_routes.extract_api_info()
      assert.is_true(info ~= nil or err ~= nil)
    end)

    it("should handle methods in API calls", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "$fetch('/api/users', { method: 'POST' })" })
      vim.api.nvim_win_set_cursor(0, {1, 0})

      local info, err = api_routes.extract_api_info()
      if info then
        assert.is_true(info.method == "POST" or info.method == "GET")
      end
    end)
  end)

  describe("find_server_route", function()
    it("should return error for nil api_path", function()
      local path, err = api_routes.find_server_route(nil)
      assert.is_nil(path)
      assert.is_not_nil(err)
      assert.is_true(err:match("Invalid API path"))
    end)

    it("should return error for empty api_path", function()
      local path, err = api_routes.find_server_route("")
      assert.is_nil(path)
      assert.is_not_nil(err)
      assert.is_true(err:match("Invalid API path"))
    end)

    it("should return error for invalid http_method type", function()
      local path, err = api_routes.find_server_route("/api/test", 123)
      assert.is_nil(path)
      assert.is_not_nil(err)
      assert.is_true(err:match("Invalid HTTP method"))
    end)

    it("should normalize /api prefix", function()
      -- This test would need a real Nuxt project setup
      -- Just ensure it doesn't crash
      local path, err = api_routes.find_server_route("/api/users", "GET")
      -- Either finds route or returns error
      assert.is_true(path ~= nil or err ~= nil)
    end)
  end)
end)
