# Database Design — Generic DB Specialist

**Schema design, queries, migrations, and optimization.**

## When to Use

- Designing or modifying database schemas
- Writing complex SQL queries
- Optimizing query performance
- Creating migrations

## Workflow

### 1. Understand Current Schema
```bash
lean-ctx ctx_shell --command "psql -c '\dt'"  # List tables
lean-ctx ctx_shell --command "psql -c '\d table_name'"  # Describe table
```

### 2. Design Changes
- Follow normalization principles (3NF unless good reason not to)
- Use appropriate data types
- Define constraints (PK, FK, UNIQUE, CHECK)
- Plan indexes for query patterns

### 3. Implement Migration
```sql
-- Always wrap in transaction
BEGIN;
-- Migration SQL here
COMMIT;
```

### 4. Verify
```bash
lean-ctx ctx_shell --command "psql -c 'SELECT * FROM table LIMIT 5'"
```

## Best Practices

- **Naming**: snake_case, plural table names, singular column names
- **Primary Keys**: Use SERIAL or UUID
- **Foreign Keys**: Always define explicit FK constraints
- **Indexes**: Create on frequently queried columns
- **Migrations**: Always reversible, never delete data in production

## Common Patterns

| Pattern | When to Use |
|---------|-------------|
| One-to-Many | Parent-child relationships |
| Many-to-Many | Junction tables with composite keys |
| Polymorphic | Type + ID columns (use carefully) |
| Soft Delete | `deleted_at` timestamp instead of DELETE |
