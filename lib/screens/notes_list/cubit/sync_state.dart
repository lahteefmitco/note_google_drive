class SyncState {
  final bool isLoading;
  final String? successMessage;
  final String? error;

  const SyncState({this.isLoading = false, this.successMessage, this.error});

  SyncState copyWith({bool? isLoading, String? successMessage, String? error}) {
    return SyncState(
      isLoading: isLoading ?? this.isLoading,
      successMessage: successMessage,
      error: error,
    );
  }
}
