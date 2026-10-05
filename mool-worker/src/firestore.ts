import { importPKCS8, SignJWT } from 'jose';

let cachedAccessToken: string | null = null;
let tokenExpiresAt: number = 0;

export async function getGoogleAccessToken(saJsonString?: string): Promise<string | null> {
  if (!saJsonString) return null;

  const now = Math.floor(Date.now() / 1000);
  if (cachedAccessToken && now < tokenExpiresAt - 300) {
    return cachedAccessToken;
  }

  try {
    const sa = JSON.parse(saJsonString);
    const privateKey = await importPKCS8(sa.private_key, 'RS256');

    const jwt = await new SignJWT({
      scope: 'https://www.googleapis.com/auth/datastore',
    })
      .setProtectedHeader({ alg: 'RS256' })
      .setIssuer(sa.client_email)
      .setSubject(sa.client_email)
      .setAudience('https://oauth2.googleapis.com/token')
      .setExpirationTime('1h')
      .setIssuedAt()
      .sign(privateKey);

    const res = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion: jwt,
      }),
    });

    if (!res.ok) {
      const err = await res.text();
      console.warn('Could not exchange SA JWT for access token:', err);
      return null;
    }

    const data: any = await res.json();
    cachedAccessToken = data.access_token;
    tokenExpiresAt = now + (data.expires_in || 3600);
    return cachedAccessToken;
  } catch (err) {
    console.warn('Error generating Google access token:', err);
    return null;
  }
}

export async function saveFirestoreDoc(
  projectId: string,
  collection: string,
  documentId: string,
  fields: Record<string, any>,
  saJson?: string
): Promise<boolean> {
  const token = await getGoogleAccessToken(saJson);
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${collection}/${documentId}`;

  // Convert raw JS object to Firestore typed fields
  const formattedFields: Record<string, any> = {};
  for (const [key, val] of Object.entries(fields)) {
    if (typeof val === 'string') {
      formattedFields[key] = { stringValue: val };
    } else if (typeof val === 'number') {
      formattedFields[key] = Number.isInteger(val) ? { integerValue: String(val) } : { doubleValue: val };
    } else if (typeof val === 'boolean') {
      formattedFields[key] = { booleanValue: val };
    } else if (Array.isArray(val)) {
      formattedFields[key] = {
        arrayValue: {
          values: val.map((v) => ({ stringValue: String(v) })),
        },
      };
    } else if (val && typeof val === 'object') {
      formattedFields[key] = { stringValue: JSON.stringify(val) };
    }
  }

  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
  };
  if (token) {
    headers['Authorization'] = `Bearer ${token}`;
  }

  try {
    const res = await fetch(url, {
      method: 'PATCH',
      headers,
      body: JSON.stringify({ fields: formattedFields }),
    });
    return res.ok;
  } catch (err) {
    console.warn(`Error writing Firestore doc ${collection}/${documentId}:`, err);
    return false;
  }
}
