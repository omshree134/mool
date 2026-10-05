/**
 * Native WebCrypto HMAC-SHA1 signature verification for Twilio webhooks.
 * Runs in pure Web standard APIs on Cloudflare Workers without requiring Node.js 'twilio' SDK.
 */

export async function verifyTwilioSignature(
  expectedSignature: string | null | undefined,
  url: string,
  params: Record<string, string>,
  authToken: string
): Promise<boolean> {
  if (!authToken || !expectedSignature) {
    // If auth token is not configured in dev, skip verification
    return true;
  }

  // Sort keys alphabetically
  const sortedKeys = Object.keys(params).sort();
  let data = url;
  for (const key of sortedKeys) {
    data += key + params[key];
  }

  const encoder = new TextEncoder();
  const keyBuffer = encoder.encode(authToken);
  const dataBuffer = encoder.encode(data);

  const cryptoKey = await crypto.subtle.importKey(
    'raw',
    keyBuffer,
    { name: 'HMAC', hash: 'SHA-1' },
    false,
    ['sign']
  );

  const signatureBuffer = await crypto.subtle.sign('HMAC', cryptoKey, dataBuffer);
  const signatureBytes = new Uint8Array(signatureBuffer);
  
  // Convert binary to base64 string
  let binary = '';
  for (let i = 0; i < signatureBytes.byteLength; i++) {
    binary += String.fromCharCode(signatureBytes[i]);
  }
  const computedSignature = btoa(binary);

  return computedSignature === expectedSignature;
}
