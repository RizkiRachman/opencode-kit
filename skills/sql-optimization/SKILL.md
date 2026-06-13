# SQL Optimization — Query Performance

**Identify and fix slow queries.**

## When to Use

- Queries running slowly
- High database load
- Need to add indexes
- Optimizing complex JOINs

## Workflow

### 1. Identify Slow Queries
```bash
lean-ctx ctx_shell --command "psql -c \"SELECT query, mean_time FROM pg_stat_statements ORDER BY mean_time DESC LIMIT 10;\""
```

### 2. Analyze Query Plan
```sql
EXPLAIN ANALYZE
SELECT * FROM orders WHERE user_id = 123;
```

### 3. Common Optimizations

| Issue | Solution |
|-------|----------|
| Sequential Scan | Add index on filtered column |
| Nested Loop | Rewrite JOIN or add index |
| Sort Operation | Add index matching ORDER BY |
| Subquery | Rewrite as JOIN or CTE |
| SELECT * | Select only needed columns |

### 4. Add Indexes
```sql
-- B-tree for equality/range queries
CREATE INDEX idx_orders_user_id ON orders(user_id);

-- Composite index for multi-column queries
CREATE INDEX idx_orders_user_date ON orders(user_id, created_at);

-- Partial index for filtered queries
CREATE INDEX idx_active_users ON users(email) WHERE active = true;
```

## Best Practices

- **Index Selectivity**: Index columns with high cardinality
- **Covering Indexes**: Include SELECT columns to avoid table lookups
- **Avoid Over-Indexing**: Each index slows down writes
- **Analyze Regularly**: Run ANALYZE after schema changes
- **Monitor Usage**: Drop unused indexes

## Quick Reference

```sql
-- Find missing indexes
SELECT schemaname, tablename, attname, n_distinct, correlation
FROM pg_stats
WHERE tablename = 'orders';

-- Check index usage
SELECT indexrelname, idx_scan, idx_tup_read, idx_tup_fetch
FROM pg_stat_user_indexes
WHERE schemaname = 'public';
```
