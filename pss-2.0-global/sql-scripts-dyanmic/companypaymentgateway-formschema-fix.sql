-- =====================================================================================
-- FIX — COMPANYPAYMENTGATEWAY create/edit form crashed on render (2026-07-31).
--
-- SYMPTOM
--   Screen #167 > My Configuration > New (or Available Gateways > Configure) opened the dialog and
--   rendered "Form Error / Error rendering form / Cannot read properties of undefined (reading
--   'length')" instead of the form.
--
-- CAUSE — the seeded GridFormSchema was written against a widget API that does not exist:
--   1. The three CSV fields (supportedCurrencies / supportedCountryCodes / supportedPaymentMethods)
--      used ApiMultiSelect with "ui:options": { "query": "..." }. ApiMultiSelect reads
--      "ui:options"."queryKey", not "query", and only from its own fixed map — so the key fell back
--      to EMPTY, the query was skipped, and enumOptions came back undefined. The widget then read
--      .length off it, which threw and took the whole form down. THIS was the crash.
--   2. paymentGatewayId used "query": "GET_PAYMENTGATEWAY_LIST" for ApiSelectV2 — same wrong option
--      name, and there was no PAYMENTGATEWAY key in that widget map at all, so the Gateway dropdown
--      could never have populated even without the crash.
--   3. isDefault used "SwitchWidget", which is not a registered widget name (it would have thrown
--      "No widget SwitchWidget" as soon as the crash above was fixed).
--
-- WHAT CHANGED HERE — uiSchema only. The "schema" half (fields, types, required, validation) is
-- byte-for-byte what it was; no column, no DTO and no validator is affected.
--   • paymentGatewayId  → "ui:options": { "queryKey": "PAYMENTGATEWAY" }
--   • the three CSV fields → "tag-input" (chip entry, stores the same comma-separated string) with
--     per-field quick-add presets
--   • isDefault → "CheckboxWidget"
--   • credential help text now states the write-only rule: blank on edit = keep the stored value
--
-- PAIRED FRONTEND CHANGES (already committed — this script alone is not enough):
--   • use-api-selectv2.ts        — registers the PAYMENTGATEWAY query key
--   • api-multi-select-widget    — treats undefined enumOptions as [] instead of throwing
--   • tag-input-widget           — presets/placeholder now come from ui:options / ui:placeholder
--
-- IDEMPOTENT: it is a plain UPDATE of one column on one row. Re-running changes nothing.
-- After running, hard-refresh the browser — the grid config is cached client-side.
--
-- The canonical copy of this schema lives in
-- PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/companypaymentgateway-sqlscripts.sql
-- (STEP 4d) and has been updated to match, so a fresh seed produces the fixed form.
-- =====================================================================================

