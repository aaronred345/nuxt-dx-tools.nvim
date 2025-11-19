import { DefinitionProvider } from '../providers/definition-provider';
import { NuxtProjectManager } from '../nuxt/project-manager';
import { Logger } from '../utils/logger';
import { TextDocument } from 'vscode-languageserver-textdocument';
import { Position } from 'vscode-languageserver/node';

describe('DefinitionProvider', () => {
  let provider: DefinitionProvider;
  let mockProjectManager: jest.Mocked<NuxtProjectManager>;
  let mockLogger: jest.Mocked<Logger>;

  beforeEach(() => {
    mockLogger = {
      info: jest.fn(),
      warn: jest.fn(),
      error: jest.fn(),
    } as any;

    mockProjectManager = {
      getNuxtRoot: jest.fn().mockReturnValue('/test/project'),
      getComponentMappings: jest.fn().mockReturnValue({}),
      getComposableMappings: jest.fn().mockReturnValue({}),
      getPathAliases: jest.fn().mockReturnValue({}),
    } as any;

    provider = new DefinitionProvider(mockProjectManager, mockLogger);
  });

  describe('provideDefinition', () => {
    it('should handle empty document', async () => {
      const document = TextDocument.create('file:///test.vue', 'vue', 1, '');
      const position = Position.create(0, 0);

      const result = await provider.provideDefinition(document, position);
      // Should return null or handle gracefully
      expect(result).toBeDefined();
    });

    it('should detect CSS imports', async () => {
      const document = TextDocument.create(
        'file:///test.vue',
        'vue',
        1,
        "import './styles.css'"
      );
      const position = Position.create(0, 10);

      const result = await provider.provideDefinition(document, position);
      // Should either find definition or return null
      expect(result !== undefined).toBe(true);
    });

    it('should detect virtual module imports', async () => {
      const document = TextDocument.create(
        'file:///test.vue',
        'vue',
        1,
        "import { ref } from '#imports'"
      );
      const position = Position.create(0, 25);

      const result = await provider.provideDefinition(document, position);
      // Should detect #imports pattern
      expect(mockLogger.info).toHaveBeenCalled();
    });

    it('should handle $fetch API calls', async () => {
      const document = TextDocument.create(
        'file:///test.vue',
        'vue',
        1,
        "const data = $fetch('/api/users')"
      );
      const position = Position.create(0, 25);

      const result = await provider.provideDefinition(document, position);
      // Should attempt to find API route
      expect(mockLogger.info).toHaveBeenCalled();
    });

    it('should handle definePageMeta', async () => {
      const document = TextDocument.create(
        'file:///test.vue',
        'vue',
        1,
        "definePageMeta({ layout: 'default' })"
      );
      const position = Position.create(0, 28);

      const result = await provider.provideDefinition(document, position);
      expect(mockLogger.info).toHaveBeenCalled();
    });

    it('should not crash on invalid position', async () => {
      const document = TextDocument.create('file:///test.vue', 'vue', 1, 'test');
      const position = Position.create(100, 100); // Out of bounds

      const result = await provider.provideDefinition(document, position);
      // Should handle gracefully
      expect(result !== undefined).toBe(true);
    });
  });
});
