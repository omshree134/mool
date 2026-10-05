import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Users, QrCode, Plus, Search, ShieldCheck, Eye, UserCheck, AlertTriangle, Scale } from 'lucide-react';
import { collection, onSnapshot, query } from 'firebase/firestore';
import { db } from '../../lib/firebase/firestore';
import { GroundedCard } from '../common/GroundedCard';
import { OrganicButton } from '../common/OrganicButton';
import { QrGeneratorModal } from './QrGeneratorModal';
import { CaseImportModal } from './CaseImportModal';
import { Beneficiary, ConsentStatus } from '../../types';
import { useAuth } from '../../context/AuthContext';
import { maskPseudonym, maskIdentifier, isMaskedRole } from '../../lib/maskData';

const INITIAL_BENEFICIARIES: Beneficiary[] = [
  {
    id: 'survivor-882',
    pseudonym: 'Aarav',
    consentStatus: 'granted',
    language: 'en',
    createdAt: '2026-08-14',
    linkedCaseworker: 'Officer Rajesh Singh',
    region: 'District A (East)',
    lastCheckinDaysAgo: 1,
    currentRiskLevel: 'low',
  },
  {
    id: 'survivor-904',
    pseudonym: 'Priya',
    consentStatus: 'granted',
    language: 'hi',
    createdAt: '2026-08-20',
    linkedCaseworker: 'Officer Rajesh Singh',
    region: 'District B (Valley)',
    lastCheckinDaysAgo: 4,
    currentRiskLevel: 'high',
  },
  {
    id: 'survivor-912',
    pseudonym: 'Meera',
    consentStatus: 'granted',
    language: 'mr',
    createdAt: '2026-08-28',
    linkedCaseworker: 'Ananya Sharma (NGO)',
    region: 'District A (East)',
    lastCheckinDaysAgo: 0,
    currentRiskLevel: 'low',
  },
  {
    id: 'survivor-940',
    pseudonym: 'Kabir',
    consentStatus: 'paused',
    language: 'bn',
    createdAt: '2026-09-02',
    linkedCaseworker: 'Ananya Sharma (NGO)',
    region: 'District D (Border)',
    lastCheckinDaysAgo: 9,
    currentRiskLevel: 'moderate',
  },
];

