// INTEGRATION POINT 6: Role-based route guards on /portal/*
import React from 'react';
import { Routes, Route, Navigate } from 'react-router-dom';
import { PortalNav } from '../components/portal/PortalNav';
import { AggregateDashboard } from '../components/portal/AggregateDashboard';
import { BeneficiaryManager } from '../components/portal/BeneficiaryManager';
import { DistressAlertsQueue } from '../components/portal/DistressAlertsQueue';
import { CaseView } from '../components/portal/CaseView';
import { AuditLogTable } from '../components/portal/AuditLogTable';
import { GuardianHub } from '../components/guardian/GuardianHub';
import { StaffManager } from '../components/portal/StaffManager';
import { IvrsPhoneSimulator } from '../components/simulator/IvrsPhoneSimulator';
import { useAuth } from '../context/AuthContext';

export const PortalRoutes: React.FC = () => {
  const { role } = useAuth();

  // INTEGRATION POINT 6: Enforces claims-based RBAC in production
  if (!role || role === 'survivor') {
    return <Navigate to="/portal/login" replace />;
  }

  return (
    <div className="min-h-screen bg-mool-linen flex flex-col font-sans selection:bg-mool-dusk/20">
      <PortalNav />

      <main className="flex-1 pb-12">
        <Routes>
          <Route path="guardian" element={<GuardianHub />} />
          <Route path="dashboard" element={<AggregateDashboard />} />
          <Route path="beneficiaries" element={<BeneficiaryManager />} />
          <Route path="alerts" element={<DistressAlertsQueue />} />
          <Route path="simulator" element={<IvrsPhoneSimulator />} />
          <Route path="case/:id" element={<CaseView />} />
          <Route path="audit" element={<AuditLogTable />} />
          <Route path="staff" element={<StaffManager />} />
          <Route path="*" element={<Navigate to="guardian" replace />} />
        </Routes>
      </main>
    </div>
  );
};

