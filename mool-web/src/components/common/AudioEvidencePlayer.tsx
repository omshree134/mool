import React, { useState, useRef, useEffect } from 'react';
import { Play, Pause, Volume2, VolumeX, Download, Clock, Radio } from 'lucide-react';

interface AudioEvidencePlayerProps {
  src?: string;
  title?: string;
  kind?: string;
  timestamp?: string;
  durationSec?: number;
  sha256?: string;
  className?: string;
}

export const AudioEvidencePlayer: React.FC<AudioEvidencePlayerProps> = ({
  src,
  title = 'Audio Evidence Recording',
  kind = 'report',
  timestamp,
  durationSec,
  sha256,
  className = '',
}) => {
  const audioRef = useRef<HTMLAudioElement | null>(null);
  const [isPlaying, setIsPlaying] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);
  const [duration, setDuration] = useState(durationSec || 0);
  const [isMuted, setIsMuted] = useState(false);
  const [error, setError] = useState(false);

  useEffect(() => {
    const audio = audioRef.current;
    if (!audio) return;

    const onTimeUpdate = () => setCurrentTime(audio.currentTime);
    const onLoadedMetadata = () => {
      if (audio.duration && !isNaN(audio.duration) && isFinite(audio.duration)) {
        setDuration(audio.duration);
      }
    };
    const onEnded = () => setIsPlaying(false);
    const onError = () => {
      console.warn('Audio playback error for:', src);
      setError(true);
      setIsPlaying(false);
    };

    audio.addEventListener('timeupdate', onTimeUpdate);
    audio.addEventListener('loadedmetadata', onLoadedMetadata);
    audio.addEventListener('ended', onEnded);
    audio.addEventListener('error', onError);

    return () => {
      audio.removeEventListener('timeupdate', onTimeUpdate);
      audio.removeEventListener('loadedmetadata', onLoadedMetadata);
      audio.removeEventListener('ended', onEnded);
      audio.removeEventListener('error', onError);
    };
  }, [src]);

  const togglePlay = () => {
    if (!audioRef.current || !src) return;
    if (isPlaying) {
      audioRef.current.pause();
      setIsPlaying(false);
    } else {
      audioRef.current.play()
        .then(() => setIsPlaying(true))
        .catch((e) => {
          console.warn('Audio play request failed:', e);
          setIsPlaying(false);
        });
    }
  };

  const handleSeek = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (!audioRef.current) return;
    const newTime = parseFloat(e.target.value);
    audioRef.current.currentTime = newTime;
    setCurrentTime(newTime);
  };

  const toggleMute = () => {
    if (!audioRef.current) return;
    audioRef.current.muted = !isMuted;
    setIsMuted(!isMuted);
  };

  const formatTime = (secs: number) => {
    if (isNaN(secs) || !isFinite(secs)) return '0:00';
    const m = Math.floor(secs / 60);
    const s = Math.floor(secs % 60);
    return `${m}:${s < 10 ? '0' : ''}${s}`;
  };

  const getKindColor = () => {
    switch (kind?.toLowerCase()) {
      case 'sos':
        return 'bg-red-100 text-red-700 border-red-200';
      case 'report':
        return 'bg-amber-100 text-amber-800 border-amber-200';
      default:
        return 'bg-mool-moss/15 text-mool-moss-dark border-mool-moss/30';
    }
  };

  if (!src) {
    return (
      <div className={`p-3 bg-mool-mist/30 rounded-xl border border-mool-mist text-xs text-mool-ink-muted flex items-center space-x-2 ${className}`}>
        <VolumeX className="w-4 h-4 opacity-50" />
        <span>No audio recording available for this item</span>
      </div>
    );
  }

  return (
    <div className={`bg-white border border-mool-mist rounded-organic p-3.5 space-y-2.5 shadow-sm ${className}`}>
      {/* Hidden native audio element */}
      <audio ref={audioRef} src={src} preload="metadata" />

      {/* Top Header: Title & Badges */}
      <div className="flex items-center justify-between gap-2 flex-wrap">
        <div className="flex items-center space-x-2">
          <div className={`p-1.5 rounded-lg ${isPlaying ? 'bg-mool-moss text-white animate-pulse' : 'bg-mool-mist text-mool-ink'}`}>
            <Radio className="w-3.5 h-3.5" />
          </div>
          <div>
            <h5 className="text-xs font-bold text-mool-ink tracking-tight flex items-center space-x-1.5">
              <span>{title}</span>
              {isPlaying && (
                <span className="inline-flex space-x-0.5 items-end h-3">
                  <span className="w-0.5 h-2 bg-mool-moss animate-pulse" />
                  <span className="w-0.5 h-3 bg-mool-moss animate-pulse delay-75" />
                  <span className="w-0.5 h-1.5 bg-mool-moss animate-pulse delay-150" />
                </span>
              )}
            </h5>
            {timestamp && (
              <span className="text-[10px] text-mool-ink-muted flex items-center space-x-1">
                <Clock className="w-2.5 h-2.5" />
                <span>{new Date(timestamp).toLocaleString([], { dateStyle: 'short', timeStyle: 'short' })}</span>
              </span>
            )}
          </div>
        </div>

        <div className="flex items-center space-x-1.5">
          <span className={`text-[10px] uppercase font-bold px-2 py-0.5 rounded border ${getKindColor()}`}>
            {kind === 'sos' ? 'SOS Ambient Audio' : kind === 'report' ? 'Incident Audio' : 'Voice Evidence'}
          </span>
          {sha256 && (
            <span
              className="text-[9px] font-mono bg-mool-mist px-1.5 py-0.5 rounded text-mool-ink-muted hidden sm:inline"
              title={`Forensic SHA-256: ${sha256}`}
            >
              SHA:{sha256.substring(0, 6)}…
            </span>
          )}
        </div>
      </div>

      {/* Player Controls Bar */}
      <div className="flex items-center space-x-3 bg-mool-mist/30 p-2 rounded-xl">
        {/* Play / Pause Button */}
        <button
          onClick={togglePlay}
          className="w-8 h-8 rounded-full bg-mool-moss text-white hover:bg-mool-moss-dark flex items-center justify-center shadow-sm shrink-0 transition-transform active:scale-95"
          title={isPlaying ? 'Pause' : 'Play audio recording'}
        >
          {isPlaying ? <Pause className="w-4 h-4 fill-white" /> : <Play className="w-4 h-4 ml-0.5 fill-white" />}
        </button>

        {/* Time Progress */}
        <span className="text-[11px] font-mono text-mool-ink-muted w-10 text-right">
          {formatTime(currentTime)}
        </span>

        {/* Seek Scrubber Bar */}
        <input
          type="range"
          min="0"
          max={duration > 0 ? duration : 100}
          step="0.1"
          value={currentTime}
          onChange={handleSeek}
          className="flex-1 accent-mool-moss h-1.5 bg-mool-mist rounded-lg cursor-pointer"
        />

        <span className="text-[11px] font-mono text-mool-ink-muted w-10">
          {formatTime(duration)}
        </span>

        {/* Volume Mute Toggle */}
        <button
          onClick={toggleMute}
          className="text-mool-ink-muted hover:text-mool-ink p-1 rounded transition-colors"
          title={isMuted ? 'Unmute' : 'Mute'}
        >
          {isMuted ? <VolumeX className="w-4 h-4 text-mool-signal" /> : <Volume2 className="w-4 h-4" />}
        </button>

        {/* Direct Download Link */}
        {(src.startsWith('http') || src.startsWith('data:')) && (
          <a
            href={src}
            download={`mool_evidence_${kind}_${Date.now()}.m4a`}
            className="text-mool-ink-muted hover:text-mool-ink p-1 rounded transition-colors"
            title="Download evidence audio file"
          >
            <Download className="w-3.5 h-3.5" />
          </a>
        )}
      </div>

      {error && (
        <p className="text-[10px] text-mool-signal">
          Audio format not directly streamable in this browser. Try downloading the raw audio file.
        </p>
      )}
    </div>
  );
};
