import { initializeApp, getApps, getApp } from "firebase/app";
import { getDatabase, ref, onValue, set, remove, push, get } from "firebase/database";

const firebaseConfig = {
  apiKey: "AIzaSyAalk10jjDFPeRkFxClA5frKH3Yya2nnWg",
  authDomain: "tuition2025-d4e25.firebaseapp.com",
  databaseURL: "https://tuition2025-d4e25-default-rtdb.asia-southeast1.firebasedatabase.app",
  projectId: "tuition2025-d4e25",
  storageBucket: "tuition2025-d4e25.firebasestorage.app",
  messagingSenderId: "1030301766778",
  appId: "1:1030301766778:web:tuition2025"
};

const app = !getApps().length ? initializeApp(firebaseConfig) : getApp();
const db = getDatabase(app);

export { app, db, ref, onValue, set, remove, push, get };