export const BeneficiaryManager: React.FC = () => {
  const { role } = useAuth();
  const [beneficiaries, setBeneficiaries] = useState<Beneficiary[]>(INITIAL_BENEFICIARIES);
  const [search, setSearch] = useState('');
  const [selectedQrBeneficiary, setSelectedQrBeneficiary] = useState<{ id: string; name: string } | null>(null);
  const [showAddForm, setShowAddForm] = useState(false);
  const [showImportModal, setShowImportModal] = useState(false);
  const [newPseudonym, setNewPseudonym] = useState('');
  const [newRegion, setNewRegion] = useState('District A (East)');
  const navigate = useNavigate();

  // Real-time Firestore sync with members collection
  useEffect(() => {
    try {
      const q = query(collection(db, 'members'));
      const unsubscribe = onSnapshot(q, (snapshot) => {
        const liveBens: Beneficiary[] = [];

        snapshot.forEach((docSnap) => {
          const data = docSnap.data();
          const isSos = Boolean(data.sosActive || data.activeSos);
          const daysAgo = data.lastCheckInAt 
            ? Math.max(0, Math.floor((Date.now() - new Date(data.lastCheckInAt).getTime()) / (1000 * 86400)))
            : 0;

          liveBens.push({
            id: docSnap.id,
            pseudonym: data.displayName || 'Protected Ward',
            consentStatus: 'granted',
            language: 'en',
            createdAt: data.linkedAt ? data.linkedAt.split('T')[0] : '2026-09-12',
            linkedCaseworker: data.guardianName || 'Unassigned Responder',
            region: data.guardianName ? `Care of ${data.guardianName}` : 'District General',
            lastCheckinDaysAgo: daysAgo,
            currentRiskLevel: isSos 
              ? 'critical' 
              : data.latestTier === 'outreach' 
              ? 'high' 
              : data.latestTier === 'watch' 
              ? 'moderate' 
              : 'low',
          });
        });

        // Merge live records with sample seed
        setBeneficiaries((prev) => {
          const liveIds = new Set(liveBens.map(b => b.id));
          const nonDupePrev = prev.filter(b => !liveIds.has(b.id) && !b.id.startsWith('ward-'));
          return [...liveBens, ...nonDupePrev];
        });
      }, (err) => {
        console.warn('Firestore beneficiary listener note:', err);
      });

      return () => unsubscribe();
    } catch (e) {
      console.warn('Error subscribing to members collection:', e);
    }
  }, []);

  const handleRegisterBeneficiary = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newPseudonym.trim()) return;

    const newBen: Beneficiary = {
      id: `survivor-${Math.floor(100 + Math.random() * 900)}`,
      pseudonym: newPseudonym.trim(),
      consentStatus: 'granted',
      language: 'en',
      createdAt: new Date().toISOString().split('T')[0],
      linkedCaseworker: 'Officer Rajesh Singh',
      region: newRegion,
      lastCheckinDaysAgo: 0,
      currentRiskLevel: 'low',
    };

    setBeneficiaries(prev => [newBen, ...prev]);
    setNewPseudonym('');
    setShowAddForm(false);
    // Automatically trigger QR code generator modal for new beneficiary
    setSelectedQrBeneficiary({ id: newBen.id, name: newBen.pseudonym });
  };

  const filtered = beneficiaries.filter(b =>
    b.pseudonym.toLowerCase().includes(search.toLowerCase()) ||
    b.id.toLowerCase().includes(search.toLowerCase()) ||
    b.region.toLowerCase().includes(search.toLowerCase())
  );

  return (
    <div className="max-w-7xl mx-auto p-4 sm:p-6 space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 bg-mool-dusk text-white p-6 rounded-organic-lg shadow-dusk-elevated">
        <div>
          <h1 className="font-serif text-2xl sm:text-3xl font-bold tracking-tight text-mool-linen">
            Beneficiary Management & Anonymous Reports
          </h1>
          <p className="text-xs text-mool-linen/80 mt-1">
            {isMaskedRole(role)
              ? 'Anonymized oversight view. Real survivor names and contact lines are de-identified for Data Analysts & Admins.'
              : 'Register new survivors, mint single-use pairing QR codes, and monitor consent status.'}
          </p>
        </div>

        {role !== 'analyst' && (
          <div className="flex items-center gap-2">
            <OrganicButton variant="sandrose" onClick={() => setShowImportModal(true)}>
              <Scale className="w-4 h-4 mr-2" />
              <span>Import Cases (PoA / CSV)</span>
            </OrganicButton>
            <OrganicButton variant="moss" onClick={() => setShowAddForm(!showAddForm)}>
              <Plus className="w-4 h-4 mr-2" />
              <span>Register New Beneficiary</span>
            </OrganicButton>
          </div>
        )}
      </div>

      {/* Add New Beneficiary Form Collapsible */}
      {showAddForm && (
        <GroundedCard variant="primary" elevation="floating" className="border-2 border-mool-moss/40 space-y-4">
          <h3 className="font-serif text-lg font-bold text-mool-ink flex items-center space-x-2">
            <UserCheck className="w-5 h-5 text-mool-moss" />
            <span>Pre-Register New Beneficiary Record</span>
          </h3>

          <form onSubmit={handleRegisterBeneficiary} className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <div>
              <label className="block text-xs font-semibold text-mool-ink mb-1">Pseudonym / Name</label>
              <input
                type="text"
                value={newPseudonym}
                onChange={(e) => setNewPseudonym(e.target.value)}
                placeholder="e.g. Aarav"
                className="w-full px-3.5 py-2 bg-white border border-mool-mist rounded-organic text-xs text-mool-ink"
                required
              />
            </div>

            <div>
              <label className="block text-xs font-semibold text-mool-ink mb-1">Assigned Region</label>
              <select
                value={newRegion}
                onChange={(e) => setNewRegion(e.target.value)}
                className="w-full px-3.5 py-2 bg-white border border-mool-mist rounded-organic text-xs text-mool-ink"
              >
                <option value="District A (East)">District A (East)</option>
                <option value="District B (Valley)">District B (Valley)</option>
                <option value="District C (North)">District C (North)</option>
                <option value="District D (Border)">District D (Border)</option>
              </select>
            </div>

            <div className="flex items-end space-x-2">
              <OrganicButton type="submit" variant="moss" fullWidth>
                <span>Save & Generate QR</span>
              </OrganicButton>
            </div>
          </form>
        </GroundedCard>
      )}

      {/* Search & Filter Bar */}
      <div className="flex items-center space-x-3 bg-white p-3 rounded-organic border border-mool-mist shadow-soft-ground">
        <Search className="w-4 h-4 text-mool-ink-muted ml-2 shrink-0" />
        <input
          type="text"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Filter by pseudonym, case ID, or region..."
          className="w-full text-xs text-mool-ink bg-transparent focus:outline-none"
        />
      </div>

      {/* Beneficiaries Table */}
      <GroundedCard variant="primary" elevation="ground" className="p-0 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="bg-mool-mist/50 text-mool-ink font-semibold uppercase tracking-wider text-[10px] border-b border-mool-mist">
              <tr>
                <th className="p-4">Pseudonym / ID</th>
                <th className="p-4">Region</th>
                <th className="p-4">Consent Status</th>
                <th className="p-4">Last Check-in</th>
                <th className="p-4">Risk Level</th>
                <th className="p-4">Guardian / Caseworker</th>
                <th className="p-4 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-mool-mist/40 text-mool-ink font-sans">
              {filtered.map((b) => (
                <tr key={b.id} className="hover:bg-mool-mist/20 transition-colors">
                  <td className="p-4 font-semibold">
                    <div className="flex items-center space-x-2">
                      <div className="w-7 h-7 rounded-full bg-mool-dusk/10 text-mool-dusk flex items-center justify-center font-bold text-xs font-serif">
                        {isMaskedRole(role) ? 'A' : b.pseudonym.charAt(0)}
                      </div>
                      <div>
                        <span className="block text-sm text-mool-ink">{maskPseudonym(b.pseudonym, b.id, role)}</span>
                        <span className="text-[10px] font-mono text-mool-ink-faint">{maskIdentifier(b.id, role)}</span>
                      </div>
                    </div>
                  </td>

                  <td className="p-4 text-mool-ink-muted">{b.region}</td>

                  <td className="p-4">
                    <span className={`px-2.5 py-1 rounded-full text-[10px] font-semibold ${
                      b.consentStatus === 'granted'
                        ? 'bg-mool-moss/15 text-mool-moss'
                        : 'bg-mool-sandrose/20 text-mool-sandrose'
                    }`}>
                      {b.consentStatus.toUpperCase()}
                    </span>
                  </td>

                  <td className="p-4 text-mool-ink-muted">
                    {b.lastCheckinDaysAgo === 0 ? 'Today' : `${b.lastCheckinDaysAgo} days ago`}
                  </td>

                  <td className="p-4">
                    <span className={`px-2 py-0.5 rounded-full text-[10px] font-semibold ${
                      b.currentRiskLevel === 'critical'
                        ? 'bg-red-600 text-white font-bold animate-pulse'
                        : b.currentRiskLevel === 'high'
                        ? 'bg-mool-signal/15 text-mool-signal'
                        : b.currentRiskLevel === 'moderate'
                        ? 'bg-mool-sandrose/20 text-mool-sandrose'
                        : 'bg-mool-moss/10 text-mool-moss'
                    }`}>
                      {b.currentRiskLevel.toUpperCase()}
                    </span>
                  </td>

                  <td className="p-4 text-mool-ink-muted">{b.linkedCaseworker}</td>

                  <td className="p-4 text-right space-x-2">
                    <button
                      onClick={() => setSelectedQrBeneficiary({ id: b.id, name: b.pseudonym })}
                      className="inline-flex items-center space-x-1 text-xs font-semibold text-mool-moss bg-mool-moss/10 hover:bg-mool-moss/20 px-2.5 py-1.5 rounded-organic transition-colors"
                      title="Generate Pairing QR"
                    >
                      <QrCode className="w-3.5 h-3.5" />
                      <span>QR Code</span>
                    </button>

                    <button
                      onClick={() => navigate(`/portal/case/${b.id}`)}
                      className="inline-flex items-center space-x-1 text-xs font-semibold text-mool-dusk bg-mool-dusk/10 hover:bg-mool-dusk/20 px-2.5 py-1.5 rounded-organic transition-colors"
                      title="View Case File"
                    >
                      <Eye className="w-3.5 h-3.5" />
                      <span>Case View</span>
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </GroundedCard>

      {/* QR Code Generator Modal */}
      {selectedQrBeneficiary && (
        <QrGeneratorModal
          isOpen={!!selectedQrBeneficiary}
          onClose={() => setSelectedQrBeneficiary(null)}
          beneficiaryId={selectedQrBeneficiary.id}
          beneficiaryPseudonym={selectedQrBeneficiary.name}
        />
      )}

      {/* PoA & CSV Case Import Modal */}
      <CaseImportModal
        isOpen={showImportModal}
        onClose={() => setShowImportModal(false)}
        onImportBeneficiaries={(imported) => {
          setBeneficiaries((prev) => [...imported, ...prev]);
        }}
      />
    </div>
  );
};
