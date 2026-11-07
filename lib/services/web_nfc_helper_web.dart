import 'dart:js_interop';

typedef NfcWebCallback = void Function(String uid);

@JS('onNfcTagScanned')
external set _onNfcTagScanned(JSFunction? fn);

void registerWebNfcCallback(NfcWebCallback? callback) {
  if (callback == null) {
    _onNfcTagScanned = null;
    return;
  }
  _onNfcTagScanned = ((JSString uid) {
    callback(uid.toDart);
  }).toJS;
}
