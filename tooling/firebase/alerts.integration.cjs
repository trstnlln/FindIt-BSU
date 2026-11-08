const fromFunctions = require('node:module').createRequire(require('node:path').resolve(__dirname,'../../functions/package.json'));
const {initializeApp} = fromFunctions('firebase-admin/app');
const {getFirestore,FieldValue} = fromFunctions('firebase-admin/firestore');
const assert = require('node:assert/strict');
if (!process.env.FIRESTORE_EMULATOR_HOST || process.env.GCLOUD_PROJECT !== 'demo-finditbsu') throw Error('Run through the isolated demo emulators.');
const app=initializeApp({projectId:'demo-finditbsu'});const db=getFirestore(app);
async function waitFor(uid,predicate) {
 const deadline=Date.now()+30000;
 while(Date.now()<deadline) {
  const docs=(await db.collection('users').doc(uid).collection('notifications').get()).docs.map(d=>d.data());
  if(predicate(docs)) return docs;
  await new Promise(resolve=>setTimeout(resolve,200));
 }
 throw Error('Expected backend alert did not arrive for '+uid);
}
(async()=>{
 const stamp=Date.now();
 const item={title:'Black Casio calculator',description:'Scientific fx991 calculator',category:'Electronics',location:'Library',date:stamp,createdAt:stamp,status:'open'};
 await db.doc('users/observer/savedSearches/calculator').set({query:'casio calculator',category:null,location:null,createdAt:FieldValue.serverTimestamp()});
 await db.doc('items/alerts-lost').set({...item,type:'lost',ownerId:'student'});
 await db.doc('items/alerts-found').set({...item,type:'found',ownerId:'finder'});
 await waitFor('student',docs=>docs.some(d=>d.type==='match'&&d.itemId==='alerts-found'));
 await waitFor('observer',docs=>docs.some(d=>d.type==='saved_search'));
 const claim={ownerId:'finder',claimantId:'student',itemId:'alerts-found',itemTitle:item.title,status:'pending'};
 await db.doc('claims/alerts-claim').set(claim);
 await waitFor('finder',docs=>docs.some(d=>d.type==='claim'));
 await db.doc('claims/alerts-claim').update({status:'reviewing'});
 await waitFor('student',docs=>docs.some(d=>d.type==='claim_update'));
 await db.doc('conversations/alerts-claim').set(claim);
 await db.doc('conversations/alerts-claim/messages/hello').set({senderId:'student',text:'Can we arrange pickup?',sentAt:FieldValue.serverTimestamp()});
 await waitFor('finder',docs=>docs.some(d=>d.type==='message'));
 // Invoke the scheduled handler against the emulator, including retry deduplication.
 await db.doc('items/old-report').set({...item,type:'lost',ownerId:'old-student',createdAt:stamp-15*86400000});
 const backend=require('../../functions');
 await backend.reportReminders.run({scheduleTime:new Date().toISOString(),jobName:'local-test'});
 await backend.reportReminders.run({scheduleTime:new Date().toISOString(),jobName:'local-retry-test'});
 const reminders=await waitFor('old-student',docs=>docs.some(d=>d.type==='reminder'));
 assert.equal(reminders.filter(d=>d.type==='reminder').length,1);
 // Parent deletion must clean up private proof and conversations, not orphan them.
 await db.doc('items/alerts-found/private/details').set({answers:['private']});
 await db.doc('items/alerts-found').delete();
 const deadline=Date.now()+15000;
 while(Date.now()<deadline && (await db.doc('claims/alerts-claim').get()).exists) await new Promise(resolve=>setTimeout(resolve,200));
 assert.equal((await db.doc('claims/alerts-claim').get()).exists,false);
 assert.equal((await db.doc('items/alerts-found/private/details').get()).exists,false);
 assert.equal((await db.doc('conversations/alerts-claim/messages/hello').get()).exists,false);
 const all=await db.doc('users/student').collection('notifications').get();
 assert.ok(all.docs.every(d=>d.data().read===false));
 console.log('PASS: real Firestore triggers deliver match, saved-search, incoming-claim, stage-update and private-message alerts; scheduled reminders deduplicate retries; report deletion removes private details and conversations.');
 await db.terminate();
})().catch(error=>{console.error(error);process.exit(1)});
