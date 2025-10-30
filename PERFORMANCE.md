# Performance Optimization Guide

## Configuration for Laravel Octane + Swoole

This runtime is optimized for long-running Swoole workers with minimal memory footprint and maximum request throughput.

## Memory Usage per Worker

### Expected Memory Consumption

```
Base PHP process:        ~25MB
OPcache (shared):        ~96MB (shared across all workers)
JIT buffer (shared):     ~48MB (shared across all workers)
Laravel app loaded:      ~40MB
Swoole overhead:         ~15MB
Working memory:          ~60MB (per request average)
--------------------------------
Total per worker:        ~140-180MB
```

### Capacity Planning

**For 1GB RAM server:**
```
Available RAM:           1024MB
System overhead:         -150MB (Alpine + services)
Shared memory (OPcache): -96MB
Shared memory (JIT):     -48MB
Available for workers:   730MB
Worker capacity:         730MB / 180MB = ~4 workers
```

**For 2GB RAM server:**
```
Available RAM:           2048MB
System overhead:         -150MB
Shared memory:           -144MB
Available for workers:   1754MB
Worker capacity:         1754MB / 180MB = ~9 workers
```

## PHP Configuration Breakdown

### Memory Limits (256M per worker)
- Sufficient for Laravel Octane APIs
- Prevents memory leaks from consuming entire system
- Allows running 4+ workers on 1GB RAM

### OPcache (96MB total)
- **Reduced from 256MB**: Laravel apps typically use 50-80MB
- **Shared across all workers**: Not multiplied per worker!
- **Zero filesystem validation**: `validate_timestamps=0`
- **No file cache**: Saves memory, relies on shared memory only

### JIT Compiler (48MB total)
- **Mode 1255**: Tracing JIT optimized for web requests
  - 1 = Enable JIT
  - 2 = Optimize all functions
  - 5 = Trace mode (best for web apps)
  - 5 = Maximum optimization
- **Shared across all workers**: Not per-worker memory
- **15-30% performance boost** for CPU-intensive operations

### Realpath Cache (4MB)
- **Reduces stat() syscalls by ~70%**
- Critical for performance with Swoole (long-running process)
- 10-minute TTL means Laravel rarely hits filesystem

## Swoole-Specific Optimizations

### Worker Configuration

Recommended `config/octane.php` settings:

```php
'swoole' => [
    'options' => [
        // Worker settings - optimized for low memory
        'worker_num' => 4,              // Adjust based on available RAM
        'max_request' => 10000,         // Recycle after 10k requests (prevents leaks)
        'max_wait_time' => 60,          // Kill stuck workers after 60s

        // Task workers for async jobs
        'task_worker_num' => 2,         // Separate workers for background tasks
        'task_max_request' => 5000,

        // Memory optimizations
        'buffer_output_size' => 2 * 1024 * 1024,    // 2MB output buffer
        'socket_buffer_size' => 2 * 1024 * 1024,    // 2MB socket buffer
        'package_max_length' => 10 * 1024 * 1024,   // 10MB max request size

        // Performance tuning
        'open_cpu_affinity' => true,    // Pin workers to CPU cores
        'tcp_fastopen' => true,         // Faster connection establishment
        'open_tcp_nodelay' => true,     // Disable Nagle's algorithm
        'max_coroutine' => 100000,      // Swoole coroutine limit

        // Keep-alive
        'heartbeat_check_interval' => 60,
        'heartbeat_idle_time' => 600,
    ],

    // Tables for shared state (optional)
    'tables' => [
        'cache' => [
            'size' => 1000,
            'columns' => [
                ['name' => 'value', 'type' => 21, 'size' => 4096],
            ],
        ],
    ],
],
```

### Supervisor Configuration

Example `/etc/supervisor/conf.d/octane.conf`:

```ini
[program:octane]
command=php /var/www/artisan octane:start --server=swoole --host=0.0.0.0 --port=8000 --workers=4 --max-requests=10000
directory=/var/www
user=www-data
autostart=true
autorestart=true
startretries=3
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
stopwaitsecs=30
```

## Monitoring Memory Usage

### Check Runtime Memory

```bash
# Inside running container
docker exec <container> sh -c "ps aux | grep php"

# Memory per worker
docker exec <container> sh -c "ps aux | grep 'octane:start' | awk '{print \$6}'"

# OPcache status (requires endpoint or CLI script)
docker exec <container> php -r "print_r(opcache_get_status());"
```

