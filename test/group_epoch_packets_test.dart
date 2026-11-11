import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshlink/features/messages/data/models/group_epoch_packets.dart';

void main() {
  final testTimestamp = DateTime.utc(2026, 11, 11, 14, 30, 0);
  const testOpId = '0123456789abcdef0123456789abcdef';
  const testGroupId = 'GRP-1730000000000-A1B2C3';
  const testAdminId = 'PEER-ADMIN-NODE';
  const testMemberId = 'PEER-MEMBER-NODE';

  group('Phase 9 Step 6.2 — Re-epoch Packet Models & Serialization Tests', () {
    // =========================================================================
    // 1. Round-trip serialization for all eight packet types
    // =========================================================================
    group('1. Round-trip serialization for all eight packet types', () {
      test('1.1 GroupEpochPreparePacket round-trip serialization', () {
        final packet = GroupEpochPreparePacket(
          operationId: testOpId,
          groupId: testGroupId,
          previousEpoch: 1,
          targetEpoch: 2,
          operationSequenceNumber: 1,
          adminPeerId: testAdminId,
          timestamp: testTimestamp,
        );

        // toMap / fromMap
        final map = packet.toMap();
        expect(map['type'], GroupEpochPreparePacket.packetType);
        expect(map['version'], 1);
        expect(map['operationId'], testOpId);
        expect(map['groupId'], testGroupId);
        expect(map['previousEpoch'], 1);
        expect(map['targetEpoch'], 2);
        expect(map['operationSequenceNumber'], 1);
        expect(map['adminPeerId'], testAdminId);
        expect(map['timestamp'], testTimestamp.toIso8601String());
        expect(map['canonicalPayload'], isNotEmpty);

        final fromMapPacket = GroupEpochPreparePacket.fromMap(map);
        expect(fromMapPacket, equals(packet));
        expect(fromMapPacket.canonicalPayload, equals(packet.canonicalPayload));

        // toJson / fromJson
        final jsonStr = packet.toJson();
        final fromJsonPacket = GroupEpochPreparePacket.fromJson(jsonStr);
        expect(fromJsonPacket, equals(packet));

        // Polymorphic GroupEpochPacket.fromMap / fromJson
        final polymorphic = GroupEpochPacket.fromJson(jsonStr);
        expect(polymorphic, isA<GroupEpochPreparePacket>());
        expect(polymorphic, equals(packet));
      });

      test('1.2 GroupEpochPrepareAckPacket round-trip serialization', () {
        final packet = GroupEpochPrepareAckPacket(
          operationId: testOpId,
          groupId: testGroupId,
          memberPeerId: testMemberId,
          targetEpoch: 2,
          status: GroupEpochAckStatus.acknowledged,
          timestamp: testTimestamp,
        );

        final map = packet.toMap();
        expect(map['type'], GroupEpochPrepareAckPacket.packetType);
        expect(map['status'], 'acknowledged');

        final fromMapPacket = GroupEpochPrepareAckPacket.fromMap(map);
        expect(fromMapPacket, equals(packet));

        final jsonStr = packet.toJson();
        final fromJsonPacket = GroupEpochPrepareAckPacket.fromJson(jsonStr);
        expect(fromJsonPacket, equals(packet));

        final polymorphic = GroupEpochPacket.fromJson(jsonStr);
        expect(polymorphic, isA<GroupEpochPrepareAckPacket>());
        expect(polymorphic, equals(packet));
      });

      test('1.3 GroupEpochCommitPacket round-trip serialization', () {
        final packet = GroupEpochCommitPacket(
          operationId: testOpId,
          groupId: testGroupId,
          previousEpoch: 1,
          targetEpoch: 2,
          sequenceNumber: 1,
          adminPeerId: testAdminId,
          timestamp: testTimestamp,
        );

        final map = packet.toMap();
        expect(map['type'], GroupEpochCommitPacket.packetType);
        expect(map['sequenceNumber'], 1);

        final fromMapPacket = GroupEpochCommitPacket.fromMap(map);
        expect(fromMapPacket, equals(packet));

        final jsonStr = packet.toJson();
        final fromJsonPacket = GroupEpochCommitPacket.fromJson(jsonStr);
        expect(fromJsonPacket, equals(packet));

        final polymorphic = GroupEpochPacket.fromJson(jsonStr);
        expect(polymorphic, isA<GroupEpochCommitPacket>());
        expect(polymorphic, equals(packet));
      });

      test('1.4 GroupEpochCommitAckPacket round-trip serialization', () {
        final packet = GroupEpochCommitAckPacket(
          operationId: testOpId,
          groupId: testGroupId,
          memberPeerId: testMemberId,
          targetEpoch: 2,
          status: GroupEpochAckStatus.acknowledged,
          timestamp: testTimestamp,
        );

        final map = packet.toMap();
        expect(map['type'], GroupEpochCommitAckPacket.packetType);
        expect(map['status'], 'acknowledged');

        final fromMapPacket = GroupEpochCommitAckPacket.fromMap(map);
        expect(fromMapPacket, equals(packet));

        final jsonStr = packet.toJson();
        final fromJsonPacket = GroupEpochCommitAckPacket.fromJson(jsonStr);
        expect(fromJsonPacket, equals(packet));

        final polymorphic = GroupEpochPacket.fromJson(jsonStr);
        expect(polymorphic, isA<GroupEpochCommitAckPacket>());
        expect(polymorphic, equals(packet));
      });

      test('1.5 GroupEpochFinalizePacket round-trip serialization', () {
        final packet = GroupEpochFinalizePacket(
          operationId: testOpId,
          groupId: testGroupId,
          previousEpoch: 1,
          targetEpoch: 2,
          sequenceNumber: 1,
          adminPeerId: testAdminId,
          timestamp: testTimestamp,
        );

        final map = packet.toMap();
        expect(map['type'], GroupEpochFinalizePacket.packetType);

        final fromMapPacket = GroupEpochFinalizePacket.fromMap(map);
        expect(fromMapPacket, equals(packet));

        final jsonStr = packet.toJson();
        final fromJsonPacket = GroupEpochFinalizePacket.fromJson(jsonStr);
        expect(fromJsonPacket, equals(packet));

        final polymorphic = GroupEpochPacket.fromJson(jsonStr);
        expect(polymorphic, isA<GroupEpochFinalizePacket>());
        expect(polymorphic, equals(packet));
      });

      test('1.6 GroupEpochFinalizeAckPacket round-trip serialization', () {
        final packet = GroupEpochFinalizeAckPacket(
          operationId: testOpId,
          groupId: testGroupId,
          memberPeerId: testMemberId,
          targetEpoch: 2,
          status: GroupEpochAckStatus.acknowledged,
          timestamp: testTimestamp,
        );

        final map = packet.toMap();
        expect(map['type'], GroupEpochFinalizeAckPacket.packetType);

        final fromMapPacket = GroupEpochFinalizeAckPacket.fromMap(map);
        expect(fromMapPacket, equals(packet));

        final jsonStr = packet.toJson();
        final fromJsonPacket = GroupEpochFinalizeAckPacket.fromJson(jsonStr);
        expect(fromJsonPacket, equals(packet));

        final polymorphic = GroupEpochPacket.fromJson(jsonStr);
        expect(polymorphic, isA<GroupEpochFinalizeAckPacket>());
        expect(polymorphic, equals(packet));
      });

      test('1.7 GroupEpochStatusProbePacket round-trip serialization', () {
        final packet = GroupEpochStatusProbePacket(
          operationId: testOpId,
          groupId: testGroupId,
          requestingPeerId: testMemberId,
          knownEpoch: 1,
          knownSequenceNumber: 0,
          timestamp: testTimestamp,
        );

        final map = packet.toMap();
        expect(map['type'], GroupEpochStatusProbePacket.packetType);
        expect(map['knownEpoch'], 1);
        expect(map['knownSequenceNumber'], 0);

        final fromMapPacket = GroupEpochStatusProbePacket.fromMap(map);
        expect(fromMapPacket, equals(packet));

        final jsonStr = packet.toJson();
        final fromJsonPacket = GroupEpochStatusProbePacket.fromJson(jsonStr);
        expect(fromJsonPacket, equals(packet));

        final polymorphic = GroupEpochPacket.fromJson(jsonStr);
        expect(polymorphic, isA<GroupEpochStatusProbePacket>());
        expect(polymorphic, equals(packet));
      });

      test('1.8 GroupEpochStatusResponsePacket round-trip serialization', () {
        final packet = GroupEpochStatusResponsePacket(
          operationId: testOpId,
          groupId: testGroupId,
          respondingPeerId: testAdminId,
          authoritativeEpoch: 2,
          authoritativeSequenceNumber: 1,
          operationStatus: GroupEpochOperationStatus.finalized,
          timestamp: testTimestamp,
          targetEpoch: 2,
          previousEpoch: 1,
          isReEpochPending: false,
        );

        final map = packet.toMap();
        expect(map['type'], GroupEpochStatusResponsePacket.packetType);
        expect(map['authoritativeEpoch'], 2);
        expect(map['authoritativeSequenceNumber'], 1);
        expect(map['operationStatus'], 'finalized');
        expect(map['targetEpoch'], 2);
        expect(map['previousEpoch'], 1);
        expect(map['isReEpochPending'], false);

        final fromMapPacket = GroupEpochStatusResponsePacket.fromMap(map);
        expect(fromMapPacket, equals(packet));

        final jsonStr = packet.toJson();
        final fromJsonPacket = GroupEpochStatusResponsePacket.fromJson(jsonStr);
        expect(fromJsonPacket, equals(packet));

        final polymorphic = GroupEpochPacket.fromJson(jsonStr);
        expect(polymorphic, isA<GroupEpochStatusResponsePacket>());
        expect(polymorphic, equals(packet));
      });
    });

    // =========================================================================
    // 2. Missing required fields
    // =========================================================================
    group('2. Missing required fields rejection', () {
      test('2.1 GroupEpochPreparePacket rejects missing fields', () {
        final base = GroupEpochPreparePacket(
          operationId: testOpId,
          groupId: testGroupId,
          previousEpoch: 1,
          targetEpoch: 2,
          operationSequenceNumber: 1,
          adminPeerId: testAdminId,
          timestamp: testTimestamp,
        ).toMap();

        for (final key in [
          'type',
          'version',
          'operationId',
          'groupId',
          'previousEpoch',
          'targetEpoch',
          'operationSequenceNumber',
          'adminPeerId',
          'timestamp',
        ]) {
          final corrupt = Map<String, dynamic>.from(base)..remove(key);
          expect(
            () => GroupEpochPreparePacket.fromMap(corrupt),
            throwsA(isA<FormatException>()),
            reason: 'Should reject missing key "$key"',
          );
        }
      });

      test('2.2 GroupEpochPrepareAckPacket rejects missing fields', () {
        final base = GroupEpochPrepareAckPacket(
          operationId: testOpId,
          groupId: testGroupId,
          memberPeerId: testMemberId,
          targetEpoch: 2,
          status: GroupEpochAckStatus.acknowledged,
          timestamp: testTimestamp,
        ).toMap();

        for (final key in [
          'type',
          'version',
          'operationId',
          'groupId',
          'memberPeerId',
          'targetEpoch',
          'status',
          'timestamp',
        ]) {
          final corrupt = Map<String, dynamic>.from(base)..remove(key);
          expect(
            () => GroupEpochPrepareAckPacket.fromMap(corrupt),
            throwsA(isA<FormatException>()),
            reason: 'Should reject missing key "$key"',
          );
        }
      });

      test('2.3 GroupEpochCommitPacket rejects missing fields', () {
        final base = GroupEpochCommitPacket(
          operationId: testOpId,
          groupId: testGroupId,
          previousEpoch: 1,
          targetEpoch: 2,
          sequenceNumber: 1,
          adminPeerId: testAdminId,
          timestamp: testTimestamp,
        ).toMap();

        for (final key in [
          'type',
          'version',
          'operationId',
          'groupId',
          'previousEpoch',
          'targetEpoch',
          'sequenceNumber',
          'adminPeerId',
          'timestamp',
        ]) {
          final corrupt = Map<String, dynamic>.from(base)..remove(key);
          expect(
            () => GroupEpochCommitPacket.fromMap(corrupt),
            throwsA(isA<FormatException>()),
            reason: 'Should reject missing key "$key"',
          );
        }
      });
    });

    // =========================================================================
    // 3. Wrong JSON value types
    // =========================================================================
    group('3. Wrong JSON value types rejection', () {
      test('3.1 Rejects wrong types for int fields', () {
        final base = GroupEpochPreparePacket(
          operationId: testOpId,
          groupId: testGroupId,
          previousEpoch: 1,
          targetEpoch: 2,
          operationSequenceNumber: 1,
          adminPeerId: testAdminId,
          timestamp: testTimestamp,
        ).toMap();

        final corrupt1 = Map<String, dynamic>.from(base)..['targetEpoch'] = '2'; // string instead of int
        expect(() => GroupEpochPreparePacket.fromMap(corrupt1), throwsA(isA<FormatException>()));

        final corrupt2 = Map<String, dynamic>.from(base)..['previousEpoch'] = true; // bool instead of int
        expect(() => GroupEpochPreparePacket.fromMap(corrupt2), throwsA(isA<FormatException>()));

        final corrupt3 = Map<String, dynamic>.from(base)
          ..['operationSequenceNumber'] = [1]; // list instead of int
        expect(() => GroupEpochPreparePacket.fromMap(corrupt3), throwsA(isA<FormatException>()));
      });

      test('3.2 Rejects wrong types for string fields', () {
        final base = GroupEpochCommitPacket(
          operationId: testOpId,
          groupId: testGroupId,
          previousEpoch: 1,
          targetEpoch: 2,
          sequenceNumber: 1,
          adminPeerId: testAdminId,
          timestamp: testTimestamp,
        ).toMap();

        final corrupt1 = Map<String, dynamic>.from(base)..['operationId'] = 12345; // int instead of string
        expect(() => GroupEpochCommitPacket.fromMap(corrupt1), throwsA(isA<FormatException>()));

        final corrupt2 = Map<String, dynamic>.from(base)..['groupId'] = {'id': 'GRP-1'}; // map instead of string
        expect(() => GroupEpochCommitPacket.fromMap(corrupt2), throwsA(isA<FormatException>()));

        final corrupt3 = Map<String, dynamic>.from(base)..['adminPeerId'] = null; // null instead of string
        expect(() => GroupEpochCommitPacket.fromMap(corrupt3), throwsA(isA<FormatException>()));
      });
    });

    // =========================================================================
    // 4. Invalid operation IDs
    // =========================================================================
    group('4. Invalid operation IDs rejection', () {
      test('4.1 Rejects operation ID with wrong character count', () {
        // 31 characters (too short)
        expect(
          () => GroupEpochValidator.validateAndNormalizeOperationId('0123456789abcdef0123456789abcde'),
          throwsA(isA<ArgumentError>()),
        );

        // 33 characters (too long)
        expect(
          () => GroupEpochValidator.validateAndNormalizeOperationId('0123456789abcdef0123456789abcdef0'),
          throwsA(isA<ArgumentError>()),
        );

        // Empty
        expect(
          () => GroupEpochValidator.validateAndNormalizeOperationId(''),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('4.2 Rejects operation ID with non-hex characters', () {
        expect(
          () => GroupEpochValidator.validateAndNormalizeOperationId('0123456789abcdef0123456789abcdeg'), // 'g' is non-hex
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => GroupEpochValidator.validateAndNormalizeOperationId('0123456789abcdef0123456789abcde-'), // '-' is non-hex
          throwsA(isA<ArgumentError>()),
        );
      });

      test('4.3 Rejects operation ID with leading or trailing whitespace', () {
        expect(
          () => GroupEpochValidator.validateAndNormalizeOperationId(' 0123456789abcdef0123456789abcdef'),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => GroupEpochValidator.validateAndNormalizeOperationId('0123456789abcdef0123456789abcdef '),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('4.4 Normalizes valid uppercase and mixed-case hex to lowercase', () {
        final normalized = GroupEpochValidator.validateAndNormalizeOperationId('0123456789ABCDEF0123456789ABCDEF');
        expect(normalized, equals('0123456789abcdef0123456789abcdef'));
      });
    });

    // =========================================================================
    // 5. Invalid group IDs and peer IDs
    // =========================================================================
    group('5. Invalid group IDs and peer IDs rejection', () {
      test('5.1 Rejects malformed group IDs', () {
        for (final malformedGroup in [
          'GRP-INVALID',
          'GRP-1730000000000-12345', // 5 hex chars instead of 6
          'GRP-1730000000000-1234567', // 7 hex chars
          'GRP-NOTANINT-A1B2C3',
          'GRP-0-A1B2C3',
          ' GRP-1730000000000-A1B2C3',
          '',
        ]) {
          expect(
            () => GroupEpochPreparePacket(
              operationId: testOpId,
              groupId: malformedGroup,
              previousEpoch: 1,
              targetEpoch: 2,
              operationSequenceNumber: 1,
              adminPeerId: testAdminId,
              timestamp: testTimestamp,
            ),
            throwsA(isA<ArgumentError>()),
            reason: 'Should reject malformed groupId "$malformedGroup"',
          );
        }
      });

      test('5.2 Rejects malformed peer IDs', () {
        for (final malformedPeer in [
          '',
          ' PEER-SPACED',
          'PEER-SPACED ',
          'PEER\x00NULL',
          'PEER\nNEWLINE',
          'A' * 129, // Exceeds 128 max length
        ]) {
          expect(
            () => GroupEpochPrepareAckPacket(
              operationId: testOpId,
              groupId: testGroupId,
              memberPeerId: malformedPeer,
              targetEpoch: 2,
              status: GroupEpochAckStatus.acknowledged,
              timestamp: testTimestamp,
            ),
            throwsA(isA<ArgumentError>()),
            reason: 'Should reject malformed peerId "$malformedPeer"',
          );
        }
      });
    });

    // =========================================================================
    // 6. Invalid epoch relationships
    // =========================================================================
    group('6. Invalid epoch relationships rejection', () {
      test('6.1 Rejects targetEpoch <= previousEpoch in prepare, commit, finalize', () {
        // targetEpoch == previousEpoch
        expect(
          () => GroupEpochPreparePacket(
            operationId: testOpId,
            groupId: testGroupId,
            previousEpoch: 2,
            targetEpoch: 2,
            operationSequenceNumber: 1,
            adminPeerId: testAdminId,
            timestamp: testTimestamp,
          ),
          throwsA(isA<ArgumentError>()),
        );

        // targetEpoch < previousEpoch
        expect(
          () => GroupEpochCommitPacket(
            operationId: testOpId,
            groupId: testGroupId,
            previousEpoch: 3,
            targetEpoch: 2,
            sequenceNumber: 1,
            adminPeerId: testAdminId,
            timestamp: testTimestamp,
          ),
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => GroupEpochFinalizePacket(
            operationId: testOpId,
            groupId: testGroupId,
            previousEpoch: 5,
            targetEpoch: 4,
            sequenceNumber: 1,
            adminPeerId: testAdminId,
            timestamp: testTimestamp,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('6.2 Rejects non-positive epochs (< 1)', () {
        expect(
          () => GroupEpochPreparePacket(
            operationId: testOpId,
            groupId: testGroupId,
            previousEpoch: 0,
            targetEpoch: 2,
            operationSequenceNumber: 1,
            adminPeerId: testAdminId,
            timestamp: testTimestamp,
          ),
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => GroupEpochPrepareAckPacket(
            operationId: testOpId,
            groupId: testGroupId,
            memberPeerId: testMemberId,
            targetEpoch: 0,
            status: GroupEpochAckStatus.acknowledged,
            timestamp: testTimestamp,
          ),
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => GroupEpochStatusProbePacket(
            operationId: testOpId,
            groupId: testGroupId,
            requestingPeerId: testMemberId,
            knownEpoch: 0,
            knownSequenceNumber: 0,
            timestamp: testTimestamp,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    // =========================================================================
    // 7. Invalid sequence numbers
    // =========================================================================
    group('7. Invalid sequence numbers rejection', () {
      test('7.1 Rejects sequence number <= 0 in prepare, commit, finalize', () {
        expect(
          () => GroupEpochPreparePacket(
            operationId: testOpId,
            groupId: testGroupId,
            previousEpoch: 1,
            targetEpoch: 2,
            operationSequenceNumber: 0, // Must be >= 1
            adminPeerId: testAdminId,
            timestamp: testTimestamp,
          ),
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => GroupEpochCommitPacket(
            operationId: testOpId,
            groupId: testGroupId,
            previousEpoch: 1,
            targetEpoch: 2,
            sequenceNumber: -1,
            adminPeerId: testAdminId,
            timestamp: testTimestamp,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('7.2 Allows non-negative sequence numbers (>= 0) in status probe and response', () {
        final probe = GroupEpochStatusProbePacket(
          operationId: testOpId,
          groupId: testGroupId,
          requestingPeerId: testMemberId,
          knownEpoch: 1,
          knownSequenceNumber: 0, // 0 is allowed (no known operation yet)
          timestamp: testTimestamp,
        );
        expect(probe.knownSequenceNumber, 0);

        // Rejects negative sequence number
        expect(
          () => GroupEpochStatusProbePacket(
            operationId: testOpId,
            groupId: testGroupId,
            requestingPeerId: testMemberId,
            knownEpoch: 1,
            knownSequenceNumber: -1,
            timestamp: testTimestamp,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    // =========================================================================
    // 8. Unknown packet type and protocol version
    // =========================================================================
    group('8. Unknown packet type and protocol version rejection', () {
      test('8.1 Polymorphic GroupEpochPacket.fromMap rejects unknown packet type', () {
        final badMap = {
          'type': 'group_epoch_unknown_action',
          'version': 1,
          'operationId': testOpId,
          'groupId': testGroupId,
          'timestamp': testTimestamp.toIso8601String(),
        };
        expect(() => GroupEpochPacket.fromMap(badMap), throwsA(isA<FormatException>()));
      });

      test('8.2 Individual packet parser rejects unsupported protocol version', () {
        final base = GroupEpochPreparePacket(
          operationId: testOpId,
          groupId: testGroupId,
          previousEpoch: 1,
          targetEpoch: 2,
          operationSequenceNumber: 1,
          adminPeerId: testAdminId,
          timestamp: testTimestamp,
        ).toMap();

        final corruptVersion = Map<String, dynamic>.from(base)..['version'] = 2; // expected 1
        expect(() => GroupEpochPreparePacket.fromMap(corruptVersion), throwsA(isA<FormatException>()));
      });
    });

    // =========================================================================
    // 9. Unknown acknowledgement and operation statuses
    // =========================================================================
    group('9. Unknown acknowledgement and operation statuses rejection', () {
      test('9.1 Rejects unknown GroupEpochAckStatus in ACK packets', () {
        final base = GroupEpochPrepareAckPacket(
          operationId: testOpId,
          groupId: testGroupId,
          memberPeerId: testMemberId,
          targetEpoch: 2,
          status: GroupEpochAckStatus.acknowledged,
          timestamp: testTimestamp,
        ).toMap();

        for (final badStatus in ['unknown', 'rejected', 'aborted', 'accepted', '']) {
          final corrupt = Map<String, dynamic>.from(base)..['status'] = badStatus;
          expect(
            () => GroupEpochPrepareAckPacket.fromMap(corrupt),
            throwsA(isA<FormatException>()),
            reason: 'Should reject invalid status "$badStatus"',
          );
        }
      });

      test('9.2 Rejects unknown GroupEpochOperationStatus in StatusResponsePacket', () {
        final base = GroupEpochStatusResponsePacket(
          operationId: testOpId,
          groupId: testGroupId,
          respondingPeerId: testAdminId,
          authoritativeEpoch: 2,
          authoritativeSequenceNumber: 1,
          operationStatus: GroupEpochOperationStatus.finalized,
          timestamp: testTimestamp,
        ).toMap();

        for (final badStatus in ['unknown', 'running', 'in_progress', 'cancelled', '']) {
          final corrupt = Map<String, dynamic>.from(base)..['operationStatus'] = badStatus;
          expect(
            () => GroupEpochStatusResponsePacket.fromMap(corrupt),
            throwsA(isA<FormatException>()),
            reason: 'Should reject invalid operationStatus "$badStatus"',
          );
        }
      });
    });

    // =========================================================================
    // 10. UTC timestamp normalization and non-UTC rejection
    // =========================================================================
    group('10. UTC timestamp normalization and non-UTC rejection', () {
      test('10.1 Constructor rejects non-UTC timestamps', () {
        // Construct non-UTC DateTime
        final localDateTime = DateTime(2026, 11, 11, 14, 30, 0); // local, not UTC

        expect(
          () => GroupEpochPreparePacket(
            operationId: testOpId,
            groupId: testGroupId,
            previousEpoch: 1,
            targetEpoch: 2,
            operationSequenceNumber: 1,
            adminPeerId: testAdminId,
            timestamp: localDateTime,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('10.2 Parser rejects non-UTC ISO timestamp strings', () {
        final base = GroupEpochPreparePacket(
          operationId: testOpId,
          groupId: testGroupId,
          previousEpoch: 1,
          targetEpoch: 2,
          operationSequenceNumber: 1,
          adminPeerId: testAdminId,
          timestamp: testTimestamp,
        ).toMap();

        // Non-UTC timestamp string without 'Z'
        final corrupt = Map<String, dynamic>.from(base)..['timestamp'] = '2026-11-11T14:30:00.000';
        expect(() => GroupEpochPreparePacket.fromMap(corrupt), throwsA(isA<FormatException>()));
      });
    });

    // =========================================================================
    // 11. Canonical payload deterministic output
    // =========================================================================
    group('11. Canonical payload deterministic output', () {
      test('11.1 Same logical operation produces identical canonical bytes across runs', () {
        final payload1 = GroupEpochCanonicalPayload(
          packetType: GroupEpochPreparePacket.packetType,
          operationId: testOpId,
          groupId: testGroupId,
          previousEpoch: 1,
          targetEpoch: 2,
          operationSequenceNumber: 1,
          adminPeerId: testAdminId,
          timestamp: testTimestamp,
        );

        final payload2 = GroupEpochCanonicalPayload(
          packetType: GroupEpochPreparePacket.packetType,
          operationId: testOpId,
          groupId: testGroupId,
          previousEpoch: 1,
          targetEpoch: 2,
          operationSequenceNumber: 1,
          adminPeerId: testAdminId,
          timestamp: testTimestamp,
        );

        // String serialization equality
        expect(payload1.serialize(), equals(payload2.serialize()));

        // Byte-for-byte equality
        expect(payload1.bytes, orderedEquals(payload2.bytes));

        // Prepared packet getter equality
        final packet = GroupEpochPreparePacket(
          operationId: testOpId,
          groupId: testGroupId,
          previousEpoch: 1,
          targetEpoch: 2,
          operationSequenceNumber: 1,
          adminPeerId: testAdminId,
          timestamp: testTimestamp,
        );
        expect(packet.canonicalPayload, equals(payload1.serialize()));
        expect(packet.canonicalPayloadBytes, orderedEquals(payload1.bytes));
      });

      test('11.2 Keys in canonical payload are strictly sorted lexicographically', () {
        final payload = GroupEpochCanonicalPayload(
          packetType: GroupEpochPreparePacket.packetType,
          operationId: testOpId,
          groupId: testGroupId,
          previousEpoch: 1,
          targetEpoch: 2,
          operationSequenceNumber: 1,
          adminPeerId: testAdminId,
          timestamp: testTimestamp,
        );

        final serialized = payload.serialize();
        final decoded = jsonDecode(serialized) as Map<String, dynamic>;
        final keys = decoded.keys.toList();
        final sortedKeys = List<String>.from(keys)..sort();

        expect(keys, orderedEquals(sortedKeys));
      });
    });

    // =========================================================================
    // 12. Canonical payload changes when any security-relevant field changes
    // =========================================================================
    group('12. Canonical payload field-change sensitivity', () {
      final basePayload = GroupEpochCanonicalPayload(
        packetType: GroupEpochPreparePacket.packetType,
        operationId: testOpId,
        groupId: testGroupId,
        previousEpoch: 1,
        targetEpoch: 2,
        operationSequenceNumber: 1,
        adminPeerId: testAdminId,
        timestamp: testTimestamp,
      );

      test('12.1 Changes when targetEpoch changes', () {
        final altered = GroupEpochCanonicalPayload(
          packetType: GroupEpochPreparePacket.packetType,
          operationId: testOpId,
          groupId: testGroupId,
          previousEpoch: 1,
          targetEpoch: 3, // Changed from 2 to 3
          operationSequenceNumber: 1,
          adminPeerId: testAdminId,
          timestamp: testTimestamp,
        );
        expect(altered.bytes, isNot(orderedEquals(basePayload.bytes)));
      });

      test('12.2 Changes when adminPeerId changes', () {
        final altered = GroupEpochCanonicalPayload(
          packetType: GroupEpochPreparePacket.packetType,
          operationId: testOpId,
          groupId: testGroupId,
          previousEpoch: 1,
          targetEpoch: 2,
          operationSequenceNumber: 1,
          adminPeerId: 'PEER-ADMIN-IMPOSTOR', // Changed
          timestamp: testTimestamp,
        );
        expect(altered.bytes, isNot(orderedEquals(basePayload.bytes)));
      });

      test('12.3 Changes when operationId changes', () {
        final altered = GroupEpochCanonicalPayload(
          packetType: GroupEpochPreparePacket.packetType,
          operationId: 'ffffffffffffffffffffffffffffffff', // Changed
          groupId: testGroupId,
          previousEpoch: 1,
          targetEpoch: 2,
          operationSequenceNumber: 1,
          adminPeerId: testAdminId,
          timestamp: testTimestamp,
        );
        expect(altered.bytes, isNot(orderedEquals(basePayload.bytes)));
      });

      test('12.4 Changes when sequenceNumber changes', () {
        final altered = GroupEpochCanonicalPayload(
          packetType: GroupEpochPreparePacket.packetType,
          operationId: testOpId,
          groupId: testGroupId,
          previousEpoch: 1,
          targetEpoch: 2,
          operationSequenceNumber: 2, // Changed from 1 to 2
          adminPeerId: testAdminId,
          timestamp: testTimestamp,
        );
        expect(altered.bytes, isNot(orderedEquals(basePayload.bytes)));
      });

      test('12.5 Changes when timestamp changes', () {
        final altered = GroupEpochCanonicalPayload(
          packetType: GroupEpochPreparePacket.packetType,
          operationId: testOpId,
          groupId: testGroupId,
          previousEpoch: 1,
          targetEpoch: 2,
          operationSequenceNumber: 1,
          adminPeerId: testAdminId,
          timestamp: testTimestamp.add(const Duration(seconds: 1)), // Changed
        );
        expect(altered.bytes, isNot(orderedEquals(basePayload.bytes)));
      });
    });

    // =========================================================================
    // 13. No secret or plaintext message fields are serialized
    // =========================================================================
    group('13. Absence of secret or plaintext message fields', () {
      test('13.1 None of the 8 packet serializations contain sensitive or message fields', () {
        final forbiddenSubstrings = [
          'secret',
          'privatekey',
          'plaintext',
          'content',
          'text_content',
          'sessionkey',
          'ratchet',
        ];

        final packets = <GroupEpochPacket>[
          GroupEpochPreparePacket(
            operationId: testOpId,
            groupId: testGroupId,
            previousEpoch: 1,
            targetEpoch: 2,
            operationSequenceNumber: 1,
            adminPeerId: testAdminId,
            timestamp: testTimestamp,
          ),
          GroupEpochPrepareAckPacket(
            operationId: testOpId,
            groupId: testGroupId,
            memberPeerId: testMemberId,
            targetEpoch: 2,
            status: GroupEpochAckStatus.acknowledged,
            timestamp: testTimestamp,
          ),
          GroupEpochCommitPacket(
            operationId: testOpId,
            groupId: testGroupId,
            previousEpoch: 1,
            targetEpoch: 2,
            sequenceNumber: 1,
            adminPeerId: testAdminId,
            timestamp: testTimestamp,
          ),
          GroupEpochCommitAckPacket(
            operationId: testOpId,
            groupId: testGroupId,
            memberPeerId: testMemberId,
            targetEpoch: 2,
            status: GroupEpochAckStatus.acknowledged,
            timestamp: testTimestamp,
          ),
          GroupEpochFinalizePacket(
            operationId: testOpId,
            groupId: testGroupId,
            previousEpoch: 1,
            targetEpoch: 2,
            sequenceNumber: 1,
            adminPeerId: testAdminId,
            timestamp: testTimestamp,
          ),
          GroupEpochFinalizeAckPacket(
            operationId: testOpId,
            groupId: testGroupId,
            memberPeerId: testMemberId,
            targetEpoch: 2,
            status: GroupEpochAckStatus.acknowledged,
            timestamp: testTimestamp,
          ),
          GroupEpochStatusProbePacket(
            operationId: testOpId,
            groupId: testGroupId,
            requestingPeerId: testMemberId,
            knownEpoch: 1,
            knownSequenceNumber: 0,
            timestamp: testTimestamp,
          ),
          GroupEpochStatusResponsePacket(
            operationId: testOpId,
            groupId: testGroupId,
            respondingPeerId: testAdminId,
            authoritativeEpoch: 2,
            authoritativeSequenceNumber: 1,
            operationStatus: GroupEpochOperationStatus.finalized,
            timestamp: testTimestamp,
          ),
        ];

        for (final p in packets) {
          final jsonStr = p.toJson().toLowerCase();
          for (final forbidden in forbiddenSubstrings) {
            expect(
              jsonStr.contains('"$forbidden"'),
              isFalse,
              reason: 'Packet ${p.type} JSON must not contain forbidden key "$forbidden"',
            );
          }
        }
      });
    });

    // =========================================================================
    // 14. Malformed packet rejection
    // =========================================================================
    group('14. Malformed packet rejection', () {
      test('14.1 Rejects garbage non-JSON strings', () {
        expect(() => GroupEpochPacket.fromJson('not a json string'), throwsA(isA<FormatException>()));
        expect(() => GroupEpochPreparePacket.fromJson('{corrupt'), throwsA(isA<FormatException>()));
      });

      test('14.2 Rejects JSON array where Map is expected', () {
        expect(() => GroupEpochPacket.fromJson('[1, 2, 3]'), throwsA(isA<FormatException>()));
        expect(() => GroupEpochCommitPacket.fromJson('["array"]'), throwsA(isA<FormatException>()));
      });

      test('14.3 Rejects mismatched canonicalPayload in PreparePacket JSON', () {
        final validMap = GroupEpochPreparePacket(
          operationId: testOpId,
          groupId: testGroupId,
          previousEpoch: 1,
          targetEpoch: 2,
          operationSequenceNumber: 1,
          adminPeerId: testAdminId,
          timestamp: testTimestamp,
        ).toMap();

        // Tamper with the canonicalPayload string
        final tamperedMap = Map<String, dynamic>.from(validMap)
          ..['canonicalPayload'] = '{"tampered":true}';

        expect(
          () => GroupEpochPreparePacket.fromMap(tamperedMap),
          throwsA(isA<FormatException>()),
          reason: 'Must reject packet when canonicalPayload does not match computed value',
        );
      });
    });
  });
}
