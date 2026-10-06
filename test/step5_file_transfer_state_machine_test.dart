import 'package:flutter_test/flutter_test.dart';
import 'package:meshlink/features/messages/domain/models/models.dart';
import 'package:meshlink/features/messages/domain/services/file_transfer_state_machine.dart';

void main() {
  const stateMachine = FileTransferStateMachine();

  group('Phase 8 Step 5 — Outgoing Transfer Lifecycle Transitions', () {
    test('valid primary outgoing happy path: initiated -> offerSent -> acceptReceived -> transferring -> completed', () {
      // 1. initiated -> offerSent
      expect(
        stateMachine.canTransition(
          direction: FileTransferDirection.outgoing,
          from: FileTransferStatus.initiated,
          to: FileTransferStatus.offerSent,
        ),
        isTrue,
      );
      final r1 = stateMachine.transition(
        direction: FileTransferDirection.outgoing,
        from: FileTransferStatus.initiated,
        to: FileTransferStatus.offerSent,
      );
      expect(r1.allowed, isTrue);
      expect(r1.previousStatus, FileTransferStatus.initiated);
      expect(r1.newStatus, FileTransferStatus.offerSent);
      expect(r1.error, isNull);

      // 2. offerSent -> acceptReceived
      expect(
        stateMachine.canTransition(
          direction: FileTransferDirection.outgoing,
          from: FileTransferStatus.offerSent,
          to: FileTransferStatus.acceptReceived,
        ),
        isTrue,
      );
      final r2 = stateMachine.transition(
        direction: FileTransferDirection.outgoing,
        from: FileTransferStatus.offerSent,
        to: FileTransferStatus.acceptReceived,
      );
      expect(r2.allowed, isTrue);
      expect(r2.previousStatus, FileTransferStatus.offerSent);
      expect(r2.newStatus, FileTransferStatus.acceptReceived);
      expect(r2.error, isNull);

      // 3. acceptReceived -> transferring
      expect(
        stateMachine.canTransition(
          direction: FileTransferDirection.outgoing,
          from: FileTransferStatus.acceptReceived,
          to: FileTransferStatus.transferring,
        ),
        isTrue,
      );
      final r3 = stateMachine.transition(
        direction: FileTransferDirection.outgoing,
        from: FileTransferStatus.acceptReceived,
        to: FileTransferStatus.transferring,
      );
      expect(r3.allowed, isTrue);
      expect(r3.previousStatus, FileTransferStatus.acceptReceived);
      expect(r3.newStatus, FileTransferStatus.transferring);
      expect(r3.error, isNull);

      // 4. transferring -> completed
      expect(
        stateMachine.canTransition(
          direction: FileTransferDirection.outgoing,
          from: FileTransferStatus.transferring,
          to: FileTransferStatus.completed,
        ),
        isTrue,
      );
      final r4 = stateMachine.transition(
        direction: FileTransferDirection.outgoing,
        from: FileTransferStatus.transferring,
        to: FileTransferStatus.completed,
      );
      expect(r4.allowed, isTrue);
      expect(r4.previousStatus, FileTransferStatus.transferring);
      expect(r4.newStatus, FileTransferStatus.completed);
      expect(r4.error, isNull);
    });

    test('invalid outgoing transitions are rejected', () {
      final invalidTransitions = [
        // Skipping steps
        (FileTransferStatus.initiated, FileTransferStatus.acceptReceived),
        (FileTransferStatus.initiated, FileTransferStatus.transferring),
        (FileTransferStatus.initiated, FileTransferStatus.completed),
        (FileTransferStatus.offerSent, FileTransferStatus.transferring),
        (FileTransferStatus.offerSent, FileTransferStatus.completed),
        (FileTransferStatus.acceptReceived, FileTransferStatus.completed),

        // Backward flow
        (FileTransferStatus.acceptReceived, FileTransferStatus.offerSent),
        (FileTransferStatus.transferring, FileTransferStatus.acceptReceived),
        (FileTransferStatus.transferring, FileTransferStatus.offerSent),
        (FileTransferStatus.transferring, FileTransferStatus.initiated),

        // Incoming states in outgoing flow
        (FileTransferStatus.initiated, FileTransferStatus.offerReceived),
        (FileTransferStatus.initiated, FileTransferStatus.acceptSent),
        (FileTransferStatus.offerSent, FileTransferStatus.acceptSent),
      ];

      for (final (from, to) in invalidTransitions) {
        expect(
          stateMachine.canTransition(
            direction: FileTransferDirection.outgoing,
            from: from,
            to: to,
          ),
          isFalse,
          reason: 'Outgoing transition from $from to $to should be rejected',
        );

        final result = stateMachine.transition(
          direction: FileTransferDirection.outgoing,
          from: from,
          to: to,
        );
        expect(result.allowed, isFalse);
        expect(result.error, isNotNull);
        expect(result.error!.isNotEmpty, isTrue);
        expect(result.previousStatus, from);
        expect(result.newStatus, to);
      }
    });

    test('outgoing failure and cancellation branches', () {
      // From offerSent -> cancelled or failed
      expect(
        stateMachine.canTransition(
          direction: FileTransferDirection.outgoing,
          from: FileTransferStatus.offerSent,
          to: FileTransferStatus.cancelled,
        ),
        isTrue,
      );
      expect(
        stateMachine.canTransition(
          direction: FileTransferDirection.outgoing,
          from: FileTransferStatus.offerSent,
          to: FileTransferStatus.failed,
        ),
        isTrue,
      );

      // From acceptReceived -> cancelled or failed
      expect(
        stateMachine.canTransition(
          direction: FileTransferDirection.outgoing,
          from: FileTransferStatus.acceptReceived,
          to: FileTransferStatus.cancelled,
        ),
        isTrue,
      );
      expect(
        stateMachine.canTransition(
          direction: FileTransferDirection.outgoing,
          from: FileTransferStatus.acceptReceived,
          to: FileTransferStatus.failed,
        ),
        isTrue,
      );
    });
  });

  group('Phase 8 Step 5 — Incoming Transfer Lifecycle Transitions', () {
    test('valid primary incoming happy path: initiated -> offerReceived -> acceptSent -> transferring -> completed', () {
      // 1. initiated -> offerReceived
      expect(
        stateMachine.canTransition(
          direction: FileTransferDirection.incoming,
          from: FileTransferStatus.initiated,
          to: FileTransferStatus.offerReceived,
        ),
        isTrue,
      );
      final r1 = stateMachine.transition(
        direction: FileTransferDirection.incoming,
        from: FileTransferStatus.initiated,
        to: FileTransferStatus.offerReceived,
      );
      expect(r1.allowed, isTrue);
      expect(r1.previousStatus, FileTransferStatus.initiated);
      expect(r1.newStatus, FileTransferStatus.offerReceived);
      expect(r1.error, isNull);

      // 2. offerReceived -> acceptSent
      expect(
        stateMachine.canTransition(
          direction: FileTransferDirection.incoming,
          from: FileTransferStatus.offerReceived,
          to: FileTransferStatus.acceptSent,
        ),
        isTrue,
      );
      final r2 = stateMachine.transition(
        direction: FileTransferDirection.incoming,
        from: FileTransferStatus.offerReceived,
        to: FileTransferStatus.acceptSent,
      );
      expect(r2.allowed, isTrue);
      expect(r2.previousStatus, FileTransferStatus.offerReceived);
      expect(r2.newStatus, FileTransferStatus.acceptSent);
      expect(r2.error, isNull);

      // 3. acceptSent -> transferring
      expect(
        stateMachine.canTransition(
          direction: FileTransferDirection.incoming,
          from: FileTransferStatus.acceptSent,
          to: FileTransferStatus.transferring,
        ),
        isTrue,
      );
      final r3 = stateMachine.transition(
        direction: FileTransferDirection.incoming,
        from: FileTransferStatus.acceptSent,
        to: FileTransferStatus.transferring,
      );
      expect(r3.allowed, isTrue);
      expect(r3.previousStatus, FileTransferStatus.acceptSent);
      expect(r3.newStatus, FileTransferStatus.transferring);
      expect(r3.error, isNull);

      // 4. transferring -> completed
      expect(
        stateMachine.canTransition(
          direction: FileTransferDirection.incoming,
          from: FileTransferStatus.transferring,
          to: FileTransferStatus.completed,
        ),
        isTrue,
      );
      final r4 = stateMachine.transition(
        direction: FileTransferDirection.incoming,
        from: FileTransferStatus.transferring,
        to: FileTransferStatus.completed,
      );
      expect(r4.allowed, isTrue);
      expect(r4.previousStatus, FileTransferStatus.transferring);
      expect(r4.newStatus, FileTransferStatus.completed);
      expect(r4.error, isNull);
    });

    test('invalid incoming transitions are rejected', () {
      final invalidTransitions = [
        // Outgoing states in incoming flow
        (FileTransferStatus.initiated, FileTransferStatus.offerSent),
        (FileTransferStatus.initiated, FileTransferStatus.acceptReceived),
        (FileTransferStatus.offerReceived, FileTransferStatus.acceptReceived),

        // Skipping steps
        (FileTransferStatus.initiated, FileTransferStatus.acceptSent),
        (FileTransferStatus.initiated, FileTransferStatus.transferring),
        (FileTransferStatus.initiated, FileTransferStatus.completed),
        (FileTransferStatus.offerReceived, FileTransferStatus.transferring),
        (FileTransferStatus.offerReceived, FileTransferStatus.completed),
        (FileTransferStatus.acceptSent, FileTransferStatus.completed),

        // Backward flow
        (FileTransferStatus.acceptSent, FileTransferStatus.offerReceived),
        (FileTransferStatus.transferring, FileTransferStatus.acceptSent),
        (FileTransferStatus.transferring, FileTransferStatus.offerReceived),
        (FileTransferStatus.transferring, FileTransferStatus.initiated),
      ];

      for (final (from, to) in invalidTransitions) {
        expect(
          stateMachine.canTransition(
            direction: FileTransferDirection.incoming,
            from: from,
            to: to,
          ),
          isFalse,
          reason: 'Incoming transition from $from to $to should be rejected',
        );

        final result = stateMachine.transition(
          direction: FileTransferDirection.incoming,
          from: from,
          to: to,
        );
        expect(result.allowed, isFalse);
        expect(result.error, isNotNull);
        expect(result.error!.isNotEmpty, isTrue);
        expect(result.previousStatus, from);
        expect(result.newStatus, to);
      }
    });

    test('incoming failure and cancellation branches', () {
      // From offerReceived -> cancelled or failed
      expect(
        stateMachine.canTransition(
          direction: FileTransferDirection.incoming,
          from: FileTransferStatus.offerReceived,
          to: FileTransferStatus.cancelled,
        ),
        isTrue,
      );
      expect(
        stateMachine.canTransition(
          direction: FileTransferDirection.incoming,
          from: FileTransferStatus.offerReceived,
          to: FileTransferStatus.failed,
        ),
        isTrue,
      );

      // From acceptSent -> cancelled or failed
      expect(
        stateMachine.canTransition(
          direction: FileTransferDirection.incoming,
          from: FileTransferStatus.acceptSent,
          to: FileTransferStatus.cancelled,
        ),
        isTrue,
      );
      expect(
        stateMachine.canTransition(
          direction: FileTransferDirection.incoming,
          from: FileTransferStatus.acceptSent,
          to: FileTransferStatus.failed,
        ),
        isTrue,
      );
    });
  });

  group('Phase 8 Step 5 — Common Lifecycle (Pause, Resume, Failure, Cancel)', () {
    for (final dir in FileTransferDirection.values) {
      test('transferring -> paused, cancelled, failed is allowed for ${dir.name}', () {
        expect(
          stateMachine.canTransition(
            direction: dir,
            from: FileTransferStatus.transferring,
            to: FileTransferStatus.paused,
          ),
          isTrue,
        );
        expect(
          stateMachine.canTransition(
            direction: dir,
            from: FileTransferStatus.transferring,
            to: FileTransferStatus.cancelled,
          ),
          isTrue,
        );
        expect(
          stateMachine.canTransition(
            direction: dir,
            from: FileTransferStatus.transferring,
            to: FileTransferStatus.failed,
          ),
          isTrue,
        );

        final rPause = stateMachine.transition(
          direction: dir,
          from: FileTransferStatus.transferring,
          to: FileTransferStatus.paused,
        );
        expect(rPause.allowed, isTrue);
        expect(rPause.previousStatus, FileTransferStatus.transferring);
        expect(rPause.newStatus, FileTransferStatus.paused);
      });

      test('paused -> transferring, cancelled, failed is allowed for ${dir.name}', () {
        expect(
          stateMachine.canTransition(
            direction: dir,
            from: FileTransferStatus.paused,
            to: FileTransferStatus.transferring,
          ),
          isTrue,
        );
        expect(
          stateMachine.canTransition(
            direction: dir,
            from: FileTransferStatus.paused,
            to: FileTransferStatus.cancelled,
          ),
          isTrue,
        );
        expect(
          stateMachine.canTransition(
            direction: dir,
            from: FileTransferStatus.paused,
            to: FileTransferStatus.failed,
          ),
          isTrue,
        );

        final rResume = stateMachine.transition(
          direction: dir,
          from: FileTransferStatus.paused,
          to: FileTransferStatus.transferring,
        );
        expect(rResume.allowed, isTrue);
        expect(rResume.previousStatus, FileTransferStatus.paused);
        expect(rResume.newStatus, FileTransferStatus.transferring);
      });

      test('paused cannot directly jump to completed without transferring for ${dir.name}', () {
        expect(
          stateMachine.canTransition(
            direction: dir,
            from: FileTransferStatus.paused,
            to: FileTransferStatus.completed,
          ),
          isFalse,
        );
      });
    }
  });

  group('Phase 8 Step 5 — Terminal States Enforcement', () {
    final terminalStates = [
      FileTransferStatus.completed,
      FileTransferStatus.cancelled,
      FileTransferStatus.failed,
    ];

    test('isTerminal reports true for completed, cancelled, failed and false for others', () {
      for (final status in FileTransferStatus.values) {
        final expected = terminalStates.contains(status);
        expect(
          stateMachine.isTerminal(status),
          expected,
          reason: '$status terminal check failed',
        );
      }
    });

    for (final dir in FileTransferDirection.values) {
      for (final terminal in terminalStates) {
        test('$terminal is terminal and rejects transitions to all states for ${dir.name}', () {
          expect(stateMachine.allowedNextStates(direction: dir, current: terminal), isEmpty);

          for (final target in FileTransferStatus.values) {
            expect(
              stateMachine.canTransition(direction: dir, from: terminal, to: target),
              isFalse,
              reason: 'Cannot transition from terminal $terminal to $target (${dir.name})',
            );

            final result = stateMachine.transition(direction: dir, from: terminal, to: target);
            expect(result.allowed, isFalse);
            expect(result.previousStatus, terminal);
            expect(result.newStatus, target);
            expect(result.error, isNotNull);
            expect(
              result.error,
              anyOf([
                contains('terminal status'),
                contains('Same-state transition is not allowed'),
              ]),
            );
          }
        });
      }
    }
  });

  group('Phase 8 Step 5 — Same-State Transitions Policy', () {
    test('same-state transitions are rejected across all statuses and directions', () {
      for (final dir in FileTransferDirection.values) {
        for (final status in FileTransferStatus.values) {
          expect(
            stateMachine.canTransition(direction: dir, from: status, to: status),
            isFalse,
            reason: 'Same-state transition for $status should be rejected',
          );

          final result = stateMachine.transition(direction: dir, from: status, to: status);
          expect(result.allowed, isFalse);
          expect(result.previousStatus, status);
          expect(result.newStatus, status);
          expect(
            result.error,
            contains("Same-state transition is not allowed: already in '${status.name}' status."),
          );
        }
      }
    });
  });

  group('Phase 8 Step 5 — Direction Isolation Tests', () {
    test('outgoing-specific states cannot be entered in incoming direction', () {
      final outgoingSpecific = [
        FileTransferStatus.offerSent,
        FileTransferStatus.acceptReceived,
      ];

      for (final from in FileTransferStatus.values) {
        for (final to in outgoingSpecific) {
          expect(
            stateMachine.canTransition(
              direction: FileTransferDirection.incoming,
              from: from,
              to: to,
            ),
            isFalse,
          );
        }
      }
    });

    test('incoming-specific states cannot be entered in outgoing direction', () {
      final incomingSpecific = [
        FileTransferStatus.offerReceived,
        FileTransferStatus.acceptSent,
      ];

      for (final from in FileTransferStatus.values) {
        for (final to in incomingSpecific) {
          expect(
            stateMachine.canTransition(
              direction: FileTransferDirection.outgoing,
              from: from,
              to: to,
            ),
            isFalse,
          );
        }
      }
    });

    test('direction mismatch yields informative diagnostic error messages', () {
      final outgoingMismatch = stateMachine.transition(
        direction: FileTransferDirection.outgoing,
        from: FileTransferStatus.initiated,
        to: FileTransferStatus.offerReceived,
      );
      expect(outgoingMismatch.allowed, isFalse);
      expect(outgoingMismatch.error, contains("Status 'offerReceived' is only valid for incoming transfers."));

      final incomingMismatch = stateMachine.transition(
        direction: FileTransferDirection.incoming,
        from: FileTransferStatus.initiated,
        to: FileTransferStatus.offerSent,
      );
      expect(incomingMismatch.allowed, isFalse);
      expect(incomingMismatch.error, contains("Status 'offerSent' is only valid for outgoing transfers."));
    });
  });

  group('Phase 8 Step 5 — allowedNextStates API Tests', () {
    test('allowedNextStates returns exact expected sets for outgoing transfers', () {
      expect(
        stateMachine.allowedNextStates(
          direction: FileTransferDirection.outgoing,
          current: FileTransferStatus.initiated,
        ),
        [FileTransferStatus.offerSent],
      );

      expect(
        stateMachine.allowedNextStates(
          direction: FileTransferDirection.outgoing,
          current: FileTransferStatus.offerSent,
        ),
        unorderedEquals([
          FileTransferStatus.acceptReceived,
          FileTransferStatus.cancelled,
          FileTransferStatus.failed,
        ]),
      );

      expect(
        stateMachine.allowedNextStates(
          direction: FileTransferDirection.outgoing,
          current: FileTransferStatus.acceptReceived,
        ),
        unorderedEquals([
          FileTransferStatus.transferring,
          FileTransferStatus.cancelled,
          FileTransferStatus.failed,
        ]),
      );

      expect(
        stateMachine.allowedNextStates(
          direction: FileTransferDirection.outgoing,
          current: FileTransferStatus.transferring,
        ),
        unorderedEquals([
          FileTransferStatus.completed,
          FileTransferStatus.paused,
          FileTransferStatus.cancelled,
          FileTransferStatus.failed,
        ]),
      );

      expect(
        stateMachine.allowedNextStates(
          direction: FileTransferDirection.outgoing,
          current: FileTransferStatus.paused,
        ),
        unorderedEquals([
          FileTransferStatus.transferring,
          FileTransferStatus.cancelled,
          FileTransferStatus.failed,
        ]),
      );

      expect(
        stateMachine.allowedNextStates(
          direction: FileTransferDirection.outgoing,
          current: FileTransferStatus.completed,
        ),
        isEmpty,
      );
      expect(
        stateMachine.allowedNextStates(
          direction: FileTransferDirection.outgoing,
          current: FileTransferStatus.cancelled,
        ),
        isEmpty,
      );
      expect(
        stateMachine.allowedNextStates(
          direction: FileTransferDirection.outgoing,
          current: FileTransferStatus.failed,
        ),
        isEmpty,
      );
    });

    test('allowedNextStates returns exact expected sets for incoming transfers', () {
      expect(
        stateMachine.allowedNextStates(
          direction: FileTransferDirection.incoming,
          current: FileTransferStatus.initiated,
        ),
        [FileTransferStatus.offerReceived],
      );

      expect(
        stateMachine.allowedNextStates(
          direction: FileTransferDirection.incoming,
          current: FileTransferStatus.offerReceived,
        ),
        unorderedEquals([
          FileTransferStatus.acceptSent,
          FileTransferStatus.cancelled,
          FileTransferStatus.failed,
        ]),
      );

      expect(
        stateMachine.allowedNextStates(
          direction: FileTransferDirection.incoming,
          current: FileTransferStatus.acceptSent,
        ),
        unorderedEquals([
          FileTransferStatus.transferring,
          FileTransferStatus.cancelled,
          FileTransferStatus.failed,
        ]),
      );

      expect(
        stateMachine.allowedNextStates(
          direction: FileTransferDirection.incoming,
          current: FileTransferStatus.transferring,
        ),
        unorderedEquals([
          FileTransferStatus.completed,
          FileTransferStatus.paused,
          FileTransferStatus.cancelled,
          FileTransferStatus.failed,
        ]),
      );

      expect(
        stateMachine.allowedNextStates(
          direction: FileTransferDirection.incoming,
          current: FileTransferStatus.paused,
        ),
        unorderedEquals([
          FileTransferStatus.transferring,
          FileTransferStatus.cancelled,
          FileTransferStatus.failed,
        ]),
      );

      expect(
        stateMachine.allowedNextStates(
          direction: FileTransferDirection.incoming,
          current: FileTransferStatus.completed,
        ),
        isEmpty,
      );
      expect(
        stateMachine.allowedNextStates(
          direction: FileTransferDirection.incoming,
          current: FileTransferStatus.cancelled,
        ),
        isEmpty,
      );
      expect(
        stateMachine.allowedNextStates(
          direction: FileTransferDirection.incoming,
          current: FileTransferStatus.failed,
        ),
        isEmpty,
      );
    });
  });

  group('Phase 8 Step 5 — applyTransition Pure Domain Integration', () {
    final baseTime = DateTime.utc(2026, 10, 6, 10, 0, 0);

    FileTransfer createSampleTransfer({
      required FileTransferDirection direction,
      required FileTransferStatus status,
    }) {
      return FileTransfer(
        transferId: 'FT-TEST-001',
        conversationId: 'CONV-PEER-1',
        peerId: 'PEER-1',
        direction: direction,
        fileName: 'notes.txt',
        fileSize: 1024,
        mimeType: 'text/plain',
        fileHash: 'sha256-hash-1234',
        localPath: '/safe/notes.txt',
        stagingPath: '/safe/staging/notes.txt.part',
        totalChunks: 1,
        chunkSize: 16384,
        status: status,
        createdAt: baseTime,
        updatedAt: baseTime,
      );
    }

    test('applyTransition returns a new instance with updated status and time', () {
      final transfer = createSampleTransfer(
        direction: FileTransferDirection.outgoing,
        status: FileTransferStatus.initiated,
      );

      final nextTime = DateTime.utc(2026, 10, 6, 10, 1, 0);
      final updated = stateMachine.applyTransition(
        transfer: transfer,
        to: FileTransferStatus.offerSent,
        updatedAt: nextTime,
      );

      // Verify returned transfer has new status and timestamp
      expect(updated.status, FileTransferStatus.offerSent);
      expect(updated.updatedAt, nextTime);
      expect(updated.transferId, transfer.transferId);
      expect(updated.fileName, transfer.fileName);
      expect(updated.fileSize, transfer.fileSize);

      // Verify immutability: original object is completely unchanged
      expect(transfer.status, FileTransferStatus.initiated);
      expect(transfer.updatedAt, baseTime);
    });

    test('applyTransition throws StateError on invalid transition without modifying transfer', () {
      final transfer = createSampleTransfer(
        direction: FileTransferDirection.outgoing,
        status: FileTransferStatus.initiated,
      );

      expect(
        () => stateMachine.applyTransition(
          transfer: transfer,
          to: FileTransferStatus.transferring, // Invalid transition
        ),
        throwsStateError,
      );

      expect(transfer.status, FileTransferStatus.initiated);
      expect(transfer.updatedAt, baseTime);
    });
  });

  group('Phase 8 Step 5 — Invariant & Exhaustive Coverage Tests', () {
    test('Invariant 1: No terminal state has outgoing transitions', () {
      for (final dir in FileTransferDirection.values) {
        for (final terminal in FileTransferStateMachine.terminalStatuses) {
          expect(stateMachine.allowedNextStates(direction: dir, current: terminal), isEmpty);
          for (final target in FileTransferStatus.values) {
            expect(
              stateMachine.canTransition(direction: dir, from: terminal, to: target),
              isFalse,
            );
          }
        }
      }
    });

    test('Invariant 2: Every allowedNextState is consistent with canTransition', () {
      for (final dir in FileTransferDirection.values) {
        for (final from in FileTransferStatus.values) {
          final nextStates = stateMachine.allowedNextStates(direction: dir, current: from);
          for (final to in FileTransferStatus.values) {
            final can = stateMachine.canTransition(direction: dir, from: from, to: to);
            expect(
              can,
              nextStates.contains(to),
              reason: 'Mismatch between allowedNextStates and canTransition for $dir: $from -> $to',
            );
          }
        }
      }
    });

    test('Invariant 3: transition.allowed strictly matches canTransition for all 200 (dir, from, to) combinations', () {
      var evaluatedTransitions = 0;
      for (final dir in FileTransferDirection.values) {
        for (final from in FileTransferStatus.values) {
          for (final to in FileTransferStatus.values) {
            final can = stateMachine.canTransition(direction: dir, from: from, to: to);
            final result = stateMachine.transition(direction: dir, from: from, to: to);

            expect(
              result.allowed,
              can,
              reason: 'canTransition and transition disagree on $dir: $from -> $to',
            );
            if (result.allowed) {
              expect(result.error, isNull);
              expect(result.previousStatus, from);
              expect(result.newStatus, to);
            } else {
              expect(result.error, isNotNull);
              expect(result.error!.isNotEmpty, isTrue);
              expect(result.previousStatus, from);
              expect(result.newStatus, to);
            }
            evaluatedTransitions++;
          }
        }
      }
      expect(evaluatedTransitions, 2 * 10 * 10); // 2 directions * 10 statuses * 10 statuses = 200 combinations
    });

    test('Invariant 4: Determinism — repeated evaluations yield identical results', () {
      for (var i = 0; i < 50; i++) {
        final r1 = stateMachine.transition(
          direction: FileTransferDirection.outgoing,
          from: FileTransferStatus.transferring,
          to: FileTransferStatus.completed,
        );
        expect(r1.allowed, isTrue);
        expect(r1.previousStatus, FileTransferStatus.transferring);
        expect(r1.newStatus, FileTransferStatus.completed);

        final r2 = stateMachine.transition(
          direction: FileTransferDirection.incoming,
          from: FileTransferStatus.completed,
          to: FileTransferStatus.transferring,
        );
        expect(r2.allowed, isFalse);
        expect(r2.error, contains('terminal status'));
      }
    });

    test('FileTransferTransitionResult equality and toString', () {
      const res1 = FileTransferTransitionResult.success(
        previousStatus: FileTransferStatus.initiated,
        newStatus: FileTransferStatus.offerSent,
      );
      const res2 = FileTransferTransitionResult.success(
        previousStatus: FileTransferStatus.initiated,
        newStatus: FileTransferStatus.offerSent,
      );
      const res3 = FileTransferTransitionResult.failure(
        previousStatus: FileTransferStatus.initiated,
        newStatus: FileTransferStatus.transferring,
        error: 'Invalid',
      );

      expect(res1, equals(res2));
      expect(res1.hashCode, equals(res2.hashCode));
      expect(res1 == res3, isFalse);
      expect(res1.toString(), contains('success'));
      expect(res3.toString(), contains('failure'));
    });
  });
}
