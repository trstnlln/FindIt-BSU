const { test, before, after, beforeEach } = require('node:test');
const fs = require('node:fs');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, setDoc, getDoc, updateDoc, writeBatch, collection, query, where, getDocs, runTransaction } = require('firebase/firestore');
let env;
const email = uid => `${uid}@g.batstate-u.edu.ph`;
const db = uid => env.authenticatedContext(uid, { email: email(uid) }).firestore();
const item = { ownerId: 'finder', type: 'found', status: 'open', title: 'Wallet' };
const claim = { itemId: 'wallet', ownerId: 'finder', claimantId: 'student', claimantEmail: email('student'), status: 'pending', proof: 'Red lining' };
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
