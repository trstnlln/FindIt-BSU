'use strict';
const {initializeApp,getApps} = require('firebase-admin/app');
const {getFirestore,FieldValue,FieldPath} = require('firebase-admin/firestore');
const {getMessaging} = require('firebase-admin/messaging');
const {onDocumentCreated,onDocumentUpdated,onDocumentDeleted} = require('firebase-functions/v2/firestore');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const {logger} = require('firebase-functions');
const {matchScore,matchesSearch,timestampMillis} = require('./matching');
if (!getApps().length) initializeApp();
const db = getFirestore();
const region = process.env.FUNCTION_REGION || 'asia-southeast1';
const crypto = require('node:crypto');
const key = parts => crypto.createHash('sha256').update(JSON.stringify(parts)).digest('hex');
async function* pages(query) {
  let cursor;
  for (;;) {
    let page = query.orderBy(FieldPath.documentId()).limit(200);
    if (cursor) page = page.startAfter(cursor);
    const result = await page.get();
    if (result.empty) return;
    for (const doc of result.docs) yield doc;
    cursor = result.docs.at(-1);
    if (result.size < 200) return;
  }
}
async function notify(uid,id,data) {
  if (!uid) return;
  const ref = db.collection('users').doc(uid).collection('notifications').doc(id);
  try { await ref.create({...data,read:false,createdAt:FieldValue.serverTimestamp()}); }
  catch (error) { if (error.code === 6 || error.code === 'already-exists') return; throw error; }
}
exports.itemAlerts = onDocumentCreated({document:'items/{itemId}',region,retry:true}, async event => {
  const item = event.data?.data(); if (!item || item.status !== 'open') return;
  const itemId = event.params.itemId;
  const opposite = item.type === 'lost' ? 'found' : 'lost';
  // Paginate instead of loading the entire campus feed into memory.
  for await (const doc of pages(db.collection('items').where('type','==',opposite).where('status','==','open'))) {
    const other = doc.data();
    if (matchScore(item,other) < 65) continue;
    await notify(other.ownerId,key(['match',doc.id,itemId]),{type:'match',title:'A possible match was reported',body:'A new campus report resembles your item. Open it and compare the details.',itemId});
    await notify(item.ownerId,key(['match',itemId,doc.id]),{type:'match',title:'A possible match is waiting',body:'A campus report resembles your item. Compare the details before making a claim.',itemId:doc.id});
  }
  for await (const doc of pages(db.collectionGroup('savedSearches'))) {
    const uid = doc.ref.parent.parent.id;
    if (uid !== item.ownerId && matchesSearch(doc.data(),item)) await notify(uid,key(['saved',doc.id,itemId]),{type:'saved_search',title:'A saved search has a new result',body:'A new campus report matches your saved search.',itemId});
  }
});
exports.claimCreated = onDocumentCreated({document:'claims/{claimId}',region,retry:true}, async event => {
  const claim = event.data?.data(); if (!claim) return;
  await notify(claim.ownerId,key(['claim',event.params.claimId]),{type:'claim',title:'A new claim needs review',body:'Open your report to review the ownership proof privately.',itemId:claim.itemId,claimId:event.params.claimId});
});
exports.claimUpdated = onDocumentUpdated({document:'claims/{claimId}',region,retry:true}, async event => {
  const before = event.data?.before.data(); const claim = event.data?.after.data();
  if (!claim || before.status === claim.status) return;
  const text = {reviewing:'Your claim is under review.',approved:'Your claim is approved. Wait for pickup instructions.',ready:'Your item is ready for pickup. Coordinate a safe handover.',returned:'Your item was marked returned.',rejected:'The reporter could not confirm this claim.'}[claim.status];
  if (text) await notify(claim.claimantId,key(['stage',event.params.claimId,event.id]),{type:'claim_update',title:'Your claim has an update',body:text,itemId:claim.itemId,claimId:event.params.claimId});
});
exports.messageAlert = onDocumentCreated({document:'conversations/{claimId}/messages/{messageId}',region,retry:true}, async event => {
  const message = event.data?.data(); if (!message) return;
  const conversation = (await db.collection('conversations').doc(event.params.claimId).get()).data();
  if (!conversation) return;
  const recipient = message.senderId === conversation.ownerId ? conversation.claimantId : conversation.ownerId;
  await notify(recipient,key(['message',event.params.messageId]),{type:'message',title:'You have a private message',body:'Open your claim to continue the conversation.',itemId:conversation.itemId,claimId:event.params.claimId});
});
exports.pushAlert = onDocumentCreated({document:'users/{uid}/notifications/{id}',region,retry:true}, async event => {
  const data = event.data?.data(); if (!data) return;
  const devices = await db.collection('users').doc(event.params.uid).collection('devices').get();
  for (let offset=0;offset<devices.size;offset+=500) {
    const docs = devices.docs.slice(offset,offset+500);
    const result = await getMessaging().sendEachForMulticast({tokens:docs.map(doc=>doc.data().token),notification:{title:'FindIt BSU',body:'You have a campus lost-and-found update.'},data:{itemId:String(data.itemId || ''),notificationId:event.params.id}});
    for (let i=0;i<docs.length;i++) {
      const error = result.responses[i].error;
      if (error && ['messaging/registration-token-not-registered','messaging/invalid-registration-token'].includes(error.code)) await docs[i].ref.delete();
      else if (error) logger.warn('Notification delivery failed',{code:error.code});
    }
  }
});
exports.reportReminders = onSchedule({schedule:'every day 09:00',timeZone:'Asia/Manila',region,retryCount:3}, async () => {
  const now = Date.now();
  const week = Math.floor(now / (7*86400000));
  for await (const doc of pages(db.collection('items').where('status','==','open'))) {
    const item = doc.data(); if (item.archived) continue;
    const createdAt=timestampMillis(item.createdAt);
    if (!Number.isFinite(createdAt) || now - createdAt < 14*86400000) continue;
    await notify(item.ownerId,key(['reminder',doc.id,week]),{type:'reminder',title:'Is your report still open?',body:'Review your old report, update the details, or mark it returned if it has been recovered.',itemId:doc.id});
  }
});
exports.cleanDeletedReport = onDocumentDeleted({document:'items/{itemId}',region,retry:true}, async event => {
  const itemId = event.params.itemId;
  // Deleting a Firestore parent does not remove its private subcollections.
  await db.recursiveDelete(db.collection('items').doc(itemId));
  for await (const doc of pages(db.collection('claims').where('itemId','==',itemId))) {
    await db.recursiveDelete(db.collection('conversations').doc(doc.id));
    await doc.ref.delete();
  }
});
