import React, { useState } from 'react';
import { ShieldAlert, UserPlus, Users, Lock, CheckCircle, Mail, Building, ShieldCheck, AlertTriangle } from 'lucide-react';
import { useAuth, StaffMember } from '../../context/AuthContext';
import { GroundedCard } from '../common/GroundedCard';
import { OrganicButton } from '../common/OrganicButton';

export const StaffManager: React.FC = () => {
  const { role, staffList, createStaffAccount } = useAuth();
  
  const [showAddModal, setShowAddModal] = useState(false);
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [staffRole, setStaffRole] = useState<'admin' | 'analyst' | 'caseworker'>('analyst');
  const [department, setDepartment] = useState('');
  const [successMsg, setSuccessMsg] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  // Security gate: only admins can view or manage staff
  if (role !== 'admin') {
    return (
      <div className="max-w-4xl mx-auto p-6 text-center">
        <GroundedCard variant="dusk" elevation="floating" className="p-8 space-y-4">
          <ShieldAlert className="w-12 h-12 text-mool-signal mx-auto" />
          <h2 className="font-serif text-2xl font-bold text-white">Restricted Administrator Area</h2>
          <p className="text-xs text-mool-linen/80 max-w-md mx-auto">
            Staff provisioning and role assignment are restricted to authenticated System Administrators.
          </p>
        </GroundedCard>
      </div>
    );
  }

  const handleCreate = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!name.trim() || !email.trim()) return;

    setSubmitting(true);
    setSuccessMsg(null);
    try {
      await createStaffAccount({
        name: name.trim(),
        email: email.trim(),
        role: staffRole,
        department: department.trim() || 'Mental Health Operations',
      });

      setSuccessMsg(`Successfully provisioned ${staffRole.toUpperCase()} account for ${name}.`);
      setName('');
      setEmail('');
      setPassword('');
      setDepartment('');
      setShowAddModal(false);
    } catch (err: any) {
      console.warn('Error creating staff account:', err);
    } finally {
      setSubmitting(false);
    }
  };

  const getRoleBadge = (r: 'admin' | 'analyst' | 'caseworker') => {
    switch (r) {
      case 'admin':
        return { label: 'System Admin', color: 'bg-mool-dusk text-white border-mool-dusk' };
      case 'analyst':
        return { label: 'Data Analyst', color: 'bg-mool-sandrose/20 text-mool-sandrose border-mool-sandrose/30 font-semibold' };
      case 'caseworker':
        return { label: 'Direct Caseworker', color: 'bg-mool-moss/20 text-mool-moss-dark border-mool-moss/30 font-semibold' };
    }
  };

  return (
    <div className="max-w-7xl mx-auto p-4 sm:p-6 space-y-6">
      {/* Header Banner */}
      <div className="bg-mool-dusk text-white rounded-organic-lg p-6 sm:p-8 shadow-dusk-elevated relative overflow-hidden">
        <div className="relative z-10 flex flex-col md:flex-row md:items-center md:justify-between gap-4">
          <div className="space-y-2">
            <div className="inline-flex items-center space-x-2 px-3 py-1 bg-white/10 text-mool-linen rounded-full text-xs font-semibold">
              <Lock className="w-3.5 h-3.5 text-mool-moss-light" />
              <span>Restricted Administrative Access Controls</span>
            </div>
            <h1 className="font-serif text-3xl sm:text-4xl font-bold tracking-tight">
              Staff & Role Provisioning
            </h1>
            <p className="text-xs sm:text-sm text-mool-linen/80 leading-relaxed max-w-xl">
              Public registration is disabled for administrative and analyst roles. Only authenticated Admins can provision new staff accounts.
            </p>
          </div>

          <div>
            <OrganicButton
              variant="sandrose"
              size="md"
              onClick={() => {
                setShowAddModal(true);
                setSuccessMsg(null);
              }}
              className="shadow-md"
            >
              <UserPlus className="w-4 h-4 mr-2" />
              <span>Provision Staff Account</span>
            </OrganicButton>
          </div>
        </div>
      </div>

      {successMsg && (
        <div className="p-4 bg-mool-moss/15 border border-mool-moss/40 rounded-xl flex items-center space-x-3 text-xs text-mool-moss-dark font-medium">
          <CheckCircle className="w-5 h-5 text-mool-moss shrink-0" />
          <span>{successMsg}</span>
        </div>
      )}

      {/* Roster & Access Controls */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 items-start">
        {/* Left: Active Staff Table */}
        <div className="lg:col-span-8 space-y-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-2">
              <Users className="w-5 h-5 text-mool-moss" />
              <h2 className="font-serif text-xl font-bold text-mool-ink">
                Provisioned Personnel ({staffList.length})
              </h2>
            </div>
          </div>

          <GroundedCard variant="primary" elevation="ground" className="p-0 overflow-hidden border border-mool-mist">
            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs">
                <thead className="bg-mool-mist/50 text-mool-ink font-semibold uppercase tracking-wider text-[10px] border-b border-mool-mist">
                  <tr>
                    <th className="p-4">Staff Member</th>
                    <th className="p-4">Assigned Role</th>
                    <th className="p-4">Department / Unit</th>
                    <th className="p-4">Status</th>
                    <th className="p-4">Provisioned</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-mool-mist/40 text-mool-ink">
                  {staffList.map((s) => {
                    const badge = getRoleBadge(s.role);
                    return (
                      <tr key={s.id} className="hover:bg-mool-mist/20 transition-colors">
                        <td className="p-4">
                          <div className="font-semibold text-sm text-mool-ink">{s.name}</div>
                          <div className="text-[11px] font-mono text-mool-ink-muted">{s.email}</div>
                        </td>
                        <td className="p-4">
                          <span className={`text-[10px] px-2.5 py-1 rounded-full border ${badge.color}`}>
                            {badge.label}
                          </span>
                        </td>
                        <td className="p-4 text-mool-ink-muted">{s.department}</td>
                        <td className="p-4">
                          <span className="inline-flex items-center space-x-1 text-[11px] font-semibold text-mool-moss">
                            <span className="w-2 h-2 rounded-full bg-mool-moss" />
                            <span>Active</span>
                          </span>
                        </td>
                        <td className="p-4 text-xs font-mono text-mool-ink-faint">{s.createdAt}</td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          </GroundedCard>
        </div>

        {/* Right: Policy & Role Capabilities Guide */}
        <div className="lg:col-span-4 space-y-4">
          <GroundedCard variant="primary" elevation="floating" className="p-5 space-y-4 border border-mool-mist">
            <div className="flex items-center space-x-2 border-b border-mool-mist pb-3">
              <ShieldCheck className="w-5 h-5 text-mool-moss" />
              <h3 className="font-serif text-base font-bold text-mool-ink">Role Matrix & Policies</h3>
            </div>

            <div className="space-y-3 text-xs leading-relaxed">
              <div className="p-3 bg-mool-mist/30 rounded-xl space-y-1">
                <div className="font-semibold text-mool-ink flex items-center justify-between">
                  <span>Data Analyst Role</span>
                  <span className="text-[10px] text-mool-sandrose font-bold uppercase">Analytics</span>
                </div>
                <p className="text-mool-ink-muted text-[11px]">
                  Macro-level analytics, distress distribution triage, and PHQ/GAD score heatmaps. Survivor identities and private reflections are protected in anonymous aggregate reports.
                </p>
              </div>

              <div className="p-3 bg-mool-mist/30 rounded-xl space-y-1">
                <div className="font-semibold text-mool-ink flex items-center justify-between">
                  <span>System Admin Role</span>
                  <span className="text-[10px] text-mool-dusk font-bold uppercase">Oversight</span>
                </div>
                <p className="text-mool-ink-muted text-[11px]">
                  Can provision new accounts for other Admins and Data Analysts. Audit trail visibility and anonymous macro oversight.
                </p>
              </div>

              <div className="p-3 bg-mool-mist/30 rounded-xl space-y-1">
                <div className="font-semibold text-mool-ink flex items-center justify-between">
                  <span>Caseworker / Direct Guardian</span>
                  <span className="text-[10px] text-mool-moss font-bold uppercase">Direct Care</span>
                </div>
                <p className="text-mool-ink-muted text-[11px]">
                  Assigned directly to specific protected wards with verified contact channels for active crisis intervention.
                </p>
              </div>
            </div>
          </GroundedCard>
        </div>
      </div>

      {/* Modal: Provision Staff Account */}
      {showAddModal && (
        <div className="fixed inset-0 z-50 bg-mool-dusk/60 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-white rounded-organic-lg max-w-lg w-full p-6 sm:p-8 space-y-5 border border-mool-mist shadow-floating animate-fadeIn">
            <div className="flex items-center justify-between border-b border-mool-mist pb-3">
              <div className="flex items-center space-x-2.5">
                <div className="w-8 h-8 rounded-full bg-mool-moss text-white flex items-center justify-center">
                  <UserPlus className="w-4 h-4" />
                </div>
                <div>
                  <h3 className="font-serif text-lg font-bold text-mool-ink">Provision Staff Account</h3>
                  <p className="text-[11px] text-mool-ink-muted">Authorized by System Administrator</p>
                </div>
              </div>
              <button
                onClick={() => setShowAddModal(false)}
                className="text-mool-ink-muted hover:text-mool-ink text-sm font-semibold p-1"
              >
                ✕
              </button>
            </div>

            <form onSubmit={handleCreate} className="space-y-4">
              {/* Role Selection */}
              <div className="space-y-1">
                <label className="block text-xs font-semibold text-mool-ink">Target Role *</label>
                <div className="grid grid-cols-3 gap-2">
                  {[
                    { id: 'analyst', label: 'Data Analyst' },
                    { id: 'admin', label: 'System Admin' },
                    { id: 'caseworker', label: 'Caseworker' },
                  ].map((r) => (
                    <button
                      key={r.id}
                      type="button"
                      onClick={() => setStaffRole(r.id as any)}
                      className={`py-2 text-xs font-semibold rounded-xl border transition-all ${
                        staffRole === r.id
                          ? 'bg-mool-moss text-white border-mool-moss shadow-sm'
                          : 'bg-white border-mool-mist text-mool-ink-muted hover:border-mool-moss/40'
                      }`}
                    >
                      {r.label}
                    </button>
                  ))}
                </div>
              </div>

              {/* Name */}
              <div className="space-y-1">
                <label className="block text-xs font-semibold text-mool-ink">Full Name & Title *</label>
                <input
                  type="text"
                  required
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  placeholder="e.g. Dr. Sunita Kapoor, Officer Vikram Rao"
                  className="w-full px-3.5 py-2.5 bg-white border border-mool-mist rounded-xl text-xs text-mool-ink focus:outline-none focus:border-mool-moss"
                />
              </div>

              {/* Official Email */}
              <div className="space-y-1">
                <label className="block text-xs font-semibold text-mool-ink">Official Agency Email *</label>
                <input
                  type="email"
                  required
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="name@mool.gov.in or agency.org"
                  className="w-full px-3.5 py-2.5 bg-white border border-mool-mist rounded-xl text-xs text-mool-ink focus:outline-none focus:border-mool-moss"
                />
              </div>

              {/* Password */}
              <div className="space-y-1">
                <label className="block text-xs font-semibold text-mool-ink">Initial Provisioning Password *</label>
                <input
                  type="password"
                  required
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="••••••••••••"
                  className="w-full px-3.5 py-2.5 bg-white border border-mool-mist rounded-xl text-xs text-mool-ink focus:outline-none focus:border-mool-moss"
                />
              </div>

              {/* Department */}
              <div className="space-y-1">
                <label className="block text-xs font-semibold text-mool-ink">Department / Agency Unit</label>
                <input
                  type="text"
                  value={department}
                  onChange={(e) => setDepartment(e.target.value)}
                  placeholder="e.g. Mental Health Analytics Bureau"
                  className="w-full px-3.5 py-2.5 bg-white border border-mool-mist rounded-xl text-xs text-mool-ink focus:outline-none focus:border-mool-moss"
                />
              </div>

              <div className="pt-2 flex items-center justify-end space-x-3">
                <button
                  type="button"
                  onClick={() => setShowAddModal(false)}
                  className="px-4 py-2 text-xs font-semibold text-mool-ink-muted hover:text-mool-ink"
                >
                  Cancel
                </button>
                <OrganicButton variant="moss" size="md" disabled={submitting}>
                  {submitting ? 'Provisioning...' : 'Confirm & Create Account'}
                </OrganicButton>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
