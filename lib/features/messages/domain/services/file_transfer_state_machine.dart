import 'package:meshlink/features/messages/domain/models/models.dart';

/// Structured outcome of a state transition attempt.
class FileTransferTransitionResult {
  const FileTransferTransitionResult({
    required this.allowed,
    this.previousStatus,
    this.newStatus,
    this.error,
  });

  /// Factory constructor for a successful transition.
  const FileTransferTransitionResult.success({
    required this.previousStatus,
    required this.newStatus,
  }) : allowed = true,
       error = null;

  /// Factory constructor for an invalid or rejected transition.
  const FileTransferTransitionResult.failure({
    required this.previousStatus,
    required this.newStatus,
    required this.error,
  }) : allowed = false;


  /// Whether the requested state transition is allowed.
  final bool allowed;

  /// The status before the transition attempt.
  final FileTransferStatus? previousStatus;

  /// The requested target status.
  final FileTransferStatus? newStatus;

  /// Explanatory message when the transition is rejected, or null if allowed.
  final String? error;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileTransferTransitionResult &&
          runtimeType == other.runtimeType &&
          allowed == other.allowed &&
          previousStatus == other.previousStatus &&
          newStatus == other.newStatus &&
          error == other.error;

  @override
  int get hashCode => Object.hash(allowed, previousStatus, newStatus, error);

  @override
  String toString() {
    if (allowed) {
      return 'FileTransferTransitionResult.success(from: ${previousStatus?.name}, to: ${newStatus?.name})';
    }
    return 'FileTransferTransitionResult.failure(from: ${previousStatus?.name}, to: ${newStatus?.name}, error: $error)';
  }
}

/// Pure domain state machine engine controlling file-transfer lifecycle transitions.
///
/// Fully deterministic and independent of Flutter UI, BLE transport, MeshRouter,
/// filesystem operations, cryptography, and database persistence.
class FileTransferStateMachine {
  const FileTransferStateMachine();

  /// Default singleton/const instance for convenient reuse.
  static const FileTransferStateMachine instance = FileTransferStateMachine();

  /// Terminal statuses from which no subsequent transitions are permitted.
  static const Set<FileTransferStatus> terminalStatuses = {
    FileTransferStatus.completed,
    FileTransferStatus.cancelled,
    FileTransferStatus.failed,
  };

  /// Terminal statuses getter for instance access.
  Set<FileTransferStatus> get terminalStates => terminalStatuses;

  /// Allowed transitions for outgoing file transfers.
  static const Map<FileTransferStatus, Set<FileTransferStatus>> _outgoingTransitions = {
    FileTransferStatus.initiated: {
      FileTransferStatus.offerSent,
    },
    FileTransferStatus.offerSent: {
      FileTransferStatus.acceptReceived,
      FileTransferStatus.cancelled,
      FileTransferStatus.failed,
    },
    FileTransferStatus.acceptReceived: {
      FileTransferStatus.transferring,
      FileTransferStatus.cancelled,
      FileTransferStatus.failed,
    },
    FileTransferStatus.transferring: {
      FileTransferStatus.completed,
      FileTransferStatus.paused,
      FileTransferStatus.cancelled,
      FileTransferStatus.failed,
    },
    FileTransferStatus.paused: {
      FileTransferStatus.transferring,
      FileTransferStatus.cancelled,
      FileTransferStatus.failed,
    },
    FileTransferStatus.completed: {},
    FileTransferStatus.cancelled: {},
    FileTransferStatus.failed: {},
    FileTransferStatus.offerReceived: {},
    FileTransferStatus.acceptSent: {},
  };

  /// Allowed transitions for incoming file transfers.
  static const Map<FileTransferStatus, Set<FileTransferStatus>> _incomingTransitions = {
    FileTransferStatus.initiated: {
      FileTransferStatus.offerReceived,
    },
    FileTransferStatus.offerReceived: {
      FileTransferStatus.acceptSent,
      FileTransferStatus.cancelled,
      FileTransferStatus.failed,
    },
    FileTransferStatus.acceptSent: {
      FileTransferStatus.transferring,
      FileTransferStatus.cancelled,
      FileTransferStatus.failed,
    },
    FileTransferStatus.transferring: {
      FileTransferStatus.completed,
      FileTransferStatus.paused,
      FileTransferStatus.cancelled,
      FileTransferStatus.failed,
    },
    FileTransferStatus.paused: {
      FileTransferStatus.transferring,
      FileTransferStatus.cancelled,
      FileTransferStatus.failed,
    },
    FileTransferStatus.completed: {},
    FileTransferStatus.cancelled: {},
    FileTransferStatus.failed: {},
    FileTransferStatus.offerSent: {},
    FileTransferStatus.acceptReceived: {},
  };

