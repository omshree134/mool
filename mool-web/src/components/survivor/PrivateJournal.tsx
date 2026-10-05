import React from 'react';
import { BookOpen, Calendar, Lock, Volume2 } from 'lucide-react';
import { GroundedCard } from '../common/GroundedCard';
import { TopographyDivider } from '../common/TopographyDivider';
import { useSurvivor } from '../../context/SurvivorContext';

export const PrivateJournal: React.FC = () => {
  const { checkins, pseudonym } = useSurvivor();

  const getMoodBadge = (score: number) => {
    switch (score) {
      case 5: return { label: 'Peaceful', color: 'bg-mool-moss/20 text-mool-moss-dark' };
      case 4: return { label: 'Grounded', color: 'bg-mool-moss/10 text-mool-moss' };
      case 3: return { label: 'Steady', color: 'bg-mool-mist text-mool-ink-muted' };
      case 2: return { label: 'Unsettled', color: 'bg-mool-sandrose/20 text-mool-sandrose' };
      case 1: return { label: 'Distressed', color: 'bg-mool-signal/15 text-mool-signal' };
      default: return { label: 'Recorded', color: 'bg-mool-mist text-mool-ink' };
    }
  };

  return (
    <div className="max-w-md mx-auto p-4 space-y-5 pb-24">
      <div className="space-y-1">
        <div className="flex items-center space-x-2 text-xs text-mool-moss font-semibold">
          <Lock className="w-3.5 h-3.5" />
          <span>Private & Encrypted</span>
        </div>
        <h1 className="font-serif text-2xl text-mool-ink font-semibold">{pseudonym}'s Reflection Journal</h1>
        <p className="text-xs text-mool-ink-muted">
          Your personal space to look back on your feelings and grounding moments.
        </p>
      </div>

      <TopographyDivider variant="mist" />

      {checkins.length === 0 ? (
        <GroundedCard variant="primary" className="text-center py-10 space-y-3">
          <BookOpen className="w-10 h-10 text-mool-moss/40 mx-auto" />
          <h2 className="font-serif text-base text-mool-ink font-semibold">No journal entries yet</h2>
          <p className="text-xs text-mool-ink-muted">Your daily check-in reflections will appear safely here.</p>
        </GroundedCard>
      ) : (
        <div className="space-y-3">
          {checkins.map((entry) => {
            const badge = getMoodBadge(entry.moodScore);
            const dateStr = new Date(entry.timestamp).toLocaleDateString(undefined, {
              weekday: 'short',
              month: 'short',
              day: 'numeric',
              hour: '2-digit',
              minute: '2-digit',
            });

            return (
              <GroundedCard key={entry.id} variant="primary" className="space-y-2 p-4">
                <div className="flex items-center justify-between">
                  <div className="flex items-center space-x-2 text-[11px] text-mool-ink-muted">
                    <Calendar className="w-3.5 h-3.5 text-mool-moss" />
                    <span>{dateStr}</span>
                  </div>
                  
                  <span className={`text-[10px] px-2.5 py-0.5 rounded-full font-semibold ${badge.color}`}>
                    {badge.label} ({entry.moodScore}/5)
                  </span>
                </div>

                {entry.note && (
                  <p className="text-xs text-mool-ink leading-relaxed font-sans pt-1">
                    "{entry.note}"
                  </p>
                )}

                {entry.voiceUrl && (
                  <div className="pt-2 flex items-center space-x-2 text-xs text-mool-dusk bg-mool-dusk/5 p-2 rounded-organic border border-mool-dusk/10">
                    <Volume2 className="w-4 h-4 text-mool-dusk shrink-0" />
                    <span className="text-[11px] font-medium">Voice note attached ({entry.voiceDurationSeconds || 12}s)</span>
                  </div>
                )}

                {entry.tags && entry.tags.length > 0 && (
                  <div className="flex flex-wrap gap-1 pt-1">
                    {entry.tags.map((t, idx) => (
                      <span key={idx} className="text-[9px] bg-mool-mist/50 text-mool-ink-muted px-2 py-0.5 rounded-md">
                        #{t}
                      </span>
                    ))}
                  </div>
                )}
              </GroundedCard>
            );
          })}
        </div>
      )}
    </div>
  );
};

