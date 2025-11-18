"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.Cache = void 0;
class Cache {
    cache = new Map();
    /**
     * Get a value from the cache
     * @param key Cache key
     * @returns Cached value or undefined if not found or expired
     */
    get(key) {
        const entry = this.cache.get(key);
        if (!entry) {
            return undefined;
        }
        const now = Date.now();
        if (now - entry.timestamp > entry.ttl) {
            // Expired
            this.cache.delete(key);
            return undefined;
        }
        return entry.value;
    }
    /**
     * Set a value in the cache
     * @param key Cache key
     * @param value Value to cache
     * @param ttl Time to live in milliseconds (default: 5000ms)
     */
    set(key, value, ttl = 5000) {
        this.cache.set(key, {
            value,
            timestamp: Date.now(),
            ttl,
        });
    }
    /**
     * Check if a key exists and is not expired
     */
    has(key) {
        return this.get(key) !== undefined;
    }
    /**
     * Invalidate a specific cache entry
     */
    invalidate(key) {
        this.cache.delete(key);
    }
    /**
     * Clear all cache entries
     */
    clear() {
        this.cache.clear();
    }
    /**
     * Get or compute a value
     * @param key Cache key
     * @param compute Function to compute the value if not cached
     * @param ttl Time to live in milliseconds
     */
    async getOrCompute(key, compute, ttl) {
        const cached = this.get(key);
        if (cached !== undefined) {
            return cached;
        }
        const value = await compute();
        this.set(key, value, ttl);
        return value;
    }
}
exports.Cache = Cache;
//# sourceMappingURL=cache.js.map