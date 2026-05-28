import { LightningElement, api, track } from 'lwc';
import createRecord from '@salesforce/apex/DynamicRecordSaver.createRecord';

const INPUT_TYPE_MAP = {
    STRING:      'text',
    EMAIL:       'email',
    PHONE:       'tel',
    URL:         'url',
    INTEGER:     'number',
    DOUBLE:      'number',
    LONG:        'number',
    CURRENCY:    'number',
    PERCENT:     'number',
    DATE:        'date',
    DATETIME:    'datetime-local',
    TIME:        'time'
};

const TEXTAREA_TYPES = new Set(['TEXTAREA', 'ENCRYPTEDSTRING']);

const POLYMORPHIC_LABELS = {
    WhoId:   'Searches Contacts. Use WhatId for Leads.',
    WhatId:  'Searches Accounts.'
};

export default class DynamicRecordCreator extends LightningElement {

    @api value;

    @track fieldValues   = {};
    @track isSaving      = false;
    @track isSaved       = false;
    @track statusMessage = '';
    @track isError       = false;

    @track savedRecordUrl  = '';
    @track savedRecordName = '';
    @track successMessage  = '';

    get objectLabel()   { return this.value?.objectLabel  || 'Record'; }
    get iconName()      { return this.value?.objectIconName || 'standard:record'; }
    get isDisabled()    { return this.isSaving || this.isSaved; }
    get saveButtonLabel() { return this.isSaving ? 'Saving…' : 'Save'; }

    get statusClass() {
        return 'status-row ' + (this.isError ? 'status-row--error' : 'status-row--info');
    }

    get statusIcon() {
        return this.isError ? 'utility:error' : 'utility:info';
    }

    get statusIconVariant() {
        return this.isError ? 'error' : '';
    }

    get processedFields() {
        return (this.value?.fields || [])
            .filter(field => field.isHidden !== true)
            .map(field => {
                const type         = (field.fieldType || 'STRING').toUpperCase();
                const currentValue = this.fieldValues[field.fieldApiName] !== undefined
                                     ? this.fieldValues[field.fieldApiName]
                                     : (field.defaultValue || '');

                const isTextarea      = TEXTAREA_TYPES.has(type);
                const isCheckbox      = type === 'BOOLEAN';
                const isPicklist      = type === 'PICKLIST';
                const isMultiPicklist = type === 'MULTIPICKLIST';
                const isLookup        = type === 'REFERENCE';
                const isStandard      = !isTextarea && !isCheckbox && !isPicklist && !isMultiPicklist && !isLookup;

                const picklistOptions = (field.picklistValues || []).map(v => ({ label: v, value: v }));

                const multiValues = isMultiPicklist && currentValue
                    ? (Array.isArray(currentValue) ? currentValue : currentValue.split(';'))
                    : [];

                const referenceTo         = field.referenceTo || [];
                const referenceObjectName = referenceTo[0] || 'Account';
                const referenceNote       = POLYMORPHIC_LABELS[field.fieldApiName] || null;

                return {
                    fieldApiName:       field.fieldApiName,
                    fieldLabel:         field.fieldLabel,
                    fieldType:          type,
                    isRequired:         field.isRequired === true,
                    isStandard,
                    isTextarea,
                    isCheckbox,
                    isPicklist,
                    isMultiPicklist,
                    isLookup,
                    referenceObjectName,
                    referenceNote,
                    inputType:          INPUT_TYPE_MAP[type] || 'text',
                    currentValue,
                    checkedValue:       isCheckbox ? currentValue === 'true' || currentValue === true : false,
                    picklistOptions,
                    multiValues
                };
            });
    }

    handleFieldChange(event) {
        const apiName          = event.target.fieldName || event.target.getAttribute('field-name');
        this.fieldValues       = { ...this.fieldValues, [apiName]: event.target.value };
        this.statusMessage     = '';
    }

    handleCheckboxChange(event) {
        const apiName          = event.target.fieldName || event.target.getAttribute('field-name');
        this.fieldValues       = { ...this.fieldValues, [apiName]: event.target.checked };
        this.statusMessage     = '';
    }

    handleMultiPicklistChange(event) {
        const apiName          = event.target.fieldName || event.target.getAttribute('field-name');
        this.fieldValues       = { ...this.fieldValues, [apiName]: event.detail.value };
        this.statusMessage     = '';
    }

    handleLookupChange(event) {
        const apiName      = event.target.dataset.fieldName;
        const recordId     = event.detail.recordId || '';
        this.fieldValues   = { ...this.fieldValues, [apiName]: recordId };
        this.statusMessage = '';
    }

    handleCancel() {
        this.fieldValues     = {};
        this.statusMessage   = '';
        this.isError         = false;
    }

    async handleSave() {
        const objectApiName = this.value?.objectApiName;
        if (!objectApiName) {
            this._setStatus(true, 'Missing object information. Please refresh and try again.');
            return;
        }

        const missing = this.processedFields
            .filter(f => f.isRequired && this._isEmpty(f.currentValue, f))
            .map(f => f.fieldLabel);

        if (missing.length > 0) {
            this._setStatus(true, 'Please fill in required fields: ' + missing.join(', '));
            return;
        }

        this.isSaving      = true;
        this.statusMessage = '';
        this.isError       = false;

        const flatValues = {};
        for (const field of (this.value?.fields || [])) {
            if (field.defaultValue) {
                flatValues[field.fieldApiName] = field.defaultValue;
            }
        }

        for (const key of Object.keys(this.fieldValues)) {
            const val = this.fieldValues[key];
            flatValues[key] = Array.isArray(val) ? val.join(';') : val;
        }

        try {
            const result = await createRecord({
                objectApiName,
                fieldsJson: JSON.stringify(flatValues)
            });

            if (result.success) {
                this.isSaved         = true;
                this.savedRecordUrl  = result.recordUrl  || '/' + result.recordId;
                this.savedRecordName = result.recordName || result.recordId;
                this.successMessage  = this.objectLabel + ' created successfully!';
            } else {
                this._setStatus(true, result.errorMessage || 'Create failed. Please review the field values.');
            }

        } catch (error) {
            const msg = error?.body?.message || 'An unexpected error occurred. Please try again.';
            this._setStatus(true, msg);
        } finally {
            this.isSaving = false;
        }
    }

    _isEmpty(value, field) {
        if (value === undefined || value === null || value === '') return true;
        if (Array.isArray(value) && value.length === 0) return true;
        if (field.isCheckbox) return false;
        return false;
    }

    _setStatus(isError, message) {
        this.isError       = isError;
        this.statusMessage = message;
    }
}