UPDATE sett."Grids"
SET "GridFormSchema" = '{
  "schema": {
    "type": "object",
    "properties": {
      "paymentGatewayId": {
        "type": "number",
        "title": "Payment Gateway",
        "minimum": 1,
        "errorMessage": {
          "required": "Payment Gateway is required.",
          "minimum": "Payment Gateway is required."
        }
      },
      "gatewayEnvironment": {
        "type": "string",
        "title": "Environment",
        "enum": ["sandbox", "production"],
        "enumNames": ["Test", "Live"],
        "default": "production",
        "errorMessage": {
          "required": "Environment is required."
        }
      },
      "encryptedApiKey": {
        "type": "string",
        "title": "API Key",
        "maxLength": 1000,
        "format": "password",
        "errorMessage": {
          "required": "API Key is required.",
          "maxLength": "Cannot exceed 1000 characters."
        }
      },
      "encryptedApiSecret": {
        "type": "string",
        "title": "API Secret",
        "maxLength": 1000,
        "format": "password",
        "errorMessage": {
          "required": "API Secret is required.",
          "maxLength": "Cannot exceed 1000 characters."
        }
      },
      "encryptedWebhookSecret": {
        "type": "string",
        "title": "Webhook Secret",
        "maxLength": 1000,
        "format": "password"
      },
      "merchantId": {
        "type": "string",
        "title": "Merchant ID",
        "maxLength": 200
      },
      "supportedCurrencies": {
        "type": "string",
        "title": "Supported Currencies"
      },
      "supportedCountryCodes": {
        "type": "string",
        "title": "Supported Country Codes"
      },
      "supportedPaymentMethods": {
        "type": "string",
        "title": "Supported Payment Methods"
      },
      "isDefault": {
        "type": "boolean",
        "title": "Set as Default Gateway",
        "default": false
      },
      "additionalConfig": {
        "type": "string",
        "title": "Additional Configuration (JSON)"
      }
    },
    "required": ["paymentGatewayId", "gatewayEnvironment", "encryptedApiKey", "encryptedApiSecret"]
  },
  "uiSchema": {
    "paymentGatewayId": {
      "ui:widget": "ApiSelectV2",
      "ui:placeholder": "Select gateway...",
      "ui:options": {
        "queryKey": "PAYMENTGATEWAY"
      }
    },
    "gatewayEnvironment": {
      "ui:widget": "SelectWidget",
      "ui:placeholder": "Select environment"
    },
    "encryptedApiKey": {
      "ui:widget": "PasswordWidget",
      "ui:placeholder": "Enter API key",
      "ui:help": "Encrypted at rest and never read back. Leave blank when editing to keep the stored key."
    },
    "encryptedApiSecret": {
      "ui:widget": "PasswordWidget",
      "ui:placeholder": "Enter API secret",
      "ui:help": "Encrypted at rest and never read back. Leave blank when editing to keep the stored secret."
    },
    "encryptedWebhookSecret": {
      "ui:widget": "PasswordWidget",
      "ui:placeholder": "Enter webhook secret",
      "ui:help": "Encrypted at rest and never read back. Leave blank when editing to keep the stored secret."
    },
    "merchantId": {
      "ui:widget": "TextWidget",
      "ui:placeholder": "Enter merchant ID"
    },
    "supportedCurrencies": {
      "ui:widget": "tag-input",
      "ui:placeholder": "Type an ISO currency code and press Enter (e.g. INR)",
      "ui:help": "Leave empty to accept whatever the gateway itself supports.",
      "ui:options": {
        "presets": [
          { "label": "India", "tokens": ["INR"] },
          { "label": "Global", "tokens": ["USD", "EUR", "GBP"] },
          { "label": "Gulf/APAC", "tokens": ["AED", "SGD", "AUD"] }
        ]
      }
    },
    "supportedCountryCodes": {
      "ui:widget": "tag-input",
      "ui:placeholder": "Type a 2-letter country code and press Enter (e.g. IN)",
      "ui:options": {
        "presets": [
          { "label": "India", "tokens": ["IN"] },
          { "label": "Global", "tokens": ["US", "GB", "AE", "SG", "AU"] }
        ]
      }
    },
    "supportedPaymentMethods": {
      "ui:widget": "tag-input",
      "ui:placeholder": "Type a method and press Enter (e.g. UPI)",
      "ui:options": {
        "presets": [
          { "label": "Cards", "tokens": ["CARD"] },
          { "label": "India", "tokens": ["UPI", "NETBANKING", "WALLET"] },
          { "label": "Recurring", "tokens": ["EMANDATE", "EMI"] }
        ]
      }
    },
    "isDefault": {
      "ui:widget": "CheckboxWidget"
    },
    "additionalConfig": {
      "ui:widget": "TextareaWidget",
      "ui:placeholder": "{ \"statement_descriptor\": \"MyOrg Donation\" }",
      "ui:options": {
        "rows": 6,
        "monospace": true
      }
    },
    "ui:order": [
      "paymentGatewayId",
      "gatewayEnvironment",
      "encryptedApiKey",
      "encryptedApiSecret",
      "encryptedWebhookSecret",
      "merchantId",
      "supportedCurrencies",
      "supportedCountryCodes",
      "supportedPaymentMethods",
      "isDefault",
      "additionalConfig"
    ],
    "ui:submitButtonOptions": {
      "submitText": "Save Payment Gateway"
    },
    "ui:layout": [
      { "paymentGatewayId": { "className": "w-1/2" }, "gatewayEnvironment": { "className": "w-1/2" } },
      { "encryptedApiKey": { "className": "w-1/2" }, "encryptedApiSecret": { "className": "w-1/2" } },
      { "encryptedWebhookSecret": { "className": "w-1/2" }, "merchantId": { "className": "w-1/2" } },
      { "supportedCurrencies": { "className": "w-1/2" }, "supportedCountryCodes": { "className": "w-1/2" } },
      { "supportedPaymentMethods": { "className": "w-1/2" }, "isDefault": { "className": "w-1/2" } },
      { "additionalConfig": { "className": "w-full" } }
    ]
  }
}'
WHERE "GridId" = (SELECT "GridId" FROM sett."Grids" WHERE "GridCode" = 'COMPANYPAYMENTGATEWAY');


-- VERIFY — must return t for all three:
--   SELECT ("GridFormSchema"::jsonb #>> '{uiSchema,paymentGatewayId,ui:options,queryKey}') = 'PAYMENTGATEWAY' AS gateway_key_ok,
--          ("GridFormSchema"::jsonb #>> '{uiSchema,supportedCurrencies,ui:widget}')         = 'tag-input'      AS currencies_ok,
--          ("GridFormSchema"::jsonb #>> '{uiSchema,isDefault,ui:widget}')                   = 'CheckboxWidget' AS is_default_ok
--   FROM sett."Grids" WHERE "GridCode" = 'COMPANYPAYMENTGATEWAY';
