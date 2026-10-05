import React, { useState, useEffect } from 'react';
import { QRCodeSVG } from 'qrcode.react';
import { X, Copy, Check, QrCode, RefreshCw, ShieldCheck } from 'lucide-react';
import { GroundedCard } from '../common/GroundedCard';
import { OrganicButton } from '../common/OrganicButton';
import { generateQrToken } from '../../lib/firebase/functions';
import { QrToken } from '../../types';

interface QrGeneratorModalProps {
  isOpen: boolean;
  onClose: () => void;
  beneficiaryId: string;
  beneficiaryPseudonym: string;
}

export const QrGeneratorModal: React.FC<QrGeneratorModalProps> = ({
  isOpen,
  onClose,
  beneficiaryId,
  beneficiaryPseudonym,
}) => {
  const [tokenData, setTokenData] = useState<QrToken | null>(null);
  const [loading, setLoading] = useState(false);
  const [copied, setCopied] = useState(false);

  const fetchNewToken = async () => {
    setLoading(true);
    try {
      // INTEGRATION POINT 3: generateQrToken Cloud Function
      const data = await generateQrToken(beneficiaryId, 'resp-caseworker-singh');
      setTokenData(data);
    } catch (err) {
      console.error('Error generating pairing QR:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (isOpen && beneficiaryId) {
      fetchNewToken();
    }
  }, [isOpen, beneficiaryId]);

  if (!isOpen) return null;

  const handleCopyToken = () => {
    if (tokenData) {
      navigator.clipboard.writeText(tokenData.token);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-mool-ink/60 backdrop-blur-sm">
      <div className="bg-mool-linen w-full max-w-md rounded-organic-lg border border-mool-mist shadow-dusk-elevated overflow-hidden space-y-4">
        {/* Header */}
        <div className="bg-mool-dusk text-white p-5 flex items-center justify-between">
          <div className="flex items-center space-x-2">
            <QrCode className="w-5 h-5 text-mool-moss" />
            <h2 className="font-serif text-lg font-bold">Pairing QR Code Generator</h2>
          </div>
          <button onClick={onClose} className="text-white/80 hover:text-white p-1 rounded-full">
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Content Body */}
        <div className="p-5 space-y-4 text-center">
          <div>
            <span className="text-xs text-mool-ink-muted">Generating pairing credentials for:</span>
            <h3 className="font-serif text-xl font-bold text-mool-ink">{beneficiaryPseudonym}</h3>
            <span className="text-[11px] font-mono text-mool-moss font-semibold">ID: {beneficiaryId}</span>
          </div>

          {loading ? (
            <div className="py-12 space-y-2">
              <RefreshCw className="w-8 h-8 text-mool-moss animate-spin mx-auto" />
              <p className="text-xs text-mool-ink-muted">Minting secure 24-hour pairing token...</p>
            </div>
          ) : tokenData ? (
            <div className="space-y-4">
              {/* QR Code SVG rendering using qrcode.react */}
              <div className="bg-white p-6 rounded-organic border border-mool-mist inline-block shadow-soft-ground">
                <QRCodeSVG
                  value={tokenData.token}
                  size={190}
                  level="H"
                  includeMargin={true}
                  fgColor="#2E4452"
                  bgColor="#FFFFFF"
                />
              </div>

              {/* Pairing Token String & Expiry */}
              <div className="bg-mool-mist/30 border border-mool-mist rounded-organic p-3 space-y-1">
                <div className="flex items-center justify-between text-xs">
                  <span className="font-mono text-mool-ink font-semibold truncate max-w-[240px]">
                    {tokenData.token}
                  </span>
                  <button
                    onClick={handleCopyToken}
                    className="text-mool-dusk hover:text-mool-dusk-dark p-1 rounded font-medium flex items-center space-x-1"
                  >
                    {copied ? <Check className="w-4 h-4 text-mool-moss" /> : <Copy className="w-4 h-4" />}
                    <span className="text-[10px]">{copied ? 'Copied' : 'Copy'}</span>
                  </button>
                </div>
                <p className="text-[10px] text-mool-ink-faint text-left">
                  Expires: {new Date(tokenData.expiresAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })} (24 hours)
                </p>
              </div>
            </div>
          ) : null}

          <div className="pt-2 text-left bg-mool-moss/10 p-3 rounded-organic border border-mool-moss/20 flex items-start space-x-2 text-xs text-mool-ink">
            <ShieldCheck className="w-4 h-4 text-mool-moss shrink-0 mt-0.5" />
            <p className="text-[11px] text-mool-ink-muted leading-relaxed">
              Show this QR code to the survivor to scan in their Mool App. Once paired, this token will automatically expire and authenticate their private session.
            </p>
          </div>
        </div>

        {/* Footer */}
        <div className="p-4 bg-mool-mist/30 border-t border-mool-mist flex justify-between items-center">
          <button
            onClick={fetchNewToken}
            className="text-xs text-mool-dusk hover:underline font-semibold flex items-center space-x-1"
          >
            <RefreshCw className="w-3.5 h-3.5" />
            <span>Generate Fresh Code</span>
          </button>
          <OrganicButton variant="dusk" size="sm" onClick={onClose}>
            <span>Done</span>
          </OrganicButton>
        </div>
      </div>
    </div>
  );
};

