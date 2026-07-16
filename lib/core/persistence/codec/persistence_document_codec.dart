abstract interface class PersistenceDocumentCodec<T> {
  int get currentSchemaVersion;

  Map<String, Object?> encode(T value);

  T decode({required int schemaVersion, required Map<String, Object?> payload});

  T get defaultValue;
}
