import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/platform_tags.dart';

import 'nfc_models.dart';

/// Android app (APK): native NFC through nfc_manager. Reads the card's UID
/// on any ISO 14443-A chip — MIFARE Classic, NTAG, DESFire — plus the
/// Fareenn NDEF link, and can format a blank MIFARE Classic card to hold it.
class NfcService {
  static bool get supported => Platform.isAndroid;

  static Future<void> _ensureAvailable() async {
    if (!await NfcManager.instance.isAvailable()) {
      throw const NfcException('Turn on NFC in your phone settings, then try again.');
    }
  }

  static Future<NfcTap> read({Duration timeout = const Duration(seconds: 40)}) async {
    await _ensureAvailable();
    final done = Completer<NfcTap>();
    await NfcManager.instance.startSession(
      onDiscovered: (NfcTag tag) async {
        try {
          final uid = _uid(tag);
          if (uid.isEmpty) throw const NfcException('This card has no readable ID. Use a Fareenn card.');
          var data = '';
          final ndef = Ndef.from(tag);
          if (ndef != null) {
            final msg = ndef.cachedMessage ?? await ndef.read();
            data = _firstLink(msg);
          }
          if (!done.isCompleted) done.complete(NfcTap(uid: uid, data: data));
        } on NfcException catch (e) {
          if (!done.isCompleted) done.completeError(e);
        } catch (_) {
          if (!done.isCompleted) {
            done.completeError(const NfcException('The card moved away too soon. Hold it still on the back of the phone.'));
          }
        } finally {
          await NfcManager.instance.stopSession();
        }
      },
    );
    return done.future.timeout(timeout, onTimeout: () {
      stop();
      throw const NfcException('No card detected. Try again.');
    });
  }

  static Future<void> writeUrl(String url, {Duration timeout = const Duration(seconds: 40)}) async {
    await _ensureAvailable();
    final done = Completer<void>();
    final message = NdefMessage([NdefRecord.createUri(Uri.parse(url))]);
    await NfcManager.instance.startSession(
      onDiscovered: (NfcTag tag) async {
        try {
          final ndef = Ndef.from(tag);
          if (ndef != null) {
            if (!ndef.isWritable) throw const NfcException('This card is locked and cannot be used.');
            await ndef.write(message);
          } else {
            final blank = NdefFormatable.from(tag);
            if (blank == null) throw const NfcException('This card cannot store the Fareenn link.');
            await blank.format(message); // e.g. a new MIFARE Classic 1K card
          }
          if (!done.isCompleted) done.complete();
        } on NfcException catch (e) {
          if (!done.isCompleted) done.completeError(e);
        } catch (_) {
          if (!done.isCompleted) {
            done.completeError(const NfcException('Could not save to the card. Hold it still and try again.'));
          }
        } finally {
          await NfcManager.instance.stopSession();
        }
      },
    );
    return done.future.timeout(timeout, onTimeout: () {
      stop();
      throw const NfcException('No card detected. Try again.');
    });
  }

  static void stop() {
    NfcManager.instance.stopSession().catchError((_) {});
  }

  static String _uid(NfcTag tag) {
    Uint8List? id = NfcA.from(tag)?.identifier ?? MifareClassic.from(tag)?.identifier;
    if (id == null) {
      final raw = (tag.data['nfca'] ?? tag.data['mifareclassic'])?['identifier'];
      if (raw is List) id = Uint8List.fromList(raw.cast<int>());
    }
    if (id == null) return '';
    return id.map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
  }

  static const _uriPrefixes = [
    '', 'http://www.', 'https://www.', 'http://', 'https://', 'tel:', 'mailto:',
  ];

  /// First URI ("U") or text ("T") record of the card's NDEF message.
  static String _firstLink(NdefMessage? msg) {
    if (msg == null) return '';
    for (final r in msg.records) {
      if (r.typeNameFormat != NdefTypeNameFormat.nfcWellknown || r.type.isEmpty || r.payload.isEmpty) continue;
      if (r.type.length == 1 && r.type[0] == 0x55) {
        final code = r.payload[0];
        final prefix = code < _uriPrefixes.length ? _uriPrefixes[code] : '';
        return prefix + utf8.decode(r.payload.sublist(1), allowMalformed: true);
      }
      if (r.type.length == 1 && r.type[0] == 0x54) {
        final langLen = r.payload[0] & 0x3f;
        return utf8.decode(r.payload.sublist(1 + langLen), allowMalformed: true);
      }
    }
    return '';
  }
}
