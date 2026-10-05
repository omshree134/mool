import React, { createContext, useContext, useState } from 'react';
import { CheckinEntry } from '../types';

interface SurvivorContextType {
  pseudonym: string;
  setPseudonym: (val: string) => void;
  language: string;
  setLanguage: (val: string) => void;
  emergencyContact: string;
  setEmergencyContact: (val: string) => void;
  hasConsented: boolean;
  setHasConsented: (val: boolean) => void;
  checkins: CheckinEntry[];
  addCheckin: (entry: Omit<CheckinEntry, 'id' | 'timestamp' | 'beneficiaryId'>) => void;
}

const SurvivorContext = createContext<SurvivorContextType | undefined>(undefined);

const MOCK_CHECKINS: CheckinEntry[] = [
  {
    id: 'chk-1',
    beneficiaryId: 'survivor-882',
    timestamp: new Date(Date.now() - 6 * 24 * 60 * 60 * 1000).toISOString(),
    moodScore: 2,
    note: 'Felt very tense in the morning after loud sounds outside. Did 5 minutes of deep breathing near the window.',
    tags: ['Intrusive Thoughts', 'Restless'],
  },
  {
    id: 'chk-2',
    beneficiaryId: 'survivor-882',
    timestamp: new Date(Date.now() - 4 * 24 * 60 * 60 * 1000).toISOString(),
    moodScore: 3,
    note: 'Quiet afternoon. Met with the community worker for tea. Slept 6 hours.',
    tags: ['Calm', 'Social Connection'],
  },
  {
    id: 'chk-3',
    beneficiaryId: 'survivor-882',
    timestamp: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000).toISOString(),
    moodScore: 4,
    note: 'Felt grounded today. Planted seeds in small clay pot.',
    tags: ['Grounded', 'Peaceful'],
  },
];

export const SurvivorProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [pseudonym, setPseudonym] = useState('Aarav');
  const [language, setLanguage] = useState('en');
  const [emergencyContact, setEmergencyContact] = useState('+91 98765 43210 (Sister)');
  const [hasConsented, setHasConsented] = useState(true);
  const [checkins, setCheckins] = useState<CheckinEntry[]>(MOCK_CHECKINS);

  const addCheckin = (entry: Omit<CheckinEntry, 'id' | 'timestamp' | 'beneficiaryId'>) => {
    const newEntry: CheckinEntry = {
      ...entry,
      id: `chk-${Date.now()}`,
      beneficiaryId: 'survivor-882',
      timestamp: new Date().toISOString(),
    };
    setCheckins(prev => [newEntry, ...prev]);
  };

  return (
    <SurvivorContext.Provider value={{
      pseudonym,
      setPseudonym,
      language,
      setLanguage,
      emergencyContact,
      setEmergencyContact,
      hasConsented,
      setHasConsented,
      checkins,
      addCheckin,
    }}>
      {children}
    </SurvivorContext.Provider>
  );
};

export const useSurvivor = () => {
  const context = useContext(SurvivorContext);
  if (!context) {
    throw new Error('useSurvivor must be used within a SurvivorProvider');
  }
  return context;
};

