import 'package:flutter/foundation.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:ndef_record/ndef_record.dart';

class NfcService extends ChangeNotifier {
  static const tagPhrase = 'BROKE-IS-GREAT';

  String _message = 'Waiting for NFC tag...';
  String get message => _message;

  Future<bool> get isNfcAvailable async {
    final availability = await NfcManager.instance.checkAvailability();
    return availability == NfcAvailability.enabled;
  }

  Future<String?> scan() async {
    final available = await isNfcAvailable;
    if (!available) {
      _message = 'NFC is not available on this device';
      notifyListeners();
      return null;
    }

    String? result;

    await NfcManager.instance.startSession(
      pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
      onDiscovered: (NfcTag tag) async {
        final ndef = NdefAndroid.from(tag);
        if (ndef == null) {
          _message = 'Tag is not NDEF compliant';
          NfcManager.instance.stopSession();
          notifyListeners();
          return;
        }

        final ndefMessage = await ndef.getNdefMessage();
        if (ndefMessage != null) {
          for (final record in ndefMessage.records) {
            // Parse NFC well-known text record
            if (record.typeNameFormat == TypeNameFormat.wellKnown &&
                record.type.length == 1 &&
                record.type.first == 0x54) {
              // Text record: first byte is status byte (language code length),
              // then language code, then the actual text
              final payload = record.payload;
              final languageCodeLength = payload.first & 0x3F;
              final text = String.fromCharCodes(
                payload.sublist(1 + languageCodeLength),
              );
              result = text;
              _message = text;
            }
          }
        }

        NfcManager.instance.stopSession();
        notifyListeners();
      },
    );

    return result;
  }

  Future<bool> write(String text) async {
    final available = await isNfcAvailable;
    if (!available) {
      _message = 'NFC is not available on this device';
      notifyListeners();
      return false;
    }

    bool success = false;

    await NfcManager.instance.startSession(
      pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
      onDiscovered: (NfcTag tag) async {
        final ndef = NdefAndroid.from(tag);
        if (ndef == null) {
          _message = 'Tag is not NDEF compliant';
          NfcManager.instance.stopSession();
          notifyListeners();
          return;
        }

        if (!ndef.isWritable) {
          _message = 'Tag is read-only';
          NfcManager.instance.stopSession();
          notifyListeners();
          return;
        }

        // Build NFC well-known text record
        final languageCode = 'en';
        final languageCodeBytes = Uint8List.fromList(languageCode.codeUnits);
        final textBytes = Uint8List.fromList(text.codeUnits);
        final payload = Uint8List(1 + languageCodeBytes.length + textBytes.length);
        payload[0] = languageCodeBytes.length;
        payload.setRange(1, 1 + languageCodeBytes.length, languageCodeBytes);
        payload.setRange(1 + languageCodeBytes.length, payload.length, textBytes);

        final record = NdefRecord(
          typeNameFormat: TypeNameFormat.wellKnown,
          type: Uint8List.fromList([0x54]), // 'T' for Text
          identifier: Uint8List(0),
          payload: payload,
        );

        try {
          await ndef.writeNdefMessage(NdefMessage(records: [record]));
          _message = 'Tag written successfully!';
          success = true;
          NfcManager.instance.stopSession();
        } catch (e) {
          _message = 'Write failed: $e';
          NfcManager.instance.stopSession();
        }

        notifyListeners();
      },
    );

    return success;
  }

  bool isValidBrokeTag(String payload) => payload == tagPhrase;
}
