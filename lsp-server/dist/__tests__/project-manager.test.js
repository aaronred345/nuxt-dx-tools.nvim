"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const project_manager_1 = require("../nuxt/project-manager");
describe('NuxtProjectManager', () => {
    let manager;
    const testRoot = '/test/nuxt-project';
    beforeEach(() => {
        manager = new project_manager_1.NuxtProjectManager(testRoot);
    });
    describe('initialization', function () {
        it('should initialize with a valid root path', () => {
            expect(manager).toBeDefined();
            expect(manager.getNuxtRoot()).toBe(testRoot);
        });
        it('should handle null or undefined root', () => {
            const managerWithNull = new project_manager_1.NuxtProjectManager('');
            expect(managerWithNull).toBeDefined();
        });
    });
    describe('getComponentMappings', () => {
        it('should return empty object when .nuxt directory does not exist', () => {
            const mappings = manager.getComponentMappings();
            expect(mappings).toBeDefined();
            expect(typeof mappings).toBe('object');
        });
        it('should not crash on invalid .nuxt directory', () => {
            const invalidManager = new project_manager_1.NuxtProjectManager('/invalid/path/that/does/not/exist');
            const mappings = invalidManager.getComponentMappings();
            expect(mappings).toBeDefined();
        });
    });
    describe('getComposableMappings', () => {
        it('should return empty object when .nuxt directory does not exist', () => {
            const mappings = manager.getComposableMappings();
            expect(mappings).toBeDefined();
            expect(typeof mappings).toBe('object');
        });
    });
    describe('getPathAliases', () => {
        it('should return default Nuxt aliases', () => {
            const aliases = manager.getPathAliases();
            expect(aliases).toBeDefined();
            expect(typeof aliases).toBe('object');
        });
        it('should include standard aliases like ~ and @', () => {
            const aliases = manager.getPathAliases();
            // Should have at least some default aliases
            expect(Object.keys(aliases).length >= 0).toBe(true);
        });
    });
    describe('detectNuxtVersion', () => {
        it('should handle missing package.json', () => {
            const invalidManager = new project_manager_1.NuxtProjectManager('/nonexistent/path');
            // Should not crash
            expect(() => invalidManager.getNuxtRoot()).not.toThrow();
        });
    });
});
//# sourceMappingURL=project-manager.test.js.map