import React from 'react';
import { NavLink, useNavigate } from 'react-router-dom';
import { LayoutDashboard, Users, AlertTriangle, FileText, ShieldCheck, LogOut, UserCheck, UserPlus, Lock, PhoneCall } from 'lucide-react';
import { useAuth } from '../../context/AuthContext';
import { isMaskedRole } from '../../lib/maskData';

export const PortalNav: React.FC = () => {
  const { role, userName, logout } = useAuth();
  const navigate = useNavigate();

  const handleLogout = () => {
    logout();
    navigate('/portal/login');
  };

  const navItems = [
    { to: '/portal/guardian', label: 'Guardian QR Hub', icon: ShieldCheck },
    { to: '/portal/dashboard', label: 'Aggregate Trends', icon: LayoutDashboard },
    { to: '/portal/beneficiaries', label: 'Beneficiaries', icon: Users },
    { to: '/portal/alerts', label: 'Distress Triage', icon: AlertTriangle },
    { to: '/portal/simulator', label: 'Voice Careline', icon: PhoneCall },
    { to: '/portal/audit', label: 'Audit Trail', icon: FileText },
    ...(role === 'admin' ? [{ to: '/portal/staff', label: 'Staff & Roles', icon: UserPlus }] : []),
  ];

  const roleLabel = {
    caseworker: 'Caseworker (Direct Care)',
    analyst: 'Data Analyst',
    admin: 'System Admin (Oversight)',
    survivor: 'Survivor Access',
  }[role || 'caseworker'];

  return (
    <header className="bg-mool-dusk text-white border-b border-mool-dusk-light sticky top-0 z-30 shadow-sm">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 h-16 flex items-center justify-between">
        {/* Left logo & Portal identity */}
        <div className="flex items-center space-x-3">
          <div className="w-9 h-9 rounded-organic bg-mool-moss flex items-center justify-center shadow-sm overflow-hidden border border-white/20">
            <img src="/app_icon.png" alt="Mool Icon" className="w-full h-full object-cover" />
          </div>
          <div>
            <div className="flex items-center space-x-2">
              <span className="font-serif text-lg font-bold tracking-tight text-white">Mool Portal</span>
              <span className="text-[10px] bg-mool-dusk-light text-mool-linen px-2 py-0.5 rounded-md uppercase font-mono tracking-wider">
                Official Responder Shell
              </span>
            </div>
            <p className="text-[11px] text-mool-linen/70 font-sans">Ministry & NGO Operations • Team Origin</p>
          </div>
        </div>

        {/* Center Nav tabs (Desktop) */}
        <nav className="hidden md:flex items-center space-x-1">
          {navItems.map((item) => {
            const Icon = item.icon;
            return (
              <NavLink
                key={item.to}
                to={item.to}
                className={({ isActive }) =>
                  `flex items-center space-x-2 px-3.5 py-2 rounded-organic text-xs font-medium transition-colors ${
                    isActive
                      ? 'bg-mool-moss text-white font-semibold'
                      : 'text-mool-linen/80 hover:bg-mool-dusk-light hover:text-white'
                  }`
                }
              >
                <Icon className="w-4 h-4" />
                <span>{item.label}</span>
              </NavLink>
            );
          })}
        </nav>

        {/* Right User Badge & Logout */}
        <div className="flex items-center space-x-3">
          <div className="hidden sm:flex flex-col items-end">
            <span className="text-xs font-semibold text-white flex items-center space-x-1">
              <UserCheck className="w-3.5 h-3.5 text-mool-moss" />
              <span>{userName || 'Officer Singh'}</span>
            </span>
            <span className="text-[10px] text-mool-sandrose font-medium">{roleLabel}</span>
          </div>

          <button
            onClick={handleLogout}
            className="p-2 rounded-organic text-mool-linen/80 hover:text-white hover:bg-mool-dusk-light transition-colors text-xs flex items-center space-x-1"
            title="Sign out of responder portal"
          >
            <LogOut className="w-4 h-4" />
            <span className="hidden sm:inline text-xs">Exit</span>
          </button>
        </div>
      </div>

      {/* Mobile nav tabs */}
      <div className="md:hidden flex overflow-x-auto bg-mool-dusk-dark border-t border-mool-dusk-light px-2 py-1 space-x-1 no-scrollbar">
        {navItems.map((item) => {
          const Icon = item.icon;
          return (
            <NavLink
              key={item.to}
              to={item.to}
              className={({ isActive }) =>
                `flex items-center space-x-1.5 px-3 py-1.5 rounded-md text-xs font-medium whitespace-nowrap ${
                  isActive ? 'bg-mool-moss text-white' : 'text-mool-linen/70'
                }`
              }
            >
              <Icon className="w-3.5 h-3.5" />
              <span>{item.label}</span>
            </NavLink>
          );
        })}
      </div>

      {/* Privacy Mode Indicator for Admin and Analyst */}
      {isMaskedRole(role) && (
        <div className="bg-mool-dusk-dark text-mool-linen/90 border-t border-white/10 px-4 py-1.5 text-center text-[11px] flex items-center justify-center space-x-2">
          <Lock className="w-3.5 h-3.5 text-mool-sandrose" />
          <span>
            <strong>Confidentiality Oversight Mode:</strong> Survivor records and reflections are protected in anonymous reports.
          </span>
        </div>
      )}
    </header>
  );
};

