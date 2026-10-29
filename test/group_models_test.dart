import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshlink/features/messages/data/models/group_packets.dart';
import 'package:meshlink/features/messages/domain/models/group.dart';

void main() {
  final nowUtc = DateTime.utc(2026, 10, 30, 2, 0, 0);

  group('Requirement 1: Valid Group construction and round-trip serialization', () {
    test('standard constructor creates immutable Group with valid fields', () {
      final group = Group(
        groupId: 'GRP-1730000000000-A1B2C3',
        name: 'MeshLink Alpha',
        creatorId: 'ML-CREATOR-1',
        adminId: 'ML-CREATOR-1',
        epoch: 1,
        createdAt: nowUtc,
        updatedAt: nowUtc,
      );

      expect(group.groupId, 'GRP-1730000000000-A1B2C3');
      expect(group.name, 'MeshLink Alpha');
      expect(group.creatorId, 'ML-CREATOR-1');
      expect(group.adminId, 'ML-CREATOR-1');
      expect(group.epoch, 1);
      expect(group.createdAt, nowUtc);
      expect(group.updatedAt, nowUtc);
    });

    test('Group.create factory helper initializes group with creator as admin and epoch 1', () {
      final group = Group.create(
        groupId: 'GRP-1730000000000-A1B2C3',
        name: 'Core Mesh Team',
        creatorId: 'ML-ALICE',
        createdAt: nowUtc,
      );

      expect(group.creatorId, 'ML-ALICE');
      expect(group.adminId, 'ML-ALICE');
      expect(group.epoch, 1);
      expect(group.createdAt, nowUtc);
      expect(group.updatedAt, nowUtc);
    });

    test('round-trip serialization via toMap and fromMap preserves equality', () {
      final original = Group(
        groupId: 'GRP-1730000000000-ABCDEF',
        name: 'Field Operations',
        creatorId: 'ML-ADMIN-9',
        adminId: 'ML-ADMIN-9',
        epoch: 1,
        createdAt: nowUtc,
        updatedAt: nowUtc,
      );

      final map = original.toMap();
      final restored = Group.fromMap(map);

      expect(restored, equals(original));
      expect(restored.hashCode, equals(original.hashCode));
    });

    test('round-trip serialization via toJson and fromJson preserves equality', () {
      final original = Group(
        groupId: 'GRP-1730000000000-ABCDEF',
        name: 'Emergency Mesh',
        creatorId: 'ML-OPERATOR',
        adminId: 'ML-OPERATOR',
        epoch: 1,
        createdAt: nowUtc,
        updatedAt: nowUtc,
      );

      final jsonString = original.toJson();
      final restored = Group.fromJson(jsonString);

      expect(restored, equals(original));
    });

    test('generateGroupId produces structurally valid group ID', () {
      final id = Group.generateGroupId(nowUtc);
      expect(id.startsWith('GRP-${nowUtc.millisecondsSinceEpoch}-'), isTrue);
      expect(() => Group.validateGroupId(id), returnsNormally);
    });

    test('valid later state allows adminId != creatorId when epoch > 1', () {
      final updatedGroup = Group(
        groupId: 'GRP-1730000000000-A1B2C3',
        name: 'MeshLink Alpha',
        creatorId: 'ML-CREATOR-1',
        adminId: 'ML-SUCCESSOR-2',
        epoch: 2,
        createdAt: nowUtc,
        updatedAt: nowUtc.add(const Duration(hours: 1)),
      );

      expect(updatedGroup.creatorId, 'ML-CREATOR-1');
      expect(updatedGroup.adminId, 'ML-SUCCESSOR-2');
      expect(updatedGroup.epoch, 2);
    });
  });

  group('Requirement 2: Rejection of malformed group IDs', () {
    test('rejects IDs with incorrect prefix or format', () {
      expect(() => Group.validateGroupId(''), throwsArgumentError);
      expect(() => Group.validateGroupId('   '), throwsArgumentError);
      expect(() => Group.validateGroupId('MSG-1730000000000-A1B2C3'), throwsArgumentError);
      expect(() => Group.validateGroupId('GRP-A1B2C3'), throwsArgumentError);
      expect(() => Group.validateGroupId('GRP--A1B2C3'), throwsArgumentError);
      expect(() => Group.validateGroupId('GRP-invalidtimestamp-A1B2C3'), throwsArgumentError);
      expect(() => Group.validateGroupId('GRP-1730000000000-'), throwsArgumentError);
      expect(() => Group.validateGroupId('GRP-1730000000000-12345'), throwsArgumentError); // 5 hex
      expect(() => Group.validateGroupId('GRP-1730000000000-1234567'), throwsArgumentError); // 7 hex
      expect(() => Group.validateGroupId('GRP-1730000000000-GGGGGG'), throwsArgumentError); // non-hex
      expect(() => Group.validateGroupId(' GRP-1730000000000-A1B2C3 '), throwsArgumentError);
    });

    test('constructor rejects malformed groupId', () {
      expect(
        () => Group(
          groupId: 'MALFORMED-GROUP-ID',
          name: 'Valid Name',
          creatorId: 'ML-ALICE',
          adminId: 'ML-ALICE',
          createdAt: nowUtc,
          updatedAt: nowUtc,
        ),
        throwsArgumentError,
      );
    });
  });

  group('Requirement 3: Rejection of empty, whitespace-only, and overlength names', () {
    test('rejects empty name', () {
      expect(
        () => Group(
          groupId: 'GRP-1730000000000-A1B2C3',
          name: '',
          creatorId: 'ML-ALICE',
          adminId: 'ML-ALICE',
          createdAt: nowUtc,
          updatedAt: nowUtc,
        ),
        throwsArgumentError,
      );
    });

    test('rejects whitespace-only name', () {
      expect(
        () => Group(
          groupId: 'GRP-1730000000000-A1B2C3',
          name: '    \t\n  ',
          creatorId: 'ML-ALICE',
          adminId: 'ML-ALICE',
          createdAt: nowUtc,
          updatedAt: nowUtc,
        ),
        throwsArgumentError,
      );
    });

    test('rejects overlength name (> 64 characters)', () {
      final longName = 'A' * 65;
      expect(
        () => Group(
          groupId: 'GRP-1730000000000-A1B2C3',
          name: longName,
          creatorId: 'ML-ALICE',
          adminId: 'ML-ALICE',
          createdAt: nowUtc,
          updatedAt: nowUtc,
        ),
        throwsArgumentError,
      );
    });

    test('accepts boundary names (1 character and 64 characters) and trims input', () {
      final group1 = Group(
        groupId: 'GRP-1730000000000-A1B2C3',
        name: '   Z   ',
        creatorId: 'ML-ALICE',
        adminId: 'ML-ALICE',
        createdAt: nowUtc,
        updatedAt: nowUtc,
      );
      expect(group1.name, 'Z');

      final name64 = 'B' * 64;
      final group64 = Group(
        groupId: 'GRP-1730000000000-A1B2C3',
        name: name64,
        creatorId: 'ML-ALICE',
        adminId: 'ML-ALICE',
        createdAt: nowUtc,
        updatedAt: nowUtc,
      );
      expect(group64.name, name64);
    });
  });

  group('Requirement 4: Rejection of invalid peer IDs and epochs', () {
    test('rejects empty or whitespace-only peer IDs', () {
      expect(
        () => Group(
          groupId: 'GRP-1730000000000-A1B2C3',
          name: 'Group',
          creatorId: '',
          adminId: '',
          createdAt: nowUtc,
          updatedAt: nowUtc,
        ),
        throwsArgumentError,
      );

      expect(
        () => Group(
          groupId: 'GRP-1730000000000-A1B2C3',
          name: 'Group',
          creatorId: '  ML-ALICE  ',
          adminId: '  ML-ALICE  ',
          createdAt: nowUtc,
          updatedAt: nowUtc,
        ),
        throwsArgumentError,
      );
    });

    test('rejects peer IDs with control characters or excessive length', () {
      expect(
        () => Group.validatePeerId('ML-PEER\x00', 'peerId'),
        throwsArgumentError,
      );
      expect(
        () => Group.validatePeerId('P' * 129, 'peerId'),
        throwsArgumentError,
      );
    });

    test('rejects invalid epoch (< 1)', () {
      expect(
        () => Group(
          groupId: 'GRP-1730000000000-A1B2C3',
          name: 'Group',
          creatorId: 'ML-ALICE',
          adminId: 'ML-ALICE',
          epoch: 0,
          createdAt: nowUtc,
          updatedAt: nowUtc,
        ),
        throwsArgumentError,
      );

      expect(
        () => Group(
          groupId: 'GRP-1730000000000-A1B2C3',
          name: 'Group',
          creatorId: 'ML-ALICE',
          adminId: 'ML-ALICE',
          epoch: -5,
          createdAt: nowUtc,
          updatedAt: nowUtc,
        ),
        throwsArgumentError,
      );
    });

    test('rejects creatorId != adminId when epoch is 1', () {
      expect(
        () => Group(
          groupId: 'GRP-1730000000000-A1B2C3',
          name: 'Group',
          creatorId: 'ML-ALICE',
          adminId: 'ML-BOB',
          epoch: 1,
          createdAt: nowUtc,
          updatedAt: nowUtc,
        ),
        throwsArgumentError,
      );
    });
  });

  group('Requirement 5: Rejection of invalid timestamps and updatedAt < createdAt', () {
    test('rejects non-UTC timestamps in constructor', () {
      final localTime = DateTime(2026, 10, 30, 10, 0, 0); // isUtc == false
      expect(
        () => Group(
          groupId: 'GRP-1730000000000-A1B2C3',
          name: 'Group',
          creatorId: 'ML-ALICE',
          adminId: 'ML-ALICE',
          createdAt: localTime,
          updatedAt: localTime,
        ),
        throwsArgumentError,
      );
    });

    test('rejects updatedAt preceding createdAt', () {
      final earlier = nowUtc.subtract(const Duration(minutes: 1));
      expect(
        () => Group(
          groupId: 'GRP-1730000000000-A1B2C3',
          name: 'Group',
          creatorId: 'ML-ALICE',
          adminId: 'ML-ALICE',
          createdAt: nowUtc,
          updatedAt: earlier,
        ),
        throwsArgumentError,
      );
    });

    test('rejects non-UTC timestamps during JSON deserialization', () {
      final map = {
        'groupId': 'GRP-1730000000000-A1B2C3',
        'name': 'Group',
        'creatorId': 'ML-ALICE',
        'adminId': 'ML-ALICE',
        'epoch': 1,
        'createdAt': '2026-10-30T10:00:00', // Missing 'Z' -> non-UTC
        'updatedAt': '2026-10-30T10:00:00',
      };

      expect(() => Group.fromMap(map), throwsFormatException);
    });
  });

  group('Requirement 6: Strict GroupMember enum serialization/deserialization', () {
    test('GroupRole serializes and deserializes strictly', () {
      expect(GroupRole.admin.toJson(), 'admin');
      expect(GroupRole.member.toJson(), 'member');
      expect(GroupRole.fromString('admin'), GroupRole.admin);
      expect(GroupRole.fromString('member'), GroupRole.member);
      expect(GroupRole.tryFromString('admin'), GroupRole.admin);
      expect(GroupRole.tryFromString('member'), GroupRole.member);

      expect(() => GroupRole.fromString('superadmin'), throwsArgumentError);
      expect(() => GroupRole.fromString('owner'), throwsArgumentError);
      expect(() => GroupRole.fromString(''), throwsArgumentError);
      expect(GroupRole.tryFromString('invalid'), isNull);
      expect(GroupRole.tryFromString(null), isNull);
    });

    test('GroupMemberStatus serializes and deserializes strictly without silent fallback', () {
      expect(GroupMemberStatus.active.toJson(), 'active');
      expect(GroupMemberStatus.pendingInvite.toJson(), 'pendingInvite');
      expect(GroupMemberStatus.removed.toJson(), 'removed');

      expect(GroupMemberStatus.fromString('active'), GroupMemberStatus.active);
      expect(GroupMemberStatus.fromString('pendingInvite'), GroupMemberStatus.pendingInvite);
      expect(GroupMemberStatus.fromString('removed'), GroupMemberStatus.removed);

      expect(() => GroupMemberStatus.fromString('banned'), throwsArgumentError);
      expect(() => GroupMemberStatus.fromString('unknown'), throwsArgumentError);
      expect(() => GroupMemberStatus.fromString(''), throwsArgumentError);
      expect(GroupMemberStatus.tryFromString('banned'), isNull);
      expect(GroupMemberStatus.tryFromString(null), isNull);
    });
  });

  group('Requirement 7: Pending, active, and removed membership states remain distinct', () {
    test('pendingInvite state has isPendingInvite=true and isActive=false', () {
      final member = GroupMember(
        groupId: 'GRP-1730000000000-A1B2C3',
        peerId: 'ML-BOB',
        role: GroupRole.member,
        status: GroupMemberStatus.pendingInvite,
        joinedAt: nowUtc,
        invitedBy: 'ML-ALICE',
      );

      expect(member.isPendingInvite, isTrue);
      expect(member.isActive, isFalse);
      expect(member.isRemoved, isFalse);
      expect(member.isMember, isTrue);
      expect(member.isAdmin, isFalse);
    });

    test('active state has isActive=true and isPendingInvite=false', () {
      final member = GroupMember(
        groupId: 'GRP-1730000000000-A1B2C3',
        peerId: 'ML-ALICE',
        role: GroupRole.admin,
        status: GroupMemberStatus.active,
        joinedAt: nowUtc,
        invitedBy: 'ML-ALICE',
      );

      expect(member.isActive, isTrue);
      expect(member.isPendingInvite, isFalse);
      expect(member.isRemoved, isFalse);
      expect(member.isAdmin, isTrue);
      expect(member.isMember, isFalse);
    });

    test('removed state has isRemoved=true and cannot be treated as active', () {
      final member = GroupMember(
        groupId: 'GRP-1730000000000-A1B2C3',
        peerId: 'ML-CHARLIE',
        role: GroupRole.member,
        status: GroupMemberStatus.removed,
        joinedAt: nowUtc,
        invitedBy: 'ML-ALICE',
      );

      expect(member.isRemoved, isTrue);
      expect(member.isActive, isFalse);
      expect(member.isPendingInvite, isFalse);
    });

    test('GroupMember serialization round-trip succeeds and preserves state', () {
      final member = GroupMember(
        groupId: 'GRP-1730000000000-A1B2C3',
        peerId: 'ML-BOB',
        role: GroupRole.member,
        status: GroupMemberStatus.active,
        joinedAt: nowUtc,
        invitedBy: 'ML-ALICE',
      );

      final json = member.toJson();
      final restored = GroupMember.fromJson(json);

      expect(restored, equals(member));
      expect(restored.status, GroupMemberStatus.active);
    });
  });

  group('Requirement 8 & 9: Member-limit helper accepts up to 8 distinct members and rejects 9', () {
    test('accepts up to 8 distinct members', () {
      final members = List.generate(
        8,
        (i) => GroupMember(
          groupId: 'GRP-1730000000000-A1B2C3',
          peerId: 'ML-PEER-$i',
          role: i == 0 ? GroupRole.admin : GroupRole.member,
          status: GroupMemberStatus.active,
          joinedAt: nowUtc,
          invitedBy: 'ML-PEER-0',
        ),
      );

      expect(
        () => GroupMembershipValidator.validateProposedMembers(
          members,
          expectedGroupId: 'GRP-1730000000000-A1B2C3',
        ),
        returnsNormally,
      );

      final peerIds = List.generate(8, (i) => 'ML-PEER-$i');
      expect(
        () => GroupMembershipValidator.validateProposedPeerIds(peerIds),
        returnsNormally,
      );
    });

    test('rejects 9 distinct members', () {
      final members = List.generate(
        9,
        (i) => GroupMember(
          groupId: 'GRP-1730000000000-A1B2C3',
          peerId: 'ML-PEER-$i',
          role: i == 0 ? GroupRole.admin : GroupRole.member,
          status: GroupMemberStatus.active,
          joinedAt: nowUtc,
          invitedBy: 'ML-PEER-0',
        ),
      );

      expect(
        () => GroupMembershipValidator.validateProposedMembers(members),
        throwsArgumentError,
      );

      final peerIds = List.generate(9, (i) => 'ML-PEER-$i');
      expect(
        () => GroupMembershipValidator.validateProposedPeerIds(peerIds),
        throwsArgumentError,
      );
    });

    test('Requirement 9: duplicate peer IDs are deduplicated and not counted as separate members', () {
      // 8 unique peers, but 10 total entries (2 duplicates)
      final membersWithDuplicates = [
        ...List.generate(
          8,
          (i) => GroupMember(
            groupId: 'GRP-1730000000000-A1B2C3',
            peerId: 'ML-PEER-$i',
            role: GroupRole.member,
            status: GroupMemberStatus.active,
            joinedAt: nowUtc,
            invitedBy: 'ML-PEER-0',
          ),
        ),
        GroupMember(
          groupId: 'GRP-1730000000000-A1B2C3',
          peerId: 'ML-PEER-0', // Duplicate
          role: GroupRole.admin,
          status: GroupMemberStatus.active,
          joinedAt: nowUtc,
          invitedBy: 'ML-PEER-0',
        ),
        GroupMember(
          groupId: 'GRP-1730000000000-A1B2C3',
          peerId: 'ML-PEER-1', // Duplicate
          role: GroupRole.member,
          status: GroupMemberStatus.active,
          joinedAt: nowUtc,
          invitedBy: 'ML-PEER-0',
        ),
      ];

      expect(membersWithDuplicates.length, 10);
      expect(
        () => GroupMembershipValidator.validateProposedMembers(membersWithDuplicates),
        returnsNormally,
      );

      final peerIdsWithDuplicates = [
        ...List.generate(8, (i) => 'ML-PEER-$i'),
        'ML-PEER-0',
        'ML-PEER-2',
      ];
      expect(peerIdsWithDuplicates.length, 10);
      expect(
        () => GroupMembershipValidator.validateProposedPeerIds(peerIdsWithDuplicates),
        returnsNormally,
      );
    });

    test('rejects members when expectedGroupId does not match', () {
      final members = [
        GroupMember(
          groupId: 'GRP-1730000000000-A1B2C3',
          peerId: 'ML-PEER-0',
          role: GroupRole.admin,
          status: GroupMemberStatus.active,
          joinedAt: nowUtc,
          invitedBy: 'ML-PEER-0',
        ),
        GroupMember(
          groupId: 'GRP-1730000000000-999999', // Different group
          peerId: 'ML-PEER-1',
          role: GroupRole.member,
          status: GroupMemberStatus.active,
          joinedAt: nowUtc,
          invitedBy: 'ML-PEER-0',
        ),
      ];

      expect(
        () => GroupMembershipValidator.validateProposedMembers(
          members,
          expectedGroupId: 'GRP-1730000000000-A1B2C3',
        ),
        throwsArgumentError,
      );
    });
  });

  group('Requirement 10: Valid round-trip serialization for every packet type', () {
    test('GroupInvitePacket round-trip serialization', () {
      final packet = GroupInvitePacket(
        groupId: 'GRP-1730000000000-A1B2C3',
        groupName: 'Mesh Explorers',
        adminId: 'ML-ADMIN-1',
        invitedPeerId: 'ML-BOB-2',
        epoch: 1,
        inviteId: 'INV-100',
        timestamp: nowUtc,
      );

      final map = packet.toMap();
      expect(map['type'], 'group_invite');
      expect(map['version'], 1);

      final fromMap = GroupInvitePacket.fromMap(map);
      expect(fromMap, equals(packet));

      final jsonStr = packet.toJson();
      final fromJson = GroupInvitePacket.fromJson(jsonStr);
      expect(fromJson, equals(packet));

      final polymorphic = GroupPacket.fromJson(jsonStr);
      expect(polymorphic, isA<GroupInvitePacket>());
      expect(polymorphic, equals(packet));
    });

    test('GroupJoinAckPacket round-trip serialization', () {
      final packet = GroupJoinAckPacket(
        groupId: 'GRP-1730000000000-A1B2C3',
        ackPeerId: 'ML-BOB-2',
        adminId: 'ML-ADMIN-1',
        epoch: 1,
        ackId: 'ACK-200',
        timestamp: nowUtc,
      );

      final map = packet.toMap();
      expect(map['type'], 'group_join_ack');
      expect(map['version'], 1);

      final fromMap = GroupJoinAckPacket.fromMap(map);
      expect(fromMap, equals(packet));

      final jsonStr = packet.toJson();
      final fromJson = GroupJoinAckPacket.fromJson(jsonStr);
      expect(fromJson, equals(packet));

      final polymorphic = GroupPacket.fromJson(jsonStr);
      expect(polymorphic, isA<GroupJoinAckPacket>());
      expect(polymorphic, equals(packet));
    });

    test('GroupMessagePacket round-trip serialization', () {
      final testCiphertext = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      final packet = GroupMessagePacket(
        groupId: 'GRP-1730000000000-A1B2C3',
        messageId: 'MSG-300',
        senderPeerId: 'ML-SENDER-1',
        epoch: 1,
        timestamp: nowUtc,
        ciphertext: testCiphertext,
      );

      final map = packet.toMap();
      expect(map['type'], 'group_message');
      expect(map['version'], 1);
      expect(map['ciphertext'], base64Encode(testCiphertext));

      final fromMap = GroupMessagePacket.fromMap(map);
      expect(fromMap, equals(packet));

      final jsonStr = packet.toJson();
      final fromJson = GroupMessagePacket.fromJson(jsonStr);
      expect(fromJson, equals(packet));

      final polymorphic = GroupPacket.fromJson(jsonStr);
      expect(polymorphic, isA<GroupMessagePacket>());
      expect(polymorphic, equals(packet));
    });

    test('GroupMemberRemovePacket round-trip serialization', () {
      final packet = GroupMemberRemovePacket(
        groupId: 'GRP-1730000000000-A1B2C3',
        targetPeerId: 'ML-MEMBER-BAD',
        adminId: 'ML-ADMIN-1',
        epoch: 2,
        removeId: 'REM-400',
        timestamp: nowUtc,
      );

      final map = packet.toMap();
      expect(map['type'], 'group_member_remove');
      expect(map['version'], 1);

      final fromMap = GroupMemberRemovePacket.fromMap(map);
      expect(fromMap, equals(packet));

      final jsonStr = packet.toJson();
      final fromJson = GroupMemberRemovePacket.fromJson(jsonStr);
      expect(fromJson, equals(packet));

      final polymorphic = GroupPacket.fromJson(jsonStr);
      expect(polymorphic, isA<GroupMemberRemovePacket>());
      expect(polymorphic, equals(packet));
    });
  });

  group('Requirement 11: Each packet rejects missing required fields and incorrect field types', () {
    test('GroupInvitePacket rejects missing or mistyped fields', () {
      final validMap = {
        'type': 'group_invite',
        'version': 1,
        'groupId': 'GRP-1730000000000-A1B2C3',
        'groupName': 'Mesh Team',
        'adminId': 'ML-ADMIN-1',
        'invitedPeerId': 'ML-BOB-2',
        'epoch': 1,
        'inviteId': 'INV-100',
        'timestamp': nowUtc.toIso8601String(),
      };

      for (final key in validMap.keys) {
        if (key == 'type' || key == 'version') continue;
        final badMap = Map<String, dynamic>.from(validMap)..remove(key);
        expect(
          () => GroupInvitePacket.fromMap(badMap),
          throwsFormatException,
          reason: 'Failed to reject missing field "$key"',
        );
      }

      // Wrong type for epoch (string instead of int)
      final mistypedMap = Map<String, dynamic>.from(validMap)..['epoch'] = 'not-an-int';
      expect(() => GroupInvitePacket.fromMap(mistypedMap), throwsFormatException);
    });

    test('GroupJoinAckPacket rejects missing or mistyped fields', () {
      final validMap = {
        'type': 'group_join_ack',
        'version': 1,
        'groupId': 'GRP-1730000000000-A1B2C3',
        'ackPeerId': 'ML-BOB-2',
        'adminId': 'ML-ADMIN-1',
        'epoch': 1,
        'ackId': 'ACK-200',
        'timestamp': nowUtc.toIso8601String(),
      };

      for (final key in validMap.keys) {
        if (key == 'type' || key == 'version') continue;
        final badMap = Map<String, dynamic>.from(validMap)..remove(key);
        expect(
          () => GroupJoinAckPacket.fromMap(badMap),
          throwsFormatException,
          reason: 'Failed to reject missing field "$key"',
        );
      }

      // Wrong type for timestamp (int instead of String)
      final mistypedMap = Map<String, dynamic>.from(validMap)..['timestamp'] = 123456789;
      expect(() => GroupJoinAckPacket.fromMap(mistypedMap), throwsFormatException);
    });

    test('GroupMessagePacket rejects missing or mistyped fields', () {
      final validMap = {
        'type': 'group_message',
        'version': 1,
        'groupId': 'GRP-1730000000000-A1B2C3',
        'messageId': 'MSG-300',
        'senderPeerId': 'ML-SENDER-1',
        'epoch': 1,
        'timestamp': nowUtc.toIso8601String(),
        'ciphertext': base64Encode([1, 2, 3]),
      };

      for (final key in validMap.keys) {
        if (key == 'type' || key == 'version') continue;
        final badMap = Map<String, dynamic>.from(validMap)..remove(key);
        expect(
          () => GroupMessagePacket.fromMap(badMap),
          throwsFormatException,
          reason: 'Failed to reject missing field "$key"',
        );
      }

      // Wrong type for ciphertext (list of ints instead of Base64 String)
      final mistypedMap = Map<String, dynamic>.from(validMap)..['ciphertext'] = [1, 2, 3];
      expect(() => GroupMessagePacket.fromMap(mistypedMap), throwsFormatException);
    });

    test('GroupMemberRemovePacket rejects missing or mistyped fields', () {
      final validMap = {
        'type': 'group_member_remove',
        'version': 1,
        'groupId': 'GRP-1730000000000-A1B2C3',
        'targetPeerId': 'ML-BAD-MEMBER',
        'adminId': 'ML-ADMIN-1',
        'epoch': 1,
        'removeId': 'REM-400',
        'timestamp': nowUtc.toIso8601String(),
      };

      for (final key in validMap.keys) {
        if (key == 'type' || key == 'version') continue;
        final badMap = Map<String, dynamic>.from(validMap)..remove(key);
        expect(
          () => GroupMemberRemovePacket.fromMap(badMap),
          throwsFormatException,
          reason: 'Failed to reject missing field "$key"',
        );
      }
    });
  });

  group('Requirement 12: Each packet rejects an unsupported or incorrect type/version discriminator', () {
    test('rejects wrong type discriminator', () {
      final map = {
        'type': 'unknown_packet_type',
        'version': 1,
        'groupId': 'GRP-1730000000000-A1B2C3',
        'groupName': 'Mesh Team',
        'adminId': 'ML-ADMIN-1',
        'invitedPeerId': 'ML-BOB-2',
        'epoch': 1,
        'inviteId': 'INV-100',
        'timestamp': nowUtc.toIso8601String(),
      };

      expect(() => GroupInvitePacket.fromMap(map), throwsFormatException);
      expect(() => GroupJoinAckPacket.fromMap(map), throwsFormatException);
      expect(() => GroupMessagePacket.fromMap(map), throwsFormatException);
      expect(() => GroupMemberRemovePacket.fromMap(map), throwsFormatException);
      expect(() => GroupPacket.fromMap(map), throwsFormatException);
    });

    test('rejects unsupported protocol version', () {
      final mapWithV2 = {
        'type': 'group_invite',
        'version': 2, // Unsupported version (expected 1)
        'groupId': 'GRP-1730000000000-A1B2C3',
        'groupName': 'Mesh Team',
        'adminId': 'ML-ADMIN-1',
        'invitedPeerId': 'ML-BOB-2',
        'epoch': 1,
        'inviteId': 'INV-100',
        'timestamp': nowUtc.toIso8601String(),
      };

      expect(() => GroupInvitePacket.fromMap(mapWithV2), throwsFormatException);

      expect(
        () => GroupInvitePacket(
          version: 2,
          groupId: 'GRP-1730000000000-A1B2C3',
          groupName: 'Mesh Team',
          adminId: 'ML-ADMIN-1',
          invitedPeerId: 'ML-BOB-2',
          epoch: 1,
          inviteId: 'INV-100',
          timestamp: nowUtc,
        ),
        throwsArgumentError,
      );
    });
  });

  group('Requirement 13: Group messages contain ciphertext only and never serialize a plaintext text field', () {
    test('GroupMessagePacket toMap and toJson never include a plaintext text key', () {
      final packet = GroupMessagePacket(
        groupId: 'GRP-1730000000000-A1B2C3',
        messageId: 'MSG-300',
        senderPeerId: 'ML-SENDER-1',
        epoch: 1,
        timestamp: nowUtc,
        ciphertext: Uint8List.fromList([10, 20, 30, 40]),
      );

      final map = packet.toMap();
      expect(map.containsKey('text'), isFalse);

      final jsonStr = packet.toJson();
      expect(jsonStr.contains('"text"'), isFalse);
    });

    test('Deserialization strictly rejects incoming payload containing plaintext "text" field', () {
      final forbiddenMap = {
        'type': 'group_message',
        'version': 1,
        'groupId': 'GRP-1730000000000-A1B2C3',
        'messageId': 'MSG-300',
        'senderPeerId': 'ML-SENDER-1',
        'epoch': 1,
        'timestamp': nowUtc.toIso8601String(),
        'ciphertext': base64Encode([10, 20, 30]),
        'text': 'Leaked plaintext message text', // STRICTLY FORBIDDEN
      };

      expect(
        () => GroupMessagePacket.fromMap(forbiddenMap),
        throwsFormatException,
      );
    });
  });

  group('Requirement 14: Empty or malformed ciphertext is rejected', () {
    test('constructor rejects empty ciphertext byte list', () {
      expect(
        () => GroupMessagePacket(
          groupId: 'GRP-1730000000000-A1B2C3',
          messageId: 'MSG-300',
          senderPeerId: 'ML-SENDER-1',
          epoch: 1,
          timestamp: nowUtc,
          ciphertext: Uint8List(0),
        ),
        throwsArgumentError,
      );
    });

    test('fromMap rejects empty Base64 string', () {
      final map = {
        'type': 'group_message',
        'version': 1,
        'groupId': 'GRP-1730000000000-A1B2C3',
        'messageId': 'MSG-300',
        'senderPeerId': 'ML-SENDER-1',
        'epoch': 1,
        'timestamp': nowUtc.toIso8601String(),
        'ciphertext': '',
      };

      expect(() => GroupMessagePacket.fromMap(map), throwsFormatException);
    });

    test('fromMap rejects whitespace-only Base64 string', () {
      final map = {
        'type': 'group_message',
        'version': 1,
        'groupId': 'GRP-1730000000000-A1B2C3',
        'messageId': 'MSG-300',
        'senderPeerId': 'ML-SENDER-1',
        'epoch': 1,
        'timestamp': nowUtc.toIso8601String(),
        'ciphertext': '   ',
      };

      expect(() => GroupMessagePacket.fromMap(map), throwsFormatException);
    });

    test('fromMap rejects malformed non-Base64 string', () {
      final map = {
        'type': 'group_message',
        'version': 1,
        'groupId': 'GRP-1730000000000-A1B2C3',
        'messageId': 'MSG-300',
        'senderPeerId': 'ML-SENDER-1',
        'epoch': 1,
        'timestamp': nowUtc.toIso8601String(),
        'ciphertext': 'NOT!VALID@BASE64#CHARACTERS==',
      };

      expect(() => GroupMessagePacket.fromMap(map), throwsFormatException);
    });
  });

  group('Requirement 15: Parsing a removal packet does not imply authorization or mutate membership', () {
    test('parsing GroupMemberRemovePacket does not mutate existing GroupMember', () {
      final member = GroupMember(
        groupId: 'GRP-1730000000000-A1B2C3',
        peerId: 'ML-TARGET-PEER',
        role: GroupRole.member,
        status: GroupMemberStatus.active,
        joinedAt: nowUtc,
        invitedBy: 'ML-ADMIN-1',
      );

      final removalPayload = jsonEncode({
        'type': 'group_member_remove',
        'version': 1,
        'groupId': 'GRP-1730000000000-A1B2C3',
        'targetPeerId': 'ML-TARGET-PEER',
        'adminId': 'ML-CLAIMED-ADMIN',
        'epoch': 1,
        'removeId': 'REM-999',
        'timestamp': nowUtc.toIso8601String(),
      });

      // Parse the wire packet
      final parsedPacket = GroupMemberRemovePacket.fromJson(removalPayload);

      // Verify packet fields
      expect(parsedPacket.targetPeerId, 'ML-TARGET-PEER');
      expect(parsedPacket.adminId, 'ML-CLAIMED-ADMIN');

      // CRITICAL: The domain member model must remain active and unaffected.
      // Wire parsing carries NO authority and causes NO side effects.
      expect(member.status, GroupMemberStatus.active);
      expect(member.isActive, isTrue);
      expect(member.isRemoved, isFalse);
    });
  });

  group('Requirement 16: Parsing a join acknowledgement does not bypass manual acceptance or identity verification', () {
    test('parsing GroupJoinAckPacket does not automatically transition pending member to active', () {
      final pendingMember = GroupMember(
        groupId: 'GRP-1730000000000-A1B2C3',
        peerId: 'ML-INVITED-PEER',
        role: GroupRole.member,
        status: GroupMemberStatus.pendingInvite,
        joinedAt: nowUtc,
        invitedBy: 'ML-ADMIN-1',
      );

      final joinAckPayload = jsonEncode({
        'type': 'group_join_ack',
        'version': 1,
        'groupId': 'GRP-1730000000000-A1B2C3',
        'ackPeerId': 'ML-INVITED-PEER',
        'adminId': 'ML-ADMIN-1',
        'epoch': 1,
        'ackId': 'ACK-888',
        'timestamp': nowUtc.toIso8601String(),
      });

      // Parse the wire packet
      final parsedAck = GroupJoinAckPacket.fromJson(joinAckPayload);

      // Verify packet fields
      expect(parsedAck.ackPeerId, 'ML-INVITED-PEER');
      expect(parsedAck.adminId, 'ML-ADMIN-1');

      // CRITICAL: The domain member model remains strictly pendingInvite.
      // Parsing the packet alone does NOT confer authenticated identity or activate membership.
      expect(pendingMember.status, GroupMemberStatus.pendingInvite);
      expect(pendingMember.isPendingInvite, isTrue);
      expect(pendingMember.isActive, isFalse);
    });
  });
}
