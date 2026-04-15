# RJSF Form Field Patterns (for GridFormSchema — MASTER_GRID only)

## When to Generate GridFormSchema
- **MASTER_GRID** (GridTypeCode = 'MASTER_GRID'): YES — generate full JSON schema + uiSchema
- **FLOW** (GridTypeCode = 'FLOW'): NO — custom view pages handle their own forms

---

## Widget Registry (Exact Names — use these in "ui:widget")

| Widget Name | Use For | Notes |
|------------|---------|-------|
| *(default — no widget)* | Short text input | Standard HTML input, no ui:widget needed |
| `TextareaWidget` | Long text (>500 chars) | Multi-line textarea |
| `ApiSelect` | FK dropdown (basic) | Legacy — prefer ApiSelectV2 |
| `ApiSelectV2` | FK dropdown (standard) | Auto-fetch, inline create, dependsOn |
| `ApiSelectV3` | FK dropdown (search) | Manual fetch, custom labels, large datasets |
| `ApiMultiSelect` | Multi-select FK | Multiple selections from API |
| `AutoGenerateText` | Code fields | Auto-generated codes (prefix-based) |
| `DatePicker` | Simple date | Basic date picker |
| `DateRangePicker` | Date with restrictions | Dependencies, min/max, prevent past |
| `TimePicker` | Time/duration | Duration picker (HH:MM:SS) |
| `CheckboxWidget` | Single boolean | Toggle on/off |
| `CheckboxesWidget` | Multiple booleans | Multi-checkbox group |
| `RadioWidget` | Single choice | Radio button group |
| `RangeWidget` | Numeric range | Slider input |
| `SelectWidget` | Static dropdown | Non-API static options |
| `RichTextEditor` | HTML content | Tiptap WYSIWYG editor |
| `LabelWidget` | Display only | Read-only label |
| `url` | URL input | HTML5 URL validation |
| `email` | Email input | HTML5 email validation |

## Global UiSchema Properties

| Property | Use For | Example |
|----------|---------|---------|
| `ui:placeholder` | Input placeholder text | `"Select Country"` |
| `ui:widget` | Override default widget | `"ApiSelectV2"` |
| `ui:readonly` | Make field read-only | `true` |
| `ui:help` | Help text below field — use for business rule hints, filter descriptions, guidance | `"Only non-family head contacts are available"` |
| `ui:options` | Widget-specific options | `{ "queryKey": "CONTACT" }` |

**When to use `ui:help`:**
- Field has a business rule that filters/restricts options (e.g., "Only active contacts", "Without family head")
- Field has a format requirement (e.g., "Format: XXX-YYYY", "Must be a valid URL")
- Field has a dependency note (e.g., "Available after selecting Country")
- Any non-obvious behavior the user should know about

**Example:**
```json
"relationContactId": {
  "ui:placeholder": "Search or Add Contact",
  "ui:help": "Only non-family head contacts are available for selection",
  "ui:widget": "ApiSelectV2",
  "ui:options": { ... }
}
```

## JSON Structure
```json
{
  "schema": {
    "definitions": { /* field definitions with validation */ },
    "type": "object",
    "properties": { /* references to definitions */ },
    "required": [ /* required field keys */ ]
  },
  "uiSchema": {
    /* widget + placeholder + help + options per field */
    "ui:layout": [ /* responsive layout with className */ ],
    "ui:columnCount": 1,
    "ui:submitButtonOptions": { "submitText": "Save" }
  }
}
```

## Fields to SKIP in GridFormSchema
- **PK field** (entityId) — hidden, auto-generated
- **CompanyId** — auto-set from tenant context
- **Audit columns** — CreatedBy, CreatedDate, ModifiedBy, ModifiedDate, IsActive, IsDeleted
- **PKReferenceId** — system field

## Fields to INCLUDE
- All user-editable fields
- FK fields as ApiSelectV2/V3 widgets (NOT plain "select")
- Boolean fields as checkboxes
- Required fields in the "required" array
- Code fields with AutoGenerateText widget (if applicable)

---

