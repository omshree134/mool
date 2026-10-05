/**
 * Give a staff account its role, so security rules let it see the right members.
 *
 *   cd functions
 *   GOOGLE_APPLICATION_CREDENTIALS=./service-account.json \
 *     node scripts/set-role.js <uid> counsellor
 *   node scripts/set-role.js <uid> district Pune
 *   node scripts/set-role.js <uid> state MH
 *
 * The person must sign out and back in on the website for the role to apply.
 * Never commit service-account.json.
 */
const admin = require('firebase-admin');
admin.initializeApp();

async function main() {
  const [uid, role, area] = process.argv.slice(2);
  if (!uid || !['counsellor', 'district', 'state'].includes(role)) {
    console.error('Usage: node scripts/set-role.js <uid> <counsellor|district|state> [district or state]');
    process.exit(1);
  }
  const claims = { role };
  if (role === 'district') claims.district = area;
  if (role === 'state') claims.state = area;
  await admin.auth().setCustomUserClaims(uid, claims);
  await admin.firestore().doc(`staff/${uid}`).set(
    { role, district: claims.district || null, state: claims.state || null, fcmTokens: [] },
    { merge: true },
  );
  console.log(`Set ${uid} ->`, claims);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
