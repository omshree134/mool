import React, { createContext, useContext, useState, useEffect } from 'react';
import { 
  createUserWithEmailAndPassword, 
  signInWithEmailAndPassword, 
  signOut,
  onAuthStateChanged,
  GoogleAuthProvider,
  signInWithPopup,
  User 
} from 'firebase/auth';
import { doc, getDoc, setDoc, serverTimestamp } from 'firebase/firestore';
import { auth } from '../lib/firebase/auth';
import { db } from '../lib/firebase/firestore';

export interface GuardianProfile {
  id: string;
  name: string;
  email: string;
  role: string;
  organization?: string;
  phone?: string;
  pairingCode: string;
  createdAt?: string;
}

interface RegisterGuardianInput {
  name: string;
  email: string;
  password: string;
  role: string;
  organization?: string;
  phone?: string;
}

interface GuardianAuthContextType {
  guardian: GuardianProfile | null;
  loading: boolean;
  error: string | null;
  registerGuardian: (input: RegisterGuardianInput) => Promise<void>;
  loginGuardian: (email: string, pass: string) => Promise<void>;
  loginWithGoogle: () => Promise<void>;
  loginDemoGuardian: (preset?: 'singh' | 'jenkins') => void;
  logoutGuardian: () => Promise<void>;
  clearError: () => void;
}

const GuardianAuthContext = createContext<GuardianAuthContextType | undefined>(undefined);

const LOCAL_STORAGE_KEY = 'mool_active_guardian';

// Helper to generate an 8-char human readable pairing code e.g. "GRD-7821"
function generatePairingCode(): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let randomPart = '';
  for (let i = 0; i < 4; i++) {
    randomPart += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return `GRD-${randomPart}`;
}

