# Contributing to nuxt-dx-tools.nvim

Thank you for considering contributing to nuxt-dx-tools.nvim! This document provides guidelines and instructions for contributing.

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Project Structure](#project-structure)
- [Making Changes](#making-changes)
- [Testing](#testing)
- [Submitting Changes](#submitting-changes)
- [Coding Guidelines](#coding-guidelines)
- [Commit Messages](#commit-messages)

## 🤝 Code of Conduct

This project follows a code of conduct based on respect, collaboration, and inclusivity. By participating, you agree to:

- Be respectful and constructive in discussions
- Welcome newcomers and help them get started
- Focus on what is best for the community
- Show empathy towards other community members

## 🚀 Getting Started

### Prerequisites

- **Neovim** >= 0.8.0
- **Node.js** >= 18.0.0
- **npm** >= 9.0.0 (or pnpm, yarn, bun)
- **Git**
- A Nuxt 3 or Nuxt 4 project for testing

### Development Setup

1. **Fork and clone the repository**
   ```bash
   git clone https://github.com/YOUR_USERNAME/nuxt-dx-tools.nvim.git
   cd nuxt-dx-tools.nvim
   ```

2. **Install LSP server dependencies**
   ```bash
   cd lsp-server
   npm install
   ```

3. **Build the LSP server**
   ```bash
   npm run build
   ```

4. **Link the plugin locally in Neovim**

   For lazy.nvim:
   ```lua
   {
     dir = "~/path/to/nuxt-dx-tools.nvim",
     config = function()
       require("nuxt-dx-tools").setup()
     end
   }
   ```

5. **Test in a Nuxt project**
   - Create or open a Nuxt project
   - Make sure `.nuxt` directory is generated (`nuxt dev`)
   - Test the plugin features

## 📁 Project Structure

```
nuxt-dx-tools.nvim/
├── plugin/nuxt-dx-tools.lua       # Plugin entry point
├── lua/nuxt-dx-tools/             # Lua plugin modules
│   ├── init.lua                   # Main initialization
│   ├── utils.lua                  # Utility functions
│   ├── components.lua             # Component navigation
│   ├── api-routes.lua             # API route handling
│   ├── picker.lua                 # Fuzzy picker UI
│   └── ...                        # Other feature modules
├── lsp-server/                    # TypeScript LSP server
│   ├── src/                       # TypeScript source
│   │   ├── server.ts              # LSP server main
│   │   ├── providers/             # LSP feature providers
│   │   ├── nuxt/                  # Nuxt project analysis
│   │   └── utils/                 # Utilities
│   └── dist/                      # Compiled JavaScript
└── tests/                         # Test files
```

## 🔨 Making Changes

### Branch Naming

Use descriptive branch names:
- `feat/add-new-feature` - New features
- `fix/bug-description` - Bug fixes
- `docs/update-readme` - Documentation updates
- `refactor/improve-code` - Code refactoring
- `test/add-tests` - Adding tests

### Development Workflow

1. **Create a feature branch**
   ```bash
   git checkout -b feat/your-feature-name
   ```

2. **Make your changes**
   - Write clear, documented code
   - Follow the coding guidelines below
   - Add tests if possible

3. **Build and test**
   ```bash
   # Build LSP server
   cd lsp-server
   npm run build

   # Test in Neovim
   nvim your-test-file.vue
   ```

4. **Run tests** (if applicable)
   ```bash
   # TypeScript tests
   cd lsp-server
   npm test

   # Lua tests (requires plenary.nvim)
   nvim --headless -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"
   ```

## 🧪 Testing

### Writing Tests

**Lua Tests (tests/\*_spec.lua)**
```lua
describe("module_name", function()
  it("should do something", function()
    local result = module.function()
    assert.equals(expected, result)
  end)
end)
```

**TypeScript Tests (lsp-server/src/__tests__/\*.test.ts)**
```typescript
describe('ClassName', () => {
  it('should do something', () => {
    const result = instance.method();
    expect(result).toBe(expected);
  });
});
```

### Test Coverage Goals

- **Core utilities**: 80%+ coverage
- **LSP providers**: 70%+ coverage
- **Feature modules**: 60%+ coverage

## 📤 Submitting Changes

### Pull Request Process

1. **Update documentation**
   - Update README.md if adding features
   - Add JSDoc/LuaDoc comments to new functions
   - Update CHANGELOG.md (if exists)

2. **Ensure quality**
   - Code builds without errors
   - Tests pass (if tests exist)
   - No linting errors
   - Functions have error handling

3. **Create pull request**
   - Use a clear, descriptive title
   - Reference any related issues
   - Describe what changed and why
   - Add screenshots/GIFs for UI changes

### Pull Request Template

```markdown
## Description
[Describe what this PR does]

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Tested in Nuxt 3 project
- [ ] Tested in Nuxt 4 project
- [ ] Tests added/updated
- [ ] Manually tested

## Checklist
- [ ] Code builds successfully
- [ ] Documentation updated
- [ ] Error handling added
- [ ] Follows coding guidelines
```

## 📝 Coding Guidelines

### Lua Style

```lua
-- Use snake_case for functions and variables
local function my_function(param_name)
  -- Add docstrings for public functions
  -- @param param_name string: Description
  -- @return table: Description
end

-- Use proper error handling
local result, err = risky_operation()
if not result then
  vim.notify("[Plugin] Error: " .. err, vim.log.levels.ERROR)
  return
end

-- Validate inputs
if not input or input == "" then
  return nil, "Invalid input: empty or nil"
end
```

### TypeScript Style

```typescript
/**
 * Function description
 * @param param Description
 * @returns Description
 */
export function myFunction(param: string): Result {
  // Validate inputs
  if (!param) {
    throw new Error('Invalid param');
  }

  try {
    // Operation
    return result;
  } catch (error) {
    console.error('Error:', error);
    throw error;
  }
}
```

### General Guidelines

- **Error Handling**: Always handle errors, never silent failures
- **Input Validation**: Validate all function inputs
- **Documentation**: Document public APIs with JSDoc/LuaDoc
- **Testing**: Write tests for new features
- **Platform Support**: Consider Windows, macOS, Linux
- **Performance**: Avoid expensive operations in hot paths
- **Logging**: Use consistent logging with `[Nuxt]` prefix

## 💬 Commit Messages

Use conventional commits format:

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

### Types

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting)
- `refactor`: Code refactoring
- `test`: Adding tests
- `chore`: Maintenance tasks

### Examples

```
feat(api-routes): add support for dynamic route parameters

- Detect [id] and [...slug] patterns
- Map to corresponding file paths
- Add tests for route resolution

Closes #123
```

```
fix(components): handle missing .nuxt directory gracefully

Users now see a helpful error message when .nuxt is missing,
with instructions to run 'nuxt dev' or 'nuxt build'.

Fixes #456
```

## 🐛 Reporting Bugs

When reporting bugs, please include:

1. **Environment**
   - Neovim version
   - Node.js version
   - OS (Windows, macOS, Linux)
   - Nuxt version (3.x or 4.x)

2. **Steps to reproduce**
   - Clear, minimal steps
   - Sample code if applicable

3. **Expected vs Actual behavior**
   - What you expected to happen
   - What actually happened

4. **Logs**
   - Enable debug mode: `:NuxtDebug`
   - Include relevant error messages

## 💡 Feature Requests

Feature requests are welcome! Please provide:

1. **Use case**: Describe the problem you're trying to solve
2. **Proposed solution**: How you envision the feature working
3. **Alternatives**: Other solutions you've considered
4. **Additional context**: Screenshots, examples, etc.

## 📚 Additional Resources

- [Neovim Lua Guide](https://neovim.io/doc/user/lua-guide.html)
- [LSP Specification](https://microsoft.github.io/language-server-protocol/)
- [Nuxt Documentation](https://nuxt.com/)
- [Project README](./README.md)

## 🙏 Thank You!

Your contributions make this project better for everyone. We appreciate your time and effort!

---

**Questions?** Open an issue or start a discussion. We're here to help!
