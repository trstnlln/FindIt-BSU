/* Background notification worker; Firebase app identifiers are public config. */
importScripts('https://www.gstatic.com/firebasejs/11.9.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/11.9.1/firebase-messaging-compat.js');
firebase.initializeApp({"apiKey": "AIzaSyDTswVYfHAnBXSxoL1Ws8mWiIClzIhrAgc", "appId": "1:481065112485:web:58b8fde67b8d90748f0e4c", "messagingSenderId": "481065112485", "projectId": "finditbsu", "authDomain": "finditbsu.firebaseapp.com", "storageBucket": "finditbsu.firebasestorage.app"});
firebase.messaging();