## Field Patterns by Type

### String Field (short — maxLength ≤ 500)
```json
// schema.definitions
"fieldKey": {
  "type": "string",
  "title": "Field Display Name",
  "minLength": 1,
  "maxLength": 100,
  "errorMessage": {
    "type": "Must be a string",
    "minLength": "Must be at least 1 characters long",
    "maxLength": "Cannot exceed 100 characters",
    "required": "This Field Display Name is required."
  }
}

// uiSchema
"fieldKey": {
  "ui:placeholder": "Enter Field Display Name"
}
```

### String Field (long — maxLength > 500 or text type)
```json
// schema.definitions
"fieldKey": {
  "type": "string",
  "title": "Description",
  "maxLength": 2000,
  "errorMessage": {
    "type": "Must be a string",
    "maxLength": "Cannot exceed 2000 characters"
  }
}

// uiSchema
"fieldKey": {
  "ui:placeholder": "Enter Description",
  "ui:widget": "textarea"
}
```

### Code Field (auto-generated)
```json
// schema.definitions
"entityCode": {
  "type": "string",
  "title": "Entity Code",
  "minLength": 1,
  "maxLength": 50,
  "errorMessage": {
    "minLength": "Code must be at least 1 character",
    "required": "This Entity Code is required."
  }
}

// uiSchema
"entityCode": {
  "ui:widget": "AutoGenerateText",
  "ui:options": {
    "prefix": "ENT"
  }
}
```

### Integer Field (non-FK)
```json
// schema.definitions
"fieldKey": {
  "type": "number",
  "title": "Quantity",
  "minimum": 0,
  "errorMessage": {
    "type": "Must be a number",
    "minimum": "Must be at least 0",
    "required": "This Quantity is required."
  }
}

// uiSchema
"fieldKey": {
  "ui:placeholder": "Enter Quantity"
}
```

### Decimal Field
```json
// schema.definitions
"fieldKey": {
  "type": "number",
  "title": "Amount",
  "minimum": 0,
  "errorMessage": {
    "type": "Must be a number",
    "minimum": "Must be at least 0",
    "required": "This Amount is required."
  }
}

// uiSchema
"fieldKey": {
  "ui:placeholder": "Enter Amount"
}
```

### Boolean Field
```json
// schema.definitions
"fieldKey": {
  "type": "boolean",
  "title": "Is Verified",
  "default": false
}

// uiSchema
"fieldKey": {
  "ui:widget": "checkbox"
}
```

### DateTime Field
```json
// schema.definitions
"fieldKey": {
  "type": "string",
  "title": "Start Date",
  "format": "date",
  "errorMessage": {
    "type": "Must be a valid date",
    "required": "This Start Date is required."
  }
}

// uiSchema
"fieldKey": {
  "ui:widget": "DateRangePicker",
  "ui:placeholder": "Select Date",
  "ui:options": {
    "dateFormat": "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
    "displayFormat": "dd/MM/yyyy",
    "previousYears": 10,
    "nextYears": 10
  }
}
```

---

## FK Field Patterns (CRITICAL — AI Self-Decision)

### Decision Table: Which Widget for FK Fields?

| Scenario | Widget | Why |
|----------|--------|-----|
| Simple lookup, small dataset (<500 records) | **ApiSelectV2** | Auto-fetches all, simple dropdown |
| Simple lookup + user may need to create new | **ApiSelectV2 + InlineCreate** | "+ Add New" in dropdown |
| Large dataset or needs search | **ApiSelectV3 (autoFetch: false)** | Type-to-search, don't load all |
| Needs custom label (show code + name) | **ApiSelectV3 + customLabel** | Rich display in dropdown |
| Dependent on another field (state→country) | **ApiSelectV2 + dependsOn** | Filters by parent value |

### Pattern A: ApiSelectV2 — Simple FK Lookup (Most Common)
```json
// schema.definitions
"countryId": {
  "type": "integer",
  "title": "Country"
}

// uiSchema
"countryId": {
  "ui:placeholder": "Select Country",
  "ui:widget": "ApiSelectV2",
  "ui:options": {
    "queryKey": "COUNTRY",
    "enableInlineCreate": true,
    "inlineCreateGridCode": "COUNTRY",
    "inlineCreateLabel": "Add New Country"
  }
}
```

