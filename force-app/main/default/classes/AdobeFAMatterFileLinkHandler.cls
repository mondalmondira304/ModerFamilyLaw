/**
 * @description
 * Links the Adobe Fee Agreement final PDF (Salesforce File) from Account to the related Matter.
 * @author  Sanders
 * @date    2026-02-28
 */
public without sharing class AdobeFAMatterFileLinkHandler {

    private static final String CLASS_NAME      = 'AdobeFAMatterFileLinkHandler';
    private static final String KEY_SUFFIX      = 'FA';
    private static final String STATUS_PENDING  = 'Pending';
    private static final String STATUS_LINKED   = 'Linked';
    private static final String STATUS_FAILED   = 'Failed';

    public class Request {
        @InvocableVariable(required=false) public Id accountId;
        @InvocableVariable(required=false) public Id matterId;

        @InvocableVariable(required=false) public Id contentDocumentId;
        @InvocableVariable(required=false) public Id firstPublishLocationId;
        @InvocableVariable(required=false) public String fileTitle;
    }

    public class Response {
        @InvocableVariable public Boolean success;
        @InvocableVariable public Boolean linked;
        @InvocableVariable public Id pendingId;
        @InvocableVariable public String message;
    }

    @InvocableMethod(
        label='Link Adobe FA File to Matter'
        description='Stages and links the Adobe Fee Agreement PDF to the Matter when both are available.'
    )
    public static List<Response> link(List<Request> requests) {
        List<Response> res = new List<Response>();
        if (requests == null || requests.isEmpty()) return res;

        for (Integer i = 0; i < requests.size(); i++) {
            Response r = new Response();
            r.success = false;
            r.linked = false;
            r.pendingId = null;
            r.message = null;
            res.add(r);
        }

        // 1) Resolve AccountId per request
        Map<Integer, Id> idxToAccountId = new Map<Integer, Id>();
        Set<Id> docIdsNeedingAccount = new Set<Id>();

        for (Integer i = 0; i < requests.size(); i++) {
            Request r = requests[i];
            if (r == null) continue;

            Id accId = r.accountId;

            if (accId == null && r.firstPublishLocationId != null
                && String.valueOf(r.firstPublishLocationId).startsWith('001')) {
                accId = r.firstPublishLocationId;
            }

            if (accId != null) {
                idxToAccountId.put(i, accId);
            } else if (r.contentDocumentId != null) {
                docIdsNeedingAccount.add(r.contentDocumentId);
            }
        }

        Map<Id, Id> docIdToAccountId = new Map<Id, Id>();
        if (!docIdsNeedingAccount.isEmpty()) {
            for (ContentDocumentLink cdl : [
                SELECT ContentDocumentId, LinkedEntityId
                FROM ContentDocumentLink
                WHERE ContentDocumentId IN :docIdsNeedingAccount
            ]) {
                if (cdl.LinkedEntityId != null && String.valueOf(cdl.LinkedEntityId).startsWith('001')) {
                    if (!docIdToAccountId.containsKey(cdl.ContentDocumentId)) {
                        docIdToAccountId.put(cdl.ContentDocumentId, cdl.LinkedEntityId);
                    }
                }
            }
        }

        for (Integer i = 0; i < requests.size(); i++) {
            if (idxToAccountId.containsKey(i)) continue;
            Request r = requests[i];
            if (r != null && r.contentDocumentId != null && docIdToAccountId.containsKey(r.contentDocumentId)) {
                idxToAccountId.put(i, docIdToAccountId.get(r.contentDocumentId));
            }
        }

        // 2) Query Accounts for AgreementId
        Set<Id> accountIds = new Set<Id>();
        for (Id aId : idxToAccountId.values()) accountIds.add(aId);

        Map<Id, Account> accountsById = new Map<Id, Account>();
        if (!accountIds.isEmpty()) {
            accountsById = new Map<Id, Account>([
                SELECT Id, FA_Portal_AgreementId__c
                FROM Account
                WHERE Id IN :accountIds
            ]);
        }

        // 3) Build keys first, then query existing pendings to preserve fields
        Map<Integer, String> idxToKey = new Map<Integer, String>();
        Set<String> keys = new Set<String>();

        for (Integer i = 0; i < requests.size(); i++) {
            Request req = requests[i];
            Response resp = res[i];

            if (!idxToAccountId.containsKey(i)) {
                resp.message = 'Could not resolve AccountId.';
                AdobeFaErrorLogUtil.logError(
                    CLASS_NAME, 'link',
                    new System.IllegalArgumentException('Could not resolve AccountId for request index ' + i),
                    null, null,
                    'Request: matterId=' + (req != null ? req.matterId : null)
                        + ', contentDocumentId=' + (req != null ? req.contentDocumentId : null),
                    AdobeFaErrorLogUtil.ErrorType.DATA_ERROR
                );
                continue;
            }

            Id accId = idxToAccountId.get(i);
            Account a = accountsById.get(accId);
            if (a == null || String.isBlank(a.FA_Portal_AgreementId__c)) {
                resp.message = 'Account missing FA_Portal_AgreementId__c.';
                AdobeFaErrorLogUtil.logError(
                    CLASS_NAME, 'link',
                    new System.IllegalArgumentException('Account ' + accId + ' missing FA_Portal_AgreementId__c'),
                    accId, null, 'AccountId: ' + accId,
                    AdobeFaErrorLogUtil.ErrorType.DATA_ERROR
                );
                continue;
            }

            String key = String.valueOf(accId) + '-' + a.FA_Portal_AgreementId__c + '-' + KEY_SUFFIX;
            idxToKey.put(i, key);
            keys.add(key);
        }

        // Query existing staging records to preserve fields during upsert
        Map<String, Pending_FA_pdf_link__c> existingByKey = new Map<String, Pending_FA_pdf_link__c>();
        if (!keys.isEmpty()) {
            for (Pending_FA_pdf_link__c ep : [
                SELECT Id, UniqueKey__c, Matter__c, ContentDocumentId__c
                FROM Pending_FA_pdf_link__c
                WHERE UniqueKey__c IN :keys
            ]) {
                existingByKey.put(ep.UniqueKey__c, ep);
            }
        }

        List<Pending_FA_pdf_link__c> pendingsToUpsert = new List<Pending_FA_pdf_link__c>();

        for (Integer i = 0; i < requests.size(); i++) {
            if (!idxToKey.containsKey(i)) continue;
            Request req = requests[i];
            Response resp = res[i];
            String key = idxToKey.get(i);
            Id accId = idxToAccountId.get(i);
            Account a = accountsById.get(accId);

            Pending_FA_pdf_link__c p = new Pending_FA_pdf_link__c();
            p.UniqueKey__c = key;
            p.Account__c = accId;
            p.AgreementId__c = a.FA_Portal_AgreementId__c;
            p.Status__c = STATUS_PENDING;

            // Preserve existing values
            Pending_FA_pdf_link__c existing = existingByKey.get(key);

            if (req != null && req.matterId != null) {
                p.Matter__c = req.matterId;
            } else if (existing != null && existing.Matter__c != null) {
                p.Matter__c = existing.Matter__c;
            }

            if (req != null && req.contentDocumentId != null) {
                p.ContentDocumentId__c = String.valueOf(req.contentDocumentId);
            } else if (existing != null && String.isNotBlank(existing.ContentDocumentId__c)) {
                p.ContentDocumentId__c = existing.ContentDocumentId__c;
            }

            pendingsToUpsert.add(p);
            resp.success = true;
            resp.message = 'Staged';
        }

        if (!pendingsToUpsert.isEmpty()) {
            try {
                upsert pendingsToUpsert Pending_FA_pdf_link__c.UniqueKey__c;
            } catch (Exception e) {
                AdobeFaErrorLogUtil.logError(
                    CLASS_NAME, 'link-upsert', e, null, null,
                    'Failed to upsert ' + pendingsToUpsert.size() + ' staging records',
                    AdobeFaErrorLogUtil.ErrorType.SYSTEM_ERROR
                );
                for (Response resp : res) {
                    resp.success = false;
                    resp.message = 'Upsert failed: ' + e.getMessage();
                }
                return res;
            }
        }

        // 4) Requery pendings
        Map<String, Pending_FA_pdf_link__c> pendingByKey = new Map<String, Pending_FA_pdf_link__c>();
        if (!keys.isEmpty()) {
            for (Pending_FA_pdf_link__c p : [
                SELECT Id, UniqueKey__c, Matter__c, ContentDocumentId__c, Status__c, Account__c
                FROM Pending_FA_pdf_link__c
                WHERE UniqueKey__c IN :keys
            ]) {
                pendingByKey.put(p.UniqueKey__c, p);
            }
        }

        for (Integer i = 0; i < res.size(); i++) {
            if (!idxToKey.containsKey(i)) continue;
            Pending_FA_pdf_link__c p = pendingByKey.get(idxToKey.get(i));
            if (p != null) res[i].pendingId = p.Id;
        }

        // 5) Link when both exist
        Map<String, Pending_FA_pdf_link__c> pairToPending = new Map<String, Pending_FA_pdf_link__c>();
        Set<Id> matterIds = new Set<Id>();
        Set<Id> docIds = new Set<Id>();

        for (Pending_FA_pdf_link__c p : pendingByKey.values()) {
            if (p == null || p.Matter__c == null || String.isBlank(p.ContentDocumentId__c)) continue;

            Id mId = p.Matter__c;
            Id dId = (Id)p.ContentDocumentId__c;
            matterIds.add(mId);
            docIds.add(dId);
            pairToPending.put(String.valueOf(mId) + '|' + String.valueOf(dId), p);
        }

        if (pairToPending.isEmpty()) return res;

        Set<String> existingPairs = new Set<String>();
        for (ContentDocumentLink cdl : [
            SELECT LinkedEntityId, ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :matterIds AND ContentDocumentId IN :docIds
        ]) {
            existingPairs.add(String.valueOf(cdl.LinkedEntityId) + '|' + String.valueOf(cdl.ContentDocumentId));
        }

        List<ContentDocumentLink> linksToInsert = new List<ContentDocumentLink>();
        List<Pending_FA_pdf_link__c> pendingsToUpdate = new List<Pending_FA_pdf_link__c>();

        for (String pk : pairToPending.keySet()) {
            Pending_FA_pdf_link__c p = pairToPending.get(pk);

            if (!existingPairs.contains(pk)) {
                List<String> parts = pk.split('\\|');
                ContentDocumentLink link = new ContentDocumentLink();
                link.LinkedEntityId = (Id)parts[0];
                link.ContentDocumentId = (Id)parts[1];
                link.ShareType = 'V';
                link.Visibility = 'AllUsers';
                linksToInsert.add(link);
            }

            p.Status__c = STATUS_LINKED;
            pendingsToUpdate.add(p);
        }

        try {
            if (!linksToInsert.isEmpty()) insert linksToInsert;
            if (!pendingsToUpdate.isEmpty()) update pendingsToUpdate;

            Set<Id> linkedPendingIds = new Set<Id>();
            for (Pending_FA_pdf_link__c p : pendingsToUpdate) linkedPendingIds.add(p.Id);

            for (Integer i = 0; i < res.size(); i++) {
                if (res[i].pendingId != null && linkedPendingIds.contains(res[i].pendingId)) {
                    res[i].linked = true;
                    res[i].message = 'Linked';
                }
            }
        } catch (Exception e) {
            Id errorAccountId = null;
            if (!pendingsToUpdate.isEmpty()) errorAccountId = pendingsToUpdate[0].Account__c;

            AdobeFaErrorLogUtil.logError(
                CLASS_NAME, 'link-cdl-insert', e, errorAccountId, null,
                'Failed to create ContentDocumentLink. Links attempted: ' + linksToInsert.size(),
                AdobeFaErrorLogUtil.ErrorType.SYSTEM_ERROR
            );

            for (Pending_FA_pdf_link__c p : pendingsToUpdate) p.Status__c = STATUS_FAILED;
            try {
                if (!pendingsToUpdate.isEmpty()) update pendingsToUpdate;
            } catch (Exception updateEx) {
                AdobeFaErrorLogUtil.logError(
                    CLASS_NAME, 'link-status-update', updateEx, errorAccountId, null,
                    'Failed to update staging records to Failed status',
                    AdobeFaErrorLogUtil.ErrorType.SYSTEM_ERROR
                );
            }
        }

        return res;
    }
}