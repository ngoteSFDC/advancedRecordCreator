# Advanced Record Creator

A generic, schema-driven Salesforce framework for **dynamically creating records** from the **Agentforce** window. Works with **any standard or custom object** — no hardcoded object or field references.

Part of the **advancedFieldUpdator** family of Agentforce utilities.

---

## Components

| Component | Type | Description |
|---|---|---|
| `DynamicRecordCreator` | Apex (Invocable) | Discovers creatable fields for any object by API name or label. Returns structured metadata for the LWC form. |
| `DynamicRecordSaver` | Apex (@AuraEnabled) | Receives field values from the LWC, performs type casting, sets defaults (e.g. `IsActive`), and inserts the record. |
| `CreateRecordData` | Apex | Wrapper class for object metadata passed to the LWC. |
| `CreateRecordField` | Apex | Wrapper class representing a single field in the create form. |
| `dynamicRecordCreator` | LWC | Renders a dynamic create-record form inside the Agentforce chat window. Supports text, picklist, multi-picklist, checkbox, textarea, lookup, and date/datetime fields. |
| `createRecordData` | Lightning Type | Bridges the Apex `CreateRecordData` class to the LWC renderer for Agentforce output. |
| `DynamicRecordCreatorTest` | Apex Test | Unit tests covering object resolution, field discovery, and record creation. |

## How It Works

1. **Agent action** calls `DynamicRecordCreator.getRequiredFields` with an object name (e.g. "Lead", "Case", "My_Custom_Object__c").
2. The invocable method introspects the object schema and returns a `CreateRecordData` payload containing field metadata.
3. The **createRecordData** custom Lightning Type routes the payload to the **dynamicRecordCreator** LWC.
4. The LWC renders an editable form. The user fills in values and clicks **Save**.
5. The LWC calls `DynamicRecordSaver.createRecord`, which casts values, applies defaults, and inserts the record.

## Deployment

### Prerequisites

- Salesforce CLI (`sf`) installed
- Authenticated to a target org (`sf org login web`)

### Deploy all components

```bash
sf project deploy start --manifest manifest/package.xml --target-org <your-org-alias>
```

### Deploy source format

```bash
sf project deploy start --source-dir force-app --target-org <your-org-alias>
```

## Extending the Framework

This framework is intentionally generic. To build **specialized** create-record actions (e.g. a Relationship Creator, Contact Point Creator, etc.):

1. Create a new Apex Invocable class that builds a `CreateRecordData` payload with pre-populated fields, custom defaults, and business logic.
2. Reuse the existing `dynamicRecordCreator` LWC and `DynamicRecordSaver` — no UI or save-logic changes needed.
3. See the [advancedFieldUpdator](https://github.com/anthropic/advancedFieldUpdator) repo for a similar pattern applied to field updates.

## Project Structure

```
advancedRecordCreator/
├── force-app/main/default/
│   ├── classes/
│   │   ├── CreateRecordData.cls
│   │   ├── CreateRecordField.cls
│   │   ├── DynamicRecordCreator.cls
│   │   ├── DynamicRecordCreatorTest.cls
│   │   └── DynamicRecordSaver.cls
│   ├── lwc/
│   │   └── dynamicRecordCreator/
│   │       ├── dynamicRecordCreator.html
│   │       ├── dynamicRecordCreator.js
│   │       ├── dynamicRecordCreator.css
│   │       └── dynamicRecordCreator.js-meta.xml
│   └── lightningTypes/
│       └── createRecordData/
│           ├── schema.json
│           └── lightningDesktopGenAi/renderer.json
├── manifest/package.xml
├── sfdx-project.json
├── .gitignore
├── .forceignore
├── LICENSE
└── README.md
```

## License

MIT
