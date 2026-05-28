public with sharing class DynamicRecordSaver {

    /**
     * Creates a new Salesforce record dynamically.
     * Called from the dynamicRecordCreator LWC.
     *
     * @param objectApiName - API name of the object to create (e.g. "Lead")
     * @param fieldsJson    - JSON string of { fieldApiName: value }
     * @return              - CreateResult with success flag, new record ID, and URL
     */
    @AuraEnabled
    public static CreateResult createRecord(String objectApiName, String fieldsJson) {
        CreateResult result = new CreateResult();

        if (String.isBlank(objectApiName)) {
            result.success      = false;
            result.errorMessage = 'Object API name is required.';
            return result;
        }
        if (String.isBlank(fieldsJson)) {
            result.success      = false;
            result.errorMessage = 'No field values provided.';
            return result;
        }

        Schema.SObjectType sObjectType = Schema.getGlobalDescribe().get(objectApiName);
        if (sObjectType == null) {
            result.success      = false;
            result.errorMessage = 'Unknown object: ' + objectApiName;
            return result;
        }

        Schema.DescribeSObjectResult objDescribe = sObjectType.getDescribe();
        if (!objDescribe.isCreateable()) {
            result.success      = false;
            result.errorMessage = 'You do not have permission to create ' + objDescribe.getLabel() + ' records.';
            return result;
        }

        Map<String, Schema.SObjectField> fieldMap = objDescribe.fields.getMap();
        Map<String, Object> fieldValues = (Map<String, Object>) JSON.deserializeUntyped(fieldsJson);

        SObject record = sObjectType.newSObject();

        for (String apiName : fieldValues.keySet()) {
            String key = apiName.toLowerCase();
            if (!fieldMap.containsKey(key)) {
                System.debug('Skipping unknown field: ' + apiName);
                continue;
            }
            Schema.DescribeFieldResult fd = fieldMap.get(key).getDescribe();
            if (!fd.isCreateable()) {
                System.debug('Skipping non-createable field: ' + apiName);
                continue;
            }
            Object rawValue = fieldValues.get(apiName);
            Object castVal  = castValue(rawValue, fd.getType());
            if (castVal != null) {
                record.put(apiName, castVal);
            }
        }

        setDefaultIfEmpty(record, fieldMap, 'IsActive', true);

        try {
            insert record;
            String newId = (String) record.get('Id');

            String recName = '';
            if (fieldMap.containsKey('name')) {
                SObject fetched = Database.query(
                    'SELECT Id, Name FROM ' + objectApiName + ' WHERE Id = :newId LIMIT 1'
                );
                recName = (String) fetched.get('Name');
            }

            result.success    = true;
            result.recordId   = newId;
            result.recordName = recName;
            result.recordUrl  = '/' + newId;

        } catch (DmlException e) {
            result.success      = false;
            result.errorMessage = e.getDmlMessage(0);
        }

        return result;
    }

    // ─── Type casting ─────────────────────────────────────────────────────────

    private static Object castValue(Object value, Schema.DisplayType fieldType) {
        if (value == null) return null;
        String strVal = String.valueOf(value).trim();
        if (String.isBlank(strVal)) return null;

        try {
            if (fieldType == Schema.DisplayType.BOOLEAN)  return Boolean.valueOf(strVal);
            if (fieldType == Schema.DisplayType.DATE)     return Date.valueOf(strVal);
            if (fieldType == Schema.DisplayType.DATETIME) return DateTime.valueOf(strVal.replace('T', ' '));
            if (fieldType == Schema.DisplayType.INTEGER)  return Integer.valueOf(strVal);
            if (fieldType == Schema.DisplayType.LONG)     return Long.valueOf(strVal);
            if (fieldType == Schema.DisplayType.DOUBLE ||
                fieldType == Schema.DisplayType.CURRENCY ||
                fieldType == Schema.DisplayType.PERCENT)  return Decimal.valueOf(strVal);
            return strVal;
        } catch (Exception e) {
            System.debug('castValue error for ' + fieldType + ' = "' + strVal + '": ' + e.getMessage());
            return strVal;
        }
    }

    private static void setDefaultIfEmpty(SObject record, Map<String, Schema.SObjectField> fieldMap, String apiName, Object value) {
        String key = apiName.toLowerCase();
        if (!fieldMap.containsKey(key)) return;
        Schema.DescribeFieldResult fd = fieldMap.get(key).getDescribe();
        if (!fd.isCreateable()) return;
        if (record.get(apiName) == null) {
            record.put(apiName, value);
        }
    }

    // ─── Result class ─────────────────────────────────────────────────────────

    public class CreateResult {
        @AuraEnabled public Boolean success = false;
        @AuraEnabled public String  recordId;
        @AuraEnabled public String  recordName;
        @AuraEnabled public String  recordUrl;
        @AuraEnabled public String  errorMessage;
    }
}
