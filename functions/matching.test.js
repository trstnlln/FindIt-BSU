const {test} = require('node:test');
const assert = require('node:assert/strict');
const {matchScore,matchesSearch,timestampMillis} = require('./matching');
const lost={ownerId:'a',type:'lost',status:'open',title:'Black Casio calculator',description:'Scientific fx991 calculator',category:'Electronics',location:'Library',date:1000000};
const found={...lost,ownerId:'b',type:'found'};
test('matching scores opposite reports by category, location, date and keywords',()=>assert.equal(matchScore(lost,found),100));
test('own, same-type and closed reports never produce match alerts',()=>{assert.equal(matchScore(lost,lost),0);assert.equal(matchScore(lost,{...found,ownerId:'a'}),0);assert.equal(matchScore(lost,{...found,status:'returned'}),0);});
test('unrelated old reports are not a match',()=>assert.equal(matchScore(lost,{...found,title:'Red jacket',description:'Cotton coat',category:'Clothing',location:'Gymnasium',date:1000000+30*86400000}),0));
test('saved searches require every keyword plus selected filters',()=>{assert.ok(matchesSearch({query:'casio calculator',category:'Electronics',location:'Library'},found));assert.ok(!matchesSearch({query:'casio wallet'},found));assert.ok(!matchesSearch({query:'',category:'Clothing'},found));assert.ok(!matchesSearch({},found));});
test('saved searches do not alert on closed reports',()=>assert.ok(!matchesSearch({query:'calculator'},{...found,status:'returned'})));

test('dates support legacy Firestore timestamps without treating missing dates as today',()=>{assert.equal(timestampMillis({toMillis:()=>123}),123);assert.ok(Number.isNaN(timestampMillis(null)));assert.equal(timestampMillis('2026-01-01T00:00:00.000Z'),Date.UTC(2026,0,1));assert.equal(matchScore({...lost,date:null},{...found,date:null}),80);});

test('archived reports do not produce matches or search alerts',()=>{assert.equal(matchScore(lost,{...found,archived:true}),0);assert.ok(!matchesSearch({query:'calculator'},{...found,archived:true}));});
