// INTEGRATION POINT 2: Authentication Helpers (Government Portal & Survivor QR Auth)
import { getAuth, signInWithEmailAndPassword, signInWithCustomToken, signOut, User } from 'firebase/auth';
import { app } from './config';

export const auth = getAuth(app);

/**
 * Sign in for Government Portal Responders (Email & Password)
 */
export async function loginResponder(email: string, pass: string): Promise<User> {
  // INTEGRATION POINT: Connects to Firebase Auth backend
  const userCredential = await signInWithEmailAndPassword(auth, email, pass);
  return userCredential.user;
}

/**
 * Sign in for Survivor App using custom token minted by exchangeQrToken Cloud Function
 */
export async function loginSurvivorWithCustomToken(customToken: string): Promise<User> {
  // INTEGRATION POINT: Mints session from QR code token exchange
  const userCredential = await signInWithCustomToken(auth, customToken);
  return userCredential.user;
}

/**
 * Logout session for either shell
 */
export async function logoutSession(): Promise<void> {
  await signOut(auth);
}