export const GuardianAuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [guardian, setGuardian] = useState<GuardianProfile | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Initialize from localStorage or Firebase Auth on mount
  useEffect(() => {
    // 1. Try reading cached session first for instant UI response
    const cached = localStorage.getItem(LOCAL_STORAGE_KEY);
    if (cached) {
      try {
        const parsed = JSON.parse(cached);
        if (parsed && parsed.id && parsed.pairingCode) {
          setGuardian(parsed);
        }
      } catch (e) {
        console.warn('Failed to parse cached guardian:', e);
      }
    }

    // 2. Listen to Firebase Auth state
    const unsubscribe = onAuthStateChanged(auth, async (user: User | null) => {
      if (user) {
        try {
          // Check Firestore guardians collection
          const docRef = doc(db, 'guardians', user.uid);
          const snap = await getDoc(docRef);
          if (snap.exists()) {
            const data = snap.data();
            const profile: GuardianProfile = {
              id: user.uid,
              name: data.name || user.displayName || 'Guardian',
              email: user.email || data.email || '',
              role: data.role === 'Authorized Support Guardian' ? 'Guardian' : (data.role || 'Guardian'),
              organization: data.organization || '',
              phone: data.phone || '',
              pairingCode: data.pairingCode || generatePairingCode(),
              createdAt: data.createdAt?.toDate?.()?.toISOString?.() || new Date().toISOString(),
            };
            setGuardian(profile);
            localStorage.setItem(LOCAL_STORAGE_KEY, JSON.stringify(profile));
          } else {
            const pairingCode = generatePairingCode();
            const profile: GuardianProfile = {
              id: user.uid,
              name: user.displayName || user.email?.split('@')[0] || 'Guardian',
              email: user.email || '',
              role: 'Guardian',
              pairingCode,
              createdAt: new Date().toISOString(),
            };
            setGuardian(profile);
            localStorage.setItem(LOCAL_STORAGE_KEY, JSON.stringify(profile));
            saveGuardianToFirestore(profile);
          }
        } catch (err) {
          console.warn('Error fetching guardian from Firestore:', err);
        }
      }
      setLoading(false);
    });

    return () => unsubscribe();
  }, []);

  const saveGuardianToFirestore = async (profile: GuardianProfile) => {
    try {
      // Save in guardians/{id}
      await setDoc(doc(db, 'guardians', profile.id), {
        id: profile.id,
        name: profile.name,
        email: profile.email,
        role: profile.role,
        organization: profile.organization || '',
        phone: profile.phone || '',
        pairingCode: profile.pairingCode,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }, { merge: true });

      // Save in pairingCodes/{pairingCode} for fast mobile resolution
      await setDoc(doc(db, 'pairingCodes', profile.pairingCode.toUpperCase()), {
        code: profile.pairingCode.toUpperCase(),
        guardianId: profile.id,
        guardianName: profile.name,
        createdAt: serverTimestamp(),
      }, { merge: true });
    } catch (e) {
      console.warn('Firestore write warning (offline or permissions):', e);
    }
  };

  const registerGuardian = async (input: RegisterGuardianInput) => {
    setLoading(true);
    setError(null);
    try {
      const pairingCode = generatePairingCode();
      let uid = `grd_${Date.now()}`;

      try {
        const cred = await createUserWithEmailAndPassword(auth, input.email.trim(), input.password);
        uid = cred.user.uid;
      } catch (authErr: any) {
        if (authErr?.code === 'auth/email-already-in-use') {
          throw new Error('An account with this email already exists. Please sign in instead.');
        }
        console.warn('Firebase Auth fallback used:', authErr);
      }

      const profile: GuardianProfile = {
        id: uid,
        name: input.name.trim(),
        email: input.email.trim(),
        role: input.role,
        organization: input.organization?.trim(),
        phone: input.phone?.trim(),
        pairingCode,
        createdAt: new Date().toISOString(),
      };

      await saveGuardianToFirestore(profile);
      setGuardian(profile);
      localStorage.setItem(LOCAL_STORAGE_KEY, JSON.stringify(profile));
    } catch (err: any) {
      const msg = err?.message || 'Registration failed. Please check your details.';
      setError(msg);
      throw err;
    } finally {
      setLoading(false);
    }
  };

  const loginGuardian = async (email: string, pass: string) => {
    setLoading(true);
    setError(null);
    try {
      let uid = '';
      try {
        const cred = await signInWithEmailAndPassword(auth, email.trim(), pass);
        uid = cred.user.uid;
      } catch (authErr: any) {
        console.warn('Firebase Auth sign-in failed, trying Firestore/local fallback:', authErr);
        if (authErr?.code === 'auth/invalid-credential' || authErr?.code === 'auth/wrong-password') {
          throw new Error('Invalid email or password. Please try again or create a new account.');
        }
        if (authErr?.code === 'auth/user-not-found') {
          throw new Error('No guardian found with this email. Please register first.');
        }
        throw authErr;
      }

      // Fetch profile from Firestore
      const docRef = doc(db, 'guardians', uid);
      const snap = await getDoc(docRef);
      if (snap.exists()) {
        const data = snap.data();
        const profile: GuardianProfile = {
          id: uid,
          name: data.name || 'Guardian',
          email: data.email || email,
          role: data.role === 'Authorized Support Guardian' ? 'Guardian' : (data.role || 'Guardian'),
          organization: data.organization || '',
          phone: data.phone || '',
          pairingCode: data.pairingCode || generatePairingCode(),
          createdAt: data.createdAt?.toDate?.()?.toISOString?.() || new Date().toISOString(),
        };
        setGuardian(profile);
        localStorage.setItem(LOCAL_STORAGE_KEY, JSON.stringify(profile));
      } else {
        const pairingCode = generatePairingCode();
        const profile: GuardianProfile = {
          id: uid,
          name: email.split('@')[0],
          email,
          role: 'Guardian',
          pairingCode,
          createdAt: new Date().toISOString(),
        };
        await saveGuardianToFirestore(profile);
        setGuardian(profile);
        localStorage.setItem(LOCAL_STORAGE_KEY, JSON.stringify(profile));
      }
    } catch (err: any) {
      const msg = err?.message || 'Sign in failed. Please check your credentials.';
      setError(msg);
      throw err;
    } finally {
      setLoading(false);
    }
  };

  const loginWithGoogle = async () => {
    setLoading(true);
    setError(null);
    try {
      const provider = new GoogleAuthProvider();
      provider.setCustomParameters({ prompt: 'select_account' });
      const res = await signInWithPopup(auth, provider);
      const user = res.user;

      // Check if this guardian already has a registered profile in Firestore
      const docRef = doc(db, 'guardians', user.uid);
      const snap = await getDoc(docRef);
      if (snap.exists()) {
        const data = snap.data();
        const profile: GuardianProfile = {
          id: user.uid,
          name: data.name || user.displayName || 'Guardian',
          email: user.email || data.email || '',
          role: data.role === 'Authorized Support Guardian' ? 'Guardian' : (data.role || 'Guardian'),
          organization: data.organization || '',
          phone: data.phone || '',
          pairingCode: data.pairingCode || generatePairingCode(),
          createdAt: data.createdAt?.toDate?.()?.toISOString?.() || new Date().toISOString(),
        };
        setGuardian(profile);
        localStorage.setItem(LOCAL_STORAGE_KEY, JSON.stringify(profile));
      } else {
        // Register brand new Guardian via Google
        const pairingCode = generatePairingCode();
        const profile: GuardianProfile = {
          id: user.uid,
          name: user.displayName || 'Guardian',
          email: user.email || '',
          role: 'Guardian',
          pairingCode,
          createdAt: new Date().toISOString(),
        };
        await saveGuardianToFirestore(profile);
        setGuardian(profile);
        localStorage.setItem(LOCAL_STORAGE_KEY, JSON.stringify(profile));
      }
    } catch (err: any) {
      if (err?.code === 'auth/popup-closed-by-user') {
        // User voluntarily dismissed popup
        setLoading(false);
        return;
      }
      console.warn('Google sign-in error:', err);
      const msg = err?.message || 'Google sign-in failed. Please try again.';
      setError(msg);
      throw err;
    } finally {
      setLoading(false);
    }
  };

  const loginDemoGuardian = (preset: 'singh' | 'jenkins' = 'singh') => {
    const profile: GuardianProfile = preset === 'singh' ? {
      id: 'guardian_singh',
      name: 'Officer Rajesh Singh (Guardian)',
      email: 'rajesh.singh@protection.mool.gov.in',
      role: 'Official Ward Caseworker',
      organization: 'Department of Women & Child Safety',
      phone: '+91 98112 00412',
      pairingCode: 'GRD-8821',
      createdAt: new Date().toISOString(),
    } : {
      id: 'guardian_jenkins',
      name: 'Dr. Sarah Jenkins, Psy.D',
      email: 'dr.jenkins@traumarecovery.org',
      role: 'Clinical Counselor / Therapist',
      organization: 'Hope Trauma Recovery Clinic',
      phone: '+91 98765 43210',
      pairingCode: 'GRD-4920',
      createdAt: new Date().toISOString(),
    };

    setGuardian(profile);
    localStorage.setItem(LOCAL_STORAGE_KEY, JSON.stringify(profile));
    saveGuardianToFirestore(profile);
  };

  const logoutGuardian = async () => {
    try {
      await signOut(auth);
    } catch (_) {}
    setGuardian(null);
    localStorage.removeItem(LOCAL_STORAGE_KEY);
  };

  const clearError = () => setError(null);

  return (
    <GuardianAuthContext.Provider value={{
      guardian,
      loading,
      error,
      registerGuardian,
      loginGuardian,
      loginWithGoogle,
      loginDemoGuardian,
      logoutGuardian,
      clearError,
    }}>
      {children}
    </GuardianAuthContext.Provider>
  );
};

export const useGuardianAuth = () => {
  const context = useContext(GuardianAuthContext);
  if (!context) {
    throw new Error('useGuardianAuth must be used within a GuardianAuthProvider');
  }
  return context;
};
