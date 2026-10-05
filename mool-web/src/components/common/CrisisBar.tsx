import React from 'react';
import { PhoneCall, ShieldAlert, HeartHandshake } from 'lucide-react';

interface CrisisBarProps {
  onOpenHelpModal: () => void;
}

export const CrisisBar: React.FC<CrisisBarProps> = ({ onOpenHelpModal }) => {
  return (
    <div className="w-full bg-mool-sandrose/15 border-t border-mool-sandrose/30 px-4 py-2.5 sm:px-6 flex items-center justify-between transition-colors">
      <div className="flex items-center space-x-2 text-xs sm:text-sm text-mool-ink font-medium">
        <HeartHandshake className="w-4 h-4 text-mool-sandrose shrink-0" />
        <span>You are not alone. Support is always one tap away.</span>
      </div>
      
      <button
        onClick={onOpenHelpModal}
        className="inline-flex items-center space-x-1.5 bg-mool-sandrose text-white text-xs font-semibold px-3 py-1.5 rounded-full hover:bg-mool-sandrose/90 transition-colors shadow-sm focus:outline-none focus:ring-2 focus:ring-mool-sandrose"
        aria-label="Get help now — view emergency crisis resources"
      >
        <PhoneCall className="w-3.5 h-3.5" />
        <span>Get help now</span>
      </button>
    </div>
  );
};

