// A project administrator approves staff identity; a chosen profile role grants no access.
const fromFunctions=require('node:module').createRequire(require('node:path').resolve(__dirname,'../../functions/package.json'));
const {initializeApp}=fromFunctions('firebase-admin/app');
const {getAuth}=fromFunctions('firebase-admin/auth');
const {getFirestore}=fromFunctions('firebase-admin/firestore');
const [email,projectId,action]=process.argv.slice(2);
if(!email||!projectId||!['grant','revoke'].includes(action)||!/^\S+@[^@\s]+\.[^@\s]+$/.test(email))throw Error('Usage: node grant-staff.cjs EMAIL PROJECT_ID grant|revoke');
initializeApp({projectId});
(async()=>{
 const auth=getAuth();let user;
 try{user=await auth.getUserByEmail(email);}catch(error){if(error.code!=='auth/user-not-found'||action!=='grant')throw error;user=await auth.createUser({email});}
 await auth.setCustomUserClaims(user.uid,{...user.customClaims,staff:action==='grant'});
 if(action==='grant'){
  const ref=getFirestore().doc(`users/${user.uid}`);if((await ref.get()).exists)await ref.update({role:'staff'});
 }else{await auth.revokeRefreshTokens(user.uid);}

 console.log(`Staff access ${action==='grant'?'approved':'revoked'}. No email verification was bypassed. The staff member must sign in again; for email/password, use Forgot password to set a password.`);
})().catch(error=>{console.error(error.message);process.exit(1)});
