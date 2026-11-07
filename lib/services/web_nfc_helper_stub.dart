typedef NfcWebCallback = void Function(String uid);

void registerWebNfcCallback(NfcWebCallback? callback) {
  // No-op em plataformas não-web (Android, iOS, Desktop)
}
