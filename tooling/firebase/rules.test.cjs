const { test, before, after, beforeEach } = require('node:test');
const fs = require('node:fs');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, setDoc, getDoc, updateDoc, writeBatch, collection, query, where, getDocs, runTransaction, serverTimestamp } = require('firebase/firestore');
let env;
const email = uid => `${uid}@g.batstate-u.edu.ph`;
const db = uid => env.authenticatedContext(uid, { email: email(uid), email_verified: true }).firestore();
const item = { ownerId: 'finder', type: 'found', status: 'open', title: 'Wallet', description: 'Brown wallet found in library', date:Date.now(), createdAt:Date.now() };
const claim = { itemId: 'wallet', ownerId: 'finder', claimantId: 'student', claimantEmail: email('student'), status: 'pending', proof: 'Red lining',itemTitle:'Wallet',claimantName:'Student',message:'I lost this wallet.',verificationAnswers:[],createdAt:Date.now() };
before(async () => {
  env = await initializeTestEnvironment({ projectId: 'demo-finditbsu', firestore: { host: '127.0.0.1', port: 8085, rules: fs.readFileSync('../../firestore.rules', 'utf8') } });
});
after(async () => { if (env) await env.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async ctx => {
    await setDoc(doc(ctx.firestore(), 'items/wallet'), item);
    await setDoc(doc(ctx.firestore(), 'claims/claim'), claim);
  });
});
test('report and private answers commit atomically; only finder reads answers', async () => {
  const finder = db('finder'); const batch = writeBatch(finder);
  batch.set(doc(finder, 'items/new'), item);
  batch.set(doc(finder, 'items/new/verification/questions'), { questions: ['Contents?'] });
  batch.set(doc(finder, 'items/new/private/details'), { answers: ['Two cards'] });
  await assertSucceeds(batch.commit());
  await assertSucceeds(getDoc(doc(finder, 'items/new/private/details')));
  await assertSucceeds(getDoc(doc(db('student'), 'items/new/verification/questions')));
  await assertFails(getDoc(doc(db('student'), 'items/new/private/details')));
  await assertFails(setDoc(doc(db('student'), 'items/new/private/details'), { answers: ['Overwrite'] }));
});
test('anonymous and non-campus users cannot submit reports', async () => {
  await assertFails(setDoc(doc(env.unauthenticatedContext().firestore(), 'items/new'), item));
  const outsider = env.authenticatedContext('finder', { email: 'finder@gmail.com' }).firestore();
  await assertFails(setDoc(doc(outsider, 'items/new'), item));
});
test('claimant cannot approve a claim, forge an owner, or claim their own item', async () => {
  await assertFails(updateDoc(doc(db('student'), 'claims/claim'), { status: 'approved' }));
  await assertFails(setDoc(doc(db('student'), 'claims/forged'), { ...claim, ownerId: 'someone-else' }));
  await assertFails(setDoc(doc(db('finder'), 'claims/self'), { ...claim, claimantId: 'finder', claimantEmail: email('finder') }));
});
test('reporter can approve but cannot replace claimant identity or proof', async () => {
  await assertFails(updateDoc(doc(db('finder'), 'claims/claim'), { claimantId: 'other' }));
  await assertFails(updateDoc(doc(db('finder'), 'claims/claim'), { proof: 'Different' }));
  const finder = db('finder');
  await assertFails(updateDoc(doc(finder, 'claims/claim'), { status: 'approved', updatedAt: Date.now() }));
  const batch = writeBatch(finder);
  batch.update(doc(finder, 'claims/claim'), { status: 'approved', updatedAt: Date.now() });
  batch.update(doc(finder, 'items/wallet'), { status: 'claimed' });
  await assertSucceeds(batch.commit());
  await assertFails(updateDoc(doc(db('finder'), 'claims/claim'), { status: 'rejected' }));
});
test('claim lists are scoped to participants', async () => {
  await assertSucceeds(getDocs(query(collection(db('student'), 'claims'), where('claimantId', '==', 'student'))));
  await assertSucceeds(getDocs(query(collection(db('finder'), 'claims'), where('ownerId', '==', 'finder'))));
  await assertFails(getDocs(collection(db('other'), 'claims')));
});
test('a deterministic claim can be read and created in one transaction', async () => {
  const student = db('student');
  await assertSucceeds(runTransaction(student, async tx => {
    await tx.get(doc(student, 'items/wallet'));
    await tx.get(doc(student, 'claims/new-student-claim'));
    tx.set(doc(student, 'claims/new-student-claim'), claim);
  }));
  await assertFails(setDoc(doc(student, 'claims/new-student-claim'), { ...claim, proof: 'Changed' }));
});
test('closed items reject claims and owners cannot transfer a report', async () => {
  await assertFails(updateDoc(doc(db('finder'), 'items/wallet'), { ownerId: 'student' }));
  await assertSucceeds(updateDoc(doc(db('finder'), 'items/wallet'), { status: 'returned' }));
  await assertFails(setDoc(doc(db('student'), 'claims/new'), claim));
});
test('user profiles match the authenticated campus identity', async () => {
  await assertSucceeds(setDoc(doc(db('student'), 'users/student'), { email: email('student'), role: 'student', name: 'Student' }));
  await assertFails(updateDoc(doc(db('student'), 'users/student'), { email: email('finder') }));
  await assertFails(setDoc(doc(db('student'), 'users/finder'), { email: email('student'), role: 'staff' }));
});

