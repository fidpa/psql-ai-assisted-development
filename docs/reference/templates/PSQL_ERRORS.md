# PostgreSQL Error Handling - Template

## 🚨 Critical Error Codes & Actions

### Connection Errors
- **40001** (serialization_failure): `RETRY` - Deadlock detected
- **53300** (too_many_connections): `SCALE` - Implement connection pooling
- **08006** (connection_failure): `RECONNECT` - Connection lost

### Schema Errors  
- **42P01** (undefined_table): `CREATE` - Table missing
- **42703** (undefined_column): `MIGRATE` - Column missing
- **42P06** (duplicate_schema): `EXISTS` - Schema already exists

### Permission Errors
- **42501** (insufficient_privilege): `GRANT` - Missing permissions
- **28000** (invalid_authorization): `AUTH` - Authentication failed

## ⚡ Instant Error Recovery

### Deadlock Recovery
```bash
powershell.exe "\$env:PGPASSWORD='${PGPASSWORD}'; & 'C:\\Program Files\\PostgreSQL\\17\\bin\\psql.exe' -h localhost -p 5432 -U postgres -d postgres -c \"SELECT retry_with_backoff('YOUR_OPERATION', 3, 1000);\""
```

### Connection Recovery
```bash
powershell.exe "\$env:PGPASSWORD='${PGPASSWORD}'; & 'C:\\Program Files\\PostgreSQL\\17\\bin\\psql.exe' -h localhost -p 5432 -U postgres -d postgres -c \"SELECT * FROM check_connection_health();\""
```

### Emergency Cleanup
```bash
powershell.exe "\$env:PGPASSWORD='${PGPASSWORD}'; & 'C:\\Program Files\\PostgreSQL\\17\\bin\\psql.exe' -h localhost -p 5432 -U postgres -d postgres -c \"SELECT emergency_response('CONNECTION_LIMIT');\""
```