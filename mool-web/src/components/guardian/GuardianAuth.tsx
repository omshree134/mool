import React, { useState } from 'react';
import { ShieldCheck, UserPlus, LogIn, Sparkles, Lock, Mail, User, Phone, Building, AlertCircle } from 'lucide-react';
import { useGuardianAuth } from '../../context/GuardianAuthContext';
import { GroundedCard } from '../common/GroundedCard';
import { OrganicButton } from '../common/OrganicButton';

const ROLE_OPTIONS = [
  'Clinical Counselor / Therapist',
  'Family / Trusted Support Person',
  'Official Ward Caseworker',
  'Legal Guardian / Advocate',
  'Healthcare / NGO Specialist',
];

export const GuardianAuth: React.FC = () => {
  const { registerGuardian, loginGuardian, loginWithGoogle, loginDemoGuardian, loading, error, clearError } = useGuardianAuth();
  
  const [isRegister, setIsRegister] = useState(true);
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [role, setRole] = useState(ROLE_OPTIONS[0]);
  const [organization, setOrganization] = useState('');
  const [phone, setPhone] = useState('');
  const [localError, setLocalError] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLocalError(null);
    clearError();

    if (!email.trim() || !password) {
      setLocalError('Please provide both email and password.');
      return;
    }

    if (password.length < 6) {
      setLocalError('Password must be at least 6 characters.');
      return;
    }

    try {
      if (isRegister) {
        if (!name.trim()) {
          setLocalError('Please enter your full name or title.');
          return;
        }
        await registerGuardian({
          name: name.trim(),
          email: email.trim(),
          password,
          role,
          organization: organization.trim(),
          phone: phone.trim(),
        });
      } else {
        await loginGuardian(email.trim(), password);
      }
    } catch (err: any) {
      // Error handled in context or captured here
      console.warn('Authentication error:', err);
    }
  };

  const activeError = localError || error;

  return (
    <div className="min-h-[85vh] flex items-center justify-center px-4 py-8 bg-organic-topography">
      <div className="max-w-xl w-full space-y-6">
        {/* Brand Header */}
        <div className="text-center space-y-2">
          <div className="w-14 h-14 rounded-full bg-mool-moss text-white flex items-center justify-center mx-auto shadow-soft-ground font-serif text-2xl font-bold">
            म
          </div>
          <div className="inline-flex items-center space-x-1.5 px-3 py-1 bg-mool-moss/10 text-mool-moss rounded-full text-xs font-semibold">
            <ShieldCheck className="w-3.5 h-3.5" />
            <span>Designated Guardian Care System</span>
          </div>
          <h1 className="font-serif text-3xl font-bold text-mool-ink tracking-tight">
            {isRegister ? 'Register Guardian Portal' : 'Guardian Sign In'}
          </h1>
          <p className="text-xs sm:text-sm text-mool-ink-muted max-w-md mx-auto leading-relaxed">
            {isRegister
              ? 'Create your guardian profile to obtain a secure pairing QR code and view encrypted wellbeing telemetry from your wards.'
              : 'Sign in to access your designated wards, review real-time check-ins, and monitor distress alerts.'}
          </p>
        </div>

        {/* Tab Switcher */}
        <div className="flex bg-mool-mist/50 p-1 rounded-xl border border-mool-mist max-w-xs mx-auto">
          <button
            type="button"
            onClick={() => {
              setIsRegister(true);
              setLocalError(null);
              clearError();
            }}
            className={`flex-1 py-1.5 px-3 rounded-lg text-xs font-semibold flex items-center justify-center space-x-1.5 transition-all ${
              isRegister
                ? 'bg-white text-mool-ink shadow-sm'
                : 'text-mool-ink-muted hover:text-mool-ink'
            }`}
          >
            <UserPlus className="w-3.5 h-3.5" />
            <span>Register</span>
          </button>
          <button
            type="button"
            onClick={() => {
              setIsRegister(false);
              setLocalError(null);
              clearError();
            }}
            className={`flex-1 py-1.5 px-3 rounded-lg text-xs font-semibold flex items-center justify-center space-x-1.5 transition-all ${
              !isRegister
                ? 'bg-white text-mool-ink shadow-sm'
                : 'text-mool-ink-muted hover:text-mool-ink'
            }`}
          >
            <LogIn className="w-3.5 h-3.5" />
            <span>Sign In</span>
          </button>
        </div>

        {/* Main Card */}
        <GroundedCard variant="primary" elevation="floating" className="p-6 sm:p-8 space-y-6 border-2 border-mool-moss/20">
          {activeError && (
            <div className="p-3.5 bg-mool-signal/10 border border-mool-signal/30 rounded-xl flex items-start space-x-2.5 text-xs text-mool-signal font-medium">
              <AlertCircle className="w-4 h-4 shrink-0 mt-0.5" />
              <span>{activeError}</span>
            </div>
          )}

          {/* Google Sign In / Registration */}
          <button
            type="button"
            onClick={async () => {
              setLocalError(null);
              clearError();
              try {
                await loginWithGoogle();
              } catch (_) {}
            }}
            disabled={loading}
            className="w-full py-2.5 px-4 bg-white border border-mool-mist hover:border-mool-moss rounded-xl text-xs font-semibold text-mool-ink flex items-center justify-center space-x-2.5 shadow-sm hover:bg-mool-moss/5 transition-all"
          >
            <svg className="w-4 h-4" viewBox="0 0 24 24">
              <path
                fill="#4285F4"
                d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"
              />
              <path
                fill="#34A853"
                d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
              />
              <path
                fill="#FBBC05"
                d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.06H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.94l2.85-2.22.81-.63z"
              />
              <path
                fill="#EA4335"
                d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.06l3.66 2.84c.87-2.6 3.3-4.52 6.16-4.52z"
              />
            </svg>
            <span>{isRegister ? 'Register with Google' : 'Sign in with Google'}</span>
          </button>

          <div className="relative">
            <div className="absolute inset-0 flex items-center">
              <div className="w-full border-t border-mool-mist" />
            </div>
            <div className="relative flex justify-center text-[10px] uppercase font-bold text-mool-ink-faint tracking-wider">
              <span className="bg-[#FAF8F5] px-3">Or continue with email</span>
            </div>
          </div>

          <form onSubmit={handleSubmit} className="space-y-4">
            {isRegister && (
              <>
                {/* Full Name */}
                <div className="space-y-1.5">
                  <label className="block text-xs font-semibold text-mool-ink flex items-center space-x-1">
                    <User className="w-3.5 h-3.5 text-mool-moss" />
                    <span>Your Full Name & Title *</span>
                  </label>
                  <input
                    type="text"
                    required
                    value={name}
                    onChange={(e) => setName(e.target.value)}
                    placeholder="e.g. Dr. Sneha Roy, Officer Vikram Patel, Maya Rao"
                    className="w-full px-3.5 py-2.5 bg-white border border-mool-mist rounded-xl text-sm text-mool-ink placeholder-mool-ink-faint focus:outline-none focus:border-mool-moss focus:ring-1 focus:ring-mool-moss"
                  />
                </div>

                {/* Role */}
                <div className="space-y-1.5">
                  <label className="block text-xs font-semibold text-mool-ink flex items-center space-x-1">
                    <ShieldCheck className="w-3.5 h-3.5 text-mool-moss" />
                    <span>Guardian Role / Capacity *</span>
                  </label>
                  <select
                    value={role}
                    onChange={(e) => setRole(e.target.value)}
                    className="w-full px-3.5 py-2.5 bg-white border border-mool-mist rounded-xl text-sm text-mool-ink focus:outline-none focus:border-mool-moss focus:ring-1 focus:ring-mool-moss"
                  >
                    {ROLE_OPTIONS.map((opt) => (
                      <option key={opt} value={opt}>
                        {opt}
                      </option>
                    ))}
                  </select>
                </div>
              </>
            )}

            {/* Email */}
            <div className="space-y-1.5">
              <label className="block text-xs font-semibold text-mool-ink flex items-center space-x-1">
                <Mail className="w-3.5 h-3.5 text-mool-moss" />
                <span>Email Address *</span>
              </label>
              <input
                type="email"
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="guardian@organization.org or personal email"
                className="w-full px-3.5 py-2.5 bg-white border border-mool-mist rounded-xl text-sm text-mool-ink placeholder-mool-ink-faint focus:outline-none focus:border-mool-moss focus:ring-1 focus:ring-mool-moss"
              />
            </div>

            {/* Password */}
            <div className="space-y-1.5">
              <label className="block text-xs font-semibold text-mool-ink flex items-center space-x-1">
                <Lock className="w-3.5 h-3.5 text-mool-moss" />
                <span>Password (min 6 characters) *</span>
              </label>
              <input
                type="password"
                required
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••"
                className="w-full px-3.5 py-2.5 bg-white border border-mool-mist rounded-xl text-sm text-mool-ink placeholder-mool-ink-faint focus:outline-none focus:border-mool-moss focus:ring-1 focus:ring-mool-moss"
              />
            </div>

            {isRegister && (
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 pt-1">
                {/* Organization */}
                <div className="space-y-1.5">
                  <label className="block text-xs font-semibold text-mool-ink flex items-center space-x-1">
                    <Building className="w-3.5 h-3.5 text-mool-ink-muted" />
                    <span>Organization (Optional)</span>
                  </label>
                  <input
                    type="text"
                    value={organization}
                    onChange={(e) => setOrganization(e.target.value)}
                    placeholder="e.g. Hope Clinic / Asha Network"
                    className="w-full px-3 py-2 bg-white border border-mool-mist rounded-xl text-xs text-mool-ink placeholder-mool-ink-faint focus:outline-none focus:border-mool-moss"
                  />
                </div>

                {/* Phone */}
                <div className="space-y-1.5">
                  <label className="block text-xs font-semibold text-mool-ink flex items-center space-x-1">
                    <Phone className="w-3.5 h-3.5 text-mool-ink-muted" />
                    <span>Contact Line (Optional)</span>
                  </label>
                  <input
                    type="tel"
                    value={phone}
                    onChange={(e) => setPhone(e.target.value)}
                    placeholder="+91 98765 43210"
                    className="w-full px-3 py-2 bg-white border border-mool-mist rounded-xl text-xs text-mool-ink placeholder-mool-ink-faint focus:outline-none focus:border-mool-moss"
                  />
                </div>
              </div>
            )}

            <div className="pt-2">
              <OrganicButton
                variant="moss"
                fullWidth
                size="md"
                disabled={loading}
              >
                {loading ? (
                  <span>Processing...</span>
                ) : isRegister ? (
                  <>
                    <UserPlus className="w-4 h-4 mr-2" />
                    <span>Register & Generate Pairing QR</span>
                  </>
                ) : (
                  <>
                    <LogIn className="w-4 h-4 mr-2" />
                    <span>Sign In to Guardian Portal</span>
                  </>
                )}
              </OrganicButton>
            </div>
          </form>

          {/* Divider */}
          <div className="relative my-4">
            <div className="absolute inset-0 flex items-center">
              <div className="w-full border-t border-mool-mist" />
            </div>
            <div className="relative flex justify-center text-[10px] uppercase font-bold text-mool-ink-faint tracking-wider">
              <span className="bg-mool-linen px-3">Or Fast-Track Testing</span>
            </div>
          </div>

          {/* Quick Demo Access Buttons */}
          <div className="space-y-2">
            <p className="text-[11px] text-mool-ink-muted text-center">
              Evaluating the platform? Instant 1-click guardian access:
            </p>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5">
              <button
                type="button"
                onClick={() => loginDemoGuardian('singh')}
                className="p-3 text-left rounded-xl border border-mool-mist hover:border-mool-moss bg-white hover:bg-mool-moss/5 transition-all text-xs"
              >
                <div className="font-semibold text-mool-ink flex items-center justify-between">
                  <span>Officer Rajesh Singh</span>
                  <Sparkles className="w-3.5 h-3.5 text-mool-moss" />
                </div>
                <div className="text-[11px] text-mool-ink-muted mt-0.5">
                  Official Caseworker • Code: <strong className="text-mool-moss">GRD-8821</strong>
                </div>
              </button>

              <button
                type="button"
                onClick={() => loginDemoGuardian('jenkins')}
                className="p-3 text-left rounded-xl border border-mool-mist hover:border-mool-sandrose bg-white hover:bg-mool-sandrose/5 transition-all text-xs"
              >
                <div className="font-semibold text-mool-ink flex items-center justify-between">
                  <span>Dr. Sarah Jenkins</span>
                  <Sparkles className="w-3.5 h-3.5 text-mool-sandrose" />
                </div>
                <div className="text-[11px] text-mool-ink-muted mt-0.5">
                  Clinical Counselor • Code: <strong className="text-mool-sandrose">GRD-4920</strong>
                </div>
              </button>
            </div>
          </div>
        </GroundedCard>

        {/* Security & Scoping Assurance */}
        <div className="text-center text-[11px] text-mool-ink-muted space-y-1">
          <p className="flex items-center justify-center space-x-1.5">
            <Lock className="w-3.5 h-3.5 text-mool-moss" />
            <span>Strict Ward Scoping: You will only see data from wards who scan your QR code.</span>
          </p>
        </div>
      </div>
    </div>
  );
};
