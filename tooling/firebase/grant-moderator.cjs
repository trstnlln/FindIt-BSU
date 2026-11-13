// Run only by a project administrator with Application Default Credentials.
const fromFunctions=require('node:module').createRequire(require('node:path').resolve(__dirname,'../../functions/package.json'));
const {initializeApp}=fromFunctions('firebase-admin/app');
const {getAuth}=fromFunctions('firebase-admin/auth');
const [uid,projectId,action]=process.argv.slice(2);
if(!uid||!projectId||!['grant','revoke'].includes(action)) throw Error('Usage: node grant-moderator.cjs UID PROJECT_ID grant|revoke');
initializeApp({projectId});
(async()=>{
 const auth=getAuth();const user=await auth.getUser(uid);
 if(action==='grant'&&(!user.emailVerified||(!user.email?.endsWith('@g.batstate-u.edu.ph') && user.customClaims?.staff !== true))) throw Error('Moderator must have a verified university or approved staff account.');
 await auth.setCustomUserClaims(uid,{...user.customClaims,moderator:action==='grant'});
 console.log('Moderator permission updated. The user must sign out and sign back in.');
})().catch(error=>{console.error(error.message);process.exit(1)});
