export interface CacheEntry<T> {
    value: T;
    timestamp: number;
    ttl: number;
}
export declare class Cache<T> {
    private cache;
    /**
     * Get a value from the cache
     * @param key Cache key
     * @returns Cached value or undefined if not found or expired
     */
    get(key: string): T | undefined;
    /**
     * Set a value in the cache
     * @param key Cache key
     * @param value Value to cache
     * @param ttl Time to live in milliseconds (default: 5000ms)
     */
    set(key: string, value: T, ttl?: number): void;
    /**
     * Check if a key exists and is not expired
     */
    has(key: string): boolean;
    /**
     * Invalidate a specific cache entry
     */
    invalidate(key: string): void;
    /**
     * Clear all cache entries
     */
    clear(): void;
    /**
     * Get or compute a value
     * @param key Cache key
     * @param compute Function to compute the value if not cached
     * @param ttl Time to live in milliseconds
     */
    getOrCompute(key: string, compute: () => Promise<T>, ttl?: number): Promise<T>;
}
//# sourceMappingURL=cache.d.ts.map