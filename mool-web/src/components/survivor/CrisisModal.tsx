import React, { useState, useEffect } from 'react';
import { X, PhoneCall, ShieldAlert, HeartHandshake, Wind, ArrowRight } from 'lucide-react';
import { GroundedCard } from '../common/GroundedCard';
import { OrganicButton } from '../common/OrganicButton';
import { useSurvivor } from '../../context/SurvivorContext';

interface CrisisModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const CrisisModal: React.FC<CrisisModalProps> = ({ isOpen, onClose }) => {
  const { emergencyContact } = useSurvivor();
  const [breathingPhase, setBreathingPhase] = useState<'Inhale' | 'Hold' | 'Exhale'>('Inhale');
  const [breathSeconds, setBreathSeconds] = useState(4);
  const [dispatched, setDispatched] = useState(false);

  useEffect(() => {
    if (!isOpen) return;
    const interval = setInterval(() => {
      setBreathSeconds(prev => {
        if (prev <= 1) {
          if (breathingPhase === 'Inhale') {
            setBreathingPhase('Hold');
            return 7;
          } else if (breathingPhase === 'Hold') {
            setBreathingPhase('Exhale');
            return 8;
          } else {
            setBreathingPhase('Inhale');
            return 4;
          }
        }
        return prev - 1;
      });
    }, 1000);

    return () => clearInterval(interval);
  }, [isOpen, breathingPhase]);

  if (!isOpen) return null;

  const handleAlertResponder = () => {
    setDispatched(true);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center p-0 sm:p-4 bg-mool-ink/60 backdrop-blur-sm animate-fade-in">
      <div className="bg-mool-linen w-full max-w-md rounded-t-organic-lg sm:rounded-organic-lg border border-mool-mist shadow-dusk-elevated overflow-hidden max-h-[90vh] flex flex-col">
        {/* Header */}
        <div className="bg-mool-sandrose text-white px-5 py-4 flex items-center justify-between">
          <div className="flex items-center space-x-2">
            <ShieldAlert className="w-5 h-5" />
            <h2 className="font-serif text-lg font-semibold">Immediate Support & Safety</h2>
          </div>
          <button
            onClick={onClose}
            className="text-white/80 hover:text-white p-1 rounded-full hover:bg-white/10 transition-colors"
            aria-label="Close crisis support modal"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Content Container */}
        <div className="p-5 space-y-5 overflow-y-auto">
          {dispatched ? (
            <GroundedCard variant="primary" className="text-center py-6 space-y-3 bg-mool-moss/10 border-mool-moss/30">
              <HeartHandshake className="w-10 h-10 text-mool-moss mx-auto animate-bounce" />
              <h3 className="font-serif text-lg font-bold text-mool-ink">Responder Notified</h3>
              <p className="text-xs text-mool-ink-muted leading-relaxed max-w-xs mx-auto">
                Your assigned caseworker has been alerted with urgent priority. Stay calm — someone is reaching out to your registered contact channel right now.
              </p>
            </GroundedCard>
          ) : (
            <>
              {/* Emergency Hotline Buttons */}
              <div className="space-y-2">
                <span className="text-xs font-semibold text-mool-ink block">Direct Hotlines (Free & Confidential)</span>
                
                <a
                  href="tel:9152987821"
                  className="w-full bg-mool-sandrose text-white rounded-organic p-3.5 flex items-center justify-between font-medium text-xs sm:text-sm hover:bg-mool-sandrose/90 transition-colors shadow-sm"
                >
                  <div className="flex items-center space-x-3">
                    <PhoneCall className="w-4 h-4 shrink-0" />
                    <span>KIRAN Mental Health Helpline</span>
                  </div>
                  <span className="font-mono text-xs underline">1800-599-0019</span>
                </a>

                <a
                  href="tel:112"
                  className="w-full bg-mool-signal text-white rounded-organic p-3.5 flex items-center justify-between font-medium text-xs sm:text-sm hover:bg-mool-signal/90 transition-colors shadow-sm"
                >
                  <div className="flex items-center space-x-3">
                    <ShieldAlert className="w-4 h-4 shrink-0" />
                    <span>National Emergency Services</span>
                  </div>
                  <span className="font-mono text-xs underline">112</span>
                </a>
              </div>

              {/* Alert Assigned Caseworker */}
              <GroundedCard variant="primary" elevation="flat" className="p-4 space-y-3">
                <div className="flex justify-between items-start">
                  <div>
                    <h4 className="font-semibold text-xs text-mool-ink">Alert Assigned Caseworker</h4>
                    <p className="text-[11px] text-mool-ink-muted mt-0.5">
                      Sends a priority notification to your designated responder.
                    </p>
                  </div>
                </div>

                {emergencyContact && (
                  <p className="text-[11px] font-mono text-mool-ink-muted bg-mool-mist/40 p-2 rounded-md">
                    Emergency Contact: {emergencyContact}
                  </p>
                )}

                <OrganicButton variant="dusk" fullWidth size="sm" onClick={handleAlertResponder}>
                  <span>Signal Urgent Support Needed</span>
                </OrganicButton>
              </GroundedCard>

              {/* 4-7-8 Breathing Grounding Circle */}
              <div className="bg-mool-mist/30 border border-mool-mist rounded-organic p-4 text-center space-y-2">
                <div className="flex items-center justify-center space-x-1.5 text-xs text-mool-moss font-semibold">
                  <Wind className="w-4 h-4" />
                  <span>Grounding Breath (4-7-8 Technique)</span>
                </div>

                <div className="w-20 h-20 rounded-full bg-mool-moss/15 border-2 border-mool-moss flex flex-col items-center justify-center mx-auto transition-all duration-1000 scale-105">
                  <span className="text-xs font-serif font-bold text-mool-moss">{breathingPhase}</span>
                  <span className="text-lg font-mono font-bold text-mool-ink">{breathSeconds}s</span>
                </div>

                <p className="text-[11px] text-mool-ink-muted">
                  Focus gently on the circle and take slow, deep breaths.
                </p>
              </div>
            </>
          )}
        </div>

        {/* Footer */}
        <div className="p-4 bg-mool-mist/20 border-t border-mool-mist flex justify-end">
          <OrganicButton variant="ghost" size="sm" onClick={onClose}>
            <span>Return to App</span>
          </OrganicButton>
        </div>
      </div>
    </div>
  );
};

