/**
 * Represents a single field in the create record form.
 * Used by the dynamicRecordCreator LWC to render the correct input type per field.
 */
@JsonAccess(serializable='always' deserializable='always')
global class CreateRecordField {

    @AuraEnabled
    global String fieldLabel;

    @AuraEnabled
    global String fieldApiName;

    @AuraEnabled
    global String fieldType;

    @AuraEnabled
    global Boolean isRequired;

    @AuraEnabled
    global String defaultValue;

    @AuraEnabled
    global List<String> picklistValues;

    @AuraEnabled
    global List<String> referenceTo;

    @AuraEnabled
    global Boolean isHidden;

    @AuraEnabled
    global Boolean isReadOnly;
}
