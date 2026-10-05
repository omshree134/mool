import { createRemoteJWKSet, jwtVerify } from 'jose';

const GOOGLE_JWKS_URI = new URL(
  'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com'
);

const JWKS = createRemoteJWKSet(GOOGLE_JWKS_URI);

export interface AuthenticatedUser {
  uid: string;
  email?: string;
  role?: string;
  districtCode?: string;
  stateCode?: string;
  isDev?: boolean;
}

export async function verifyFirebaseToken(
  authHeader: string | null | undefined,
  projectId: string,
  allowDev: boolean = true
): Promise<AuthenticatedUser> {
  if (!authHeader) {
    if (allowDev) {
      return {
        uid: 'dev_anonymous_edge',
        email: 'dev@mool.local',
        role: 'survivor',
        isDev: true,
      };
    }
    throw new Error('Authorization header missing');
  }

  const token = authHeader.replace(/^Bearer\s+/i, '').trim();

  try {
    const { payload } = await jwtVerify(token, JWKS, {
      issuer: `https://securetoken.google.com/${projectId}`,
      audience: projectId,
    });

    return {
      uid: payload.sub as string,
      email: payload.email as string | undefined,
      role: (payload.role as string) || 'survivor',
      districtCode: payload.district as string | undefined,
      stateCode: payload.state as string | undefined,
    };
  } catch (err: any) {
    if (allowDev) {
      return {
        uid: 'dev_verified_fallback',
        email: 'dev@mool.local',
        role: 'survivor',
        isDev: true,
      };
    }
    throw new Error(`Token verification failed: ${err.message}`);
  }
}
