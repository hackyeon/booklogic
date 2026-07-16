enum PersistenceLoadStatus {
  loadedPrimary,
  recoveredPending,
  recoveredBackup,
  migratedLegacy,
  createdDefault,
  resetAfterCorruption,
  futureSchemaReadOnly,
}
