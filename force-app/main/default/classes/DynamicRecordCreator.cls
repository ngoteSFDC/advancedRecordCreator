public with sharing class DynamicRecordCreator {

    private static final Set<String> SKIP_FIELDS = new Set<String>{
        'id', 'createddate', 'createdbyid', 'lastmodifieddate', 'lastmodifiedbyid',
        'systemmodstamp', 'isdeleted', 'lastactivitydate', 'lastreferenceddate',
        'lastvieweddate', 'masterrecordid', 'recordtypeid'
    };

    private static final Map<String, String> ICON_MAP = new Map<String, String>{
        'Account'     => 'standard:account',
        'Lead'        => 'standard:lead',
        'Contact'     => 'standard:contact',
        'Opportunity' => 'standard:opportunity',
        'Case'        => 'standard:case',
        'Task'        => 'standard:task',
        'Event'       => 'standard:event',
        'Campaign'    => 'standard:campaign'
    };

    @InvocableMethod(label='Get Required Fields for New Record'
                     description='Resolves a Salesforce object by name or label, discovers the required fields from schema, and returns them for display in a create-record form in the Agentforce window.'
                     category='Agentforce'
                     callout=false)
    public static List<Result> getRequiredFields(List<Request> requests) {
        List<Result> results = new List<Result>();

        for (Request req : requests) {
            Result result = new Result();
            try {
                if (String.isBlank(req.objectName)) {
                    result.success      = false;
                    result.errorMessage = 'Object name is required.';
                    results.add(result);
                    continue;
                }

                String objectApiName = resolveObjectApiName(req.objectName);
                if (String.isBlank(objectApiName)) {
                    result.success      = false;
                    result.errorMessage = 'Could not find a Salesforce object matching "' + req.objectName + '". Please verify the object name or label.';
                    results.add(result);
                    continue;
                }

                Schema.DescribeSObjectResult objDescribe = Schema.getGlobalDescribe()
                    .get(objectApiName).getDescribe();

                if (!objDescribe.isCreateable()) {
                    result.success      = false;
                    result.errorMessage = 'You do not have permission to create ' + objDescribe.getLabel() + ' records.';
                    results.add(result);
                    continue;
                }

                List<CreateRecordField> fields = buildFieldListFromSchema(objDescribe, req.showAllFields == true);

                if (fields.isEmpty()) {
                    result.success      = false;
                    result.errorMessage = 'No creatable fields found for ' + objDescribe.getLabel() + '.';
                    results.add(result);
                    continue;
                }

                CreateRecordData crd = new CreateRecordData();
                crd.objectApiName    = objectApiName;
                crd.objectLabel      = objDescribe.getLabel();
                crd.objectIconName   = ICON_MAP.containsKey(objectApiName)
                                       ? ICON_MAP.get(objectApiName)
                                       : 'standard:record';
                crd.fields           = fields;

                result.success         = true;
                result.createData      = crd;
                result.formattedOutput = buildFormattedOutput(crd);

            } catch (Exception e) {
                result.success      = false;
                result.errorMessage = 'Error: ' + e.getMessage();
                System.debug('DynamicRecordCreator error: ' + e.getMessage() + '\n' + e.getStackTraceString());
            }
            results.add(result);
        }
        return results;
    }

    // ─── Object resolution ────────────────────────────────────────────────────

    private static String resolveObjectApiName(String input) {
        String normalized = input.trim().toLowerCase();
        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();

        if (globalDescribe.containsKey(normalized)) {
            return globalDescribe.get(normalized).getDescribe().getName();
        }

        for (String apiName : globalDescribe.keySet()) {
            Schema.DescribeSObjectResult d = globalDescribe.get(apiName).getDescribe();
            if (d.getLabel().toLowerCase() == normalized ||
                d.getLabelPlural().toLowerCase() == normalized) {
                return d.getName();
            }
        }
        return null;
    }

    // ─── Schema-driven field list ────────────────────────────────────────────

    private static List<CreateRecordField> buildFieldListFromSchema(
            Schema.DescribeSObjectResult objDescribe, Boolean showAll) {

        List<CreateRecordField> required = new List<CreateRecordField>();
        List<CreateRecordField> optional = new List<CreateRecordField>();
        Map<String, Schema.SObjectField> fieldMap = objDescribe.fields.getMap();

        for (String apiName : fieldMap.keySet()) {
            if (SKIP_FIELDS.contains(apiName.toLowerCase())) continue;

            Schema.DescribeFieldResult fd = fieldMap.get(apiName).getDescribe();
            if (!fd.isCreateable() || !fd.isAccessible()) continue;

            Boolean isRequired = !fd.isNillable() && !fd.isDefaultedOnCreate();
            if (!isRequired && !showAll) continue;

            CreateRecordField crf = buildField(fd, apiName, isRequired);
            if (isRequired) {
                required.add(crf);
            } else {
                optional.add(crf);
            }
        }

        List<CreateRecordField> all = new List<CreateRecordField>();
        all.addAll(required);
        all.addAll(optional);
        return all;
    }

    // ─── Shared field builder ─────────────────────────────────────────────────

    private static CreateRecordField buildField(
            Schema.DescribeFieldResult fd, String apiName, Boolean isRequired) {

        CreateRecordField crf = new CreateRecordField();
        crf.fieldLabel        = fd.getLabel();
        crf.fieldApiName      = apiName;
        crf.fieldType         = String.valueOf(fd.getType());
        crf.isRequired        = isRequired;

        Object defVal         = fd.getDefaultValue();
        crf.defaultValue      = defVal != null ? String.valueOf(defVal) : '';

        if (fd.getType() == Schema.DisplayType.PICKLIST ||
            fd.getType() == Schema.DisplayType.MULTIPICKLIST) {
            crf.picklistValues = new List<String>();
            for (Schema.PicklistEntry entry : fd.getPicklistValues()) {
                if (entry.isActive()) crf.picklistValues.add(entry.getValue());
            }
        }

        if (fd.getType() == Schema.DisplayType.REFERENCE) {
            crf.referenceTo = new List<String>();
            for (Schema.SObjectType refType : fd.getReferenceTo()) {
                crf.referenceTo.add(refType.getDescribe().getName());
            }
        }
        return crf;
    }

    // ─── Formatted output ─────────────────────────────────────────────────────

    private static String buildFormattedOutput(CreateRecordData crd) {
        Integer reqCount = 0;
        for (CreateRecordField f : crd.fields) { if (f.isRequired) reqCount++; }

        String out = 'Ready to create a new **' + crd.objectLabel + '** record.\n\n';
        out += '**Fields (' + crd.fields.size() + ' total, ' + reqCount + ' required):**\n';
        for (CreateRecordField f : crd.fields) {
            out += '- ' + f.fieldLabel + (f.isRequired ? ' \\*' : '') + '\n';
        }
        out += '\nPlease fill in the form below and click **Save** to create the record.';
        return out;
    }

    // ─── Public data structures ───────────────────────────────────────────────

    public class Request {
        @InvocableVariable(
            label='Object Name'
            description='The Salesforce object API name or label for which to create a record. Examples: "Lead", "Account", "Task", "Event", "Opportunity". Accepts both API names and user-friendly labels.'
            required=true)
        public String objectName;

        @InvocableVariable(
            label='Show All Fields'
            description='When true, shows all creatable fields. When false (default), shows only required fields. Set to true only if the user explicitly asks to fill in additional details.')
        public Boolean showAllFields;
    }

    public class Result {
        @InvocableVariable(
            label='Success'
            description='True if the object was found and has displayable fields. False if the object name is invalid, the user lacks create permission, or no fields were found. Always check this before using other outputs.')
        public Boolean success = false;

        @InvocableVariable(
            label='Formatted Output'
            description='A markdown summary listing the fields for the new record. Display this in the agent conversation before the form appears, e.g. "Here are the fields to create a new Lead:". Only display when success is true.')
        public String formattedOutput;

        @InvocableVariable(
            label='Create Data'
            description='Structured field metadata passed to the dynamicRecordCreator custom lightning type renderer. Renders an editable create form in the Agentforce window. Set Output Rendering for this field to createRecordData custom lightning type.')
        public CreateRecordData createData;

        @InvocableVariable(
            label='Error Message'
            description='Human-readable error explaining why the action failed. Display to the user when success is false and ask them to verify the object name or their permissions.')
        public String errorMessage;
    }
}
