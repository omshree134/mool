/**
 * Generates a lightweight, self-contained 2-second dual-tone audible WAV chime.
 * Used for demo audio recordings and testing playback without external network requests.
 */
export function getSampleAudioDataUri(pitch: 'high' | 'alert' | 'voice' = 'alert'): string {
  const sampleRate = 8000;
  const numChannels = 1;
  const bitsPerSample = 16;
  const durationSec = 1.8;
  const numSamples = Math.floor(sampleRate * durationSec);
  const blockAlign = numChannels * (bitsPerSample / 8);
  const byteRate = sampleRate * blockAlign;
  const dataSize = numSamples * blockAlign;
  const buffer = new ArrayBuffer(44 + dataSize);
  const view = new DataView(buffer);

  const writeString = (offset: number, str: string) => {
    for (let i = 0; i < str.length; i++) view.setUint8(offset + i, str.charCodeAt(i));
  };

  writeString(0, 'RIFF');
  view.setUint32(4, 36 + dataSize, true);
  writeString(8, 'WAVE');
  writeString(12, 'fmt ');
  view.setUint32(16, 16, true);
  view.setUint16(20, 1, true); // PCM
  view.setUint16(22, numChannels, true);
  view.setUint32(24, sampleRate, true);
  view.setUint32(28, byteRate, true);
  view.setUint16(32, blockAlign, true);
  view.setUint16(34, bitsPerSample, true);
  writeString(36, 'data');
  view.setUint32(40, dataSize, true);

  const baseFreq = pitch === 'alert' ? 587.33 : pitch === 'high' ? 659.25 : 440.0;
  const harmonic = pitch === 'alert' ? 880.0 : pitch === 'high' ? 783.99 : 554.37;

  for (let i = 0; i < numSamples; i++) {
    const t = i / sampleRate;
    const freq = t < 0.9 ? baseFreq : harmonic;
    const envelope = Math.exp(-3.2 * (t % 0.9));
    const sample = Math.sin(2 * Math.PI * freq * t) * envelope * 0.55;
    view.setInt16(44 + i * 2, Math.floor(sample * 32767), true);
  }

  let binary = '';
  const bytes = new Uint8Array(buffer);
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return 'data:audio/wav;base64,' + btoa(binary);
}
