import React from 'react';
import { useNavigate } from 'react-router-dom';
import { ShieldCheck, Lock, Eye, PauseCircle, ArrowRight } from 'lucide-react';
import { GroundedCard } from '../common/GroundedCard';
import { OrganicButton } from '../common/OrganicButton';
import { useSurvivor } from '../../context/SurvivorContext';

export const ConsentScreen: React.FC = () => {
  const navigate = useNavigate();
  const { setHasConsented } = useSurvivor();

  const handleAccept = () => {
    setHasConsented(true);
    navigate('/app/profile');
  };

  return (
    <div className="min-h-screen bg-mool-linen flex items-center justify-center p-4">
      <div className="max-w-md w-full py-6 space-y-6">
        <div className="space-y-2">
          <div className="inline-flex items-center space-x-2 px-3 py-1 bg-mool-moss/10 text-mool-moss rounded-full text-xs font-semibold">
            <ShieldCheck className="w-4 h-4" />
            <span>Safety & Privacy First</span>
          </div>
          <h1 className="font-serif text-2xl sm:text-3xl text-mool-ink font-semibold">Your privacy and choice come first</h1>
          <p className="text-mool-ink-muted text-sm leading-relaxed">
            Mool is designed to quietly keep watch over your emotional wellbeing without ever invading your space or feeling surveillant.
          </p>
        </div>

        {/* 3 Plain-Language Safety Guarantees */}
        <div className="space-y-3">
          <GroundedCard variant="primary" elevation="flat" className="flex items-start space-x-3 p-4">
            <Lock className="w-5 h-5 text-mool-moss shrink-0 mt-0.5" />
            <div>
              <h3 className="font-semibold text-sm text-mool-ink">What is stored</h3>
              <p className="text-xs text-mool-ink-muted leading-relaxed mt-0.5">
                Your optional check-in mood scores, journal reflections, and audio notes. Everything is encrypted in transit and at rest.
              </p>
            </div>
          </GroundedCard>

          <GroundedCard variant="primary" elevation="flat" className="flex items-start space-x-3 p-4">
            <Eye className="w-5 h-5 text-mool-dusk shrink-0 mt-0.5" />
            <div>
              <h3 className="font-semibold text-sm text-mool-ink">Who can see it</h3>
              <p className="text-xs text-mool-ink-muted leading-relaxed mt-0.5">
                Only your assigned caseworker or crisis responder. No raw journal entries are exposed publicly or shared without consent.
              </p>
            </div>
          </GroundedCard>

          <GroundedCard variant="primary" elevation="flat" className="flex items-start space-x-3 p-4">
            <PauseCircle className="w-5 h-5 text-mool-sandrose shrink-0 mt-0.5" />
            <div>
              <h3 className="font-semibold text-sm text-mool-ink">You are always in control</h3>
              <p className="text-xs text-mool-ink-muted leading-relaxed mt-0.5">
                You can pause check-ins, change your pseudonym, or revoke access at any moment with zero pressure or judgment.
              </p>
            </div>
          </GroundedCard>
        </div>

        <div className="pt-2 space-y-3">
          <OrganicButton variant="moss" fullWidth onClick={handleAccept} className="shadow-sm">
            <span>I Understand & Agree</span>
            <ArrowRight className="w-4 h-4 ml-2" />
          </OrganicButton>
        </div>
      </div>
    </div>
  );
};

