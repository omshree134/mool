import React from 'react';
import { ShieldCheck, Lock, Eye, FileText, Search } from 'lucide-react';
import { GroundedCard } from '../common/GroundedCard';
import { AuditLogEntry } from '../../types';

const MOCK_AUDIT_LOGS: AuditLogEntry[] = [
  {
    id: 'aud-901',
    actorId: 'resp-caseworker-singh',
    actorName: 'Officer Rajesh Singh',
    actorRole: 'caseworker',
    action: 'VIEW_CASE_RECORD',
    targetId: 'survivor-882',
    targetType: 'beneficiary',
    timestamp: '2026-09-11 14:10:22',
    ipAddress: '192.168.1.104',
    justification: 'Routine distress check-in evaluation',
  },
  {
    id: 'aud-902',
    actorId: 'resp-analyst-sharma',
    actorName: 'Dr. Ananya Sharma',
    actorRole: 'analyst',
    action: 'EXPORT_AGGREGATE_REPORT',
    targetId: 'district-b-valley',
    targetType: 'system',
    timestamp: '2026-09-11 11:45:00',
    ipAddress: '10.0.4.12',
    justification: 'Quarterly population mental health survey',
  },
  {
    id: 'aud-903',
    actorId: 'resp-caseworker-singh',
    actorName: 'Officer Rajesh Singh',
    actorRole: 'caseworker',
    action: 'GENERATE_PAIRING_QR',
    targetId: 'survivor-940',
    targetType: 'beneficiary',
    timestamp: '2026-09-10 16:30:15',
    ipAddress: '192.168.1.104',
    justification: 'Initial NGO onboarding',
  },
  {
    id: 'aud-904',
    actorId: 'admin-system-01',
    actorName: 'System Administrator',
    actorRole: 'admin',
    action: 'UPDATE_DISTRESS_TRIAGE',
    targetId: 'evt-101',
    targetType: 'distress_event',
    timestamp: '2026-09-10 09:12:40',
    ipAddress: '127.0.0.1',
    justification: 'High-severity distress trigger escalation',
  },
];

export const AuditLogTable: React.FC = () => {
  return (
    <div className="max-w-7xl mx-auto p-4 sm:p-6 space-y-6">
      {/* Top Banner */}
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 bg-mool-dusk text-white p-6 rounded-organic-lg shadow-dusk-elevated">
        <div>
          <div className="inline-flex items-center space-x-2 px-2.5 py-0.5 bg-mool-moss text-white rounded-full text-xs font-semibold">
            <Lock className="w-3.5 h-3.5" />
            <span>Compliance & Accountability Audit Log</span>
          </div>
          <h1 className="font-serif text-2xl sm:text-3xl font-bold tracking-tight text-mool-linen mt-1">
            Access Audit Trail & Data Privacy Log
          </h1>
          <p className="text-xs text-mool-linen/80">
            Immutable log of all officer interactions with sensitive survivor records for strict governance.
          </p>
        </div>
      </div>

      {/* Audit Log Table */}
      <GroundedCard variant="primary" elevation="ground" className="p-0 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="bg-mool-mist/50 text-mool-ink font-semibold uppercase tracking-wider text-[10px] border-b border-mool-mist">
              <tr>
                <th className="p-4">Timestamp</th>
                <th className="p-4">Actor / Officer</th>
                <th className="p-4">Role</th>
                <th className="p-4">Action</th>
                <th className="p-4">Target Record</th>
                <th className="p-4">IP Address</th>
                <th className="p-4">Justification</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-mool-mist/40 text-mool-ink font-sans">
              {MOCK_AUDIT_LOGS.map((log) => (
                <tr key={log.id} className="hover:bg-mool-mist/20 transition-colors">
                  <td className="p-4 font-mono text-[11px] text-mool-ink-muted">{log.timestamp}</td>
                  <td className="p-4 font-semibold text-mool-ink">{log.actorName}</td>
                  <td className="p-4">
                    <span className="px-2 py-0.5 rounded-full text-[10px] font-semibold bg-mool-dusk/10 text-mool-dusk uppercase">
                      {log.actorRole}
                    </span>
                  </td>
                  <td className="p-4 font-mono text-[11px] font-semibold text-mool-moss">{log.action}</td>
                  <td className="p-4 font-mono text-[11px] text-mool-ink">{log.targetId}</td>
                  <td className="p-4 font-mono text-[11px] text-mool-ink-faint">{log.ipAddress}</td>
                  <td className="p-4 text-mool-ink-muted italic">{log.justification}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </GroundedCard>
    </div>
  );
};

