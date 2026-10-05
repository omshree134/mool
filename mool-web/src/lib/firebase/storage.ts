import { getStorage, ref, uploadBytes, getDownloadURL } from 'firebase/storage';
import { app } from './config';

export const storage = getStorage(app);

/**
 * Upload voice note recording to Firebase Storage
 */
export async function uploadVoiceNote(blob: Blob, beneficiaryId: string): Promise<string> {
  const filename = `voice_notes/${beneficiaryId}/${Date.now()}.webm`;
  const storageRef = ref(storage, filename);
  
  try {
    const snapshot = await uploadBytes(storageRef, blob);
    return await getDownloadURL(snapshot.ref);
  } catch (err) {
    console.warn('[Mool Storage] Local audio blob URL fallback used for offline mode.');
    return URL.createObjectURL(blob);
  }
}

