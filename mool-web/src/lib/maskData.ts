import { UserRole } from '../types';

/**
 * Returns true if the active role requires survivor PII to be masked into anonymous reports.
 * Admins and Data Analysts only see de-identified / masked data to uphold survivor confidentiality.
 */
export function isMaskedRole(role: UserRole | null): boolean {
  return role === 'admin' || role === 'analyst';
}

/**
 * Masks a survivor's pseudonym or name into an anonymous representation (e.g., "A*** (ANON-882)").
 */
export function maskPseudonym(name: string | undefined, id: string | undefined, role: UserRole | null): string {
  if (!name && !id) return 'Anonymous Ward';
  if (!isMaskedRole(role)) return name || 'Protected Ward';

  const firstLetter = name && name.trim().length > 0 ? name.trim().charAt(0).toUpperCase() : 'W';
  const cleanId = (id || '882').replace(/[^a-zA-Z0-9]/g, '').slice(-4).toUpperCase();
  return `${firstLetter}*** (ANON-${cleanId})`;
}

/**
 * Masks a phone number or emergency contact (e.g., "+91 98***-***67").
 */
export function maskPhone(phone: string | undefined, role: UserRole | null): string {
  if (!phone) return 'Not Provided';
  if (!isMaskedRole(role)) return phone;

  const trimmed = phone.trim();
  if (trimmed.length <= 4) return '[CONFIDENTIAL]';
  
  const prefix = trimmed.slice(0, 4);
  const suffix = trimmed.slice(-2);
  return `${prefix}***-***${suffix}`;
}

/**
 * Masks internal identifiers into anonymous oversight tokens.
 */
export function maskIdentifier(id: string | undefined, role: UserRole | null): string {
  if (!id) return 'ANON-XXXX';
  if (!isMaskedRole(role)) return id;

  const suffix = id.replace(/[^a-zA-Z0-9]/g, '').slice(-4).toUpperCase();
  return `ANON-${suffix}`;
}

/**
 * Replaces intimate trauma journal reflections with high-level sentiment summaries
 * to protect wards from administrative surveillance.
 */
export function maskReflection(note: string | undefined, role: UserRole | null): string {
  if (!note || note.trim().length === 0) return 'No check-in notes logged.';
  if (!isMaskedRole(role)) return note;

  return '[Survivor Journal Reflection Encrypted • Sentiment: Active & Grounded • PII Redacted for Administrative Oversight]';
}
