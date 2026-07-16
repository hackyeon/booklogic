class PersistenceEnvelope {
  const PersistenceEnvelope({
    required this.envelopeVersion,
    required this.payloadSchemaVersion,
    required this.revision,
    required this.payload,
    required this.checksum,
  });

  static const currentEnvelopeVersion = 1;

  final int envelopeVersion;
  final int payloadSchemaVersion;
  final int revision;
  final Map<String, Object?> payload;
  final int checksum;

  Map<String, Object?> toChecksumMap() {
    return {
      'envelopeVersion': envelopeVersion,
      'payloadSchemaVersion': payloadSchemaVersion,
      'revision': revision,
      'payload': payload,
    };
  }

  Map<String, Object?> toJson() {
    return {...toChecksumMap(), 'checksum': checksum};
  }
}
