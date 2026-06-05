public without sharing class MattersTriggerHandler {     

    public static boolean recursion = false;
    public static void execute(){
        generateMatterRecordsToShare();
        /*if(recursion==false){
            generateCILinksFormstack();
        }*/
    }
    
    /*private static void generateCILinksFormstack(){
        List<id> matterId = new List<Id>();
        List<Matters__c> updateMatter = new List<Matters__c>();
        for(Matters__c matter : (List<Matters__c>)Trigger.new){
            matterId.add(matter.id);  
            Matters__c matt = new Matters__c();
            matt.Id = matter.Id;
            updateMatter.add(matt);
        }

        if(!matterId.isEmpty()){
            //FFPrefill_Trigger02413
			VisualAntidote.FastFormsUtilities.DoUpdateRecords( 'Matters__c' ,  'Initial_Pleading__c' ,  'a1k4N000004tNVsQAM' ,  matterId,null );  
 			//FFPrefill_Trigger04F71
 			VisualAntidote.FastFormsUtilities.DoUpdateRecords( 'Matters__c' ,  'Asset_URL__c' ,  'a1k4N00000NcJSbQAN' ,  matterId,null );
            //FFPrefill_Trigger0C8F5
            VisualAntidote.FastFormsUtilities.DoUpdateRecords( 'Matters__c' ,  'Children_URL__c' ,  'a1k4N00000NcJRdQAN' ,  matterId,null );  
            //FFPrefill_Trigger15729
            VisualAntidote.FastFormsUtilities.DoUpdateRecords( 'Matters__c' ,  'OP_URL__c' ,  'a1k4N00000NcJPDQA3' ,  matterId,null );  
			//FFPrefill_Trigger25649
			VisualAntidote.FastFormsUtilities.DoUpdateRecords( 'Matters__c' ,  'Initial_Pleading__c' ,  'a1kTP000002r0aDYAQ' ,  matterId,null );
            //FFPrefill_Trigger41721
            VisualAntidote.FastFormsUtilities.DoUpdateRecords( 'Matters__c' ,  'Income_URL__c' ,  'a1k4N00000NcJSRQA3' ,  matterId,null ); 
            //FFPrefill_Trigger4C349	
            VisualAntidote.FastFormsUtilities.DoUpdateRecords( 'Matters__c' ,  'SFS_URL__c' ,  'a1k4N00000QFOfoQAH' ,  matterId,null );
            //FFPrefill_Trigger4FC20
            VisualAntidote.FastFormsUtilities.DoUpdateRecords( 'Matters__c' ,  'Vitals_URL__c' ,  'a1k4N00000NcJP8QAN' ,  matterId,null );
            //FFPrefill_Trigger6373B
            VisualAntidote.FastFormsUtilities.DoUpdateRecords( 'Matters__c' ,  'Special_Upload_URL__c' ,  'a1k4N000004hsBHQAY' ,  matterId,null );
            //FFPrefill_Trigger672AD
            VisualAntidote.FastFormsUtilities.DoUpdateRecords( 'Matters__c' ,  'Expenses_URL__c' ,  'a1k4N00000NcJSlQAN' ,  matterId,null );
            //FFPrefill_Trigger67FC8
            VisualAntidote.FastFormsUtilities.DoUpdateRecords( 'Matters__c' ,  'Client_Retention__c' ,  'a1k4N000004hPIBQA2' ,  matterId,null );
            //FFPrefill_Trigger72F48
            VisualAntidote.FastFormsUtilities.DoUpdateRecords( 'Matters__c' ,  'Clients_Not_Retained__c' ,  'a1k4N000004hQqYQAU' ,  matterId,null );
            //FFPrefill_Trigger90C8D
            VisualAntidote.FastFormsUtilities.DoUpdateRecords( 'Matters__c' ,  'Debt_URL__c' ,  'a1k4N00000NcJSWQA3' ,  matterId,null );
          	//FFPrefill_TriggerDE3CC
          	VisualAntidote.FastFormsUtilities.DoUpdateRecords( 'Matters__c' ,  'Initial_Pleading_COS__c' ,  'a1kTP000002G8rhYAC' ,  matterId,null );             
            update updateMatter;
            recursion=true;
        }        
    }*/

    private static void generateMatterRecordsToShare(){
        List<id> matterId = new List<Id>();
        
        for(Matters__c matter : (List<Matters__c>)Trigger.new){
            matterId.add(matter.id);            
        }

        if(!matterId.isEmpty()){
            createObjectShareListContext('Matters__c', matterId) ;
        }
    }
    public static void createObjectShare(string objectString, id objectId, id userId){
        List<AccountShare> listToInsert = new List<AccountShare>();
        List<Matters__Share> mattersListToInsert = new List<Matters__Share>();

        switch on objectString {
            when 'Account' {
                AccountShare share = new AccountShare();
                share.UserOrGroupId = userId;
                share.AccountId = objectId;                       
                share.AccountAccessLevel = 'Edit';
                share.OpportunityAccessLevel = 'None';
                share.RowCause = 'Manual';
                listToInsert.add(share);
                
            }
            when 'Matters__c' {
                Matters__Share  mShare = new Matters__Share();
                mShare.UserOrGroupId = userId;
                mShare.ParentId = objectId;                       
                mShare.AccessLevel = 'Edit';
                mShare.RowCause = Schema.Matters__Share.RowCause.Compliance__c;
                mattersListToInsert.add(mShare);
            }
        }
        if(!listToInsert.isEmpty()){
            try{
                database.insert(listToInsert, false);
            }catch(exception e) {
                Utility.createFutureErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'MattersTriggerHandler.createObjectShare(Accounts)');    
            }
        }
        if(!mattersListToInsert.isEmpty()){
            try{
                database.insert(mattersListToInsert, false);
            }catch(exception e) {
                Utility.createFutureErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'MattersTriggerHandler.createObjectShare(Matters)');    
            }
        }  
    }
    @InvocableMethod(label='create matters shares' description='Creates matters shares for matters created by Portal Users.' category='Matter')
    public static void createMatterShares ( ){ //finds matter records belonging to Portal users, reassigns the user and then creates the matters share records
        try {
            // we need to change the ownership on the matter record from the Portal user to the primary attorney on the matter otherwise we won't be able to create the sharing records
            List <Matters__c> matters= [select id, name, ownerid, owner.profile.name, Primary_Attorney__c, Primary_Attorney__r.name, Primary_Attorney__r.email,
                Primary_Paralegal__c, Primary_Paralegal__r.name, Primary_Paralegal__r.email, 
                account__r.ownerid from matters__c where owner.profile.name like '%Comm%'] ;
            List<Id> idsToUpdate = new List<Id>();
            for (Matters__c matter : matters){
                if (matter.owner.profile.name.contains('Community') ){ //redundant
                    idsToUpdate.add(matter.Id);  //definitely want to create the sharing records for this matter
                    if ( matter.Primary_Attorney__c !=null){
                        matter.ownerId=matter.Primary_Attorney__c;
                    } else if ( matter.Primary_Paralegal__c !=null){
                        matter.ownerId=matter.Primary_Paralegal__c;
                    }   else {
                        matter.ownerId=matter.account__r.ownerid; //since the account owner will never be a Portal User
                    }
                }
            }
            if (idsToUpdate.size()>0){
                update matters;
                createObjectShareListContext('Matters__c', idsToUpdate);
            }
            sendEmailsAboutMatter(matters);
        }catch(exception e) {
            Utility.createErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'MattersTriggerHandler.createMatterShares');    
        }        
    }    
    // make it public so it's easier to test--matters needs to have all the fields needed to send out the email
    public static void sendEmailsAboutMatter(List<Matters__c> matters){
        List<Messaging.SingleEmailMessage> emailsNeedToSend = new List<Messaging.SingleEmailMessage>();
        String[] sendingTo;
        string emailBody;
        Messaging.SingleEmailMessage email;
        for(Matters__c matter : matters){
            if (matter.Primary_Attorney__r.email!=null){
                emailBody = 'Hello '+matter.Primary_Attorney__r.name+',<br/><br/>';
                emailBody += 'A new matter was created as part of the automated FA process.  This matter is assigned to you and is ready to be worked on.';                       
                emailBody += '<br/>You may view the matter here :<br/>';            
                string orgUrl = URL.getOrgDomainURL().toExternalForm()+'/lightning/r/Matters__c/'+matter.Id+'/view';
                emailBody += ' <a href="'+orgUrl+'">'+matter.Name+'</a>.<br/><br/>';
                emailBody += '<p>Thank you.</p>';            
                email = new Messaging.SingleEmailMessage();
                sendingTo = new String[]{matter.Primary_Attorney__r.email};
                email.setToAddresses(sendingTo);             
                email.setSubject('New matter available:  '+matter.Name);
                email.setHtmlBody(emailBody);
                emailsNeedToSend.add(email);        
            }          
            if (matter.Primary_Paralegal__r.email!=null){
                emailBody = 'Hello '+matter.Primary_Paralegal__r.name+',<br/><br/>';
                emailBody += 'A new matter was created as part of the automated FA process.  This matter is assigned to you and is ready to be worked on.';                  
                emailBody += '<br/>You may view the matter here :';            
                string orgUrl = URL.getOrgDomainURL().toExternalForm()+'/lightning/r/Matters__c/'+matter.Id+'/view';
                emailBody += ' <a href="'+orgUrl+'">'+matter.Name+'</a>.<br/><br/>';
                emailBody += '<p>Thank you.</p>';            
                email = new Messaging.SingleEmailMessage();
                sendingTo = new String[]{matter.Primary_Paralegal__r.email};
                email.setToAddresses(sendingTo);             
                email.setSubject('New matter available:  '+matter.Name);
                email.setHtmlBody(emailBody);
                emailsNeedToSend.add(email);        
            }              
        }
        Messaging.sendEmail(emailsNeedToSend);      
    } 
    public static void createObjectShareListContext(string objectString, List<id> objectIdList){
        List<AccountShare> listToInsert = new List<AccountShare>();
        List<Matters__Share> mattersListToInsert = new List<Matters__Share>();
        
        for(User usr : [SELECT ID FROM User WHERE isActive = true AND Profile.Name = 'Attorney/Paralegal']){
            if(objectString == 'Account'){
                for(Id objectId : objectIdList){
                    AccountShare share = new AccountShare();
                    share.UserOrGroupId = usr.Id;
                    share.AccountId = objectId;                       
                    share.AccountAccessLevel = 'Edit';
                    share.OpportunityAccessLevel = 'None';
                    share.RowCause = 'Manual';
                    listToInsert.add(share);
                }
            }            
            if(objectString == 'Matters__c'){
                for(Id objectId : objectIdList){
                    Matters__Share  mShare = new Matters__Share();
                    mShare.UserOrGroupId = usr.Id;
                    mShare.ParentId = objectId;                       
                    mShare.AccessLevel = 'Edit';
                    mShare.RowCause = Schema.Matters__Share.RowCause.Compliance__c;
                    mattersListToInsert.add(mShare);
                }                       
            }             
        }        
        if(!listToInsert.isEmpty()){
            try{
                database.insert(listToInsert, false);
            }catch(exception e) {
                Utility.createFutureErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'MattersTriggerHandler.createObjectShareListContext(Accounts)');    
            }  
        }
        if(!mattersListToInsert.isEmpty()){
            try{
                database.insert(mattersListToInsert, false);
            }catch(exception e) {
                Utility.createFutureErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'MattersTriggerHandler.createObjectShareListContext(Matters)');    
            }              
        }     
    }

    // Checks for for a change in Client lookup value on Matter 
    public static void checkPrimaryUserFields(List<Matters__c> matters) {
        Map<Id, Matters__c> mattersById = new Map<Id, Matters__c>();
        for (Matters__c m : matters) {
            if (Trigger.isInsert) {
                mattersById.put(m.Id, m);
            } else {
                Matters__c originalRecord = (Matters__c)Trigger.oldMap.get(m.Id);
                if (m.Client_Name__c != null && originalRecord.Client_Name__c != m.Client_Name__c
                    && m.Client_Name__c != originalRecord.Client_Name__c) {
                    mattersById.put(m.Id, m);
                }
            }
        }
        // Process matters with changed values 
        if (!mattersById.keySet().isEmpty()) {
            updateUserFieldsOnChildren(mattersById);
        }
    }

    // Get all child records and update Client Account lookup fields 
    private static void updateUserFieldsOnChildren(Map<Id, Matters__c> matters) {
        List<Bank_Account__c> bAccts = new List<Bank_Account__c>();
        List<Life_Insurance__c> insurance = new List<Life_Insurance__c>();

        List<Housing__c> homes = new List<Housing__c>();
        for (Housing__c h : [
            SELECT Id, Client__c, Related_Matter__c
            FROM Housing__c WHERE Related_Matter__c IN :matters.keySet()
        ]) {
            Matters__c matter = matters.get(h.Related_Matter__c);
            // Update Client if (a) blank on child object or (b) current value is different than Matter value 
            if (matter.Client_Name__c != null 
                && (h.Client__c == null || (h.Client__c != matter.Client_Name__c))) {
                h.Client__c = matter.Client_Name__c;
                homes.add(h);
            }
        }
        update homes;

        List<Furniture_Personal_Property__c> props = new List<Furniture_Personal_Property__c>();
        for (Furniture_Personal_Property__c p : [
            SELECT Id, Related_Account__c, Related_Matter__c
            FROM Furniture_Personal_Property__c WHERE Related_Matter__c IN :matters.keySet()
        ]) {
            Matters__c matter = matters.get(p.Related_Matter__c);
            // Update Client if (a) blank on child object or (b) current value is different than Matter value 
            if (matter.Client_Name__c != null && p.Related_Account__c == null) {
                p.Related_Account__c = matter.Client_Name__c;
                props.add(p);
            }
        }
        update props;

        List<Life_Insurance__c> lifeIns = new List<Life_Insurance__c>();
        for (Life_Insurance__c i : [
            SELECT Id, Client__c, Related_Matter__c
            FROM Life_Insurance__c WHERE Related_Matter__c IN :matters.keySet()
        ]) {
            Matters__c matter = matters.get(i.Related_Matter__c);
            // Update Client if (a) blank on child object or (b) current value is different than Matter value 
            if (matter.Client_Name__c != null 
                && (i.Client__c != matter.Client_Name__c)) {
                i.Client__c = matter.Client_Name__c;
                lifeIns.add(i);
            }
        }
        update lifeIns;

        List<Bank_Account__c> accts = new List<Bank_Account__c>();
        for (Bank_Account__c a : [
            SELECT Id, Related_To__c, Related_Matter__c
            FROM Bank_Account__c WHERE Related_Matter__c IN :matters.keySet()
        ]) {
            Matters__c matter = matters.get(a.Related_Matter__c);
            // Update Client if (a) blank on child object or (b) current value is different than Matter value 
            if (matter.Client_Name__c != null && a.Related_To__c == null ) {
                a.Related_To__c = matter.Client_Name__c;
                accts.add(a);
            }
        }
        update accts;

        List<Investment_Account__c> invAccts = new List<Investment_Account__c>();
        for (Investment_Account__c ia : [
            SELECT Id, Related_Account__c, Related_Matter__c
            FROM Investment_Account__c WHERE Related_Matter__c IN :matters.keySet()
        ]) {
            Matters__c matter = matters.get(ia.Related_Matter__c);
            // Update Client if (a) blank on child object or (b) current value is different than Matter value 
            if (matter.Client_Name__c != null && ia.Related_Account__c == null) {
                ia.Related_Account__c = matter.Client_Name__c;
                invAccts.add(ia);
            }
        }
        update invAccts;

        List<Additional_Asset__c> addtAssets = new List<Additional_Asset__c>();
        for (Additional_Asset__c aa : [
            SELECT Id, Client__c, Related_Matter__c
            FROM Additional_Asset__c WHERE Related_Matter__c IN :matters.keySet()
        ]) {
            Matters__c matter = matters.get(aa.Related_Matter__c);
            // Update Client if (a) blank on child object or (b) current value is different than Matter value 
            if (matter.Client_Name__c != null 
                && (aa.Client__c == null || (aa.Client__c != matter.Client_Name__c))) {
                aa.Client__c = matter.Client_Name__c;
                addtAssets.add(aa);
            }
        }
        update addtAssets;

        List<Retirement_Account__c> retAccts = new List<Retirement_Account__c>();
        for (Retirement_Account__c ra : [
            SELECT Id, Client__c, Related_Matter__c
            FROM Retirement_Account__c WHERE Related_Matter__c IN :matters.keySet()
        ]) {
            Matters__c matter = matters.get(ra.Related_Matter__c);
            // Update Client if (a) blank on child object or (b) current value is different than Matter value 
            if (matter.Client_Name__c != null 
                && (ra.Client__c == null || (ra.Client__c != matter.Client_Name__c))) {
                ra.Client__c = matter.Client_Name__c;
                retAccts.add(ra);
            }
        }
        update retAccts;

        List<Vehicle__c> cars = new List<Vehicle__c>();
        for (Vehicle__c car : [
            SELECT Id, Related_To__c, Related_Matter__c
            FROM Vehicle__c WHERE Related_Matter__c IN :matters.keySet()
        ]) {
            Matters__c matter = matters.get(car.Related_Matter__c);
            // Update Client if (a) blank on child object or (b) current value is different than Matter value 
            if (matter.Client_Name__c != null && car.Related_To__c == null) {
                car.Related_To__c = matter.Client_Name__c;
                cars.add(car);
            }
        }
        update cars;

        List<Credit_Card__c> cCards = new List<Credit_Card__c>();
        for (Credit_Card__c card : [
            SELECT Id, Account_Owner__c, Matter_ID__c
            FROM Credit_Card__c WHERE Matter_ID__c IN :matters.keySet()
        ]) {
            Matters__c matter = matters.get(card.Matter_ID__c);
            // Update Client if (a) blank on child object or (b) current value is different than Matter value 
            if (matter.Client_Name__c != null && card.Account_Owner__c == null) {
                card.Account_Owner__c = matter.Client_Name__c;
                cCards.add(card);
            }
        }
        update cCards;

        List<Debt__c> debts = new List<Debt__c>();
        for (Debt__c debt : [
            SELECT Id, Related_To__c, Related_Matter__c
            FROM Debt__c WHERE Related_Matter__c IN :matters.keySet()
        ]) {
            Matters__c matter = matters.get(debt.Related_Matter__c);
            // Update Client if (a) blank on child object or (b) current value is different than Matter value 
            if (matter.Client_Name__c != null && debt.Related_To__c == null ) {
                debt.Related_To__c = matter.Client_Name__c;
                debts.add(debt);
            }
        }
        update debts;

        List<Employment__c> jobs = new List<Employment__c>();
        for (Employment__c job : [
            SELECT Id, Related_To__c, Related_Matter__c
            FROM Employment__c WHERE Related_Matter__c IN :matters.keySet()
        ]) {
            Matters__c matter = matters.get(job.Related_Matter__c);
            // Update Client if (a) blank on child object or (b) current value is different than Matter value 
            if (matter.Client_Name__c != null && job.Related_To__c == null) {
                job.Related_To__c = matter.Client_Name__c;
                jobs.add(job);
            }
        }
        update jobs;

        List<Taxes__c> taxes = new List<Taxes__c>();
        for (Taxes__c tax : [
            SELECT Id, Related_To__c, Matter_ID__c
            FROM Taxes__c WHERE Matter_ID__c IN :matters.keySet()
        ]) {
            Matters__c matter = matters.get(tax.Matter_ID__c);
            // Update Client if (a) blank on child object or (b) current value is different than Matter value 
            if (matter.Client_Name__c != null && tax.Related_To__c == null) {
                tax.Related_To__c = matter.Client_Name__c;
                taxes.add(tax);
            }
        }
        update taxes;

        List<Other_Income__c> oIncomes = new List<Other_Income__c>();
        for (Other_Income__c income : [
            SELECT Id, Related_To__c, Matter__c
            FROM Other_Income__c WHERE Matter__c IN :matters.keySet()
        ]) {
            Matters__c matter = matters.get(income.Matter__c);
            // Update Client if (a) blank on child object or (b) current value is different than Matter value 
            if (matter.Client_Name__c != null && income.Related_To__c == null) {
                income.Related_To__c = matter.Client_Name__c;
                oIncomes.add(income);
            }
        }
        update oIncomes;
    }
}