test('two claims cannot be approved for the same item', async () => {
  await env.withSecurityRulesDisabled(async ctx => {
    await setDoc(doc(ctx.firestore(), 'claims/second'), { ...claim, claimantId: 'other', claimantEmail: email('other') });
  });
  const finder = db('finder');
  const batch = writeBatch(finder);
  batch.update(doc(finder, 'items/wallet'), { status: 'claimed' });
  batch.update(doc(finder, 'claims/claim'), { status: 'approved', updatedAt: 1 });
  await assertSucceeds(batch.commit());
  await assertFails(updateDoc(doc(finder, 'claims/second'), { status: 'approved', updatedAt: 2 }));
});

test('unverified university accounts can create profiles but cannot browse or post', async () => {
  const unverified = env.authenticatedContext('new', {email: email('new'), email_verified:false}).firestore();
  await assertSucceeds(setDoc(doc(unverified,'users/new'),{email:email('new'),role:'student',name:'New student'}));
  await assertFails(getDoc(doc(unverified,'items/wallet')));
  await assertFails(setDoc(doc(unverified,'items/new'),{...item,ownerId:'new'}));
});
test('claim journey advances through review, approval, pickup and return', async () => {
  const finder = db('finder');
  await assertSucceeds(updateDoc(doc(finder,'claims/claim'),{status:'reviewing',updatedAt:1}));
  await assertFails(updateDoc(doc(finder,'claims/claim'),{status:'ready',updatedAt:2}));
  const approve = writeBatch(finder);
  approve.update(doc(finder,'items/wallet'),{status:'claimed'});
  approve.update(doc(finder,'claims/claim'),{status:'approved',updatedAt:3});
  await assertSucceeds(approve.commit());
  await assertSucceeds(updateDoc(doc(finder,'claims/claim'),{status:'ready',updatedAt:4}));
  await assertFails(updateDoc(doc(finder,'claims/claim'),{status:'returned',updatedAt:5}));
  const returned = writeBatch(finder);
  returned.update(doc(finder,'items/wallet'),{status:'returned'});
  returned.update(doc(finder,'claims/claim'),{status:'returned',updatedAt:6});
  await assertSucceeds(returned.commit());
});
test('private conversations exclude outsiders and prevent forged senders', async () => {
  const student = db('student');
  await assertSucceeds(runTransaction(student,async tx => {
    const ref = doc(student,'conversations/claim'); await tx.get(ref);
    tx.set(ref,{ownerId:'finder',claimantId:'student',itemId:'wallet',itemTitle:'Wallet',createdAt:serverTimestamp()});
  }));
  await assertSucceeds(setDoc(doc(student,'conversations/claim/messages/one'),{senderId:'student',text:'Can we meet at the campus office?',sentAt:serverTimestamp()}));
  await assertSucceeds(getDoc(doc(db('finder'),'conversations/claim/messages/one')));
  await assertFails(getDoc(doc(db('other'),'conversations/claim/messages/one')));
  await assertFails(setDoc(doc(student,'conversations/claim/messages/forged'),{senderId:'finder',text:'Forged message',sentAt:serverTimestamp()}));
  await assertFails(updateDoc(doc(student,'conversations/claim'),{claimantId:'other'}));
});
test('saved searches and notification history belong to one verified user', async () => {
  const student = db('student');
  await assertSucceeds(setDoc(doc(student,'users/student/savedSearches/calculator'),{query:'calculator',category:'Electronics',location:null,createdAt:serverTimestamp()}));
  await assertFails(getDoc(doc(db('other'),'users/student/savedSearches/calculator')));
  await assertFails(setDoc(doc(student,'users/student/notifications/fake'),{title:'Forged notification',read:false}));
  await env.withSecurityRulesDisabled(async ctx => setDoc(doc(ctx.firestore(),'users/student/notifications/real'),{title:'Claim update',read:false}));
  await assertSucceeds(updateDoc(doc(student,'users/student/notifications/real'),{read:true}));
  await assertFails(updateDoc(doc(student,'users/student/notifications/real'),{title:'Changed'}));
});
test('self-selected staff role grants no moderator access', async () => {
  const student = db('student');
  await setDoc(doc(student,'users/student'),{name:'Student',email:email('student'),role:'staff'});
  await assertSucceeds(setDoc(doc(student,'abuseReports/concern'),{reporterId:'student',itemId:'wallet',reason:'Spam',details:'Repeated fake reports',status:'open',createdAt:serverTimestamp()}));
  await assertFails(getDoc(doc(student,'abuseReports/concern')));
  await assertFails(updateDoc(doc(student,'abuseReports/concern'),{status:'resolved'}));
  const moderator = env.authenticatedContext('moderator',{email:email('moderator'),email_verified:true,moderator:true}).firestore();
  await assertSucceeds(getDoc(doc(moderator,'abuseReports/concern')));
  await assertSucceeds(updateDoc(doc(moderator,'abuseReports/concern'),{status:'resolved'}));
  await assertSucceeds(setDoc(doc(moderator,'campusOffices/library'),{name:'Library Front Desk',hours:'Published by the campus',instructions:'Bring your ID.'}));
  await assertFails(setDoc(doc(student,'campusOffices/forged'),{name:'Fake office'}));
});

test('malformed claims cannot inject invalid ownership-answer types', async () => {
  await assertFails(setDoc(doc(db('student'),'claims/malformed'),{...claim,verificationAnswers:[{bad:'value'}]}));
  await assertFails(setDoc(doc(db('student'),'claims/oversized'),{...claim,proof:'x'.repeat(2001)}));
});

test('unbounded report dates cannot poison the campus feed', async () => {
  await assertFails(setDoc(doc(db('finder'),'items/overflow'),{...item,date:9007199254740991}));
  await assertFails(setDoc(doc(db('finder'),'items/negative'),{...item,createdAt:-1}));
});
