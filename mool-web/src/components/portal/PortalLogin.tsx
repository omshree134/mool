import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { ShieldCheck, Lock, Mail, ArrowRight, ShieldAlert, Sparkles, UserCheck } from 'lucide-react';
import { GroundedCard } from '../common/GroundedCard';
import { OrganicButton } from '../common/OrganicButton';
import { useAuth } from '../../context/AuthContext';

export const PortalLogin: React.FC = () => {
  const { staffList, loginAsResponder } = useAuth();
  const navigate = useNavigate();

  const [selectedRole, setSelectedRole] = useState<'admin' | 'analyst' | 'caseworker'>('admin');
  const [email, setEmail] = useState('rajesh.singh@mool.gov.in');
  const [password, setPassword] = useState('••••••••••••');
  const [error, setError] = useState<string | null>(null);

  const handleSelectRole = (r: 'admin' | 'analyst' | 'caseworker') => {
    setSelectedRole(r);
    setError(null);
    if (r === 'admin') {
      setEmail('rajesh.singh@mool.gov.in');
    } else if (r === 'analyst') {
      setEmail('neha.verma@mool.gov.in');
    } else {
      setEmail('ananya.sharma@counseling.org');
    }
  };

  const handleLogin = (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);

    // Look up in staffList if available
    const matched = staffList.find(s => s.email.toLowerCase() === email.trim().toLowerCase());
    const finalRole = matched ? matched.role : selectedRole;
    const finalName = matched ? matched.name : (
      selectedRole === 'admin' ? 'Officer Rajesh Singh (Admin)' :
      selectedRole === 'analyst' ? 'Dr. Neha Verma (Analyst)' :
      'Ananya Sharma (Caseworker)'
    );

    loginAsResponder(finalRole, finalName, email.trim());
    navigate('/portal/dashboard');
  };

  return (
    <div className="min-h-screen bg-mool-linen flex items-center justify-center p-4 bg-organic-topography">
      <div className="max-w-md w-full py-6 space-y-6">
        {/* Portal Branding */}
        <div className="text-center space-y-2">
          <div className="w-14 h-14 rounded-organic bg-mool-dusk text-white flex items-center justify-center mx-auto font-serif text-3xl font-bold shadow-soft-ground">
            म
          </div>
          <h1 className="font-serif text-2xl sm:text-3xl text-mool-ink font-bold">Official Staff & Responder Login</h1>
          <p className="text-xs text-mool-ink-muted leading-relaxed">
            Credentialed access for System Administrators, Data Analysts & Caseworkers.
          </p>
        </div>

        {/* Security Notice: Self-Registration Disabled */}
        <div className="p-3 bg-white/70 border border-mool-mist rounded-xl text-xs text-mool-ink-muted flex items-start space-x-2.5 shadow-sm">
          <ShieldAlert className="w-4 h-4 text-mool-sandrose shrink-0 mt-0.5" />
          <span>
            <strong>Access Policy:</strong> Self-registration is strictly disabled for Analysts and Administrators. Accounts must be provisioned by an authorized System Admin.
          </span>
        </div>

        <GroundedCard variant="primary" elevation="floating" className="space-y-5 border-2 border-mool-dusk/20">
          <form onSubmit={handleLogin} className="space-y-4">
            {/* Role Selection Tabs */}
            <div>
              <label className="block text-xs font-semibold text-mool-ink mb-1.5">Select Credential Context</label>
              <div className="grid grid-cols-3 gap-2">
                {[
                  { id: 'admin', label: 'System Admin' },
                  { id: 'analyst', label: 'Data Analyst' },
                  { id: 'caseworker', label: 'Caseworker' },
                ].map((r) => (
                  <button
                    key={r.id}
                    type="button"
                    onClick={() => handleSelectRole(r.id as any)}
                    className={`py-2 text-xs font-semibold rounded-organic border transition-all ${
                      selectedRole === r.id
                        ? 'bg-mool-dusk text-white border-mool-dusk shadow-sm'
                        : 'bg-white border-mool-mist text-mool-ink-muted hover:border-mool-dusk/40'
                    }`}
                  >
                    {r.label}
                  </button>
                ))}
              </div>
            </div>

            {/* Email Field */}
            <div>
              <label className="block text-xs font-semibold text-mool-ink mb-1 flex items-center space-x-1.5">
                <Mail className="w-3.5 h-3.5 text-mool-dusk" />
                <span>Official Agency Email</span>
              </label>
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className="w-full px-3.5 py-2.5 bg-white border border-mool-mist rounded-organic text-sm text-mool-ink focus:border-mool-dusk focus:ring-1 focus:ring-mool-dusk"
                required
              />
            </div>

            {/* Password Field */}
            <div>
              <label className="block text-xs font-semibold text-mool-ink mb-1 flex items-center space-x-1.5">
                <Lock className="w-3.5 h-3.5 text-mool-dusk" />
                <span>Security Key / Password</span>
              </label>
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="w-full px-3.5 py-2.5 bg-white border border-mool-mist rounded-organic text-sm text-mool-ink focus:border-mool-dusk focus:ring-1 focus:ring-mool-dusk"
                required
              />
            </div>

            <OrganicButton type="submit" variant="dusk" fullWidth size="lg" className="shadow-md">
              <ShieldCheck className="w-4 h-4 mr-2 text-mool-moss-light" />
              <span>Authenticate Session</span>
              <ArrowRight className="w-4 h-4 ml-2" />
            </OrganicButton>
          </form>

          {/* Preset Quick Logins */}
          <div className="pt-3 border-t border-mool-mist space-y-2">
            <span className="text-[10px] uppercase font-bold text-mool-ink-faint tracking-wider block text-center">
              Pre-Provisioned Official Profiles
            </span>
            <div className="grid grid-cols-3 gap-1.5 text-center">
              <button
                type="button"
                onClick={() => handleSelectRole('admin')}
                className="py-1.5 px-2 bg-mool-mist/30 hover:bg-mool-mist rounded text-[11px] text-mool-ink font-medium transition-colors"
              >
                Admin
              </button>
              <button
                type="button"
                onClick={() => handleSelectRole('analyst')}
                className="py-1.5 px-2 bg-mool-mist/30 hover:bg-mool-mist rounded text-[11px] text-mool-ink font-medium transition-colors"
              >
                Analyst
              </button>
              <button
                type="button"
                onClick={() => handleSelectRole('caseworker')}
                className="py-1.5 px-2 bg-mool-mist/30 hover:bg-mool-mist rounded text-[11px] text-mool-ink font-medium transition-colors"
              >
                Caseworker
              </button>
            </div>
          </div>

          <div className="pt-2 border-t border-mool-mist text-center space-y-2">
            <p className="text-[11px] text-mool-ink-faint flex items-center justify-center space-x-1">
              <Lock className="w-3.5 h-3.5 text-mool-moss" />
              <span>Analyst & Admin views automatically enforce PII Data Masking</span>
            </p>

            <a
              href="/guardian"
              className="text-xs text-mool-moss font-semibold hover:underline block pt-1"
            >
              Are you a Ward Guardian? Register with Google on the Guardian Portal →
            </a>
          </div>
        </GroundedCard>
      </div>
    </div>
  );
};
