import React, { useState } from 'react';
import { Mic, MicOff, Check, Heart, Smile, Meh, Frown, Sparkles, Send } from 'lucide-react';
import { GroundedCard } from '../common/GroundedCard';
import { OrganicButton } from '../common/OrganicButton';
import { TopographyDivider } from '../common/TopographyDivider';
import { useSurvivor } from '../../context/SurvivorContext';
import { saveCheckin } from '../../lib/firebase/firestore';

export const DailyCheckin: React.FC = () => {
  const { pseudonym, addCheckin } = useSurvivor();
  const [selectedMood, setSelectedMood] = useState<number | null>(3);
  const [note, setNote] = useState('');
  const [isRecording, setIsRecording] = useState(false);
  const [recordingSeconds, setRecordingSeconds] = useState(0);
  const [recordingDone, setRecordingDone] = useState(false);
  const [submitted, setSubmitted] = useState(false);
  const [timerInterval, setTimerInterval] = useState<any>(null);

  const moodOptions = [
    { value: 1, label: 'Heavy / Distressed', icon: Frown, color: 'text-mool-signal bg-mool-signal/10 border-mool-signal/30' },
    { value: 2, label: 'Unsettled', icon: Meh, color: 'text-mool-sandrose bg-mool-sandrose/10 border-mool-sandrose/30' },
    { value: 3, label: 'Steady', icon: Smile, color: 'text-mool-ink-muted bg-mool-mist/50 border-mool-mist' },
    { value: 4, label: 'Grounded', icon: Heart, color: 'text-mool-moss bg-mool-moss/10 border-mool-moss/30' },
    { value: 5, label: 'Peaceful', icon: Sparkles, color: 'text-mool-moss-dark bg-mool-moss/20 border-mool-moss' },
  ];

  const handleToggleRecord = () => {
    if (isRecording) {
      clearInterval(timerInterval);
      setIsRecording(false);
      setRecordingDone(true);
    } else {
      setIsRecording(true);
      setRecordingDone(false);
      setRecordingSeconds(0);
      const interval = setInterval(() => {
        setRecordingSeconds(prev => prev + 1);
      }, 1000);
      setTimerInterval(interval);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedMood) return;

    const entryData = {
      moodScore: selectedMood,
      note: note.trim(),
      voiceUrl: recordingDone ? 'mock_voice_note.webm' : undefined,
      voiceDurationSeconds: recordingDone ? recordingSeconds : undefined,
      tags: ['Daily Grounding'],
    };

    addCheckin(entryData);
    await saveCheckin(entryData);
    setSubmitted(true);
  };

  const handleReset = () => {
    setSubmitted(false);
    setNote('');
    setSelectedMood(3);
    setRecordingDone(false);
    setRecordingSeconds(0);
  };

  return (
    <div className="max-w-md mx-auto p-4 space-y-5 pb-24">
      {/* Grounding Header Banner */}
      <div className="space-y-1">
        <span className="text-xs font-semibold text-mool-moss tracking-wide uppercase">Gentle Check-in</span>
        <h1 className="font-serif text-2xl text-mool-ink font-semibold">How are you feeling today, {pseudonym}?</h1>
        <p className="text-xs text-mool-ink-muted leading-relaxed">
          There are no wrong answers here. Take a breath and check in with your mind and body.
        </p>
      </div>

      <TopographyDivider variant="moss" />

      {submitted ? (
        <GroundedCard variant="primary" className="text-center py-8 space-y-4">
          <div className="w-14 h-14 rounded-full bg-mool-moss/15 text-mool-moss flex items-center justify-center mx-auto">
            <Check className="w-8 h-8" />
          </div>
          <div className="space-y-1">
            <h2 className="font-serif text-xl text-mool-ink font-semibold">Thank you for checking in</h2>
            <p className="text-xs text-mool-ink-muted max-w-xs mx-auto leading-relaxed">
              Your reflection has been quietly recorded in your private journal space. Take gentle care of yourself today.
            </p>
          </div>
          <div className="pt-2">
            <OrganicButton variant="moss" size="sm" onClick={handleReset}>
              <span>Record another entry</span>
            </OrganicButton>
          </div>
        </GroundedCard>
      ) : (
        <form onSubmit={handleSubmit} className="space-y-5">
          {/* 1. Mood Scale Selection */}
          <div className="space-y-2">
            <label className="block text-xs font-semibold text-mool-ink">
              1. How grounded or settled do you feel right now?
            </label>
            <div className="grid grid-cols-5 gap-2">
              {moodOptions.map(option => {
                const Icon = option.icon;
                const isSelected = selectedMood === option.value;
                return (
                  <button
                    key={option.value}
                    type="button"
                    onClick={() => setSelectedMood(option.value)}
                    className={`flex flex-col items-center justify-center p-2.5 rounded-organic border transition-all ${
                      isSelected
                        ? `${option.color} ring-2 ring-mool-moss font-semibold shadow-sm scale-105`
                        : 'bg-white border-mool-mist text-mool-ink-muted hover:border-mool-moss/50'
                    }`}
                  >
                    <Icon className="w-5 h-5 mb-1" />
                    <span className="text-[10px] text-center line-clamp-1">{option.value}</span>
                  </button>
                );
              })}
            </div>
            {selectedMood && (
              <p className="text-xs text-center text-mool-moss font-medium pt-1">
                Selected: {moodOptions.find(m => m.value === selectedMood)?.label}
              </p>
            )}
          </div>

          {/* 2. Free Text Journal Note */}
          <div className="space-y-1.5">
            <label htmlFor="checkin-note" className="block text-xs font-semibold text-mool-ink">
              2. Share a few thoughts or what's on your mind (Optional)
            </label>
            <textarea
              id="checkin-note"
              rows={3}
              value={note}
              onChange={(e) => setNote(e.target.value)}
              placeholder="e.g. Spent 10 minutes sitting outside in quiet daylight..."
              className="w-full p-3 bg-white border border-mool-mist rounded-organic text-xs text-mool-ink focus:border-mool-moss focus:ring-1 focus:ring-mool-moss leading-relaxed resize-none"
            />
          </div>

          {/* 3. Audio Voice Note Recording (Simulated) */}
          <div className="space-y-2">
            <label className="block text-xs font-semibold text-mool-ink">
              3. Record a voice note instead (Optional)
            </label>
            
            <div className="bg-mool-mist/30 border border-mool-mist rounded-organic p-4 flex items-center justify-between">
              <div className="flex items-center space-x-3">
                <button
                  type="button"
                  onClick={handleToggleRecord}
                  className={`w-10 h-10 rounded-full flex items-center justify-center transition-all ${
                    isRecording
                      ? 'bg-mool-signal text-white animate-pulse'
                      : recordingDone
                      ? 'bg-mool-moss text-white'
                      : 'bg-mool-linen text-mool-ink border border-mool-mist hover:bg-mool-mist'
                  }`}
                >
                  {isRecording ? <MicOff className="w-5 h-5" /> : <Mic className="w-5 h-5" />}
                </button>
                <div>
                  <span className="text-xs font-medium text-mool-ink block">
                    {isRecording ? 'Recording audio...' : recordingDone ? 'Voice note ready' : 'Tap mic to speak'}
                  </span>
                  <span className="text-[10px] text-mool-ink-muted">
                    {isRecording ? `${recordingSeconds}s elapsed` : recordingDone ? `${recordingSeconds}s captured` : 'Encrypted voice attachment'}
                  </span>
                </div>
              </div>

              {recordingDone && (
                <span className="text-xs text-mool-moss font-semibold flex items-center space-x-1">
                  <Check className="w-3.5 h-3.5" />
                  <span>Attached</span>
                </span>
              )}
            </div>
          </div>

          {/* Submit Button */}
          <OrganicButton type="submit" variant="moss" fullWidth size="lg">
            <Send className="w-4 h-4 mr-2" />
            <span>Complete Reflection</span>
          </OrganicButton>
        </form>
      )}
    </div>
  );
};

