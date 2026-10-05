import React from 'react';
import { BrowserRouter, Routes, Route, Navigate, Link } from 'react-router-dom';
import { UserCheck, ShieldCheck, ArrowRight, Sparkles, QrCode, Lock, Radio, Users } from 'lucide-react';
import { AuthProvider } from './context/AuthContext';
import { GuardianAuthProvider } from './context/GuardianAuthContext';
import { SurvivorProvider } from './context/SurvivorContext';
import { AppRoutes } from './routes/AppRoutes';
import { PortalRoutes } from './routes/PortalRoutes';
import { GuardianHub } from './components/guardian/GuardianHub';
import { QrScannerModal } from './components/survivor/QrScannerModal';
import { ConsentScreen } from './components/survivor/ConsentScreen';
import { ProfileSetup } from './components/survivor/ProfileSetup';
import { PortalLogin } from './components/portal/PortalLogin';
import { GroundedCard } from './components/common/GroundedCard';
import { OrganicButton } from './components/common/OrganicButton';

const HomeLanding: React.FC = () => {
  return (
    <div className="min-h-screen bg-mool-linen flex flex-col justify-between bg-organic-topography">
      {/* Top Global Navigation Bar */}
      <header className="border-b border-mool-mist/70 bg-white/70 backdrop-blur-md sticky top-0 z-20">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 h-16 flex items-center justify-between">
          <div className="flex items-center space-x-3">
            <div className="w-10 h-10 rounded-xl overflow-hidden border border-mool-moss/20 shadow-sm bg-mool-moss shrink-0">
              <img src="/app_icon.png" alt="Mool" className="w-full h-full object-cover" />
            </div>
            <div>
              <div className="flex items-center space-x-2">
                <span className="font-serif text-xl font-bold text-mool-ink">Mool</span>
                <span className="text-xs text-mool-ink-muted font-normal">(मूल)</span>
              </div>
              <span className="text-[10px] text-mool-moss font-semibold block -mt-1">
                Grounded Mental Health & Distress Platform
              </span>
            </div>
          </div>

          <div className="flex items-center space-x-2.5">
            <Link
              to="/guardian"
              className="px-3.5 py-1.5 rounded-lg text-xs font-semibold bg-mool-moss/10 hover:bg-mool-moss/20 text-mool-moss border border-mool-moss/20 flex items-center space-x-1.5 transition-colors"
            >
              <ShieldCheck className="w-3.5 h-3.5" />
              <span>Guardian Portal</span>
            </Link>

            <Link
              to="/portal/login"
              className="px-3.5 py-1.5 rounded-lg text-xs font-semibold bg-mool-dusk hover:bg-mool-dusk-dark text-white shadow-sm flex items-center space-x-1.5 transition-colors"
            >
              <UserCheck className="w-3.5 h-3.5" />
              <span>Responder Portal</span>
            </Link>
          </div>
        </div>
      </header>

      {/* Main Dual Front-Door Section */}
      <main className="flex-1 flex items-center justify-center p-4 sm:p-6">
        <div className="max-w-3xl w-full py-8 space-y-8 text-center relative z-10">
          {/* Brand identity */}
          <div className="space-y-3">
            <div className="w-16 h-16 rounded-2xl overflow-hidden border-2 border-white shadow-soft-ground mx-auto bg-mool-moss">
              <img src="/app_icon.png" alt="Mool Icon" className="w-full h-full object-cover" />
            </div>
            
            <div className="inline-flex items-center space-x-2 px-3 py-1 bg-mool-moss/10 text-mool-moss rounded-full text-xs font-semibold">
              <Sparkles className="w-3.5 h-3.5" />
              <span>Two-Sided Platform Architecture</span>
            </div>

            <h1 className="font-serif text-3xl sm:text-5xl text-mool-ink font-bold tracking-tight">
              Grounded Support. Real-Time Safety.
            </h1>

            <p className="text-xs sm:text-sm text-mool-ink-muted max-w-xl mx-auto leading-relaxed">
              Mool connects protected individuals and survivors with both their personal <strong>Guardians</strong> and official <strong>Responders</strong>, protecting privacy with rigorous data scoping and anonymization.
            </p>
          </div>

          {/* Dual Front-Door Cards */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-6 text-left">
            {/* SIDE 1: Guardian Care Portal */}
            <GroundedCard variant="primary" elevation="floating" className="p-6 space-y-4 border-2 border-mool-moss/40 hover:border-mool-moss transition-all flex flex-col justify-between">
              <div className="space-y-3">
                <div className="flex items-center justify-between">
                  <div className="w-10 h-10 rounded-full bg-mool-moss text-white flex items-center justify-center">
                    <ShieldCheck className="w-5 h-5" />
                  </div>
                  <span className="px-2.5 py-0.5 bg-mool-moss/10 text-mool-moss rounded-full text-[10px] font-bold uppercase tracking-wider">
                    Google & Email Login
                  </span>
                </div>

                <div>
                  <h2 className="font-serif text-xl font-bold text-mool-ink">Guardian Portal</h2>
                  <p className="text-xs text-mool-moss font-semibold mt-0.5">For Family, Therapists & Caregivers</p>
                  <p className="text-xs text-mool-ink-muted leading-relaxed mt-2">
                    Log in or register with Google to receive your dynamic Pairing QR Code. Have your ward scan it from their Mool mobile app to connect.
                  </p>
                </div>

                <div className="space-y-1.5 pt-1 text-[11px] text-mool-ink-muted border-t border-mool-mist">
                  <div className="flex items-center space-x-2">
                    <span className="w-1.5 h-1.5 rounded-full bg-mool-moss" />
                    <span>See your connected wards and real-time check-ins</span>
                  </div>
                  <div className="flex items-center space-x-2">
                    <span className="w-1.5 h-1.5 rounded-full bg-mool-moss" />
                    <span>Live 10-second heartbeat & GPS emergency SOS</span>
                  </div>
                  <div className="flex items-center space-x-2">
                    <span className="w-1.5 h-1.5 rounded-full bg-mool-moss" />
                    <span>Encrypted daily check-in notes & reflections</span>
                  </div>
                </div>
              </div>

              <Link to="/guardian" className="block pt-3">
                <OrganicButton variant="moss" fullWidth size="md">
                  <QrCode className="w-4 h-4 mr-2" />
                  <span>Enter Guardian Portal</span>
                </OrganicButton>
              </Link>
            </GroundedCard>

            {/* SIDE 2: Responder / Government Portal */}
            <GroundedCard variant="dusk" elevation="floating" className="p-6 space-y-4 border-2 border-mool-dusk-light hover:border-white/40 transition-all flex flex-col justify-between">
              <div className="space-y-3">
                <div className="flex items-center justify-between">
                  <div className="w-10 h-10 rounded-full bg-white/15 text-white flex items-center justify-center">
                    <UserCheck className="w-5 h-5" />
                  </div>
                  <span className="px-2.5 py-0.5 bg-white/10 text-mool-linen rounded-full text-[10px] font-bold uppercase tracking-wider">
                    Admin & Analyst Access
                  </span>
                </div>

                <div>
                  <h2 className="font-serif text-xl font-bold text-mool-linen">Responder Portal</h2>
                  <p className="text-xs text-mool-sandrose font-semibold mt-0.5">For Data Analysts & System Admins</p>
                  <p className="text-xs text-mool-linen/80 leading-relaxed mt-2">
                    Credentialed portal for monitoring system-wide distress trends, triage queues, and incoming emergency SOS alarms across all sectors.
                  </p>
                </div>

                <div className="space-y-1.5 pt-1 text-[11px] text-mool-linen/70 border-t border-white/10">
                  <div className="flex items-center space-x-2">
                    <span className="w-1.5 h-1.5 rounded-full bg-mool-sandrose" />
                    <span><strong>Anonymous Reports:</strong> Survivor identities protected</span>
                  </div>
                  <div className="flex items-center space-x-2">
                    <span className="w-1.5 h-1.5 rounded-full bg-mool-sandrose" />
                    <span>Real-time SOS triage queue with live GPS fix</span>
                  </div>
                  <div className="flex items-center space-x-2">
                    <span className="w-1.5 h-1.5 rounded-full bg-mool-sandrose" />
                    <span>Admin console to provision Analyst & Admin accounts</span>
                  </div>
                </div>
              </div>

              <Link to="/portal/login" className="block pt-3">
                <OrganicButton variant="sandrose" fullWidth size="md">
                  <span>Responder Staff Login</span>
                  <ArrowRight className="w-4 h-4 ml-2" />
                </OrganicButton>
              </Link>
            </GroundedCard>
          </div>

          {/* Footer info */}
          <div className="pt-2 text-xs text-mool-ink-faint space-y-1">
            <p>Privacy by Default • On-Device Sensing • Firestore Live Synchronized</p>
          </div>
        </div>
      </main>

      {/* Footer */}
      <footer className="border-t border-mool-mist/60 py-3 bg-white/40 text-center text-xs text-mool-ink-faint">
        Mool Grounded Mental Health Platform • Team Origin • All rights reserved
      </footer>
    </div>
  );
};

export const App: React.FC = () => {
  return (
    <AuthProvider>
      <GuardianAuthProvider>
        <SurvivorProvider>
          <BrowserRouter>
            <Routes>
              {/* Home Landing dual front door */}
              <Route path="/" element={<HomeLanding />} />

              {/* Direct Guardian Portal access */}
              <Route path="/guardian" element={<GuardianHub />} />

              {/* Entity A: Survivor Onboarding & Shell */}
              <Route path="/app/scan" element={<QrScannerModal />} />
              <Route path="/app/consent" element={<ConsentScreen />} />
              <Route path="/app/profile" element={<ProfileSetup />} />
              <Route path="/app/*" element={<AppRoutes />} />

              {/* Entity B: Government Portal Login & Shell */}
              <Route path="/portal/login" element={<PortalLogin />} />
              <Route path="/portal/*" element={<PortalRoutes />} />

              {/* Fallback */}
              <Route path="*" element={<Navigate to="/" replace />} />
            </Routes>
          </BrowserRouter>
        </SurvivorProvider>
      </GuardianAuthProvider>
    </AuthProvider>
  );
};

export default App;
