import React from 'react';
import { NavLink } from 'react-router-dom';
import { Heart, MessageSquare, LineChart, BookOpen, ShieldCheck } from 'lucide-react';
import { useSurvivor } from '../../context/SurvivorContext';

export const SurvivorNav: React.FC = () => {
  const { pseudonym } = useSurvivor();

  const navItems = [
    { to: '/app/home', label: 'Check-in', icon: Heart },
    { to: '/app/chat', label: 'Talk to Mool', icon: MessageSquare },
    { to: '/app/journal', label: 'Journal', icon: BookOpen },
    { to: '/app/trends', label: 'My Reflection', icon: LineChart },
  ];

  return (
    <header className="bg-mool-linen/90 backdrop-blur-md border-b border-mool-mist sticky top-0 z-30">
      <div className="max-w-md mx-auto px-4 h-14 flex items-center justify-between">
        {/* Brand logo & tagline */}
        <div className="flex items-center space-x-2">
          <div className="w-8 h-8 rounded-full overflow-hidden border border-mool-moss/30 shadow-sm shrink-0">
            <img src="/app_icon.png" alt="Mool" className="w-full h-full object-cover" />
          </div>
          <div>
            <span className="font-serif text-lg font-semibold tracking-tight text-mool-ink">Mool</span>
            <span className="text-[10px] block font-sans text-mool-ink-faint -mt-1">Grounded support</span>
          </div>
        </div>

        {/* Pseudonym Badge & Consent indicator */}
        <div className="flex items-center space-x-2">
          <div className="flex items-center space-x-1 px-2.5 py-1 bg-mool-moss/10 rounded-full border border-mool-moss/20 text-xs font-medium text-mool-moss">
            <ShieldCheck className="w-3.5 h-3.5" />
            <span>{pseudonym}</span>
          </div>
        </div>
      </div>

      {/* Bottom mobile navigation tabs */}
      <nav className="border-t border-mool-mist/50 bg-[#FAF8F3]">
        <div className="max-w-md mx-auto flex justify-around">
          {navItems.map(item => {
            const Icon = item.icon;
            return (
              <NavLink
                key={item.to}
                to={item.to}
                className={({ isActive }) =>
                  `flex flex-col items-center py-2 px-3 text-xs font-medium transition-colors ${
                    isActive
                      ? 'text-mool-moss border-b-2 border-mool-moss font-semibold'
                      : 'text-mool-ink-muted hover:text-mool-ink'
                  }`
                }
              >
                <Icon className="w-4 h-4 mb-0.5" />
                <span>{item.label}</span>
              </NavLink>
            );
          })}
        </div>
      </nav>
    </header>
  );
};

