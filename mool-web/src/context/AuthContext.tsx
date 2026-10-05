import React, { createContext, useContext, useState, useEffect } from 'react';
import { collection, onSnapshot, doc, setDoc, serverTimestamp } from 'firebase/firestore';
import { db } from '../lib/firebase/firestore';
import { UserRole } from '../types';

export interface StaffMember {
  id: string;
  name: string;
  email: string;
  role: 'admin' | 'analyst' | 'caseworker';
  department: string;
  createdAt: string;
  status: 'active' | 'suspended';
}

const INITIAL_STAFF: StaffMember[] = [
  {
    id: 'staff-admin-01',
    name: 'Officer Rajesh Singh',
    email: 'rajesh.singh@mool.gov.in',
    role: 'admin',
    department: 'Central Protection Operations',
    createdAt: '2026-08-01',
    status: 'active',
  },
  {
    id: 'staff-analyst-01',
    name: 'Dr. Neha Verma',
    email: 'neha.verma@mool.gov.in',
    role: 'analyst',
    department: 'Ministry of Health & Mental Health Analytics',
    createdAt: '2026-08-15',
    status: 'active',
  },
  {
    id: 'staff-case-01',
    name: 'Ananya Sharma',
    email: 'ananya.sharma@counseling.org',
    role: 'caseworker',
    department: 'District Trauma First Response',
    createdAt: '2026-08-20',
    status: 'active',
  },
];

interface CreateStaffInput {
  name: string;
  email: string;
  role: 'admin' | 'analyst' | 'caseworker';
  department: string;
}

interface AuthContextType {
  role: UserRole | null;
  userId: string | null;
  userName: string | null;
  userEmail: string | null;
  isAuthenticated: boolean;
  staffList: StaffMember[];
  loginAsSurvivor: (beneficiaryId: string, pseudonym?: string) => void;
  loginAsResponder: (role: 'caseworker' | 'analyst' | 'admin', name: string, email?: string) => void;
  createStaffAccount: (input: CreateStaffInput) => Promise<void>;
  logout: () => void;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  // Active session
  const [role, setRole] = useState<UserRole | null>('caseworker');
  const [userId, setUserId] = useState<string | null>('resp-singh');
  const [userName, setUserName] = useState<string | null>('Officer Rajesh Singh');
  const [userEmail, setUserEmail] = useState<string | null>('rajesh.singh@mool.gov.in');
  const [staffList, setStaffList] = useState<StaffMember[]>(INITIAL_STAFF);

  // Firestore sync for staff roster
  useEffect(() => {
    try {
      const staffRef = collection(db, 'staff');
      const unsubscribe = onSnapshot(staffRef, (snapshot) => {
        if (!snapshot.empty) {
          const live: StaffMember[] = [];
          snapshot.forEach((docSnap) => {
            const data = docSnap.data();
            live.push({
              id: docSnap.id,
              name: data.name || 'Staff Member',
              email: data.email || '',
              role: data.role || 'caseworker',
              department: data.department || 'General Operations',
              createdAt: data.createdAt?.toDate?.()?.toISOString?.()?.split('T')[0] || data.createdAt || new Date().toISOString().split('T')[0],
              status: data.status || 'active',
            });
          });
          setStaffList(live);
        }
      }, (err) => {
        console.warn('Staff listener fallback to initial list:', err);
      });

      return () => unsubscribe();
    } catch (e) {
      console.warn('Firestore staff sync error:', e);
    }
  }, []);

  const loginAsSurvivor = (beneficiaryId: string, pseudonym?: string) => {
    setRole('survivor');
    setUserId(beneficiaryId);
    setUserName(pseudonym || 'Paired Beneficiary');
    setUserEmail(null);
  };

  const loginAsResponder = (newRole: 'caseworker' | 'analyst' | 'admin', name: string, email?: string) => {
    setRole(newRole);
    setUserId(`resp-${Math.floor(Math.random() * 1000)}`);
    setUserName(name);
    setUserEmail(email || `${name.toLowerCase().replace(/\s+/g, '.')}@mool.gov.in`);
  };

  const createStaffAccount = async (input: CreateStaffInput) => {
    const newId = `staff-${input.role}-${Date.now().toString().slice(-4)}`;
    const newStaff: StaffMember = {
      id: newId,
      name: input.name.trim(),
      email: input.email.trim(),
      role: input.role,
      department: input.department.trim() || 'Operations & Oversight',
      createdAt: new Date().toISOString().split('T')[0],
      status: 'active',
    };

    // Optimistic local state update
    setStaffList(prev => [newStaff, ...prev]);

    // Save to Firestore
    try {
      await setDoc(doc(db, 'staff', newId), {
        id: newId,
        name: newStaff.name,
        email: newStaff.email,
        role: newStaff.role,
        department: newStaff.department,
        status: 'active',
        createdAt: serverTimestamp(),
      });
    } catch (e) {
      console.warn('Staff firestore write notice:', e);
    }
  };

  const logout = () => {
    setRole(null);
    setUserId(null);
    setUserName(null);
    setUserEmail(null);
  };

  return (
    <AuthContext.Provider value={{
      role,
      userId,
      userName,
      userEmail,
      isAuthenticated: role !== null,
      staffList,
      loginAsSurvivor,
      loginAsResponder,
      createStaffAccount,
      logout,
    }}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};
