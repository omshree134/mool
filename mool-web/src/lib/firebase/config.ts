// INTEGRATION POINT 1: Firebase Configuration
// Replace the placeholder credentials below or configure environment variables in .env.local

import { initializeApp, getApps, getApp } from 'firebase/app';

const firebaseConfig = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY || "AIzaSyPlaceholderKeyForMoolPlatform",
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN || "mool-origin-platform.firebaseapp.com",
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID || "mool-origin-platform",
  storageBucket: import.meta.env.VITE_FIREBASE_STORAGE_BUCKET || "mool-origin-platform.appspot.com",
  messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID || "123456789012",
  appId: import.meta.env.VITE_FIREBASE_APP_ID || "1:123456789012:web:abcdef1234567890",
};

// Initialize Firebase App (Singleton pattern)
export const app = getApps().length > 0 ? getApp() : initializeApp(firebaseConfig);

