import React, { useState } from 'react';
import { Routes, Route, Navigate } from 'react-router-dom';
import { SurvivorNav } from '../components/survivor/SurvivorNav';
import { DailyCheckin } from '../components/survivor/DailyCheckin';
import { TalkToMool } from '../components/survivor/TalkToMool';
import { PrivateJournal } from '../components/survivor/PrivateJournal';
import { PersonalTrends } from '../components/survivor/PersonalTrends';
import { CrisisBar } from '../components/common/CrisisBar';
import { CrisisModal } from '../components/survivor/CrisisModal';

export const AppRoutes: React.FC = () => {
  const [isHelpOpen, setIsHelpOpen] = useState(false);

  return (
    <div className="min-h-screen bg-mool-linen flex flex-col font-sans selection:bg-mool-moss/20">
      <SurvivorNav />

      <main className="flex-1">
        <Routes>
          <Route path="home" element={<DailyCheckin />} />
          <Route path="chat" element={<TalkToMool onOpenHelpModal={() => setIsHelpOpen(true)} />} />
          <Route path="journal" element={<PrivateJournal />} />
          <Route path="trends" element={<PersonalTrends />} />
          <Route path="*" element={<Navigate to="home" replace />} />
        </Routes>
      </main>

      {/* Floating / Sticky Crisis Help Bar (Non-negotiable path to human help) */}
      <div className="fixed bottom-0 left-0 right-0 z-20">
        <CrisisBar onOpenHelpModal={() => setIsHelpOpen(true)} />
      </div>

      {/* Get Help Now Modal Sheet */}
      <CrisisModal isOpen={isHelpOpen} onClose={() => setIsHelpOpen(false)} />
    </div>
  );
};
