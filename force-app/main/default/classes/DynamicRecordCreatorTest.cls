@IsTest
private class DynamicRecordCreatorTest {

    @IsTest
    static void testResolveByApiName() {
        DynamicRecordCreator.Request req = new DynamicRecordCreator.Request();
        req.objectName    = 'Lead';
        req.showAllFields = false;

        Test.startTest();
        List<DynamicRecordCreator.Result> results =
            DynamicRecordCreator.getRequiredFields(new List<DynamicRecordCreator.Request>{ req });
        Test.stopTest();

        System.assertNotEquals(null, results);
        System.assertEquals(1, results.size());
        System.assert(results[0].success,
            'Expected success for Lead object. Error: ' + results[0].errorMessage);
        System.assertNotEquals(null, results[0].createData);
        System.assertEquals('Lead', results[0].createData.objectApiName);
        System.assert(results[0].createData.fields.size() > 0,
            'Lead should have at least one required field');
    }

    @IsTest
    static void testResolveByLabel() {
        DynamicRecordCreator.Request req = new DynamicRecordCreator.Request();
        req.objectName    = 'Lead';
        req.showAllFields = false;

        Test.startTest();
        List<DynamicRecordCreator.Result> results =
            DynamicRecordCreator.getRequiredFields(new List<DynamicRecordCreator.Request>{ req });
        Test.stopTest();

        System.assert(results[0].success, 'Expected success for Lead label lookup');
        System.assertEquals('Lead', results[0].createData.objectApiName);
    }

    @IsTest
    static void testShowAllFields() {
        DynamicRecordCreator.Request req = new DynamicRecordCreator.Request();
        req.objectName    = 'Lead';
        req.showAllFields = true;

        Test.startTest();
        List<DynamicRecordCreator.Result> results =
            DynamicRecordCreator.getRequiredFields(new List<DynamicRecordCreator.Request>{ req });
        Test.stopTest();

        System.assert(results[0].success);
        System.assert(results[0].createData.fields.size() > 1,
            'Show all fields should return multiple fields on Lead');
    }

    @IsTest
    static void testBlankObjectName() {
        DynamicRecordCreator.Request req = new DynamicRecordCreator.Request();
        req.objectName = '';

        Test.startTest();
        List<DynamicRecordCreator.Result> results =
            DynamicRecordCreator.getRequiredFields(new List<DynamicRecordCreator.Request>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assertNotEquals(null, results[0].errorMessage);
    }

    @IsTest
    static void testUnknownObject() {
        DynamicRecordCreator.Request req = new DynamicRecordCreator.Request();
        req.objectName = 'NonExistentObject__xyz';

        Test.startTest();
        List<DynamicRecordCreator.Result> results =
            DynamicRecordCreator.getRequiredFields(new List<DynamicRecordCreator.Request>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assert(results[0].errorMessage.contains('NonExistentObject__xyz'));
    }

    @IsTest
    static void testFormattedOutputPresent() {
        DynamicRecordCreator.Request req = new DynamicRecordCreator.Request();
        req.objectName = 'Lead';

        Test.startTest();
        List<DynamicRecordCreator.Result> results =
            DynamicRecordCreator.getRequiredFields(new List<DynamicRecordCreator.Request>{ req });
        Test.stopTest();

        if (results[0].success) {
            System.assertNotEquals(null, results[0].formattedOutput);
            System.assert(results[0].formattedOutput.contains('Lead'));
        }
    }

    @IsTest
    static void testDynamicRecordSaverCreateLead() {
        Map<String, Object> fields = new Map<String, Object>{
            'LastName' => 'TestLead_DynamicCreator',
            'Company'  => 'Test Company'
        };

        Test.startTest();
        DynamicRecordSaver.CreateResult result =
            DynamicRecordSaver.createRecord('Lead', JSON.serialize(fields));
        Test.stopTest();

        System.assert(result.success, 'Expected lead insert to succeed. Error: ' + result.errorMessage);
        System.assertNotEquals(null, result.recordId);
        System.assertNotEquals(null, result.recordUrl);
    }

    @IsTest
    static void testDynamicRecordSaverBlankObject() {
        Test.startTest();
        DynamicRecordSaver.CreateResult result =
            DynamicRecordSaver.createRecord('', '{"LastName":"Test"}');
        Test.stopTest();

        System.assertEquals(false, result.success);
    }

    @IsTest
    static void testDynamicRecordSaverBlankFields() {
        Test.startTest();
        DynamicRecordSaver.CreateResult result =
            DynamicRecordSaver.createRecord('Lead', '');
        Test.stopTest();

        System.assertEquals(false, result.success);
    }

    @IsTest
    static void testDynamicRecordSaverUnknownObject() {
        Test.startTest();
        DynamicRecordSaver.CreateResult result =
            DynamicRecordSaver.createRecord('Bogus__xyz', '{"Name":"Test"}');
        Test.stopTest();

        System.assertEquals(false, result.success);
    }
}
