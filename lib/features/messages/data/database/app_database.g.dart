// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $MessagesTableTable extends MessagesTable
    with TableInfo<$MessagesTableTable, LocalMessageEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessagesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
    'message_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _senderIdMeta = const VerificationMeta(
    'senderId',
  );
  @override
  late final GeneratedColumn<String> senderId = GeneratedColumn<String>(
    'sender_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _receiverIdMeta = const VerificationMeta(
    'receiverId',
  );
  @override
  late final GeneratedColumn<String> receiverId = GeneratedColumn<String>(
    'receiver_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _textContentMeta = const VerificationMeta(
    'textContent',
  );
  @override
  late final GeneratedColumn<String> textContent = GeneratedColumn<String>(
    'text_content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    messageId,
    conversationId,
    senderId,
    receiverId,
    textContent,
    createdAt,
    status,
    retryCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'messages_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalMessageEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('sender_id')) {
      context.handle(
        _senderIdMeta,
        senderId.isAcceptableOrUnknown(data['sender_id']!, _senderIdMeta),
      );
    } else if (isInserting) {
      context.missing(_senderIdMeta);
    }
    if (data.containsKey('receiver_id')) {
      context.handle(
        _receiverIdMeta,
        receiverId.isAcceptableOrUnknown(data['receiver_id']!, _receiverIdMeta),
      );
    } else if (isInserting) {
      context.missing(_receiverIdMeta);
    }
    if (data.containsKey('text_content')) {
      context.handle(
        _textContentMeta,
        textContent.isAcceptableOrUnknown(
          data['text_content']!,
          _textContentMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_textContentMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {messageId};
  @override
  LocalMessageEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalMessageEntry(
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      senderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender_id'],
      )!,
      receiverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}receiver_id'],
      )!,
      textContent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text_content'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
    );
  }

  @override
  $MessagesTableTable createAlias(String alias) {
    return $MessagesTableTable(attachedDatabase, alias);
  }
}

