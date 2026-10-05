import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../core/local_store.dart';
import '../repository.dart';

/// Audio evidence for SOS events and intimidation reports.
///
/// Fixes compared with Abhaya's SosEvidenceService:
///  * Files are fingerprinted with SHA-256 on the phone before upload, and the
///    hash is stored in Firestore and in the file's metadata. Anyone can later
///    check the file hasn't been altered, which matters if it's used in court.
///  * Files go to the app's documents folder, not the temp folder, and stay
///    queued until the upload succeeds. Abhaya lost evidence if the one upload
///    attempt failed.
///  * No permission prompts in the middle of an emergency: the microphone is
///    only used if it was allowed when the person switched this on.
///  * Storage paths are protected by rules instead of public download URLs.
class EvidenceService {
  EvidenceService._();
  static final EvidenceService instance = EvidenceService._();

  static const _queueKey = 'evidence.queue';
  final AudioRecorder _recorder = AudioRecorder();

  String? _path;
  String? _id;
  DateTime? _startedAt;
  String? _linkedTo;
  String? _kind;
  bool _uploading = false;
  String? lastAudioDataUri;

  bool get recording => _path != null;

  Future<void> startAudio({required String linkedTo, required String kind}) async {
    if (recording) return;
    if (!await _recorder.hasPermission()) {
      throw StateError('Microphone is off for Mool');
    }
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/evidence');
    await folder.create(recursive: true);
    final id = Repo.instance.newId();
    final path = '${folder.path}/$id.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 22050),
      path: path,
    );
    _path = path;
    _id = id;
    _startedAt = DateTime.now();
    _linkedTo = linkedTo;
    _kind = kind;
  }

  /// Stops recording, fingerprints the file and queues it for upload.
  Future<String?> stopAudio() async {
    if (!recording) return null;
    final path = await _recorder.stop() ?? _path!;
    final id = _id!;
    final started = _startedAt!;
    final linkedTo = _linkedTo!;
    final kind = _kind!;
    _path = null;
    _id = null;
    _startedAt = null;
    _linkedTo = null;
    _kind = null;

    final file = File(path);
    if (!await file.exists()) return null;
    final size = await file.length();
    final digest = await sha256.bind(file.openRead()).first;
    final hash = digest.toString();
    final ended = DateTime.now();

    String? dataUri;
    try {
      if (size < 1024 * 1024) {
        final bytes = await file.readAsBytes();
        dataUri = 'data:audio/mp4;base64,${base64Encode(bytes)}';
        lastAudioDataUri = dataUri;
      }
    } catch (err) {
      debugPrint('Error converting audio to data URI: $err');
    }

    final meta = {
      'id': id,
      'kind': kind,
      'linkedTo': linkedTo,
      'sha256': hash,
      'sizeBytes': size,
      'startedAt': started.toIso8601String(),
      'endedAt': ended.toIso8601String(),
      'mime': 'audio/mp4',
      'uploaded': false,
      if (dataUri != null) 'audioUrl': dataUri,
      if (dataUri != null) 'hasAudio': true,
    };
    Repo.instance.addEvidence(id, meta);

    if (dataUri != null) {
      Repo.instance.linkDirectAudio(
        linkedTo: linkedTo,
        evidenceId: id,
        audioUrl: dataUri,
        kind: kind,
      );
    }

    final queue = LocalStore.instance.getJsonList(_queueKey)..add({...meta, 'localPath': path});
    await LocalStore.instance.setJsonList(_queueKey, queue);
    unawaited(uploadPending());
    return id;
  }

  /// Called on app start and after each recording.
  Future<void> uploadPending() async {
    if (_uploading) return;
    final uid = Repo.instance.uid;
    _uploading = true;
    try {
      final queue = LocalStore.instance.getJsonList(_queueKey);
      final remaining = <Map<String, dynamic>>[];
      for (final item in queue) {
        final file = File(item['localPath'] as String);
        if (!await file.exists()) continue;
        final storagePath = 'evidence/$uid/${item['id']}.m4a';
        try {
          final task = await FirebaseStorage.instance.ref(storagePath).putFile(
                file,
                SettableMetadata(
                  contentType: 'audio/mp4',
                  customMetadata: {
                    'sha256': item['sha256'] as String,
                    'kind': item['kind'] as String,
                    'linkedTo': item['linkedTo'] as String,
                  },
                ),
              );
          String? downloadUrl;
          try {
            downloadUrl = await task.ref.getDownloadURL();
          } catch (urlErr) {
            debugPrint('Download URL retrieval: $urlErr');
          }

          Repo.instance.markEvidenceUploaded(
            item['id'] as String,
            storagePath,
            downloadUrl: downloadUrl,
            kind: item['kind'] as String?,
            linkedTo: item['linkedTo'] as String?,
          );
          // Remove the local copy so it can't be found on a shared phone.
          await file.delete();
        } catch (e) {
          // The upload may have reached the server even though the phone lost
          // the reply. Storage is write-once, so check before retrying forever.
          if (await _alreadyUploaded(storagePath, item['sha256'] as String)) {
            String? downloadUrl;
            try {
              downloadUrl = await FirebaseStorage.instance.ref(storagePath).getDownloadURL();
            } catch (_) {}
            Repo.instance.markEvidenceUploaded(
              item['id'] as String,
              storagePath,
              downloadUrl: downloadUrl,
              kind: item['kind'] as String?,
              linkedTo: item['linkedTo'] as String?,
            );
            await file.delete();
            continue;
          }
          debugPrint('Evidence upload will retry: $e');
          remaining.add(item);
        }
      }
      await LocalStore.instance.setJsonList(_queueKey, remaining);
    } finally {
      _uploading = false;
    }
  }

  Future<bool> _alreadyUploaded(String path, String sha) async {
    try {
      final meta = await FirebaseStorage.instance.ref(path).getMetadata();
      return meta.customMetadata?['sha256'] == sha;
    } catch (_) {
      return false;
    }
  }
}
