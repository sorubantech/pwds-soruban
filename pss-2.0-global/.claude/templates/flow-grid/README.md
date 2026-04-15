# FLOW Grid Templates

## Key Differences from MASTER_GRID

| Aspect | MASTER_GRID | FLOW |
|--------|-------------|------|
| Parent form | RJSF modal (GridFormSchema) | React Hook Form on view page |
| Grid click | Opens modal | Navigates to view page |
| Child entities | None | May have child grids (tabs/sections) |
| GridFormSchema | Generated for parent | NOT generated for parent. Generated for child only if child uses RJSF. |
| FE page structure | DataTable only | DataTable + ViewPage + child components |

## FLOW Screen Structure

```
Grid (DataTable) → Click row → View Page
                                  ├── Header section (entity details)
                                  ├── Form fields (React Hook Form)
                                  ├── Child Grid 1 (tab or section)
                                  │   └── May use RJSF modal for add/edit
                                  └── Child Grid 2 (tab or section)
                                      └── May use RJSF modal for add/edit
```

## Files Generated (FLOW — additional to standard CRUD)

### Backend (same as MASTER_GRID + child entity files)
- Parent: Entity, Config, Schemas, Commands, Queries, GraphQL
- Child: Entity, Config, Schemas, Commands, Queries, GraphQL
- Nested creation if child created within parent context

### Frontend (FLOW-specific additions)
- Parent DataTable (grid page)
- ViewPage component (React Hook Form)
- Child DataTable (embedded in view page)
- View page route (/{entity}/{id})
- Zustand store (if complex state needed)

## Templates in This Folder
- `code-reference-backend.md` — SavedFilter backend code reference (canonical FLOW entity)
- `code-reference-frontend.md` — SavedFilter frontend code reference (canonical FLOW entity)
- `seed-script.sql` — DB seed with parent FLOW grid + optional child MASTER_GRID