### Pattern B: ApiSelectV2 — Dependent FK
```json
// uiSchema
"stateId": {
  "ui:placeholder": "Select State",
  "ui:widget": "ApiSelectV2",
  "ui:options": {
    "queryKey": "STATE",
    "dependsOn": "countryId",
    "clearOnParentChange": true,
    "enableInlineCreate": true,
    "inlineCreateGridCode": "STATE",
    "inlineCreateLabel": "Add New State",
    "inlineCreateFieldMapping": {
      "countryId": "countryId"
    }
  }
}
```

### Pattern C: ApiSelectV3 — Large Dataset with Search
```json
// uiSchema
"contactId": {
  "ui:placeholder": "Search Contact",
  "ui:widget": "ApiSelectV3",
  "ui:options": {
    "queryKey": "CONTACT",
    "valueField": "contactId",
    "labelField": "displayName",
    "isCustomLabel": false,
    "autoFetch": false,
    "minSearchCharacter": 3,
    "filterColumns": [
      { "field": "displayName", "parentObject": null },
      { "field": "contactCode", "parentObject": null }
    ]
  }
}
```

### Pattern D: ApiSelectV3 — Custom Label Display
```json
// uiSchema
"countryId": {
  "ui:placeholder": "Search Country",
  "ui:widget": "ApiSelectV3",
  "ui:options": {
    "queryKey": "COUNTRY",
    "valueField": "countryId",
    "labelField": "countryName",
    "isCustomLabel": true,
    "autoFetch": true,
    "filterColumns": [
      { "field": "countryName", "parentObject": null },
      { "field": "countryShortCode", "parentObject": null }
    ],
    "labelConfig": {
      "labelPattern": "{countryShortCode} - {countryName}",
      "parts": [
        { "type": "field", "value": "countryShortCode" },
        { "type": "text", "value": " - " },
        { "type": "field", "value": "countryName" }
      ]
    },
    "enableInlineCreate": true,
    "inlineCreateGridCode": "COUNTRY",
    "inlineCreateLabel": "Add New Country"
  }
}
```

---

## AI Self-Decision Guide for FK Fields

| FK Target Entity | Widget | InlineCreate? | Dependent? |
|-----------------|--------|--------------|-----------|
| Country | ApiSelectV2 | Yes | No |
| State | ApiSelectV2 | Yes | dependsOn: countryId |
| District | ApiSelectV2 | Yes | dependsOn: stateId |
| City | ApiSelectV2 | Yes | dependsOn: districtId |
| Currency | ApiSelectV2 | Yes | No |
| Language | ApiSelectV2 | Yes | No |
| Gender | ApiSelectV2 | No | No |
| Bank | ApiSelectV2 | Yes | No |
| PaymentMode | ApiSelectV2 | No | No |
| Branch | ApiSelectV2 | No | No |
| DonationPurpose | ApiSelectV2 | Yes | No |
| MasterData types | ApiSelectV2 | No | No |
| Contact | ApiSelectV3 (manual) | No | No |
| Staff | ApiSelectV3 (manual) | No | No |
| Donation | ApiSelectV3 (manual) | No | No |

---

## ui:layout Pattern

**AI decides layout based on field count:**
- 1-3 fields: `ui:columnCount: 1`, all `w-full`
- 4-8 fields: `ui:columnCount: 2`, short fields side-by-side
- 9+ fields: `ui:columnCount: 2`, group related fields on same row

```json
// 1-column
"ui:layout": [
  { "fieldA": { "className": "w-full" } },
  { "fieldB": { "className": "w-full" } }
],
"ui:columnCount": 1

// 2-column
"ui:layout": [
  { "fieldA": { "className": "w-1/2" }, "fieldB": { "className": "w-1/2" } },
  { "fieldC": { "className": "w-full" } }
],
"ui:columnCount": 2
```