### Memory Leak Detection

```bash
# Monitor memory growth over time
while true; do
    docker stats --no-stream <container> | grep -v CONTAINER
    sleep 60
done
```

If memory grows continuously, check:
1. `max_request` setting (should recycle workers periodically)
2. Laravel event listeners (may hold references)
3. Static variables or singletons
4. Database connection pooling

## Performance Benchmarks

### Expected Metrics (Laravel 11 + Octane + Swoole)

**Simple API endpoint (no DB):**
- Latency: 5-10ms (p50), 15-20ms (p99)
- Throughput: 3000-5000 req/s per worker
- Memory: ~40MB per worker idle

**Database query (single):**
- Latency: 20-30ms (p50), 50-80ms (p99)
- Throughput: 1000-2000 req/s per worker
- Memory: ~60MB per worker under load

**Complex API (multiple queries + cache):**
- Latency: 50-100ms (p50), 150-200ms (p99)
- Throughput: 500-1000 req/s per worker
- Memory: ~80-120MB per worker under load

### Benchmarking Commands

```bash
# Apache Bench
ab -n 10000 -c 100 http://localhost:8000/api/health

# wrk (more accurate)
wrk -t4 -c100 -d30s http://localhost:8000/api/health

# Load test with realistic traffic
wrk -t8 -c200 -d2m --latency http://localhost:8000/api/endpoint
```

## Troubleshooting

### High Memory Usage

**Symptoms:** Workers consuming >256MB
**Solutions:**
1. Reduce `worker_num` in octane.php
2. Lower `max_request` to recycle workers more frequently
3. Check for memory leaks in application code
4. Review OPcache consumption with `opcache_get_status()`

### Slow Requests

**Symptoms:** High p99 latency (>500ms)
**Solutions:**
1. Check `realpath_cache_size` usage: `php -r "print_r(realpath_cache_size());"`
2. Verify JIT is active: `php -r "var_dump(opcache_get_status()['jit']);"`
3. Profile with Blackfire or Xdebug
4. Check database query performance

### Worker Crashes

**Symptoms:** Workers restarting frequently
**Solutions:**
1. Check error logs: `docker logs <container>`
2. Increase `max_wait_time` in octane.php
3. Review PHP error logs in supervisor output
4. Check for segfaults in dmesg

### OPcache Full

**Symptoms:** `opcache_get_status()['cache_full'] === true`
**Solutions:**
1. Increase `opcache.memory_consumption` (currently 96MB)
2. Review `opcache.max_accelerated_files` (currently 16229)
3. Check if unnecessary files are being cached

## Advanced Optimizations

### Preloading (PHP 8.1+)

Create `/var/www/preload.php`:

```php
<?php
// Preload frequently used Laravel classes
opcache_compile_file(__DIR__ . '/vendor/autoload.php');
opcache_compile_file(__DIR__ . '/vendor/laravel/framework/src/Illuminate/Foundation/Application.php');
opcache_compile_file(__DIR__ . '/vendor/laravel/framework/src/Illuminate/Http/Request.php');
opcache_compile_file(__DIR__ . '/vendor/laravel/framework/src/Illuminate/Http/Response.php');
// Add more as needed
```

Then enable in your app Dockerfile:
```dockerfile
RUN echo "opcache.preload=/var/www/preload.php" >> /usr/local/etc/php/conf.d/opcache.ini
```

### Connection Pooling

For PostgreSQL, consider using PgBouncer:
- Reduces connection overhead
- Allows more workers with fewer DB connections
- Saves memory on connection objects

### Static Analysis

Use tools to find memory-hungry code:
```bash
# PHPStan with memory analysis
composer require --dev phpstan/phpstan
./vendor/bin/phpstan analyse --memory-limit=256M

# Psalm
composer require --dev vimeo/psalm
./vendor/bin/psalm --memory-limit=256M
```

## Summary

This configuration provides:
- ✅ **4+ workers on 1GB RAM** (vs 2 workers with default settings)
- ✅ **15-30% faster response times** (thanks to JIT)
- ✅ **70% fewer filesystem calls** (realpath cache)
- ✅ **Minimal memory overhead** (96MB OPcache vs 256MB)
- ✅ **Production-ready** (no debug overhead, optimized for long-running processes)

For questions or issues, check:
- OPcache status: `opcache_get_status()`
- Swoole status: Visit `/swoole-stats` endpoint (if configured)
- System resources: `docker stats <container>`