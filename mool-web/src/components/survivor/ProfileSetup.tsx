import React from 'react';
import { useNavigate } from 'react-router-dom';
import { User, Phone, Globe, ArrowRight } from 'lucide-react';
import { GroundedCard } from '../common/GroundedCard';
import { OrganicButton } from '../common/OrganicButton';
import { useSurvivor } from '../../context/SurvivorContext';

export const ProfileSetup: React.FC = () => {
  const navigate = useNavigate();
  const { pseudonym, setPseudonym, language, setLanguage, emergencyContact, setEmergencyContact } = useSurvivor();

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    navigate('/app/home');
  };

  return (
    <div className="min-h-screen bg-mool-linen flex items-center justify-center p-4">
      <div className="max-w-md w-full py-6 space-y-6">
        <div>
          <h1 className="font-serif text-2xl sm:text-3xl text-mool-ink font-semibold">Lightweight Setup</h1>
          <p className="text-mool-ink-muted text-sm mt-1">
            Choose how you would like to be addressed in the app. All fields are optional.
          </p>
        </div>

        <GroundedCard variant="primary">
          <form onSubmit={handleSubmit} className="space-y-4">
            {/* Pseudonym Field */}
            <div>
              <label htmlFor="pseudonym" className="block text-xs font-semibold text-mool-ink mb-1.5 flex items-center space-x-1.5">
                <User className="w-3.5 h-3.5 text-mool-moss" />
                <span>Preferred Name / Pseudonym</span>
              </label>
              <input
                id="pseudonym"
                type="text"
                value={pseudonym}
                onChange={(e) => setPseudonym(e.target.value)}
                placeholder="e.g. Aarav, Hope, or keep blank"
                className="w-full px-3.5 py-2.5 bg-white border border-mool-mist rounded-organic text-sm text-mool-ink focus:border-mool-moss focus:ring-1 focus:ring-mool-moss"
              />
              <p className="text-[11px] text-mool-ink-faint mt-1">You do not need to use your legal name.</p>
            </div>

            {/* Language Preference */}
            <div>
              <label htmlFor="language" className="block text-xs font-semibold text-mool-ink mb-1.5 flex items-center space-x-1.5">
                <Globe className="w-3.5 h-3.5 text-mool-moss" />
                <span>Preferred Language</span>
              </label>
              <select
                id="language"
                value={language}
                onChange={(e) => setLanguage(e.target.value)}
                className="w-full px-3.5 py-2.5 bg-white border border-mool-mist rounded-organic text-sm text-mool-ink focus:border-mool-moss focus:ring-1 focus:ring-mool-moss"
              >
                <option value="en">English</option>
                <option value="hi">हिंदी (Hindi)</option>
                <option value="mr">मराठी (Marathi)</option>
                <option value="bn">বাংলা (Bengali)</option>
                <option value="ta">தமிழ் (Tamil)</option>
              </select>
            </div>

            {/* Emergency Contact */}
            <div>
              <label htmlFor="emergency-contact" className="block text-xs font-semibold text-mool-ink mb-1.5 flex items-center space-x-1.5">
                <Phone className="w-3.5 h-3.5 text-mool-sandrose" />
                <span>Emergency Contact (Optional)</span>
              </label>
              <input
                id="emergency-contact"
                type="text"
                value={emergencyContact}
                onChange={(e) => setEmergencyContact(e.target.value)}
                placeholder="e.g. Trusted friend or helpline number"
                className="w-full px-3.5 py-2.5 bg-white border border-mool-mist rounded-organic text-sm text-mool-ink focus:border-mool-moss focus:ring-1 focus:ring-mool-moss"
              />
            </div>

            <div className="pt-3">
              <OrganicButton type="submit" variant="moss" fullWidth>
                <span>Complete Setup & Enter Home</span>
                <ArrowRight className="w-4 h-4 ml-2" />
              </OrganicButton>
            </div>
          </form>
        </GroundedCard>
      </div>
    </div>
  );
};