  /// Returns true if [status] is a terminal transfer status.
  bool isTerminal(FileTransferStatus status) => terminalStatuses.contains(status);

  /// Returns whether a transition from [from] to [to] is valid for [direction].
  bool canTransition({
    required FileTransferDirection direction,
    required FileTransferStatus from,
    required FileTransferStatus to,
  }) {
    if (from == to) return false;
    if (isTerminal(from)) return false;

    final transitions = direction == FileTransferDirection.outgoing
        ? _outgoingTransitions
        : _incomingTransitions;

    final allowed = transitions[from];
    return allowed != null && allowed.contains(to);
  }

  /// Evaluates and executes a transition from [from] to [to] for [direction].
  ///
  /// Returns a [FileTransferTransitionResult] indicating whether the transition
  /// was accepted, along with status info and any failure reason.
  FileTransferTransitionResult transition({
    required FileTransferDirection direction,
    required FileTransferStatus from,
    required FileTransferStatus to,
  }) {
    // 1. Same-state check (redundant transitions rejected)
    if (from == to) {
      return FileTransferTransitionResult.failure(
        previousStatus: from,
        newStatus: to,
        error: "Same-state transition is not allowed: already in '${from.name}' status.",
      );
    }

    // 2. Terminal state check
    if (isTerminal(from)) {
      return FileTransferTransitionResult.failure(
        previousStatus: from,
        newStatus: to,
        error: "Cannot transition from terminal status '${from.name}' to '${to.name}'.",
      );
    }

    final transitions = direction == FileTransferDirection.outgoing
        ? _outgoingTransitions
        : _incomingTransitions;

    final allowed = transitions[from] ?? const <FileTransferStatus>{};

    // 3. Valid transition
    if (allowed.contains(to)) {
      return FileTransferTransitionResult.success(
        previousStatus: from,
        newStatus: to,
      );
    }

    // 4. Direction mismatch diagnostic
    if (direction == FileTransferDirection.outgoing &&
        (to == FileTransferStatus.offerReceived || to == FileTransferStatus.acceptSent)) {
      return FileTransferTransitionResult.failure(
        previousStatus: from,
        newStatus: to,
        error: "Status '${to.name}' is only valid for incoming transfers.",
      );
    }

    if (direction == FileTransferDirection.incoming &&
        (to == FileTransferStatus.offerSent || to == FileTransferStatus.acceptReceived)) {
      return FileTransferTransitionResult.failure(
        previousStatus: from,
        newStatus: to,
        error: "Status '${to.name}' is only valid for outgoing transfers.",
      );
    }

    if (allowed.isEmpty) {
      return FileTransferTransitionResult.failure(
        previousStatus: from,
        newStatus: to,
        error: "No transitions are allowed from '${from.name}' for ${direction.name} transfers.",
      );
    }

    final allowedNames = allowed.map((s) => s.name).join(', ');
    return FileTransferTransitionResult.failure(
      previousStatus: from,
      newStatus: to,
      error: "Invalid transition from '${from.name}' to '${to.name}' for ${direction.name} transfer. Allowed next states: [$allowedNames].",
    );
  }

  /// Returns the ordered list of statuses that can be legally transitioned to
  /// from [current] for [direction].
  List<FileTransferStatus> allowedNextStates({
    required FileTransferDirection direction,
    required FileTransferStatus current,
  }) {
    if (isTerminal(current)) return const <FileTransferStatus>[];

    final transitions = direction == FileTransferDirection.outgoing
        ? _outgoingTransitions
        : _incomingTransitions;

    return (transitions[current] ?? const <FileTransferStatus>{}).toList();
  }

  /// Pure in-memory helper to transition a [FileTransfer] domain model.
  ///
  /// Validates the transition and returns a new copy of [FileTransfer] with the
  /// updated status and timestamp. Does NOT perform any database operations.
  /// Throws [StateError] if the transition is invalid.
  FileTransfer applyTransition({
    required FileTransfer transfer,
    required FileTransferStatus to,
    DateTime? updatedAt,
  }) {
    final result = transition(
      direction: transfer.direction,
      from: transfer.status,
      to: to,
    );

    if (!result.allowed) {
      throw StateError(
        'Cannot apply transition: ${result.error ?? "Invalid transition from ${transfer.status.name} to ${to.name}"}',
      );
    }

    return transfer.copyWith(
      status: to,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
    );
  }
}
