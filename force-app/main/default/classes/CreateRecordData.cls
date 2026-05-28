/**
 * Wrapper passed to the dynamicRecordCreator LWC custom lightning type renderer.
 * Contains the object metadata and required fields needed to render a create form
 * in the Agentforce window.
 */
@JsonAccess(serializable='always' deserializable='always')
global class CreateRecordData {

    @AuraEnabled
    global String objectApiName;

    @AuraEnabled
    global String objectLabel;

    @AuraEnabled
    global String objectIconName;

    @AuraEnabled
    global List<CreateRecordField> fields;
}
