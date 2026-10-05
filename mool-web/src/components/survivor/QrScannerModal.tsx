import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { QrCode, Upload, CheckCircle2, AlertCircle, Loader2 } from 'lucide-react';
import { GroundedCard } from '../common/GroundedCard';
import { OrganicButton } from '../common/OrganicButton';
import { exchangeQrToken } from '../../lib/firebase/functions';
import { useAuth } from '../../context/AuthContext';

export const QrScannerModal: React.FC = () => {
  const [pairingCode, setPairingCode] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [pairedSuccess, setPairedSuccess] = useState(false);
  const navigate = useNavigate();
  const { loginAsSurvivor } = useAuth();

  const handleScanSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!pairingCode.trim()) {
      setError('Please enter or scan a pairing token from your caseworker.');
      return;
    }
    setLoading(true);
    setError('');

    try {
      // INTEGRATION POINT: exchangeQrToken function call
      const res = await exchangeQrToken(pairingCode.trim());
      loginAsSurvivor(res.beneficiaryId, res.pseudonym);
      setPairedSuccess(true);
      setTimeout(() => {
        navigate('/app/consent');
      }, 1200);
    } catch (err: any) {
      setError(err.message || 'Invalid or expired pairing code. Please ask your caseworker for a fresh QR.');
    } finally {
      setLoading(false);
    }
  };

  const handleDemoScan = () => {
    setPairingCode('mool-pair-demo-7712');
  };

  return (
    <div className="min-h-screen bg-mool-linen flex items-center justify-center p-4">
      <div className="max-w-md w-full">
        {/* Grounding Header */}
        <div className="text-center mb-6">
          <div className="w-12 h-12 rounded-full bg-mool-moss/15 text-mool-moss flex items-center justify-center mx-auto mb-3 font-serif text-2xl font-bold">
            म
          </div>
          <h1 className="font-serif text-2xl sm:text-3xl text-mool-ink font-semibold">Welcome to Mool</h1>
          <p className="text-mool-ink-muted text-sm mt-1">
            Scan or enter your private pairing code provided by your NGO or caseworker.
          </p>
        </div>

        <GroundedCard variant="primary" className="space-y-5">
          {pairedSuccess ? (
            <div className="text-center py-6 space-y-3">
              <CheckCircle2 className="w-12 h-12 text-mool-moss mx-auto animate-bounce" />
              <h2 className="font-serif text-xl text-mool-ink font-medium">Pairing Verified</h2>
              <p className="text-sm text-mool-ink-muted">Securing your private grounding space...</p>
            </div>
          ) : (
            <form onSubmit={handleScanSubmit} className="space-y-4">
              {/* Simulated Camera Viewfinder */}
              <div className="relative border-2 border-dashed border-mool-moss/40 rounded-organic bg-mool-mist/30 p-6 text-center space-y-2">
                <QrCode className="w-10 h-10 text-mool-moss mx-auto animate-pulse" />
                <p className="text-xs text-mool-ink-muted">Align QR code within the frame</p>
                
                <div className="pt-2">
                  <button
                    type="button"
                    onClick={handleDemoScan}
                    className="inline-flex items-center space-x-1.5 text-xs font-medium text-mool-moss hover:underline"
                  >
                    <Upload className="w-3.5 h-3.5" />
                    <span>Auto-fill Demo QR Token</span>
                  </button>
                </div>
              </div>

              {/* Manual input fallback */}
              <div>
                <label htmlFor="token-input" className="block text-xs font-medium text-mool-ink-muted mb-1">
                  Or enter token manually
                </label>
                <input
                  id="token-input"
                  type="text"
                  value={pairingCode}
                  onChange={(e) => setPairingCode(e.target.value)}
                  placeholder="e.g. mool-pair-xxxx-xxxx"
                  className="w-full px-3.5 py-2.5 bg-white border border-mool-mist rounded-organic text-sm text-mool-ink focus:border-mool-moss focus:ring-1 focus:ring-mool-moss"
                />
              </div>

              {error && (
                <div className="p-3 bg-mool-signal-soft text-mool-signal border border-mool-signal/20 rounded-organic text-xs flex items-start space-x-2">
                  <AlertCircle className="w-4 h-4 shrink-0 mt-0.5" />
                  <span>{error}</span>
                </div>
              )}

              <OrganicButton type="submit" variant="moss" fullWidth disabled={loading}>
                {loading ? (
                  <>
                    <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                    <span>Verifying pairing token...</span>
                  </>
                ) : (
                  <span>Continue to Grounding Consent</span>
                )}
              </OrganicButton>
            </form>
          )}

          <div className="pt-2 text-center border-t border-mool-mist/60">
            <p className="text-xs text-mool-ink-muted">
              Are you a responder or caseworker?{' '}
              <a href="/portal/login" className="text-mool-dusk font-semibold underline hover:text-mool-dusk-dark">
                Go to Responder Portal
              </a>
            </p>
          </div>
        </GroundedCard>
      </div>
    </div>
  );
};

