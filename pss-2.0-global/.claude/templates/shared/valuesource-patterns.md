# ValueSource Patterns for sett.GridFields

ValueSource is a JSON column in GridFields that tells the frontend filter component
how to load dropdown options for filtering. AI must analyze each field and set the
correct ValueSource pattern.

## Decision Rules

| Field Type | ValueSource |
|-----------|-------------|
| FK field (e.g., countryId, currencyId) | API ValueSource (fetch from entity) |
| Boolean field (e.g., isActive) | Static ValueSource (true/false options) |
| String, Integer (non-FK), Decimal, DateTime | null (no dropdown filter) |

## IMPORTANT: FK Field Handling in sett.Fields and sett.GridFields

**sett.Fields**: Do NOT create new fields for FK relationships. The FK target entity's NAME field already exists.
- Example: `COUNTRYNAME` already exists from when Country was created. Don't create `TESTING_COUNTRYID`.

**sett.GridFields**: For FK columns, reference the existing NAME FieldCode with `ParentObject` set to the navigation property name.
- FieldCode: `COUNTRYNAME` (not TESTING_COUNTRYID)
- ParentObject: `'country'` (navigation property in camelCase)
- ValueSource: API JSON targeting the FK entity

**Rule**: Only insert entity's OWN fields in sett.Fields (PK, Name, Code, Description, etc.). FK display uses the target entity's NAME field which is already in sett.Fields.

## Pattern 1: Boolean Field — Static ValueSource

For any boolean field (isActive, isVerified, isPrimary, etc.):

```json
{
  "apiRequestRequired": false,
  "staticOptions": [
    { "value": "true", "label": "Active" },
    { "value": "false", "label": "Inactive" }
  ],
  "ruleFieldKey": "##fieldKey##",
  "ruleFieldDataType": "boolean"
}
```

**AI adjusts** the labels based on field meaning:
- isActive → "Active" / "Inactive"
- isVerified → "Verified" / "Not Verified"
- isPrimary → "Primary" / "Secondary"
- isDeleted → "Deleted" / "Not Deleted"

## Pattern 2: FK Field — API ValueSource

For any foreign key field (countryId, currencyId, companyId, etc.):

```json
{
  "apiRequestRequired": true,
  "entityName": "##camelPluralEntityName##",
  "valueField": "##entityIdField##",
  "labelField": "##entityNameField##",
  "orderBy": "##entityNameField##",
  "orderDescending": false,
  "whereClause": null,
  "includeFields": [],
  "ruleFieldKey": "##fkFieldKey##",
  "ruleFieldDataType": "Int"
}
```

**AI fills in** based on the FK target entity:

| FK Field | entityName | valueField | labelField |
|----------|-----------|------------|------------|
| countryId | countries | countryId | countryName |
| currencyId | currencies | currencyId | currencyName |
| companyId | companies | companyId | companyName |
| branchId | branches | branchId | branchName |
| languageId | languages | languageId | languageName |
| paymentModeId | paymentModes | paymentModeId | paymentModeName |
| donationTypeId | masterDatas | masterDataId | dataName |
| donationPurposeId | donationPurposes | donationPurposeId | donationPurposeName |
| contactId | contacts | contactId | contactName |
| bankId | banks | bankId | bankName |
| paymentGatewayId | paymentGateways | paymentGatewayId | paymentGatewayName |
| genderId | genders | genderId | genderName |
| nationalityId | nationalities | nationalityId | nationalityName |
| occupationId | occupations | occupationId | occupationName |
| salutationId | salutations | salutationId | salutationName |
| stateId | states | stateId | stateName |
| cityId | cities | cityId | cityName |
| districtId | districts | districtId | districtName |
| documentTypeId | documentTypes | documentTypeId | documentTypeName |

**For MasterData FK fields** (donationTypeId, paymentStatusId, contactBaseTypeId, etc.):
- entityName: "masterDatas"
- valueField: "masterDataId"
- labelField: "dataName"

**AI must determine**: the correct entityName (camelCase plural), valueField (PK), and labelField (display name) by analyzing the FK navigation property in the domain model.

## Pattern 3: Non-FK, Non-Boolean — No ValueSource

For string, integer (non-FK), decimal, datetime fields:
```sql
null  -- ValueSource is null, no dropdown filter
```

## SQL Format in GridFields INSERT

ValueSource is a JSON string column. Escape single quotes by doubling them in SQL:

```sql
-- Boolean example
'{"apiRequestRequired":false,"staticOptions":[{"value":"true","label":"Active"},{"value":"false","label":"Inactive"}],"ruleFieldKey":"isActive","ruleFieldDataType":"boolean"}'

-- FK example
'{"apiRequestRequired":true,"entityName":"countries","valueField":"countryId","labelField":"countryName","orderBy":"countryName","orderDescending":false,"whereClause":null,"includeFields":[],"ruleFieldKey":"countryId","ruleFieldDataType":"Int"}'

-- Non-FK/Non-Bool
null
```
