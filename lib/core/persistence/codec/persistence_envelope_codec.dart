import 'dart:convert';

import '../checksum/fnv1a_persistence_checksum.dart';
import '../checksum/persistence_checksum.dart';
import '../domain/persistence_envelope.dart';
import '../domain/persistence_issue_code.dart';
import 'canonical_json_encoder.dart';

class PersistenceDecodeException implements Exception {
  const PersistenceDecodeException(this.code, {this.revision});

  final PersistenceIssueCode code;
  final int? revision;

  @override
  String toString() => 'PersistenceDecodeException($code, revision: $revision)';
}

class PersistenceFutureSchemaException extends PersistenceDecodeException {
  const PersistenceFutureSchemaException(super.code, {super.revision});
}

class PersistenceEnvelopeCodec {
  const PersistenceEnvelopeCodec({
    CanonicalJsonEncoder jsonEncoder = const CanonicalJsonEncoder(),
    PersistenceChecksum checksum = const Fnv1aPersistenceChecksum(),
  }) : _jsonEncoder = jsonEncoder,
       _checksum = checksum;

  final CanonicalJsonEncoder _jsonEncoder;
  final PersistenceChecksum _checksum;

  String encode({
    required int payloadSchemaVersion,
    required int revision,
    required Map<String, Object?> payload,
  }) {
    final checksumMap = <String, Object?>{
      'envelopeVersion': PersistenceEnvelope.currentEnvelopeVersion,
      'payloadSchemaVersion': payloadSchemaVersion,
      'revision': revision,
      'payload': payload,
    };
    final checksum = _calculateChecksum(checksumMap);
    return _jsonEncoder.encode({...checksumMap, 'checksum': checksum});
  }

  PersistenceEnvelope decode({
    required String raw,
    required int supportedPayloadSchemaVersion,
  }) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const PersistenceDecodeException(
        PersistenceIssueCode.malformedJson,
      );
    }
    if (decoded is! Map) {
      throw const PersistenceDecodeException(
        PersistenceIssueCode.invalidEnvelope,
      );
    }

    final json = <String, Object?>{};
    for (final entry in decoded.entries) {
      final key = entry.key;
      if (key is! String) {
        throw const PersistenceDecodeException(
          PersistenceIssueCode.invalidEnvelope,
        );
      }
      json[key] = entry.value;
    }

    final envelopeVersion = _readInt(json, 'envelopeVersion');
    final payloadSchemaVersion = _readInt(json, 'payloadSchemaVersion');
    final revision = _readInt(json, 'revision');
    final checksum = _readInt(json, 'checksum');
    final payload = json['payload'];

    if (revision < 1 || checksum < 0 || checksum > 0xffffffff) {
      throw PersistenceDecodeException(
        PersistenceIssueCode.invalidEnvelope,
        revision: revision < 1 ? null : revision,
      );
    }
    if (payload is! Map) {
      throw PersistenceDecodeException(
        PersistenceIssueCode.invalidEnvelope,
        revision: revision,
      );
    }
    if (envelopeVersion > PersistenceEnvelope.currentEnvelopeVersion) {
      throw PersistenceFutureSchemaException(
        PersistenceIssueCode.futureSchemaReadOnly,
        revision: revision,
      );
    }
    if (envelopeVersion != PersistenceEnvelope.currentEnvelopeVersion) {
      throw PersistenceDecodeException(
        PersistenceIssueCode.unsupportedEnvelopeVersion,
        revision: revision,
      );
    }
    if (payloadSchemaVersion > supportedPayloadSchemaVersion) {
      throw PersistenceFutureSchemaException(
        PersistenceIssueCode.futureSchemaReadOnly,
        revision: revision,
      );
    }

    final typedPayload = <String, Object?>{};
    for (final entry in payload.entries) {
      final key = entry.key;
      if (key is! String) {
        throw PersistenceDecodeException(
          PersistenceIssueCode.invalidEnvelope,
          revision: revision,
        );
      }
      typedPayload[key] = entry.value;
    }

    final expectedChecksum = _calculateChecksum({
      'envelopeVersion': envelopeVersion,
      'payloadSchemaVersion': payloadSchemaVersion,
      'revision': revision,
      'payload': typedPayload,
    });
    if (checksum != expectedChecksum) {
      throw PersistenceDecodeException(
        PersistenceIssueCode.checksumMismatch,
        revision: revision,
      );
    }

    return PersistenceEnvelope(
      envelopeVersion: envelopeVersion,
      payloadSchemaVersion: payloadSchemaVersion,
      revision: revision,
      payload: typedPayload,
      checksum: checksum,
    );
  }

  int _calculateChecksum(Map<String, Object?> value) {
    final canonical = _jsonEncoder.encode(value);
    return _checksum.calculate(utf8.encode(canonical));
  }

  int _readInt(Map<String, Object?> json, String key) {
    if (!json.containsKey(key)) {
      throw const PersistenceDecodeException(
        PersistenceIssueCode.invalidEnvelope,
      );
    }
    final value = json[key];
    if (value is! int) {
      throw const PersistenceDecodeException(
        PersistenceIssueCode.invalidEnvelope,
      );
    }
    return value;
  }
}