class LocalMessageEntry extends DataClass
    implements Insertable<LocalMessageEntry> {
  /// Unique identifier for each message (e.g. MSG-1727220000000-A1B2C3).
  final String messageId;

  /// Stable conversation identifier (remote peer device ID).
  final String conversationId;

  /// Sender MeshLink device ID.
  final String senderId;

  /// Receiver MeshLink device ID.
  final String receiverId;

  /// Text content of the message.
  final String textContent;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Lifecycle status: pending, sending, sent, delivered, failed.
  final String status;

  /// Number of transmission retries attempted.
  final int retryCount;
  const LocalMessageEntry({
    required this.messageId,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    required this.textContent,
    required this.createdAt,
    required this.status,
    required this.retryCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['message_id'] = Variable<String>(messageId);
    map['conversation_id'] = Variable<String>(conversationId);
    map['sender_id'] = Variable<String>(senderId);
    map['receiver_id'] = Variable<String>(receiverId);
    map['text_content'] = Variable<String>(textContent);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['status'] = Variable<String>(status);
    map['retry_count'] = Variable<int>(retryCount);
    return map;
  }

  MessagesTableCompanion toCompanion(bool nullToAbsent) {
    return MessagesTableCompanion(
      messageId: Value(messageId),
      conversationId: Value(conversationId),
      senderId: Value(senderId),
      receiverId: Value(receiverId),
      textContent: Value(textContent),
      createdAt: Value(createdAt),
      status: Value(status),
      retryCount: Value(retryCount),
    );
  }

  factory LocalMessageEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalMessageEntry(
      messageId: serializer.fromJson<String>(json['messageId']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      senderId: serializer.fromJson<String>(json['senderId']),
      receiverId: serializer.fromJson<String>(json['receiverId']),
      textContent: serializer.fromJson<String>(json['textContent']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      status: serializer.fromJson<String>(json['status']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'messageId': serializer.toJson<String>(messageId),
      'conversationId': serializer.toJson<String>(conversationId),
      'senderId': serializer.toJson<String>(senderId),
      'receiverId': serializer.toJson<String>(receiverId),
      'textContent': serializer.toJson<String>(textContent),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'status': serializer.toJson<String>(status),
      'retryCount': serializer.toJson<int>(retryCount),
    };
  }

  LocalMessageEntry copyWith({
    String? messageId,
    String? conversationId,
    String? senderId,
    String? receiverId,
    String? textContent,
    DateTime? createdAt,
    String? status,
    int? retryCount,
  }) => LocalMessageEntry(
    messageId: messageId ?? this.messageId,
    conversationId: conversationId ?? this.conversationId,
    senderId: senderId ?? this.senderId,
    receiverId: receiverId ?? this.receiverId,
    textContent: textContent ?? this.textContent,
    createdAt: createdAt ?? this.createdAt,
    status: status ?? this.status,
    retryCount: retryCount ?? this.retryCount,
  );
  LocalMessageEntry copyWithCompanion(MessagesTableCompanion data) {
    return LocalMessageEntry(
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      senderId: data.senderId.present ? data.senderId.value : this.senderId,
      receiverId: data.receiverId.present
          ? data.receiverId.value
          : this.receiverId,
      textContent: data.textContent.present
          ? data.textContent.value
          : this.textContent,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      status: data.status.present ? data.status.value : this.status,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalMessageEntry(')
          ..write('messageId: $messageId, ')
          ..write('conversationId: $conversationId, ')
          ..write('senderId: $senderId, ')
          ..write('receiverId: $receiverId, ')
          ..write('textContent: $textContent, ')
          ..write('createdAt: $createdAt, ')
          ..write('status: $status, ')
          ..write('retryCount: $retryCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    messageId,
    conversationId,
    senderId,
    receiverId,
    textContent,
    createdAt,
    status,
    retryCount,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalMessageEntry &&
          other.messageId == this.messageId &&
          other.conversationId == this.conversationId &&
          other.senderId == this.senderId &&
          other.receiverId == this.receiverId &&
          other.textContent == this.textContent &&
          other.createdAt == this.createdAt &&
          other.status == this.status &&
          other.retryCount == this.retryCount);
}

class MessagesTableCompanion extends UpdateCompanion<LocalMessageEntry> {
  final Value<String> messageId;
  final Value<String> conversationId;
  final Value<String> senderId;
  final Value<String> receiverId;
  final Value<String> textContent;
  final Value<DateTime> createdAt;
  final Value<String> status;
  final Value<int> retryCount;
  final Value<int> rowid;
  const MessagesTableCompanion({
    this.messageId = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.senderId = const Value.absent(),
    this.receiverId = const Value.absent(),
    this.textContent = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.status = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessagesTableCompanion.insert({
    required String messageId,
    required String conversationId,
    required String senderId,
    required String receiverId,
    required String textContent,
    required DateTime createdAt,
    required String status,
    this.retryCount = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : messageId = Value(messageId),
       conversationId = Value(conversationId),
       senderId = Value(senderId),
       receiverId = Value(receiverId),
       textContent = Value(textContent),
       createdAt = Value(createdAt),
       status = Value(status);
  static Insertable<LocalMessageEntry> custom({
    Expression<String>? messageId,
    Expression<String>? conversationId,
    Expression<String>? senderId,
    Expression<String>? receiverId,
    Expression<String>? textContent,
    Expression<DateTime>? createdAt,
    Expression<String>? status,
    Expression<int>? retryCount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (messageId != null) 'message_id': messageId,
      if (conversationId != null) 'conversation_id': conversationId,
      if (senderId != null) 'sender_id': senderId,
      if (receiverId != null) 'receiver_id': receiverId,
      if (textContent != null) 'text_content': textContent,
      if (createdAt != null) 'created_at': createdAt,
      if (status != null) 'status': status,
      if (retryCount != null) 'retry_count': retryCount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessagesTableCompanion copyWith({
    Value<String>? messageId,
    Value<String>? conversationId,
    Value<String>? senderId,
    Value<String>? receiverId,
    Value<String>? textContent,
    Value<DateTime>? createdAt,
    Value<String>? status,
    Value<int>? retryCount,
    Value<int>? rowid,
  }) {
    return MessagesTableCompanion(
      messageId: messageId ?? this.messageId,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      textContent: textContent ?? this.textContent,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (senderId.present) {
      map['sender_id'] = Variable<String>(senderId.value);
    }
    if (receiverId.present) {
      map['receiver_id'] = Variable<String>(receiverId.value);
    }
    if (textContent.present) {
      map['text_content'] = Variable<String>(textContent.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessagesTableCompanion(')
          ..write('messageId: $messageId, ')
          ..write('conversationId: $conversationId, ')
          ..write('senderId: $senderId, ')
          ..write('receiverId: $receiverId, ')
          ..write('textContent: $textContent, ')
          ..write('createdAt: $createdAt, ')
          ..write('status: $status, ')
          ..write('retryCount: $retryCount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PeerIdentitiesTableTable extends PeerIdentitiesTable
    with TableInfo<$PeerIdentitiesTableTable, PeerIdentityEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PeerIdentitiesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _peerIdMeta = const VerificationMeta('peerId');
  @override
  late final GeneratedColumn<String> peerId = GeneratedColumn<String>(
    'peer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _identityPublicKeyMeta = const VerificationMeta(
    'identityPublicKey',
  );
  @override
  late final GeneratedColumn<String> identityPublicKey =
      GeneratedColumn<String>(
        'identity_public_key',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _safetyNumberMeta = const VerificationMeta(
    'safetyNumber',
  );
  @override
  late final GeneratedColumn<String> safetyNumber = GeneratedColumn<String>(
    'safety_number',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _trustStatusMeta = const VerificationMeta(
    'trustStatus',
  );
  @override
  late final GeneratedColumn<String> trustStatus = GeneratedColumn<String>(
    'trust_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _protocolVersionMeta = const VerificationMeta(
    'protocolVersion',
  );
  @override
  late final GeneratedColumn<int> protocolVersion = GeneratedColumn<int>(
    'protocol_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(2),
  );
  static const VerificationMeta _firstSeenAtMeta = const VerificationMeta(
    'firstSeenAt',
  );
  @override
  late final GeneratedColumn<DateTime> firstSeenAt = GeneratedColumn<DateTime>(
    'first_seen_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSeenAtMeta = const VerificationMeta(
    'lastSeenAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSeenAt = GeneratedColumn<DateTime>(
    'last_seen_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    peerId,
    identityPublicKey,
    safetyNumber,
    trustStatus,
    protocolVersion,
    firstSeenAt,
    lastSeenAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'peer_identities_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<PeerIdentityEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('peer_id')) {
      context.handle(
        _peerIdMeta,
        peerId.isAcceptableOrUnknown(data['peer_id']!, _peerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_peerIdMeta);
    }
    if (data.containsKey('identity_public_key')) {
      context.handle(
        _identityPublicKeyMeta,
        identityPublicKey.isAcceptableOrUnknown(
          data['identity_public_key']!,
          _identityPublicKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_identityPublicKeyMeta);
    }
    if (data.containsKey('safety_number')) {
      context.handle(
        _safetyNumberMeta,
        safetyNumber.isAcceptableOrUnknown(
          data['safety_number']!,
          _safetyNumberMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_safetyNumberMeta);
    }
    if (data.containsKey('trust_status')) {
      context.handle(
        _trustStatusMeta,
        trustStatus.isAcceptableOrUnknown(
          data['trust_status']!,
          _trustStatusMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_trustStatusMeta);
    }
    if (data.containsKey('protocol_version')) {
      context.handle(
        _protocolVersionMeta,
        protocolVersion.isAcceptableOrUnknown(
          data['protocol_version']!,
          _protocolVersionMeta,
        ),
      );
    }
    if (data.containsKey('first_seen_at')) {
      context.handle(
        _firstSeenAtMeta,
        firstSeenAt.isAcceptableOrUnknown(
          data['first_seen_at']!,
          _firstSeenAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_firstSeenAtMeta);
    }
    if (data.containsKey('last_seen_at')) {
      context.handle(
        _lastSeenAtMeta,
        lastSeenAt.isAcceptableOrUnknown(
          data['last_seen_at']!,
          _lastSeenAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastSeenAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {peerId};
  @override
  PeerIdentityEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PeerIdentityEntry(
      peerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}peer_id'],
      )!,
      identityPublicKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}identity_public_key'],
      )!,
      safetyNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}safety_number'],
      )!,
      trustStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trust_status'],
      )!,
      protocolVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}protocol_version'],
      )!,
      firstSeenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}first_seen_at'],
      )!,
      lastSeenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_seen_at'],
      )!,
    );
  }

  @override
  $PeerIdentitiesTableTable createAlias(String alias) {
    return $PeerIdentitiesTableTable(attachedDatabase, alias);
  }
}

class PeerIdentityEntry extends DataClass
    implements Insertable<PeerIdentityEntry> {
  /// Remote peer device ID (e.g. ML-A1B2C3).
  final String peerId;

  /// Ed25519 identity public key representation (Base64URL encoded 32 bytes).
  final String identityPublicKey;

  /// Currently calculated verification value (e.g. 6-digit SAS).
  final String safetyNumber;

  /// Lifecycle trust status: tofu_unverified, verified, compromised.
  final String trustStatus;

  /// Protocol version supported by peer (e.g. 2).
  final int protocolVersion;

  /// Initial pairing/discovery timestamp.
  final DateTime firstSeenAt;

  /// Last observed activity/handshake timestamp.
  final DateTime lastSeenAt;
  const PeerIdentityEntry({
    required this.peerId,
    required this.identityPublicKey,
    required this.safetyNumber,
    required this.trustStatus,
    required this.protocolVersion,
    required this.firstSeenAt,
    required this.lastSeenAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['peer_id'] = Variable<String>(peerId);
    map['identity_public_key'] = Variable<String>(identityPublicKey);
    map['safety_number'] = Variable<String>(safetyNumber);
    map['trust_status'] = Variable<String>(trustStatus);
    map['protocol_version'] = Variable<int>(protocolVersion);
    map['first_seen_at'] = Variable<DateTime>(firstSeenAt);
    map['last_seen_at'] = Variable<DateTime>(lastSeenAt);
    return map;
  }

  PeerIdentitiesTableCompanion toCompanion(bool nullToAbsent) {
    return PeerIdentitiesTableCompanion(
      peerId: Value(peerId),
      identityPublicKey: Value(identityPublicKey),
      safetyNumber: Value(safetyNumber),
      trustStatus: Value(trustStatus),
      protocolVersion: Value(protocolVersion),
      firstSeenAt: Value(firstSeenAt),
      lastSeenAt: Value(lastSeenAt),
    );
  }

  factory PeerIdentityEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PeerIdentityEntry(
      peerId: serializer.fromJson<String>(json['peerId']),
      identityPublicKey: serializer.fromJson<String>(json['identityPublicKey']),
      safetyNumber: serializer.fromJson<String>(json['safetyNumber']),
      trustStatus: serializer.fromJson<String>(json['trustStatus']),
      protocolVersion: serializer.fromJson<int>(json['protocolVersion']),
      firstSeenAt: serializer.fromJson<DateTime>(json['firstSeenAt']),
      lastSeenAt: serializer.fromJson<DateTime>(json['lastSeenAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'peerId': serializer.toJson<String>(peerId),
      'identityPublicKey': serializer.toJson<String>(identityPublicKey),
      'safetyNumber': serializer.toJson<String>(safetyNumber),
      'trustStatus': serializer.toJson<String>(trustStatus),
      'protocolVersion': serializer.toJson<int>(protocolVersion),
      'firstSeenAt': serializer.toJson<DateTime>(firstSeenAt),
      'lastSeenAt': serializer.toJson<DateTime>(lastSeenAt),
    };
  }

  PeerIdentityEntry copyWith({
    String? peerId,
    String? identityPublicKey,
    String? safetyNumber,
    String? trustStatus,
    int? protocolVersion,
    DateTime? firstSeenAt,
    DateTime? lastSeenAt,
  }) => PeerIdentityEntry(
    peerId: peerId ?? this.peerId,
    identityPublicKey: identityPublicKey ?? this.identityPublicKey,
    safetyNumber: safetyNumber ?? this.safetyNumber,
    trustStatus: trustStatus ?? this.trustStatus,
    protocolVersion: protocolVersion ?? this.protocolVersion,
    firstSeenAt: firstSeenAt ?? this.firstSeenAt,
    lastSeenAt: lastSeenAt ?? this.lastSeenAt,
  );
  PeerIdentityEntry copyWithCompanion(PeerIdentitiesTableCompanion data) {
    return PeerIdentityEntry(
      peerId: data.peerId.present ? data.peerId.value : this.peerId,
      identityPublicKey: data.identityPublicKey.present
          ? data.identityPublicKey.value
          : this.identityPublicKey,
      safetyNumber: data.safetyNumber.present
          ? data.safetyNumber.value
          : this.safetyNumber,
      trustStatus: data.trustStatus.present
          ? data.trustStatus.value
          : this.trustStatus,
      protocolVersion: data.protocolVersion.present
          ? data.protocolVersion.value
          : this.protocolVersion,
      firstSeenAt: data.firstSeenAt.present
          ? data.firstSeenAt.value
          : this.firstSeenAt,
      lastSeenAt: data.lastSeenAt.present
          ? data.lastSeenAt.value
          : this.lastSeenAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PeerIdentityEntry(')
          ..write('peerId: $peerId, ')
          ..write('identityPublicKey: $identityPublicKey, ')
          ..write('safetyNumber: $safetyNumber, ')
          ..write('trustStatus: $trustStatus, ')
          ..write('protocolVersion: $protocolVersion, ')
          ..write('firstSeenAt: $firstSeenAt, ')
          ..write('lastSeenAt: $lastSeenAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    peerId,
    identityPublicKey,
    safetyNumber,
    trustStatus,
    protocolVersion,
    firstSeenAt,
    lastSeenAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PeerIdentityEntry &&
          other.peerId == this.peerId &&
          other.identityPublicKey == this.identityPublicKey &&
          other.safetyNumber == this.safetyNumber &&
          other.trustStatus == this.trustStatus &&
          other.protocolVersion == this.protocolVersion &&
          other.firstSeenAt == this.firstSeenAt &&
          other.lastSeenAt == this.lastSeenAt);
}

class PeerIdentitiesTableCompanion extends UpdateCompanion<PeerIdentityEntry> {
  final Value<String> peerId;
  final Value<String> identityPublicKey;
  final Value<String> safetyNumber;
  final Value<String> trustStatus;
  final Value<int> protocolVersion;
  final Value<DateTime> firstSeenAt;
  final Value<DateTime> lastSeenAt;
  final Value<int> rowid;
  const PeerIdentitiesTableCompanion({
    this.peerId = const Value.absent(),
    this.identityPublicKey = const Value.absent(),
    this.safetyNumber = const Value.absent(),
    this.trustStatus = const Value.absent(),
    this.protocolVersion = const Value.absent(),
    this.firstSeenAt = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PeerIdentitiesTableCompanion.insert({
    required String peerId,
    required String identityPublicKey,
    required String safetyNumber,
    required String trustStatus,
    this.protocolVersion = const Value.absent(),
    required DateTime firstSeenAt,
    required DateTime lastSeenAt,
    this.rowid = const Value.absent(),
  }) : peerId = Value(peerId),
       identityPublicKey = Value(identityPublicKey),
       safetyNumber = Value(safetyNumber),
       trustStatus = Value(trustStatus),
       firstSeenAt = Value(firstSeenAt),
       lastSeenAt = Value(lastSeenAt);
  static Insertable<PeerIdentityEntry> custom({
    Expression<String>? peerId,
    Expression<String>? identityPublicKey,
    Expression<String>? safetyNumber,
    Expression<String>? trustStatus,
    Expression<int>? protocolVersion,
    Expression<DateTime>? firstSeenAt,
    Expression<DateTime>? lastSeenAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (peerId != null) 'peer_id': peerId,
      if (identityPublicKey != null) 'identity_public_key': identityPublicKey,
      if (safetyNumber != null) 'safety_number': safetyNumber,
      if (trustStatus != null) 'trust_status': trustStatus,
      if (protocolVersion != null) 'protocol_version': protocolVersion,
      if (firstSeenAt != null) 'first_seen_at': firstSeenAt,
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PeerIdentitiesTableCompanion copyWith({
    Value<String>? peerId,
    Value<String>? identityPublicKey,
    Value<String>? safetyNumber,
    Value<String>? trustStatus,
    Value<int>? protocolVersion,
    Value<DateTime>? firstSeenAt,
    Value<DateTime>? lastSeenAt,
    Value<int>? rowid,
  }) {
    return PeerIdentitiesTableCompanion(
      peerId: peerId ?? this.peerId,
      identityPublicKey: identityPublicKey ?? this.identityPublicKey,
      safetyNumber: safetyNumber ?? this.safetyNumber,
      trustStatus: trustStatus ?? this.trustStatus,
      protocolVersion: protocolVersion ?? this.protocolVersion,
      firstSeenAt: firstSeenAt ?? this.firstSeenAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (peerId.present) {
      map['peer_id'] = Variable<String>(peerId.value);
    }
    if (identityPublicKey.present) {
      map['identity_public_key'] = Variable<String>(identityPublicKey.value);
    }
    if (safetyNumber.present) {
      map['safety_number'] = Variable<String>(safetyNumber.value);
    }
    if (trustStatus.present) {
      map['trust_status'] = Variable<String>(trustStatus.value);
    }
    if (protocolVersion.present) {
      map['protocol_version'] = Variable<int>(protocolVersion.value);
    }
    if (firstSeenAt.present) {
      map['first_seen_at'] = Variable<DateTime>(firstSeenAt.value);
    }
    if (lastSeenAt.present) {
      map['last_seen_at'] = Variable<DateTime>(lastSeenAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PeerIdentitiesTableCompanion(')
          ..write('peerId: $peerId, ')
          ..write('identityPublicKey: $identityPublicKey, ')
          ..write('safetyNumber: $safetyNumber, ')
          ..write('trustStatus: $trustStatus, ')
          ..write('protocolVersion: $protocolVersion, ')
          ..write('firstSeenAt: $firstSeenAt, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SeenPacketsTableTable extends SeenPacketsTable
    with TableInfo<$SeenPacketsTableTable, SeenPacketEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SeenPacketsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _replayKeyMeta = const VerificationMeta(
    'replayKey',
  );
  @override
  late final GeneratedColumn<String> replayKey = GeneratedColumn<String>(
    'replay_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _packetTypeMeta = const VerificationMeta(
    'packetType',
  );
  @override
  late final GeneratedColumn<String> packetType = GeneratedColumn<String>(
    'packet_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originIdMeta = const VerificationMeta(
    'originId',
  );
  @override
  late final GeneratedColumn<String> originId = GeneratedColumn<String>(
    'origin_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _receivedAtMeta = const VerificationMeta(
    'receivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> receivedAt = GeneratedColumn<DateTime>(
    'received_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    replayKey,
    packetType,
    originId,
    receivedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'seen_packets_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<SeenPacketEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('replay_key')) {
      context.handle(
        _replayKeyMeta,
        replayKey.isAcceptableOrUnknown(data['replay_key']!, _replayKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_replayKeyMeta);
    }
    if (data.containsKey('packet_type')) {
      context.handle(
        _packetTypeMeta,
        packetType.isAcceptableOrUnknown(data['packet_type']!, _packetTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_packetTypeMeta);
    }
    if (data.containsKey('origin_id')) {
      context.handle(
        _originIdMeta,
        originId.isAcceptableOrUnknown(data['origin_id']!, _originIdMeta),
      );
    } else if (isInserting) {
      context.missing(_originIdMeta);
    }
    if (data.containsKey('received_at')) {
      context.handle(
        _receivedAtMeta,
        receivedAt.isAcceptableOrUnknown(data['received_at']!, _receivedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_receivedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {replayKey};
  @override
  SeenPacketEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SeenPacketEntry(
      replayKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}replay_key'],
      )!,
      packetType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}packet_type'],
      )!,
      originId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin_id'],
      )!,
      receivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}received_at'],
      )!,
    );
  }

  @override
  $SeenPacketsTableTable createAlias(String alias) {
    return $SeenPacketsTableTable(attachedDatabase, alias);
  }
}

class SeenPacketEntry extends DataClass implements Insertable<SeenPacketEntry> {
  /// Canonical composite replay key: "packetType:originId:packetId".
  final String replayKey;

  /// Category of packet (e.g. encrypted_message, ack, key_request, key_response, file_chunk).
  final String packetType;

  /// Origin node identifier.
  final String originId;

  /// Local timestamp when packet was recorded.
  final DateTime receivedAt;
  const SeenPacketEntry({
    required this.replayKey,
    required this.packetType,
    required this.originId,
    required this.receivedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['replay_key'] = Variable<String>(replayKey);
    map['packet_type'] = Variable<String>(packetType);
    map['origin_id'] = Variable<String>(originId);
    map['received_at'] = Variable<DateTime>(receivedAt);
    return map;
  }

  SeenPacketsTableCompanion toCompanion(bool nullToAbsent) {
    return SeenPacketsTableCompanion(
      replayKey: Value(replayKey),
      packetType: Value(packetType),
      originId: Value(originId),
      receivedAt: Value(receivedAt),
    );
  }

  factory SeenPacketEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SeenPacketEntry(
      replayKey: serializer.fromJson<String>(json['replayKey']),
      packetType: serializer.fromJson<String>(json['packetType']),
      originId: serializer.fromJson<String>(json['originId']),
      receivedAt: serializer.fromJson<DateTime>(json['receivedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'replayKey': serializer.toJson<String>(replayKey),
      'packetType': serializer.toJson<String>(packetType),
      'originId': serializer.toJson<String>(originId),
      'receivedAt': serializer.toJson<DateTime>(receivedAt),
    };
  }

  SeenPacketEntry copyWith({
    String? replayKey,
    String? packetType,
    String? originId,
    DateTime? receivedAt,
  }) => SeenPacketEntry(
    replayKey: replayKey ?? this.replayKey,
    packetType: packetType ?? this.packetType,
    originId: originId ?? this.originId,
    receivedAt: receivedAt ?? this.receivedAt,
  );
  SeenPacketEntry copyWithCompanion(SeenPacketsTableCompanion data) {
    return SeenPacketEntry(
      replayKey: data.replayKey.present ? data.replayKey.value : this.replayKey,
      packetType: data.packetType.present
          ? data.packetType.value
          : this.packetType,
      originId: data.originId.present ? data.originId.value : this.originId,
      receivedAt: data.receivedAt.present
          ? data.receivedAt.value
          : this.receivedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SeenPacketEntry(')
          ..write('replayKey: $replayKey, ')
          ..write('packetType: $packetType, ')
          ..write('originId: $originId, ')
          ..write('receivedAt: $receivedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(replayKey, packetType, originId, receivedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SeenPacketEntry &&
          other.replayKey == this.replayKey &&
          other.packetType == this.packetType &&
          other.originId == this.originId &&
          other.receivedAt == this.receivedAt);
}

class SeenPacketsTableCompanion extends UpdateCompanion<SeenPacketEntry> {
  final Value<String> replayKey;
  final Value<String> packetType;
  final Value<String> originId;
  final Value<DateTime> receivedAt;
  final Value<int> rowid;
  const SeenPacketsTableCompanion({
    this.replayKey = const Value.absent(),
    this.packetType = const Value.absent(),
    this.originId = const Value.absent(),
    this.receivedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SeenPacketsTableCompanion.insert({
    required String replayKey,
    required String packetType,
    required String originId,
    required DateTime receivedAt,
    this.rowid = const Value.absent(),
  }) : replayKey = Value(replayKey),
       packetType = Value(packetType),
       originId = Value(originId),
       receivedAt = Value(receivedAt);
  static Insertable<SeenPacketEntry> custom({
    Expression<String>? replayKey,
    Expression<String>? packetType,
    Expression<String>? originId,
    Expression<DateTime>? receivedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (replayKey != null) 'replay_key': replayKey,
      if (packetType != null) 'packet_type': packetType,
      if (originId != null) 'origin_id': originId,
      if (receivedAt != null) 'received_at': receivedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SeenPacketsTableCompanion copyWith({
    Value<String>? replayKey,
    Value<String>? packetType,
    Value<String>? originId,
    Value<DateTime>? receivedAt,
    Value<int>? rowid,
  }) {
    return SeenPacketsTableCompanion(
      replayKey: replayKey ?? this.replayKey,
      packetType: packetType ?? this.packetType,
      originId: originId ?? this.originId,
      receivedAt: receivedAt ?? this.receivedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (replayKey.present) {
      map['replay_key'] = Variable<String>(replayKey.value);
    }
    if (packetType.present) {
      map['packet_type'] = Variable<String>(packetType.value);
    }
    if (originId.present) {
      map['origin_id'] = Variable<String>(originId.value);
    }
    if (receivedAt.present) {
      map['received_at'] = Variable<DateTime>(receivedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SeenPacketsTableCompanion(')
          ..write('replayKey: $replayKey, ')
          ..write('packetType: $packetType, ')
          ..write('originId: $originId, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FileTransfersTableTable extends FileTransfersTable
    with TableInfo<$FileTransfersTableTable, FileTransferEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FileTransfersTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _transferIdMeta = const VerificationMeta(
    'transferId',
  );
  @override
  late final GeneratedColumn<String> transferId = GeneratedColumn<String>(
    'transfer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _peerIdMeta = const VerificationMeta('peerId');
  @override
  late final GeneratedColumn<String> peerId = GeneratedColumn<String>(
    'peer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _directionMeta = const VerificationMeta(
    'direction',
  );
  @override
  late final GeneratedColumn<String> direction = GeneratedColumn<String>(
    'direction',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileSizeMeta = const VerificationMeta(
    'fileSize',
  );
  @override
  late final GeneratedColumn<BigInt> fileSize = GeneratedColumn<BigInt>(
    'file_size',
    aliasedName,
    false,
    type: DriftSqlType.bigInt,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mimeTypeMeta = const VerificationMeta(
    'mimeType',
  );
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
    'mime_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileHashMeta = const VerificationMeta(
    'fileHash',
  );
  @override
  late final GeneratedColumn<String> fileHash = GeneratedColumn<String>(
    'file_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stagingPathMeta = const VerificationMeta(
    'stagingPath',
  );
  @override
  late final GeneratedColumn<String> stagingPath = GeneratedColumn<String>(
    'staging_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalChunksMeta = const VerificationMeta(
    'totalChunks',
  );
  @override
  late final GeneratedColumn<int> totalChunks = GeneratedColumn<int>(
    'total_chunks',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chunkSizeMeta = const VerificationMeta(
    'chunkSize',
  );
  @override
  late final GeneratedColumn<int> chunkSize = GeneratedColumn<int>(
    'chunk_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    transferId,
    conversationId,
    peerId,
    direction,
    fileName,
    fileSize,
    mimeType,
    fileHash,
    localPath,
    stagingPath,
    totalChunks,
    chunkSize,
    status,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'file_transfers_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<FileTransferEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('transfer_id')) {
      context.handle(
        _transferIdMeta,
        transferId.isAcceptableOrUnknown(data['transfer_id']!, _transferIdMeta),
      );
    } else if (isInserting) {
      context.missing(_transferIdMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('peer_id')) {
      context.handle(
        _peerIdMeta,
        peerId.isAcceptableOrUnknown(data['peer_id']!, _peerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_peerIdMeta);
    }
    if (data.containsKey('direction')) {
      context.handle(
        _directionMeta,
        direction.isAcceptableOrUnknown(data['direction']!, _directionMeta),
      );
    } else if (isInserting) {
      context.missing(_directionMeta);
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('file_size')) {
      context.handle(
        _fileSizeMeta,
        fileSize.isAcceptableOrUnknown(data['file_size']!, _fileSizeMeta),
      );
    } else if (isInserting) {
      context.missing(_fileSizeMeta);
    }
    if (data.containsKey('mime_type')) {
      context.handle(
        _mimeTypeMeta,
        mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_mimeTypeMeta);
    }
    if (data.containsKey('file_hash')) {
      context.handle(
        _fileHashMeta,
        fileHash.isAcceptableOrUnknown(data['file_hash']!, _fileHashMeta),
      );
    } else if (isInserting) {
      context.missing(_fileHashMeta);
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    } else if (isInserting) {
      context.missing(_localPathMeta);
    }
    if (data.containsKey('staging_path')) {
      context.handle(
        _stagingPathMeta,
        stagingPath.isAcceptableOrUnknown(
          data['staging_path']!,
          _stagingPathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_stagingPathMeta);
    }
    if (data.containsKey('total_chunks')) {
      context.handle(
        _totalChunksMeta,
        totalChunks.isAcceptableOrUnknown(
          data['total_chunks']!,
          _totalChunksMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalChunksMeta);
    }
    if (data.containsKey('chunk_size')) {
      context.handle(
        _chunkSizeMeta,
        chunkSize.isAcceptableOrUnknown(data['chunk_size']!, _chunkSizeMeta),
      );
    } else if (isInserting) {
      context.missing(_chunkSizeMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {transferId};
  @override
  FileTransferEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FileTransferEntry(
      transferId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transfer_id'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      peerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}peer_id'],
      )!,
      direction: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}direction'],
      )!,
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      )!,
      fileSize: attachedDatabase.typeMapping.read(
        DriftSqlType.bigInt,
        data['${effectivePrefix}file_size'],
      )!,
      mimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime_type'],
      )!,
      fileHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_hash'],
      )!,
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      )!,
      stagingPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}staging_path'],
      )!,
      totalChunks: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_chunks'],
      )!,
      chunkSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chunk_size'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $FileTransfersTableTable createAlias(String alias) {
    return $FileTransfersTableTable(attachedDatabase, alias);
  }
}

class FileTransferEntry extends DataClass
    implements Insertable<FileTransferEntry> {
  /// Unique transfer identifier (e.g. FT-1727220000000-A1B2C3).
  final String transferId;

  /// Stable conversation identifier (remote peer device ID).
  final String conversationId;

  /// Remote peer device ID.
  final String peerId;

  /// Transfer direction: 'outgoing' or 'incoming'.
  final String direction;

  /// Original or sanitized file name.
  final String fileName;

  /// Total file size in bytes (64-bit integer).
  final BigInt fileSize;

  /// MIME type string (e.g. image/jpeg, application/octet-stream).
  final String mimeType;

  /// SHA-256 hash of the entire file.
  final String fileHash;

  /// Final local filesystem path once completed.
  final String localPath;

  /// Staging / partial filesystem path during transfer.
  final String stagingPath;

  /// Total number of chunks expected.
  final int totalChunks;

  /// Size of each chunk in bytes (except possibly the final chunk).
  final int chunkSize;

  /// Current transfer lifecycle status (e.g. pending, offered, accepted, transferring, paused, completed, failed, cancelled).
  final String status;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Last updated timestamp.
  final DateTime updatedAt;
  const FileTransferEntry({
    required this.transferId,
    required this.conversationId,
    required this.peerId,
    required this.direction,
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
    required this.fileHash,
    required this.localPath,
    required this.stagingPath,
    required this.totalChunks,
    required this.chunkSize,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['transfer_id'] = Variable<String>(transferId);
    map['conversation_id'] = Variable<String>(conversationId);
    map['peer_id'] = Variable<String>(peerId);
    map['direction'] = Variable<String>(direction);
    map['file_name'] = Variable<String>(fileName);
    map['file_size'] = Variable<BigInt>(fileSize);
    map['mime_type'] = Variable<String>(mimeType);
    map['file_hash'] = Variable<String>(fileHash);
    map['local_path'] = Variable<String>(localPath);
    map['staging_path'] = Variable<String>(stagingPath);
    map['total_chunks'] = Variable<int>(totalChunks);
    map['chunk_size'] = Variable<int>(chunkSize);
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  FileTransfersTableCompanion toCompanion(bool nullToAbsent) {
    return FileTransfersTableCompanion(
      transferId: Value(transferId),
      conversationId: Value(conversationId),
      peerId: Value(peerId),
      direction: Value(direction),
      fileName: Value(fileName),
      fileSize: Value(fileSize),
      mimeType: Value(mimeType),
      fileHash: Value(fileHash),
      localPath: Value(localPath),
      stagingPath: Value(stagingPath),
      totalChunks: Value(totalChunks),
      chunkSize: Value(chunkSize),
      status: Value(status),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory FileTransferEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FileTransferEntry(
      transferId: serializer.fromJson<String>(json['transferId']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      peerId: serializer.fromJson<String>(json['peerId']),
      direction: serializer.fromJson<String>(json['direction']),
      fileName: serializer.fromJson<String>(json['fileName']),
      fileSize: serializer.fromJson<BigInt>(json['fileSize']),
      mimeType: serializer.fromJson<String>(json['mimeType']),
      fileHash: serializer.fromJson<String>(json['fileHash']),
      localPath: serializer.fromJson<String>(json['localPath']),
      stagingPath: serializer.fromJson<String>(json['stagingPath']),
      totalChunks: serializer.fromJson<int>(json['totalChunks']),
      chunkSize: serializer.fromJson<int>(json['chunkSize']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'transferId': serializer.toJson<String>(transferId),
      'conversationId': serializer.toJson<String>(conversationId),
      'peerId': serializer.toJson<String>(peerId),
      'direction': serializer.toJson<String>(direction),
      'fileName': serializer.toJson<String>(fileName),
      'fileSize': serializer.toJson<BigInt>(fileSize),
      'mimeType': serializer.toJson<String>(mimeType),
      'fileHash': serializer.toJson<String>(fileHash),
      'localPath': serializer.toJson<String>(localPath),
      'stagingPath': serializer.toJson<String>(stagingPath),
      'totalChunks': serializer.toJson<int>(totalChunks),
      'chunkSize': serializer.toJson<int>(chunkSize),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  FileTransferEntry copyWith({
    String? transferId,
    String? conversationId,
    String? peerId,
    String? direction,
    String? fileName,
    BigInt? fileSize,
    String? mimeType,
    String? fileHash,
    String? localPath,
    String? stagingPath,
    int? totalChunks,
    int? chunkSize,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => FileTransferEntry(
    transferId: transferId ?? this.transferId,
    conversationId: conversationId ?? this.conversationId,
    peerId: peerId ?? this.peerId,
    direction: direction ?? this.direction,
    fileName: fileName ?? this.fileName,
    fileSize: fileSize ?? this.fileSize,
    mimeType: mimeType ?? this.mimeType,
    fileHash: fileHash ?? this.fileHash,
    localPath: localPath ?? this.localPath,
    stagingPath: stagingPath ?? this.stagingPath,
    totalChunks: totalChunks ?? this.totalChunks,
    chunkSize: chunkSize ?? this.chunkSize,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  FileTransferEntry copyWithCompanion(FileTransfersTableCompanion data) {
    return FileTransferEntry(
      transferId: data.transferId.present
          ? data.transferId.value
          : this.transferId,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      peerId: data.peerId.present ? data.peerId.value : this.peerId,
      direction: data.direction.present ? data.direction.value : this.direction,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      fileSize: data.fileSize.present ? data.fileSize.value : this.fileSize,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      fileHash: data.fileHash.present ? data.fileHash.value : this.fileHash,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      stagingPath: data.stagingPath.present
          ? data.stagingPath.value
          : this.stagingPath,
      totalChunks: data.totalChunks.present
          ? data.totalChunks.value
          : this.totalChunks,
      chunkSize: data.chunkSize.present ? data.chunkSize.value : this.chunkSize,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FileTransferEntry(')
          ..write('transferId: $transferId, ')
          ..write('conversationId: $conversationId, ')
          ..write('peerId: $peerId, ')
          ..write('direction: $direction, ')
          ..write('fileName: $fileName, ')
          ..write('fileSize: $fileSize, ')
          ..write('mimeType: $mimeType, ')
          ..write('fileHash: $fileHash, ')
          ..write('localPath: $localPath, ')
          ..write('stagingPath: $stagingPath, ')
          ..write('totalChunks: $totalChunks, ')
          ..write('chunkSize: $chunkSize, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    transferId,
    conversationId,
    peerId,
    direction,
    fileName,
    fileSize,
    mimeType,
    fileHash,
    localPath,
    stagingPath,
    totalChunks,
    chunkSize,
    status,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FileTransferEntry &&
          other.transferId == this.transferId &&
          other.conversationId == this.conversationId &&
          other.peerId == this.peerId &&
          other.direction == this.direction &&
          other.fileName == this.fileName &&
          other.fileSize == this.fileSize &&
          other.mimeType == this.mimeType &&
          other.fileHash == this.fileHash &&
          other.localPath == this.localPath &&
          other.stagingPath == this.stagingPath &&
          other.totalChunks == this.totalChunks &&
          other.chunkSize == this.chunkSize &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class FileTransfersTableCompanion extends UpdateCompanion<FileTransferEntry> {
  final Value<String> transferId;
  final Value<String> conversationId;
  final Value<String> peerId;
  final Value<String> direction;
  final Value<String> fileName;
  final Value<BigInt> fileSize;
  final Value<String> mimeType;
  final Value<String> fileHash;
  final Value<String> localPath;
  final Value<String> stagingPath;
  final Value<int> totalChunks;
  final Value<int> chunkSize;
  final Value<String> status;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const FileTransfersTableCompanion({
    this.transferId = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.peerId = const Value.absent(),
    this.direction = const Value.absent(),
    this.fileName = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.fileHash = const Value.absent(),
    this.localPath = const Value.absent(),
    this.stagingPath = const Value.absent(),
    this.totalChunks = const Value.absent(),
    this.chunkSize = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FileTransfersTableCompanion.insert({
    required String transferId,
    required String conversationId,
    required String peerId,
    required String direction,
    required String fileName,
    required BigInt fileSize,
    required String mimeType,
    required String fileHash,
    required String localPath,
    required String stagingPath,
    required int totalChunks,
    required int chunkSize,
    required String status,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : transferId = Value(transferId),
       conversationId = Value(conversationId),
       peerId = Value(peerId),
       direction = Value(direction),
       fileName = Value(fileName),
       fileSize = Value(fileSize),
       mimeType = Value(mimeType),
       fileHash = Value(fileHash),
       localPath = Value(localPath),
       stagingPath = Value(stagingPath),
       totalChunks = Value(totalChunks),
       chunkSize = Value(chunkSize),
       status = Value(status),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<FileTransferEntry> custom({
    Expression<String>? transferId,
    Expression<String>? conversationId,
    Expression<String>? peerId,
    Expression<String>? direction,
    Expression<String>? fileName,
    Expression<BigInt>? fileSize,
    Expression<String>? mimeType,
    Expression<String>? fileHash,
    Expression<String>? localPath,
    Expression<String>? stagingPath,
    Expression<int>? totalChunks,
    Expression<int>? chunkSize,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (transferId != null) 'transfer_id': transferId,
      if (conversationId != null) 'conversation_id': conversationId,
      if (peerId != null) 'peer_id': peerId,
      if (direction != null) 'direction': direction,
      if (fileName != null) 'file_name': fileName,
      if (fileSize != null) 'file_size': fileSize,
      if (mimeType != null) 'mime_type': mimeType,
      if (fileHash != null) 'file_hash': fileHash,
      if (localPath != null) 'local_path': localPath,
      if (stagingPath != null) 'staging_path': stagingPath,
      if (totalChunks != null) 'total_chunks': totalChunks,
      if (chunkSize != null) 'chunk_size': chunkSize,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FileTransfersTableCompanion copyWith({
    Value<String>? transferId,
    Value<String>? conversationId,
    Value<String>? peerId,
    Value<String>? direction,
    Value<String>? fileName,
    Value<BigInt>? fileSize,
    Value<String>? mimeType,
    Value<String>? fileHash,
    Value<String>? localPath,
    Value<String>? stagingPath,
    Value<int>? totalChunks,
    Value<int>? chunkSize,
    Value<String>? status,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return FileTransfersTableCompanion(
      transferId: transferId ?? this.transferId,
      conversationId: conversationId ?? this.conversationId,
      peerId: peerId ?? this.peerId,
      direction: direction ?? this.direction,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      mimeType: mimeType ?? this.mimeType,
      fileHash: fileHash ?? this.fileHash,
      localPath: localPath ?? this.localPath,
      stagingPath: stagingPath ?? this.stagingPath,
      totalChunks: totalChunks ?? this.totalChunks,
      chunkSize: chunkSize ?? this.chunkSize,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (transferId.present) {
      map['transfer_id'] = Variable<String>(transferId.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (peerId.present) {
      map['peer_id'] = Variable<String>(peerId.value);
    }
    if (direction.present) {
      map['direction'] = Variable<String>(direction.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (fileSize.present) {
      map['file_size'] = Variable<BigInt>(fileSize.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (fileHash.present) {
      map['file_hash'] = Variable<String>(fileHash.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (stagingPath.present) {
      map['staging_path'] = Variable<String>(stagingPath.value);
    }
    if (totalChunks.present) {
      map['total_chunks'] = Variable<int>(totalChunks.value);
    }
    if (chunkSize.present) {
      map['chunk_size'] = Variable<int>(chunkSize.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FileTransfersTableCompanion(')
          ..write('transferId: $transferId, ')
          ..write('conversationId: $conversationId, ')
          ..write('peerId: $peerId, ')
          ..write('direction: $direction, ')
          ..write('fileName: $fileName, ')
          ..write('fileSize: $fileSize, ')
          ..write('mimeType: $mimeType, ')
          ..write('fileHash: $fileHash, ')
          ..write('localPath: $localPath, ')
          ..write('stagingPath: $stagingPath, ')
          ..write('totalChunks: $totalChunks, ')
          ..write('chunkSize: $chunkSize, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FileChunksTableTable extends FileChunksTable
    with TableInfo<$FileChunksTableTable, FileChunkEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FileChunksTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _transferIdMeta = const VerificationMeta(
    'transferId',
  );
  @override
  late final GeneratedColumn<String> transferId = GeneratedColumn<String>(
    'transfer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chunkIndexMeta = const VerificationMeta(
    'chunkIndex',
  );
  @override
  late final GeneratedColumn<int> chunkIndex = GeneratedColumn<int>(
    'chunk_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _receivedAtMeta = const VerificationMeta(
    'receivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> receivedAt = GeneratedColumn<DateTime>(
    'received_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    transferId,
    chunkIndex,
    status,
    receivedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'file_chunks_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<FileChunkEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('transfer_id')) {
      context.handle(
        _transferIdMeta,
        transferId.isAcceptableOrUnknown(data['transfer_id']!, _transferIdMeta),
      );
    } else if (isInserting) {
      context.missing(_transferIdMeta);
    }
    if (data.containsKey('chunk_index')) {
      context.handle(
        _chunkIndexMeta,
        chunkIndex.isAcceptableOrUnknown(data['chunk_index']!, _chunkIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_chunkIndexMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('received_at')) {
      context.handle(
        _receivedAtMeta,
        receivedAt.isAcceptableOrUnknown(data['received_at']!, _receivedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_receivedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {transferId, chunkIndex};
  @override
  FileChunkEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FileChunkEntry(
      transferId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transfer_id'],
      )!,
      chunkIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chunk_index'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      receivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}received_at'],
      )!,
    );
  }

  @override
  $FileChunksTableTable createAlias(String alias) {
    return $FileChunksTableTable(attachedDatabase, alias);
  }
}

class FileChunkEntry extends DataClass implements Insertable<FileChunkEntry> {
  /// Associated transfer ID.
  final String transferId;

  /// 0-based index of this chunk.
  final int chunkIndex;

  /// Chunk status (e.g. 'pending', 'received', 'verified').
  final String status;

  /// Local timestamp when chunk was received or recorded.
  final DateTime receivedAt;
  const FileChunkEntry({
    required this.transferId,
    required this.chunkIndex,
    required this.status,
    required this.receivedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['transfer_id'] = Variable<String>(transferId);
    map['chunk_index'] = Variable<int>(chunkIndex);
    map['status'] = Variable<String>(status);
    map['received_at'] = Variable<DateTime>(receivedAt);
    return map;
  }

  FileChunksTableCompanion toCompanion(bool nullToAbsent) {
    return FileChunksTableCompanion(
      transferId: Value(transferId),
      chunkIndex: Value(chunkIndex),
      status: Value(status),
      receivedAt: Value(receivedAt),
    );
  }

  factory FileChunkEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FileChunkEntry(
      transferId: serializer.fromJson<String>(json['transferId']),
      chunkIndex: serializer.fromJson<int>(json['chunkIndex']),
      status: serializer.fromJson<String>(json['status']),
      receivedAt: serializer.fromJson<DateTime>(json['receivedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'transferId': serializer.toJson<String>(transferId),
      'chunkIndex': serializer.toJson<int>(chunkIndex),
      'status': serializer.toJson<String>(status),
      'receivedAt': serializer.toJson<DateTime>(receivedAt),
    };
  }

  FileChunkEntry copyWith({
    String? transferId,
    int? chunkIndex,
    String? status,
    DateTime? receivedAt,
  }) => FileChunkEntry(
    transferId: transferId ?? this.transferId,
    chunkIndex: chunkIndex ?? this.chunkIndex,
    status: status ?? this.status,
    receivedAt: receivedAt ?? this.receivedAt,
  );
  FileChunkEntry copyWithCompanion(FileChunksTableCompanion data) {
    return FileChunkEntry(
      transferId: data.transferId.present
          ? data.transferId.value
          : this.transferId,
      chunkIndex: data.chunkIndex.present
          ? data.chunkIndex.value
          : this.chunkIndex,
      status: data.status.present ? data.status.value : this.status,
      receivedAt: data.receivedAt.present
          ? data.receivedAt.value
          : this.receivedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FileChunkEntry(')
          ..write('transferId: $transferId, ')
          ..write('chunkIndex: $chunkIndex, ')
          ..write('status: $status, ')
          ..write('receivedAt: $receivedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(transferId, chunkIndex, status, receivedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FileChunkEntry &&
          other.transferId == this.transferId &&
          other.chunkIndex == this.chunkIndex &&
          other.status == this.status &&
          other.receivedAt == this.receivedAt);
}

class FileChunksTableCompanion extends UpdateCompanion<FileChunkEntry> {
  final Value<String> transferId;
  final Value<int> chunkIndex;
  final Value<String> status;
  final Value<DateTime> receivedAt;
  final Value<int> rowid;
  const FileChunksTableCompanion({
    this.transferId = const Value.absent(),
    this.chunkIndex = const Value.absent(),
    this.status = const Value.absent(),
    this.receivedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FileChunksTableCompanion.insert({
    required String transferId,
    required int chunkIndex,
    required String status,
    required DateTime receivedAt,
    this.rowid = const Value.absent(),
  }) : transferId = Value(transferId),
       chunkIndex = Value(chunkIndex),
       status = Value(status),
       receivedAt = Value(receivedAt);
  static Insertable<FileChunkEntry> custom({
    Expression<String>? transferId,
    Expression<int>? chunkIndex,
    Expression<String>? status,
    Expression<DateTime>? receivedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (transferId != null) 'transfer_id': transferId,
      if (chunkIndex != null) 'chunk_index': chunkIndex,
      if (status != null) 'status': status,
      if (receivedAt != null) 'received_at': receivedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FileChunksTableCompanion copyWith({
    Value<String>? transferId,
    Value<int>? chunkIndex,
    Value<String>? status,
    Value<DateTime>? receivedAt,
    Value<int>? rowid,
  }) {
    return FileChunksTableCompanion(
      transferId: transferId ?? this.transferId,
      chunkIndex: chunkIndex ?? this.chunkIndex,
      status: status ?? this.status,
      receivedAt: receivedAt ?? this.receivedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (transferId.present) {
      map['transfer_id'] = Variable<String>(transferId.value);
    }
    if (chunkIndex.present) {
      map['chunk_index'] = Variable<int>(chunkIndex.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (receivedAt.present) {
      map['received_at'] = Variable<DateTime>(receivedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FileChunksTableCompanion(')
          ..write('transferId: $transferId, ')
          ..write('chunkIndex: $chunkIndex, ')
          ..write('status: $status, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $MessagesTableTable messagesTable = $MessagesTableTable(this);
  late final $PeerIdentitiesTableTable peerIdentitiesTable =
      $PeerIdentitiesTableTable(this);
  late final $SeenPacketsTableTable seenPacketsTable = $SeenPacketsTableTable(
    this,
  );
  late final $FileTransfersTableTable fileTransfersTable =
      $FileTransfersTableTable(this);
  late final $FileChunksTableTable fileChunksTable = $FileChunksTableTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    messagesTable,
    peerIdentitiesTable,
    seenPacketsTable,
    fileTransfersTable,
    fileChunksTable,
  ];
}

typedef $$MessagesTableTableCreateCompanionBuilder =
    MessagesTableCompanion Function({
      required String messageId,
      required String conversationId,
      required String senderId,
      required String receiverId,
      required String textContent,
      required DateTime createdAt,
      required String status,
      Value<int> retryCount,
      Value<int> rowid,
    });
typedef $$MessagesTableTableUpdateCompanionBuilder =
    MessagesTableCompanion Function({
      Value<String> messageId,
      Value<String> conversationId,
      Value<String> senderId,
      Value<String> receiverId,
      Value<String> textContent,
      Value<DateTime> createdAt,
      Value<String> status,
      Value<int> retryCount,
      Value<int> rowid,
    });

class $$MessagesTableTableFilterComposer
    extends Composer<_$AppDatabase, $MessagesTableTable> {
  $$MessagesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get senderId => $composableBuilder(
    column: $table.senderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get receiverId => $composableBuilder(
    column: $table.receiverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get textContent => $composableBuilder(
    column: $table.textContent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MessagesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $MessagesTableTable> {
  $$MessagesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get senderId => $composableBuilder(
    column: $table.senderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get receiverId => $composableBuilder(
    column: $table.receiverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get textContent => $composableBuilder(
    column: $table.textContent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MessagesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $MessagesTableTable> {
  $$MessagesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get senderId =>
      $composableBuilder(column: $table.senderId, builder: (column) => column);

  GeneratedColumn<String> get receiverId => $composableBuilder(
    column: $table.receiverId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get textContent => $composableBuilder(
    column: $table.textContent,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );
}

class $$MessagesTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MessagesTableTable,
          LocalMessageEntry,
          $$MessagesTableTableFilterComposer,
          $$MessagesTableTableOrderingComposer,
          $$MessagesTableTableAnnotationComposer,
          $$MessagesTableTableCreateCompanionBuilder,
          $$MessagesTableTableUpdateCompanionBuilder,
          (
            LocalMessageEntry,
            BaseReferences<
              _$AppDatabase,
              $MessagesTableTable,
              LocalMessageEntry
            >,
          ),
          LocalMessageEntry,
          PrefetchHooks Function()
        > {
  $$MessagesTableTableTableManager(_$AppDatabase db, $MessagesTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessagesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessagesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessagesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> messageId = const Value.absent(),
                Value<String> conversationId = const Value.absent(),
                Value<String> senderId = const Value.absent(),
                Value<String> receiverId = const Value.absent(),
                Value<String> textContent = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessagesTableCompanion(
                messageId: messageId,
                conversationId: conversationId,
                senderId: senderId,
                receiverId: receiverId,
                textContent: textContent,
                createdAt: createdAt,
                status: status,
                retryCount: retryCount,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String messageId,
                required String conversationId,
                required String senderId,
                required String receiverId,
                required String textContent,
                required DateTime createdAt,
                required String status,
                Value<int> retryCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessagesTableCompanion.insert(
                messageId: messageId,
                conversationId: conversationId,
                senderId: senderId,
                receiverId: receiverId,
                textContent: textContent,
                createdAt: createdAt,
                status: status,
                retryCount: retryCount,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MessagesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MessagesTableTable,
      LocalMessageEntry,
      $$MessagesTableTableFilterComposer,
      $$MessagesTableTableOrderingComposer,
      $$MessagesTableTableAnnotationComposer,
      $$MessagesTableTableCreateCompanionBuilder,
      $$MessagesTableTableUpdateCompanionBuilder,
      (
        LocalMessageEntry,
        BaseReferences<_$AppDatabase, $MessagesTableTable, LocalMessageEntry>,
      ),
      LocalMessageEntry,
      PrefetchHooks Function()
    >;
typedef $$PeerIdentitiesTableTableCreateCompanionBuilder =
    PeerIdentitiesTableCompanion Function({
      required String peerId,
      required String identityPublicKey,
      required String safetyNumber,
      required String trustStatus,
      Value<int> protocolVersion,
      required DateTime firstSeenAt,
      required DateTime lastSeenAt,
      Value<int> rowid,
    });
typedef $$PeerIdentitiesTableTableUpdateCompanionBuilder =
    PeerIdentitiesTableCompanion Function({
      Value<String> peerId,
      Value<String> identityPublicKey,
      Value<String> safetyNumber,
      Value<String> trustStatus,
      Value<int> protocolVersion,
      Value<DateTime> firstSeenAt,
      Value<DateTime> lastSeenAt,
      Value<int> rowid,
    });

class $$PeerIdentitiesTableTableFilterComposer
    extends Composer<_$AppDatabase, $PeerIdentitiesTableTable> {
  $$PeerIdentitiesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get peerId => $composableBuilder(
    column: $table.peerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get identityPublicKey => $composableBuilder(
    column: $table.identityPublicKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get safetyNumber => $composableBuilder(
    column: $table.safetyNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trustStatus => $composableBuilder(
    column: $table.trustStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get protocolVersion => $composableBuilder(
    column: $table.protocolVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get firstSeenAt => $composableBuilder(
    column: $table.firstSeenAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PeerIdentitiesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $PeerIdentitiesTableTable> {
  $$PeerIdentitiesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get peerId => $composableBuilder(
    column: $table.peerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get identityPublicKey => $composableBuilder(
    column: $table.identityPublicKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get safetyNumber => $composableBuilder(
    column: $table.safetyNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trustStatus => $composableBuilder(
    column: $table.trustStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get protocolVersion => $composableBuilder(
    column: $table.protocolVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get firstSeenAt => $composableBuilder(
    column: $table.firstSeenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PeerIdentitiesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $PeerIdentitiesTableTable> {
  $$PeerIdentitiesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get peerId =>
      $composableBuilder(column: $table.peerId, builder: (column) => column);

  GeneratedColumn<String> get identityPublicKey => $composableBuilder(
    column: $table.identityPublicKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get safetyNumber => $composableBuilder(
    column: $table.safetyNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get trustStatus => $composableBuilder(
    column: $table.trustStatus,
    builder: (column) => column,
  );

  GeneratedColumn<int> get protocolVersion => $composableBuilder(
    column: $table.protocolVersion,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get firstSeenAt => $composableBuilder(
    column: $table.firstSeenAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => column,
  );
}

class $$PeerIdentitiesTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PeerIdentitiesTableTable,
          PeerIdentityEntry,
          $$PeerIdentitiesTableTableFilterComposer,
          $$PeerIdentitiesTableTableOrderingComposer,
          $$PeerIdentitiesTableTableAnnotationComposer,
          $$PeerIdentitiesTableTableCreateCompanionBuilder,
          $$PeerIdentitiesTableTableUpdateCompanionBuilder,
          (
            PeerIdentityEntry,
            BaseReferences<
              _$AppDatabase,
              $PeerIdentitiesTableTable,
              PeerIdentityEntry
            >,
          ),
          PeerIdentityEntry,
          PrefetchHooks Function()
        > {
  $$PeerIdentitiesTableTableTableManager(
    _$AppDatabase db,
    $PeerIdentitiesTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PeerIdentitiesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PeerIdentitiesTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PeerIdentitiesTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> peerId = const Value.absent(),
                Value<String> identityPublicKey = const Value.absent(),
                Value<String> safetyNumber = const Value.absent(),
                Value<String> trustStatus = const Value.absent(),
                Value<int> protocolVersion = const Value.absent(),
                Value<DateTime> firstSeenAt = const Value.absent(),
                Value<DateTime> lastSeenAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PeerIdentitiesTableCompanion(
                peerId: peerId,
                identityPublicKey: identityPublicKey,
                safetyNumber: safetyNumber,
                trustStatus: trustStatus,
                protocolVersion: protocolVersion,
                firstSeenAt: firstSeenAt,
                lastSeenAt: lastSeenAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String peerId,
                required String identityPublicKey,
                required String safetyNumber,
                required String trustStatus,
                Value<int> protocolVersion = const Value.absent(),
                required DateTime firstSeenAt,
                required DateTime lastSeenAt,
                Value<int> rowid = const Value.absent(),
              }) => PeerIdentitiesTableCompanion.insert(
                peerId: peerId,
                identityPublicKey: identityPublicKey,
                safetyNumber: safetyNumber,
                trustStatus: trustStatus,
                protocolVersion: protocolVersion,
                firstSeenAt: firstSeenAt,
                lastSeenAt: lastSeenAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PeerIdentitiesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PeerIdentitiesTableTable,
      PeerIdentityEntry,
      $$PeerIdentitiesTableTableFilterComposer,
      $$PeerIdentitiesTableTableOrderingComposer,
      $$PeerIdentitiesTableTableAnnotationComposer,
      $$PeerIdentitiesTableTableCreateCompanionBuilder,
      $$PeerIdentitiesTableTableUpdateCompanionBuilder,
      (
        PeerIdentityEntry,
        BaseReferences<
          _$AppDatabase,
          $PeerIdentitiesTableTable,
          PeerIdentityEntry
        >,
      ),
      PeerIdentityEntry,
      PrefetchHooks Function()
    >;
typedef $$SeenPacketsTableTableCreateCompanionBuilder =
    SeenPacketsTableCompanion Function({
      required String replayKey,
      required String packetType,
      required String originId,
      required DateTime receivedAt,
      Value<int> rowid,
    });
typedef $$SeenPacketsTableTableUpdateCompanionBuilder =
    SeenPacketsTableCompanion Function({
      Value<String> replayKey,
      Value<String> packetType,
      Value<String> originId,
      Value<DateTime> receivedAt,
      Value<int> rowid,
    });

class $$SeenPacketsTableTableFilterComposer
    extends Composer<_$AppDatabase, $SeenPacketsTableTable> {
  $$SeenPacketsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get replayKey => $composableBuilder(
    column: $table.replayKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get packetType => $composableBuilder(
    column: $table.packetType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originId => $composableBuilder(
    column: $table.originId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SeenPacketsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $SeenPacketsTableTable> {
  $$SeenPacketsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get replayKey => $composableBuilder(
    column: $table.replayKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get packetType => $composableBuilder(
    column: $table.packetType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originId => $composableBuilder(
    column: $table.originId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SeenPacketsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $SeenPacketsTableTable> {
  $$SeenPacketsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get replayKey =>
      $composableBuilder(column: $table.replayKey, builder: (column) => column);

  GeneratedColumn<String> get packetType => $composableBuilder(
    column: $table.packetType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get originId =>
      $composableBuilder(column: $table.originId, builder: (column) => column);

  GeneratedColumn<DateTime> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => column,
  );
}

class $$SeenPacketsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SeenPacketsTableTable,
          SeenPacketEntry,
          $$SeenPacketsTableTableFilterComposer,
          $$SeenPacketsTableTableOrderingComposer,
          $$SeenPacketsTableTableAnnotationComposer,
          $$SeenPacketsTableTableCreateCompanionBuilder,
          $$SeenPacketsTableTableUpdateCompanionBuilder,
          (
            SeenPacketEntry,
            BaseReferences<
              _$AppDatabase,
              $SeenPacketsTableTable,
              SeenPacketEntry
            >,
          ),
          SeenPacketEntry,
          PrefetchHooks Function()
        > {
  $$SeenPacketsTableTableTableManager(
    _$AppDatabase db,
    $SeenPacketsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SeenPacketsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SeenPacketsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SeenPacketsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> replayKey = const Value.absent(),
                Value<String> packetType = const Value.absent(),
                Value<String> originId = const Value.absent(),
                Value<DateTime> receivedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SeenPacketsTableCompanion(
                replayKey: replayKey,
                packetType: packetType,
                originId: originId,
                receivedAt: receivedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String replayKey,
                required String packetType,
                required String originId,
                required DateTime receivedAt,
                Value<int> rowid = const Value.absent(),
              }) => SeenPacketsTableCompanion.insert(
                replayKey: replayKey,
                packetType: packetType,
                originId: originId,
                receivedAt: receivedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SeenPacketsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SeenPacketsTableTable,
      SeenPacketEntry,
      $$SeenPacketsTableTableFilterComposer,
      $$SeenPacketsTableTableOrderingComposer,
      $$SeenPacketsTableTableAnnotationComposer,
      $$SeenPacketsTableTableCreateCompanionBuilder,
      $$SeenPacketsTableTableUpdateCompanionBuilder,
      (
        SeenPacketEntry,
        BaseReferences<_$AppDatabase, $SeenPacketsTableTable, SeenPacketEntry>,
      ),
      SeenPacketEntry,
      PrefetchHooks Function()
    >;
typedef $$FileTransfersTableTableCreateCompanionBuilder =
    FileTransfersTableCompanion Function({
      required String transferId,
      required String conversationId,
      required String peerId,
      required String direction,
      required String fileName,
      required BigInt fileSize,
      required String mimeType,
      required String fileHash,
      required String localPath,
      required String stagingPath,
      required int totalChunks,
      required int chunkSize,
      required String status,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$FileTransfersTableTableUpdateCompanionBuilder =
    FileTransfersTableCompanion Function({
      Value<String> transferId,
      Value<String> conversationId,
      Value<String> peerId,
      Value<String> direction,
      Value<String> fileName,
      Value<BigInt> fileSize,
      Value<String> mimeType,
      Value<String> fileHash,
      Value<String> localPath,
      Value<String> stagingPath,
      Value<int> totalChunks,
      Value<int> chunkSize,
      Value<String> status,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$FileTransfersTableTableFilterComposer
    extends Composer<_$AppDatabase, $FileTransfersTableTable> {
  $$FileTransfersTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get transferId => $composableBuilder(
    column: $table.transferId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get peerId => $composableBuilder(
    column: $table.peerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<BigInt> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileHash => $composableBuilder(
    column: $table.fileHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stagingPath => $composableBuilder(
    column: $table.stagingPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalChunks => $composableBuilder(
    column: $table.totalChunks,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chunkSize => $composableBuilder(
    column: $table.chunkSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FileTransfersTableTableOrderingComposer
    extends Composer<_$AppDatabase, $FileTransfersTableTable> {
  $$FileTransfersTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get transferId => $composableBuilder(
    column: $table.transferId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get peerId => $composableBuilder(
    column: $table.peerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<BigInt> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileHash => $composableBuilder(
    column: $table.fileHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stagingPath => $composableBuilder(
    column: $table.stagingPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalChunks => $composableBuilder(
    column: $table.totalChunks,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chunkSize => $composableBuilder(
    column: $table.chunkSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FileTransfersTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $FileTransfersTableTable> {
  $$FileTransfersTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get transferId => $composableBuilder(
    column: $table.transferId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get peerId =>
      $composableBuilder(column: $table.peerId, builder: (column) => column);

  GeneratedColumn<String> get direction =>
      $composableBuilder(column: $table.direction, builder: (column) => column);

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<BigInt> get fileSize =>
      $composableBuilder(column: $table.fileSize, builder: (column) => column);

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<String> get fileHash =>
      $composableBuilder(column: $table.fileHash, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<String> get stagingPath => $composableBuilder(
    column: $table.stagingPath,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalChunks => $composableBuilder(
    column: $table.totalChunks,
    builder: (column) => column,
  );

  GeneratedColumn<int> get chunkSize =>
      $composableBuilder(column: $table.chunkSize, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$FileTransfersTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FileTransfersTableTable,
          FileTransferEntry,
          $$FileTransfersTableTableFilterComposer,
          $$FileTransfersTableTableOrderingComposer,
          $$FileTransfersTableTableAnnotationComposer,
          $$FileTransfersTableTableCreateCompanionBuilder,
          $$FileTransfersTableTableUpdateCompanionBuilder,
          (
            FileTransferEntry,
            BaseReferences<
              _$AppDatabase,
              $FileTransfersTableTable,
              FileTransferEntry
            >,
          ),
          FileTransferEntry,
          PrefetchHooks Function()
        > {
  $$FileTransfersTableTableTableManager(
    _$AppDatabase db,
    $FileTransfersTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FileTransfersTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FileTransfersTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FileTransfersTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> transferId = const Value.absent(),
                Value<String> conversationId = const Value.absent(),
                Value<String> peerId = const Value.absent(),
                Value<String> direction = const Value.absent(),
                Value<String> fileName = const Value.absent(),
                Value<BigInt> fileSize = const Value.absent(),
                Value<String> mimeType = const Value.absent(),
                Value<String> fileHash = const Value.absent(),
                Value<String> localPath = const Value.absent(),
                Value<String> stagingPath = const Value.absent(),
                Value<int> totalChunks = const Value.absent(),
                Value<int> chunkSize = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FileTransfersTableCompanion(
                transferId: transferId,
                conversationId: conversationId,
                peerId: peerId,
                direction: direction,
                fileName: fileName,
                fileSize: fileSize,
                mimeType: mimeType,
                fileHash: fileHash,
                localPath: localPath,
                stagingPath: stagingPath,
                totalChunks: totalChunks,
                chunkSize: chunkSize,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String transferId,
                required String conversationId,
                required String peerId,
                required String direction,
                required String fileName,
                required BigInt fileSize,
                required String mimeType,
                required String fileHash,
                required String localPath,
                required String stagingPath,
                required int totalChunks,
                required int chunkSize,
                required String status,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => FileTransfersTableCompanion.insert(
                transferId: transferId,
                conversationId: conversationId,
                peerId: peerId,
                direction: direction,
                fileName: fileName,
                fileSize: fileSize,
                mimeType: mimeType,
                fileHash: fileHash,
                localPath: localPath,
                stagingPath: stagingPath,
                totalChunks: totalChunks,
                chunkSize: chunkSize,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FileTransfersTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FileTransfersTableTable,
      FileTransferEntry,
      $$FileTransfersTableTableFilterComposer,
      $$FileTransfersTableTableOrderingComposer,
      $$FileTransfersTableTableAnnotationComposer,
      $$FileTransfersTableTableCreateCompanionBuilder,
      $$FileTransfersTableTableUpdateCompanionBuilder,
      (
        FileTransferEntry,
        BaseReferences<
          _$AppDatabase,
          $FileTransfersTableTable,
          FileTransferEntry
        >,
      ),
      FileTransferEntry,
      PrefetchHooks Function()
    >;
typedef $$FileChunksTableTableCreateCompanionBuilder =
    FileChunksTableCompanion Function({
      required String transferId,
      required int chunkIndex,
      required String status,
      required DateTime receivedAt,
      Value<int> rowid,
    });
typedef $$FileChunksTableTableUpdateCompanionBuilder =
    FileChunksTableCompanion Function({
      Value<String> transferId,
      Value<int> chunkIndex,
      Value<String> status,
      Value<DateTime> receivedAt,
      Value<int> rowid,
    });

class $$FileChunksTableTableFilterComposer
    extends Composer<_$AppDatabase, $FileChunksTableTable> {
  $$FileChunksTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get transferId => $composableBuilder(
    column: $table.transferId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chunkIndex => $composableBuilder(
    column: $table.chunkIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FileChunksTableTableOrderingComposer
    extends Composer<_$AppDatabase, $FileChunksTableTable> {
  $$FileChunksTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get transferId => $composableBuilder(
    column: $table.transferId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chunkIndex => $composableBuilder(
    column: $table.chunkIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FileChunksTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $FileChunksTableTable> {
  $$FileChunksTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get transferId => $composableBuilder(
    column: $table.transferId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get chunkIndex => $composableBuilder(
    column: $table.chunkIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => column,
  );
}

class $$FileChunksTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FileChunksTableTable,
          FileChunkEntry,
          $$FileChunksTableTableFilterComposer,
          $$FileChunksTableTableOrderingComposer,
          $$FileChunksTableTableAnnotationComposer,
          $$FileChunksTableTableCreateCompanionBuilder,
          $$FileChunksTableTableUpdateCompanionBuilder,
          (
            FileChunkEntry,
            BaseReferences<
              _$AppDatabase,
              $FileChunksTableTable,
              FileChunkEntry
            >,
          ),
          FileChunkEntry,
          PrefetchHooks Function()
        > {
  $$FileChunksTableTableTableManager(
    _$AppDatabase db,
    $FileChunksTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FileChunksTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FileChunksTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FileChunksTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> transferId = const Value.absent(),
                Value<int> chunkIndex = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> receivedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FileChunksTableCompanion(
                transferId: transferId,
                chunkIndex: chunkIndex,
                status: status,
                receivedAt: receivedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String transferId,
                required int chunkIndex,
                required String status,
                required DateTime receivedAt,
                Value<int> rowid = const Value.absent(),
              }) => FileChunksTableCompanion.insert(
                transferId: transferId,
                chunkIndex: chunkIndex,
                status: status,
                receivedAt: receivedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FileChunksTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FileChunksTableTable,
      FileChunkEntry,
      $$FileChunksTableTableFilterComposer,
      $$FileChunksTableTableOrderingComposer,
      $$FileChunksTableTableAnnotationComposer,
      $$FileChunksTableTableCreateCompanionBuilder,
      $$FileChunksTableTableUpdateCompanionBuilder,
      (
        FileChunkEntry,
        BaseReferences<_$AppDatabase, $FileChunksTableTable, FileChunkEntry>,
      ),
      FileChunkEntry,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$MessagesTableTableTableManager get messagesTable =>
      $$MessagesTableTableTableManager(_db, _db.messagesTable);
  $$PeerIdentitiesTableTableTableManager get peerIdentitiesTable =>
      $$PeerIdentitiesTableTableTableManager(_db, _db.peerIdentitiesTable);
  $$SeenPacketsTableTableTableManager get seenPacketsTable =>
      $$SeenPacketsTableTableTableManager(_db, _db.seenPacketsTable);
  $$FileTransfersTableTableTableManager get fileTransfersTable =>
      $$FileTransfersTableTableTableManager(_db, _db.fileTransfersTable);
  $$FileChunksTableTableTableManager get fileChunksTable =>
      $$FileChunksTableTableTableManager(_db, _db.fileChunksTable);
}
