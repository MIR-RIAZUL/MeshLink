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

class $GroupsTableTable extends GroupsTable
    with TableInfo<$GroupsTableTable, GroupEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GroupsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _creatorIdMeta = const VerificationMeta(
    'creatorId',
  );
  @override
  late final GeneratedColumn<String> creatorId = GeneratedColumn<String>(
    'creator_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _adminIdMeta = const VerificationMeta(
    'adminId',
  );
  @override
  late final GeneratedColumn<String> adminId = GeneratedColumn<String>(
    'admin_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _epochMeta = const VerificationMeta('epoch');
  @override
  late final GeneratedColumn<int> epoch = GeneratedColumn<int>(
    'epoch',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _isReEpochPendingMeta = const VerificationMeta(
    'isReEpochPending',
  );
  @override
  late final GeneratedColumn<bool> isReEpochPending = GeneratedColumn<bool>(
    'is_re_epoch_pending',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_re_epoch_pending" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _activeReEpochOperationIdMeta =
      const VerificationMeta('activeReEpochOperationId');
  @override
  late final GeneratedColumn<String> activeReEpochOperationId =
      GeneratedColumn<String>(
        'active_re_epoch_operation_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _preparedEpochMeta = const VerificationMeta(
    'preparedEpoch',
  );
  @override
  late final GeneratedColumn<int> preparedEpoch = GeneratedColumn<int>(
    'prepared_epoch',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _operationSequenceNumberMeta =
      const VerificationMeta('operationSequenceNumber');
  @override
  late final GeneratedColumn<int> operationSequenceNumber =
      GeneratedColumn<int>(
        'operation_sequence_number',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
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
    groupId,
    name,
    creatorId,
    adminId,
    epoch,
    isReEpochPending,
    activeReEpochOperationId,
    preparedEpoch,
    operationSequenceNumber,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'groups_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<GroupEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('creator_id')) {
      context.handle(
        _creatorIdMeta,
        creatorId.isAcceptableOrUnknown(data['creator_id']!, _creatorIdMeta),
      );
    } else if (isInserting) {
      context.missing(_creatorIdMeta);
    }
    if (data.containsKey('admin_id')) {
      context.handle(
        _adminIdMeta,
        adminId.isAcceptableOrUnknown(data['admin_id']!, _adminIdMeta),
      );
    } else if (isInserting) {
      context.missing(_adminIdMeta);
    }
    if (data.containsKey('epoch')) {
      context.handle(
        _epochMeta,
        epoch.isAcceptableOrUnknown(data['epoch']!, _epochMeta),
      );
    }
    if (data.containsKey('is_re_epoch_pending')) {
      context.handle(
        _isReEpochPendingMeta,
        isReEpochPending.isAcceptableOrUnknown(
          data['is_re_epoch_pending']!,
          _isReEpochPendingMeta,
        ),
      );
    }
    if (data.containsKey('active_re_epoch_operation_id')) {
      context.handle(
        _activeReEpochOperationIdMeta,
        activeReEpochOperationId.isAcceptableOrUnknown(
          data['active_re_epoch_operation_id']!,
          _activeReEpochOperationIdMeta,
        ),
      );
    }
    if (data.containsKey('prepared_epoch')) {
      context.handle(
        _preparedEpochMeta,
        preparedEpoch.isAcceptableOrUnknown(
          data['prepared_epoch']!,
          _preparedEpochMeta,
        ),
      );
    }
    if (data.containsKey('operation_sequence_number')) {
      context.handle(
        _operationSequenceNumberMeta,
        operationSequenceNumber.isAcceptableOrUnknown(
          data['operation_sequence_number']!,
          _operationSequenceNumberMeta,
        ),
      );
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
  Set<GeneratedColumn> get $primaryKey => {groupId};
  @override
  GroupEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GroupEntry(
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      creatorId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}creator_id'],
      )!,
      adminId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}admin_id'],
      )!,
      epoch: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}epoch'],
      )!,
      isReEpochPending: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_re_epoch_pending'],
      )!,
      activeReEpochOperationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}active_re_epoch_operation_id'],
      ),
      preparedEpoch: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}prepared_epoch'],
      ),
      operationSequenceNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}operation_sequence_number'],
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
  $GroupsTableTable createAlias(String alias) {
    return $GroupsTableTable(attachedDatabase, alias);
  }
}

class GroupEntry extends DataClass implements Insertable<GroupEntry> {
  /// Unique group identifier (e.g. GRP-1727220000000-A1B2C3).
  final String groupId;

  /// Human-readable group name (1-64 characters).
  final String name;

  /// Creator MeshLink device ID.
  final String creatorId;

  /// Current admin MeshLink device ID.
  final String adminId;

  /// Monotonically increasing membership epoch (starts at 1).
  final int epoch;

  /// Whether an administrative re-epoch operation is pending for this group.
  final bool isReEpochPending;

  /// Active 128-bit re-epoch operation identifier (nullable).
  final String? activeReEpochOperationId;

  /// Target epoch prepared by members during re-epoching (nullable).
  final int? preparedEpoch;

  /// Monotonically increasing operation sequence number for this group.
  final int operationSequenceNumber;

  /// Creation timestamp in UTC.
  final DateTime createdAt;

  /// Last updated timestamp in UTC.
  final DateTime updatedAt;
  const GroupEntry({
    required this.groupId,
    required this.name,
    required this.creatorId,
    required this.adminId,
    required this.epoch,
    required this.isReEpochPending,
    this.activeReEpochOperationId,
    this.preparedEpoch,
    required this.operationSequenceNumber,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['group_id'] = Variable<String>(groupId);
    map['name'] = Variable<String>(name);
    map['creator_id'] = Variable<String>(creatorId);
    map['admin_id'] = Variable<String>(adminId);
    map['epoch'] = Variable<int>(epoch);
    map['is_re_epoch_pending'] = Variable<bool>(isReEpochPending);
    if (!nullToAbsent || activeReEpochOperationId != null) {
      map['active_re_epoch_operation_id'] = Variable<String>(
        activeReEpochOperationId,
      );
    }
    if (!nullToAbsent || preparedEpoch != null) {
      map['prepared_epoch'] = Variable<int>(preparedEpoch);
    }
    map['operation_sequence_number'] = Variable<int>(operationSequenceNumber);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  GroupsTableCompanion toCompanion(bool nullToAbsent) {
    return GroupsTableCompanion(
      groupId: Value(groupId),
      name: Value(name),
      creatorId: Value(creatorId),
      adminId: Value(adminId),
      epoch: Value(epoch),
      isReEpochPending: Value(isReEpochPending),
      activeReEpochOperationId: activeReEpochOperationId == null && nullToAbsent
          ? const Value.absent()
          : Value(activeReEpochOperationId),
      preparedEpoch: preparedEpoch == null && nullToAbsent
          ? const Value.absent()
          : Value(preparedEpoch),
      operationSequenceNumber: Value(operationSequenceNumber),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory GroupEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GroupEntry(
      groupId: serializer.fromJson<String>(json['groupId']),
      name: serializer.fromJson<String>(json['name']),
      creatorId: serializer.fromJson<String>(json['creatorId']),
      adminId: serializer.fromJson<String>(json['adminId']),
      epoch: serializer.fromJson<int>(json['epoch']),
      isReEpochPending: serializer.fromJson<bool>(json['isReEpochPending']),
      activeReEpochOperationId: serializer.fromJson<String?>(
        json['activeReEpochOperationId'],
      ),
      preparedEpoch: serializer.fromJson<int?>(json['preparedEpoch']),
      operationSequenceNumber: serializer.fromJson<int>(
        json['operationSequenceNumber'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'groupId': serializer.toJson<String>(groupId),
      'name': serializer.toJson<String>(name),
      'creatorId': serializer.toJson<String>(creatorId),
      'adminId': serializer.toJson<String>(adminId),
      'epoch': serializer.toJson<int>(epoch),
      'isReEpochPending': serializer.toJson<bool>(isReEpochPending),
      'activeReEpochOperationId': serializer.toJson<String?>(
        activeReEpochOperationId,
      ),
      'preparedEpoch': serializer.toJson<int?>(preparedEpoch),
      'operationSequenceNumber': serializer.toJson<int>(
        operationSequenceNumber,
      ),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  GroupEntry copyWith({
    String? groupId,
    String? name,
    String? creatorId,
    String? adminId,
    int? epoch,
    bool? isReEpochPending,
    Value<String?> activeReEpochOperationId = const Value.absent(),
    Value<int?> preparedEpoch = const Value.absent(),
    int? operationSequenceNumber,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => GroupEntry(
    groupId: groupId ?? this.groupId,
    name: name ?? this.name,
    creatorId: creatorId ?? this.creatorId,
    adminId: adminId ?? this.adminId,
    epoch: epoch ?? this.epoch,
    isReEpochPending: isReEpochPending ?? this.isReEpochPending,
    activeReEpochOperationId: activeReEpochOperationId.present
        ? activeReEpochOperationId.value
        : this.activeReEpochOperationId,
    preparedEpoch: preparedEpoch.present
        ? preparedEpoch.value
        : this.preparedEpoch,
    operationSequenceNumber:
        operationSequenceNumber ?? this.operationSequenceNumber,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  GroupEntry copyWithCompanion(GroupsTableCompanion data) {
    return GroupEntry(
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      name: data.name.present ? data.name.value : this.name,
      creatorId: data.creatorId.present ? data.creatorId.value : this.creatorId,
      adminId: data.adminId.present ? data.adminId.value : this.adminId,
      epoch: data.epoch.present ? data.epoch.value : this.epoch,
      isReEpochPending: data.isReEpochPending.present
          ? data.isReEpochPending.value
          : this.isReEpochPending,
      activeReEpochOperationId: data.activeReEpochOperationId.present
          ? data.activeReEpochOperationId.value
          : this.activeReEpochOperationId,
      preparedEpoch: data.preparedEpoch.present
          ? data.preparedEpoch.value
          : this.preparedEpoch,
      operationSequenceNumber: data.operationSequenceNumber.present
          ? data.operationSequenceNumber.value
          : this.operationSequenceNumber,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GroupEntry(')
          ..write('groupId: $groupId, ')
          ..write('name: $name, ')
          ..write('creatorId: $creatorId, ')
          ..write('adminId: $adminId, ')
          ..write('epoch: $epoch, ')
          ..write('isReEpochPending: $isReEpochPending, ')
          ..write('activeReEpochOperationId: $activeReEpochOperationId, ')
          ..write('preparedEpoch: $preparedEpoch, ')
          ..write('operationSequenceNumber: $operationSequenceNumber, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    groupId,
    name,
    creatorId,
    adminId,
    epoch,
    isReEpochPending,
    activeReEpochOperationId,
    preparedEpoch,
    operationSequenceNumber,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GroupEntry &&
          other.groupId == this.groupId &&
          other.name == this.name &&
          other.creatorId == this.creatorId &&
          other.adminId == this.adminId &&
          other.epoch == this.epoch &&
          other.isReEpochPending == this.isReEpochPending &&
          other.activeReEpochOperationId == this.activeReEpochOperationId &&
          other.preparedEpoch == this.preparedEpoch &&
          other.operationSequenceNumber == this.operationSequenceNumber &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class GroupsTableCompanion extends UpdateCompanion<GroupEntry> {
  final Value<String> groupId;
  final Value<String> name;
  final Value<String> creatorId;
  final Value<String> adminId;
  final Value<int> epoch;
  final Value<bool> isReEpochPending;
  final Value<String?> activeReEpochOperationId;
  final Value<int?> preparedEpoch;
  final Value<int> operationSequenceNumber;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const GroupsTableCompanion({
    this.groupId = const Value.absent(),
    this.name = const Value.absent(),
    this.creatorId = const Value.absent(),
    this.adminId = const Value.absent(),
    this.epoch = const Value.absent(),
    this.isReEpochPending = const Value.absent(),
    this.activeReEpochOperationId = const Value.absent(),
    this.preparedEpoch = const Value.absent(),
    this.operationSequenceNumber = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GroupsTableCompanion.insert({
    required String groupId,
    required String name,
    required String creatorId,
    required String adminId,
    this.epoch = const Value.absent(),
    this.isReEpochPending = const Value.absent(),
    this.activeReEpochOperationId = const Value.absent(),
    this.preparedEpoch = const Value.absent(),
    this.operationSequenceNumber = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : groupId = Value(groupId),
       name = Value(name),
       creatorId = Value(creatorId),
       adminId = Value(adminId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<GroupEntry> custom({
    Expression<String>? groupId,
    Expression<String>? name,
    Expression<String>? creatorId,
    Expression<String>? adminId,
    Expression<int>? epoch,
    Expression<bool>? isReEpochPending,
    Expression<String>? activeReEpochOperationId,
    Expression<int>? preparedEpoch,
    Expression<int>? operationSequenceNumber,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (groupId != null) 'group_id': groupId,
      if (name != null) 'name': name,
      if (creatorId != null) 'creator_id': creatorId,
      if (adminId != null) 'admin_id': adminId,
      if (epoch != null) 'epoch': epoch,
      if (isReEpochPending != null) 'is_re_epoch_pending': isReEpochPending,
      if (activeReEpochOperationId != null)
        'active_re_epoch_operation_id': activeReEpochOperationId,
      if (preparedEpoch != null) 'prepared_epoch': preparedEpoch,
      if (operationSequenceNumber != null)
        'operation_sequence_number': operationSequenceNumber,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GroupsTableCompanion copyWith({
    Value<String>? groupId,
    Value<String>? name,
    Value<String>? creatorId,
    Value<String>? adminId,
    Value<int>? epoch,
    Value<bool>? isReEpochPending,
    Value<String?>? activeReEpochOperationId,
    Value<int?>? preparedEpoch,
    Value<int>? operationSequenceNumber,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return GroupsTableCompanion(
      groupId: groupId ?? this.groupId,
      name: name ?? this.name,
      creatorId: creatorId ?? this.creatorId,
      adminId: adminId ?? this.adminId,
      epoch: epoch ?? this.epoch,
      isReEpochPending: isReEpochPending ?? this.isReEpochPending,
      activeReEpochOperationId:
          activeReEpochOperationId ?? this.activeReEpochOperationId,
      preparedEpoch: preparedEpoch ?? this.preparedEpoch,
      operationSequenceNumber:
          operationSequenceNumber ?? this.operationSequenceNumber,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (creatorId.present) {
      map['creator_id'] = Variable<String>(creatorId.value);
    }
    if (adminId.present) {
      map['admin_id'] = Variable<String>(adminId.value);
    }
    if (epoch.present) {
      map['epoch'] = Variable<int>(epoch.value);
    }
    if (isReEpochPending.present) {
      map['is_re_epoch_pending'] = Variable<bool>(isReEpochPending.value);
    }
    if (activeReEpochOperationId.present) {
      map['active_re_epoch_operation_id'] = Variable<String>(
        activeReEpochOperationId.value,
      );
    }
    if (preparedEpoch.present) {
      map['prepared_epoch'] = Variable<int>(preparedEpoch.value);
    }
    if (operationSequenceNumber.present) {
      map['operation_sequence_number'] = Variable<int>(
        operationSequenceNumber.value,
      );
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
    return (StringBuffer('GroupsTableCompanion(')
          ..write('groupId: $groupId, ')
          ..write('name: $name, ')
          ..write('creatorId: $creatorId, ')
          ..write('adminId: $adminId, ')
          ..write('epoch: $epoch, ')
          ..write('isReEpochPending: $isReEpochPending, ')
          ..write('activeReEpochOperationId: $activeReEpochOperationId, ')
          ..write('preparedEpoch: $preparedEpoch, ')
          ..write('operationSequenceNumber: $operationSequenceNumber, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GroupMembersTableTable extends GroupMembersTable
    with TableInfo<$GroupMembersTableTable, GroupMemberEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GroupMembersTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL REFERENCES groups_table(group_id) ON DELETE CASCADE',
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
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
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
  static const VerificationMeta _joinedAtMeta = const VerificationMeta(
    'joinedAt',
  );
  @override
  late final GeneratedColumn<DateTime> joinedAt = GeneratedColumn<DateTime>(
    'joined_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _invitedByMeta = const VerificationMeta(
    'invitedBy',
  );
  @override
  late final GeneratedColumn<String> invitedBy = GeneratedColumn<String>(
    'invited_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    groupId,
    peerId,
    role,
    status,
    joinedAt,
    invitedBy,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'group_members_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<GroupMemberEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('peer_id')) {
      context.handle(
        _peerIdMeta,
        peerId.isAcceptableOrUnknown(data['peer_id']!, _peerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_peerIdMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('joined_at')) {
      context.handle(
        _joinedAtMeta,
        joinedAt.isAcceptableOrUnknown(data['joined_at']!, _joinedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_joinedAtMeta);
    }
    if (data.containsKey('invited_by')) {
      context.handle(
        _invitedByMeta,
        invitedBy.isAcceptableOrUnknown(data['invited_by']!, _invitedByMeta),
      );
    } else if (isInserting) {
      context.missing(_invitedByMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {groupId, peerId};
  @override
  GroupMemberEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GroupMemberEntry(
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      )!,
      peerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}peer_id'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      joinedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}joined_at'],
      )!,
      invitedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}invited_by'],
      )!,
    );
  }

  @override
  $GroupMembersTableTable createAlias(String alias) {
    return $GroupMembersTableTable(attachedDatabase, alias);
  }
}

class GroupMemberEntry extends DataClass
    implements Insertable<GroupMemberEntry> {
  /// Target group identifier, referencing GroupsTable.
  final String groupId;

  /// Peer device identifier.
  final String peerId;

  /// Role within the group: 'admin' or 'member'.
  final String role;

  /// Membership lifecycle status: 'active', 'pendingInvite', 'removed'.
  final String status;

  /// Timestamp when the member joined or was invited.
  final DateTime joinedAt;

  /// Peer device ID of the admin who invited this member.
  final String invitedBy;
  const GroupMemberEntry({
    required this.groupId,
    required this.peerId,
    required this.role,
    required this.status,
    required this.joinedAt,
    required this.invitedBy,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['group_id'] = Variable<String>(groupId);
    map['peer_id'] = Variable<String>(peerId);
    map['role'] = Variable<String>(role);
    map['status'] = Variable<String>(status);
    map['joined_at'] = Variable<DateTime>(joinedAt);
    map['invited_by'] = Variable<String>(invitedBy);
    return map;
  }

  GroupMembersTableCompanion toCompanion(bool nullToAbsent) {
    return GroupMembersTableCompanion(
      groupId: Value(groupId),
      peerId: Value(peerId),
      role: Value(role),
      status: Value(status),
      joinedAt: Value(joinedAt),
      invitedBy: Value(invitedBy),
    );
  }

  factory GroupMemberEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GroupMemberEntry(
      groupId: serializer.fromJson<String>(json['groupId']),
      peerId: serializer.fromJson<String>(json['peerId']),
      role: serializer.fromJson<String>(json['role']),
      status: serializer.fromJson<String>(json['status']),
      joinedAt: serializer.fromJson<DateTime>(json['joinedAt']),
      invitedBy: serializer.fromJson<String>(json['invitedBy']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'groupId': serializer.toJson<String>(groupId),
      'peerId': serializer.toJson<String>(peerId),
      'role': serializer.toJson<String>(role),
      'status': serializer.toJson<String>(status),
      'joinedAt': serializer.toJson<DateTime>(joinedAt),
      'invitedBy': serializer.toJson<String>(invitedBy),
    };
  }

  GroupMemberEntry copyWith({
    String? groupId,
    String? peerId,
    String? role,
    String? status,
    DateTime? joinedAt,
    String? invitedBy,
  }) => GroupMemberEntry(
    groupId: groupId ?? this.groupId,
    peerId: peerId ?? this.peerId,
    role: role ?? this.role,
    status: status ?? this.status,
    joinedAt: joinedAt ?? this.joinedAt,
    invitedBy: invitedBy ?? this.invitedBy,
  );
  GroupMemberEntry copyWithCompanion(GroupMembersTableCompanion data) {
    return GroupMemberEntry(
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      peerId: data.peerId.present ? data.peerId.value : this.peerId,
      role: data.role.present ? data.role.value : this.role,
      status: data.status.present ? data.status.value : this.status,
      joinedAt: data.joinedAt.present ? data.joinedAt.value : this.joinedAt,
      invitedBy: data.invitedBy.present ? data.invitedBy.value : this.invitedBy,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GroupMemberEntry(')
          ..write('groupId: $groupId, ')
          ..write('peerId: $peerId, ')
          ..write('role: $role, ')
          ..write('status: $status, ')
          ..write('joinedAt: $joinedAt, ')
          ..write('invitedBy: $invitedBy')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(groupId, peerId, role, status, joinedAt, invitedBy);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GroupMemberEntry &&
          other.groupId == this.groupId &&
          other.peerId == this.peerId &&
          other.role == this.role &&
          other.status == this.status &&
          other.joinedAt == this.joinedAt &&
          other.invitedBy == this.invitedBy);
}

class GroupMembersTableCompanion extends UpdateCompanion<GroupMemberEntry> {
  final Value<String> groupId;
  final Value<String> peerId;
  final Value<String> role;
  final Value<String> status;
  final Value<DateTime> joinedAt;
  final Value<String> invitedBy;
  final Value<int> rowid;
  const GroupMembersTableCompanion({
    this.groupId = const Value.absent(),
    this.peerId = const Value.absent(),
    this.role = const Value.absent(),
    this.status = const Value.absent(),
    this.joinedAt = const Value.absent(),
    this.invitedBy = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GroupMembersTableCompanion.insert({
    required String groupId,
    required String peerId,
    required String role,
    required String status,
    required DateTime joinedAt,
    required String invitedBy,
    this.rowid = const Value.absent(),
  }) : groupId = Value(groupId),
       peerId = Value(peerId),
       role = Value(role),
       status = Value(status),
       joinedAt = Value(joinedAt),
       invitedBy = Value(invitedBy);
  static Insertable<GroupMemberEntry> custom({
    Expression<String>? groupId,
    Expression<String>? peerId,
    Expression<String>? role,
    Expression<String>? status,
    Expression<DateTime>? joinedAt,
    Expression<String>? invitedBy,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (groupId != null) 'group_id': groupId,
      if (peerId != null) 'peer_id': peerId,
      if (role != null) 'role': role,
      if (status != null) 'status': status,
      if (joinedAt != null) 'joined_at': joinedAt,
      if (invitedBy != null) 'invited_by': invitedBy,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GroupMembersTableCompanion copyWith({
    Value<String>? groupId,
    Value<String>? peerId,
    Value<String>? role,
    Value<String>? status,
    Value<DateTime>? joinedAt,
    Value<String>? invitedBy,
    Value<int>? rowid,
  }) {
    return GroupMembersTableCompanion(
      groupId: groupId ?? this.groupId,
      peerId: peerId ?? this.peerId,
      role: role ?? this.role,
      status: status ?? this.status,
      joinedAt: joinedAt ?? this.joinedAt,
      invitedBy: invitedBy ?? this.invitedBy,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (peerId.present) {
      map['peer_id'] = Variable<String>(peerId.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (joinedAt.present) {
      map['joined_at'] = Variable<DateTime>(joinedAt.value);
    }
    if (invitedBy.present) {
      map['invited_by'] = Variable<String>(invitedBy.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GroupMembersTableCompanion(')
          ..write('groupId: $groupId, ')
          ..write('peerId: $peerId, ')
          ..write('role: $role, ')
          ..write('status: $status, ')
          ..write('joinedAt: $joinedAt, ')
          ..write('invitedBy: $invitedBy, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GroupEpochOperationsTableTable extends GroupEpochOperationsTable
    with TableInfo<$GroupEpochOperationsTableTable, GroupEpochOperationEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GroupEpochOperationsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _operationIdMeta = const VerificationMeta(
    'operationId',
  );
  @override
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
    'operation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL REFERENCES groups_table(group_id) ON DELETE CASCADE',
  );
  static const VerificationMeta _previousEpochMeta = const VerificationMeta(
    'previousEpoch',
  );
  @override
  late final GeneratedColumn<int> previousEpoch = GeneratedColumn<int>(
    'previous_epoch',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetEpochMeta = const VerificationMeta(
    'targetEpoch',
  );
  @override
  late final GeneratedColumn<int> targetEpoch = GeneratedColumn<int>(
    'target_epoch',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationSequenceNumberMeta =
      const VerificationMeta('operationSequenceNumber');
  @override
  late final GeneratedColumn<int> operationSequenceNumber =
      GeneratedColumn<int>(
        'operation_sequence_number',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _operationStatusMeta = const VerificationMeta(
    'operationStatus',
  );
  @override
  late final GeneratedColumn<String> operationStatus = GeneratedColumn<String>(
    'operation_status',
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
    operationId,
    groupId,
    previousEpoch,
    targetEpoch,
    operationSequenceNumber,
    operationStatus,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'group_epoch_operations_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<GroupEpochOperationEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('operation_id')) {
      context.handle(
        _operationIdMeta,
        operationId.isAcceptableOrUnknown(
          data['operation_id']!,
          _operationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationIdMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('previous_epoch')) {
      context.handle(
        _previousEpochMeta,
        previousEpoch.isAcceptableOrUnknown(
          data['previous_epoch']!,
          _previousEpochMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_previousEpochMeta);
    }
    if (data.containsKey('target_epoch')) {
      context.handle(
        _targetEpochMeta,
        targetEpoch.isAcceptableOrUnknown(
          data['target_epoch']!,
          _targetEpochMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetEpochMeta);
    }
    if (data.containsKey('operation_sequence_number')) {
      context.handle(
        _operationSequenceNumberMeta,
        operationSequenceNumber.isAcceptableOrUnknown(
          data['operation_sequence_number']!,
          _operationSequenceNumberMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationSequenceNumberMeta);
    }
    if (data.containsKey('operation_status')) {
      context.handle(
        _operationStatusMeta,
        operationStatus.isAcceptableOrUnknown(
          data['operation_status']!,
          _operationStatusMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationStatusMeta);
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
  Set<GeneratedColumn> get $primaryKey => {operationId};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {operationId, groupId},
  ];
  @override
  GroupEpochOperationEntry map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GroupEpochOperationEntry(
      operationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_id'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      )!,
      previousEpoch: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}previous_epoch'],
      )!,
      targetEpoch: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_epoch'],
      )!,
      operationSequenceNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}operation_sequence_number'],
      )!,
      operationStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_status'],
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
  $GroupEpochOperationsTableTable createAlias(String alias) {
    return $GroupEpochOperationsTableTable(attachedDatabase, alias);
  }
}

class GroupEpochOperationEntry extends DataClass
    implements Insertable<GroupEpochOperationEntry> {
  /// Unique 128-bit operation identifier (e.g. RE-OP-<32 hex chars>).
  final String operationId;

  /// Foreign key referencing groups_table(group_id).
  final String groupId;

  /// Epoch before this operation began.
  final int previousEpoch;

  /// Epoch targeted by this operation (strictly > previousEpoch).
  final int targetEpoch;

  /// Strictly positive, monotonically increasing operation sequence number.
  final int operationSequenceNumber;

  /// Current lifecycle status: preparing, committing, finalizing, finalized, superseded.
  final String operationStatus;

  /// UTC creation timestamp.
  final DateTime createdAt;

  /// UTC last updated timestamp.
  final DateTime updatedAt;
  const GroupEpochOperationEntry({
    required this.operationId,
    required this.groupId,
    required this.previousEpoch,
    required this.targetEpoch,
    required this.operationSequenceNumber,
    required this.operationStatus,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['operation_id'] = Variable<String>(operationId);
    map['group_id'] = Variable<String>(groupId);
    map['previous_epoch'] = Variable<int>(previousEpoch);
    map['target_epoch'] = Variable<int>(targetEpoch);
    map['operation_sequence_number'] = Variable<int>(operationSequenceNumber);
    map['operation_status'] = Variable<String>(operationStatus);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  GroupEpochOperationsTableCompanion toCompanion(bool nullToAbsent) {
    return GroupEpochOperationsTableCompanion(
      operationId: Value(operationId),
      groupId: Value(groupId),
      previousEpoch: Value(previousEpoch),
      targetEpoch: Value(targetEpoch),
      operationSequenceNumber: Value(operationSequenceNumber),
      operationStatus: Value(operationStatus),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory GroupEpochOperationEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GroupEpochOperationEntry(
      operationId: serializer.fromJson<String>(json['operationId']),
      groupId: serializer.fromJson<String>(json['groupId']),
      previousEpoch: serializer.fromJson<int>(json['previousEpoch']),
      targetEpoch: serializer.fromJson<int>(json['targetEpoch']),
      operationSequenceNumber: serializer.fromJson<int>(
        json['operationSequenceNumber'],
      ),
      operationStatus: serializer.fromJson<String>(json['operationStatus']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'operationId': serializer.toJson<String>(operationId),
      'groupId': serializer.toJson<String>(groupId),
      'previousEpoch': serializer.toJson<int>(previousEpoch),
      'targetEpoch': serializer.toJson<int>(targetEpoch),
      'operationSequenceNumber': serializer.toJson<int>(
        operationSequenceNumber,
      ),
      'operationStatus': serializer.toJson<String>(operationStatus),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  GroupEpochOperationEntry copyWith({
    String? operationId,
    String? groupId,
    int? previousEpoch,
    int? targetEpoch,
    int? operationSequenceNumber,
    String? operationStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => GroupEpochOperationEntry(
    operationId: operationId ?? this.operationId,
    groupId: groupId ?? this.groupId,
    previousEpoch: previousEpoch ?? this.previousEpoch,
    targetEpoch: targetEpoch ?? this.targetEpoch,
    operationSequenceNumber:
        operationSequenceNumber ?? this.operationSequenceNumber,
    operationStatus: operationStatus ?? this.operationStatus,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  GroupEpochOperationEntry copyWithCompanion(
    GroupEpochOperationsTableCompanion data,
  ) {
    return GroupEpochOperationEntry(
      operationId: data.operationId.present
          ? data.operationId.value
          : this.operationId,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      previousEpoch: data.previousEpoch.present
          ? data.previousEpoch.value
          : this.previousEpoch,
      targetEpoch: data.targetEpoch.present
          ? data.targetEpoch.value
          : this.targetEpoch,
      operationSequenceNumber: data.operationSequenceNumber.present
          ? data.operationSequenceNumber.value
          : this.operationSequenceNumber,
      operationStatus: data.operationStatus.present
          ? data.operationStatus.value
          : this.operationStatus,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GroupEpochOperationEntry(')
          ..write('operationId: $operationId, ')
          ..write('groupId: $groupId, ')
          ..write('previousEpoch: $previousEpoch, ')
          ..write('targetEpoch: $targetEpoch, ')
          ..write('operationSequenceNumber: $operationSequenceNumber, ')
          ..write('operationStatus: $operationStatus, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    operationId,
    groupId,
    previousEpoch,
    targetEpoch,
    operationSequenceNumber,
    operationStatus,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GroupEpochOperationEntry &&
          other.operationId == this.operationId &&
          other.groupId == this.groupId &&
          other.previousEpoch == this.previousEpoch &&
          other.targetEpoch == this.targetEpoch &&
          other.operationSequenceNumber == this.operationSequenceNumber &&
          other.operationStatus == this.operationStatus &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class GroupEpochOperationsTableCompanion
    extends UpdateCompanion<GroupEpochOperationEntry> {
  final Value<String> operationId;
  final Value<String> groupId;
  final Value<int> previousEpoch;
  final Value<int> targetEpoch;
  final Value<int> operationSequenceNumber;
  final Value<String> operationStatus;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const GroupEpochOperationsTableCompanion({
    this.operationId = const Value.absent(),
    this.groupId = const Value.absent(),
    this.previousEpoch = const Value.absent(),
    this.targetEpoch = const Value.absent(),
    this.operationSequenceNumber = const Value.absent(),
    this.operationStatus = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GroupEpochOperationsTableCompanion.insert({
    required String operationId,
    required String groupId,
    required int previousEpoch,
    required int targetEpoch,
    required int operationSequenceNumber,
    required String operationStatus,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : operationId = Value(operationId),
       groupId = Value(groupId),
       previousEpoch = Value(previousEpoch),
       targetEpoch = Value(targetEpoch),
       operationSequenceNumber = Value(operationSequenceNumber),
       operationStatus = Value(operationStatus),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<GroupEpochOperationEntry> custom({
    Expression<String>? operationId,
    Expression<String>? groupId,
    Expression<int>? previousEpoch,
    Expression<int>? targetEpoch,
    Expression<int>? operationSequenceNumber,
    Expression<String>? operationStatus,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (operationId != null) 'operation_id': operationId,
      if (groupId != null) 'group_id': groupId,
      if (previousEpoch != null) 'previous_epoch': previousEpoch,
      if (targetEpoch != null) 'target_epoch': targetEpoch,
      if (operationSequenceNumber != null)
        'operation_sequence_number': operationSequenceNumber,
      if (operationStatus != null) 'operation_status': operationStatus,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GroupEpochOperationsTableCompanion copyWith({
    Value<String>? operationId,
    Value<String>? groupId,
    Value<int>? previousEpoch,
    Value<int>? targetEpoch,
    Value<int>? operationSequenceNumber,
    Value<String>? operationStatus,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return GroupEpochOperationsTableCompanion(
      operationId: operationId ?? this.operationId,
      groupId: groupId ?? this.groupId,
      previousEpoch: previousEpoch ?? this.previousEpoch,
      targetEpoch: targetEpoch ?? this.targetEpoch,
      operationSequenceNumber:
          operationSequenceNumber ?? this.operationSequenceNumber,
      operationStatus: operationStatus ?? this.operationStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (previousEpoch.present) {
      map['previous_epoch'] = Variable<int>(previousEpoch.value);
    }
    if (targetEpoch.present) {
      map['target_epoch'] = Variable<int>(targetEpoch.value);
    }
    if (operationSequenceNumber.present) {
      map['operation_sequence_number'] = Variable<int>(
        operationSequenceNumber.value,
      );
    }
    if (operationStatus.present) {
      map['operation_status'] = Variable<String>(operationStatus.value);
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
    return (StringBuffer('GroupEpochOperationsTableCompanion(')
          ..write('operationId: $operationId, ')
          ..write('groupId: $groupId, ')
          ..write('previousEpoch: $previousEpoch, ')
          ..write('targetEpoch: $targetEpoch, ')
          ..write('operationSequenceNumber: $operationSequenceNumber, ')
          ..write('operationStatus: $operationStatus, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GroupEpochSyncTableTable extends GroupEpochSyncTable
    with TableInfo<$GroupEpochSyncTableTable, GroupEpochSyncEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GroupEpochSyncTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _operationIdMeta = const VerificationMeta(
    'operationId',
  );
  @override
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
    'operation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _memberPeerIdMeta = const VerificationMeta(
    'memberPeerId',
  );
  @override
  late final GeneratedColumn<String> memberPeerId = GeneratedColumn<String>(
    'member_peer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _prepareStatusMeta = const VerificationMeta(
    'prepareStatus',
  );
  @override
  late final GeneratedColumn<String> prepareStatus = GeneratedColumn<String>(
    'prepare_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _commitStatusMeta = const VerificationMeta(
    'commitStatus',
  );
  @override
  late final GeneratedColumn<String> commitStatus = GeneratedColumn<String>(
    'commit_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _finalizeStatusMeta = const VerificationMeta(
    'finalizeStatus',
  );
  @override
  late final GeneratedColumn<String> finalizeStatus = GeneratedColumn<String>(
    'finalize_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
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
    operationId,
    groupId,
    memberPeerId,
    prepareStatus,
    commitStatus,
    finalizeStatus,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'group_epoch_sync_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<GroupEpochSyncEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('operation_id')) {
      context.handle(
        _operationIdMeta,
        operationId.isAcceptableOrUnknown(
          data['operation_id']!,
          _operationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationIdMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('member_peer_id')) {
      context.handle(
        _memberPeerIdMeta,
        memberPeerId.isAcceptableOrUnknown(
          data['member_peer_id']!,
          _memberPeerIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_memberPeerIdMeta);
    }
    if (data.containsKey('prepare_status')) {
      context.handle(
        _prepareStatusMeta,
        prepareStatus.isAcceptableOrUnknown(
          data['prepare_status']!,
          _prepareStatusMeta,
        ),
      );
    }
    if (data.containsKey('commit_status')) {
      context.handle(
        _commitStatusMeta,
        commitStatus.isAcceptableOrUnknown(
          data['commit_status']!,
          _commitStatusMeta,
        ),
      );
    }
    if (data.containsKey('finalize_status')) {
      context.handle(
        _finalizeStatusMeta,
        finalizeStatus.isAcceptableOrUnknown(
          data['finalize_status']!,
          _finalizeStatusMeta,
        ),
      );
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
  Set<GeneratedColumn> get $primaryKey => {operationId, memberPeerId};
  @override
  GroupEpochSyncEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GroupEpochSyncEntry(
      operationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_id'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      )!,
      memberPeerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}member_peer_id'],
      )!,
      prepareStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prepare_status'],
      )!,
      commitStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}commit_status'],
      )!,
      finalizeStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}finalize_status'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $GroupEpochSyncTableTable createAlias(String alias) {
    return $GroupEpochSyncTableTable(attachedDatabase, alias);
  }
}

class GroupEpochSyncEntry extends DataClass
    implements Insertable<GroupEpochSyncEntry> {
  /// Operation identifier referencing group_epoch_operations_table.
  final String operationId;

  /// Group identifier referencing matching operation group.
  final String groupId;

  /// Peer device identifier of the group member.
  final String memberPeerId;

  /// Phase 1 prepare status: pending, acknowledged, failed.
  final String prepareStatus;

  /// Phase 2 commit status: pending, acknowledged, failed.
  final String commitStatus;

  /// Phase 3 finalize status: pending, acknowledged, failed.
  final String finalizeStatus;

  /// UTC last updated timestamp.
  final DateTime updatedAt;
  const GroupEpochSyncEntry({
    required this.operationId,
    required this.groupId,
    required this.memberPeerId,
    required this.prepareStatus,
    required this.commitStatus,
    required this.finalizeStatus,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['operation_id'] = Variable<String>(operationId);
    map['group_id'] = Variable<String>(groupId);
    map['member_peer_id'] = Variable<String>(memberPeerId);
    map['prepare_status'] = Variable<String>(prepareStatus);
    map['commit_status'] = Variable<String>(commitStatus);
    map['finalize_status'] = Variable<String>(finalizeStatus);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  GroupEpochSyncTableCompanion toCompanion(bool nullToAbsent) {
    return GroupEpochSyncTableCompanion(
      operationId: Value(operationId),
      groupId: Value(groupId),
      memberPeerId: Value(memberPeerId),
      prepareStatus: Value(prepareStatus),
      commitStatus: Value(commitStatus),
      finalizeStatus: Value(finalizeStatus),
      updatedAt: Value(updatedAt),
    );
  }

  factory GroupEpochSyncEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GroupEpochSyncEntry(
      operationId: serializer.fromJson<String>(json['operationId']),
      groupId: serializer.fromJson<String>(json['groupId']),
      memberPeerId: serializer.fromJson<String>(json['memberPeerId']),
      prepareStatus: serializer.fromJson<String>(json['prepareStatus']),
      commitStatus: serializer.fromJson<String>(json['commitStatus']),
      finalizeStatus: serializer.fromJson<String>(json['finalizeStatus']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'operationId': serializer.toJson<String>(operationId),
      'groupId': serializer.toJson<String>(groupId),
      'memberPeerId': serializer.toJson<String>(memberPeerId),
      'prepareStatus': serializer.toJson<String>(prepareStatus),
      'commitStatus': serializer.toJson<String>(commitStatus),
      'finalizeStatus': serializer.toJson<String>(finalizeStatus),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  GroupEpochSyncEntry copyWith({
    String? operationId,
    String? groupId,
    String? memberPeerId,
    String? prepareStatus,
    String? commitStatus,
    String? finalizeStatus,
    DateTime? updatedAt,
  }) => GroupEpochSyncEntry(
    operationId: operationId ?? this.operationId,
    groupId: groupId ?? this.groupId,
    memberPeerId: memberPeerId ?? this.memberPeerId,
    prepareStatus: prepareStatus ?? this.prepareStatus,
    commitStatus: commitStatus ?? this.commitStatus,
    finalizeStatus: finalizeStatus ?? this.finalizeStatus,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  GroupEpochSyncEntry copyWithCompanion(GroupEpochSyncTableCompanion data) {
    return GroupEpochSyncEntry(
      operationId: data.operationId.present
          ? data.operationId.value
          : this.operationId,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      memberPeerId: data.memberPeerId.present
          ? data.memberPeerId.value
          : this.memberPeerId,
      prepareStatus: data.prepareStatus.present
          ? data.prepareStatus.value
          : this.prepareStatus,
      commitStatus: data.commitStatus.present
          ? data.commitStatus.value
          : this.commitStatus,
      finalizeStatus: data.finalizeStatus.present
          ? data.finalizeStatus.value
          : this.finalizeStatus,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GroupEpochSyncEntry(')
          ..write('operationId: $operationId, ')
          ..write('groupId: $groupId, ')
          ..write('memberPeerId: $memberPeerId, ')
          ..write('prepareStatus: $prepareStatus, ')
          ..write('commitStatus: $commitStatus, ')
          ..write('finalizeStatus: $finalizeStatus, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    operationId,
    groupId,
    memberPeerId,
    prepareStatus,
    commitStatus,
    finalizeStatus,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GroupEpochSyncEntry &&
          other.operationId == this.operationId &&
          other.groupId == this.groupId &&
          other.memberPeerId == this.memberPeerId &&
          other.prepareStatus == this.prepareStatus &&
          other.commitStatus == this.commitStatus &&
          other.finalizeStatus == this.finalizeStatus &&
          other.updatedAt == this.updatedAt);
}

class GroupEpochSyncTableCompanion
    extends UpdateCompanion<GroupEpochSyncEntry> {
  final Value<String> operationId;
  final Value<String> groupId;
  final Value<String> memberPeerId;
  final Value<String> prepareStatus;
  final Value<String> commitStatus;
  final Value<String> finalizeStatus;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const GroupEpochSyncTableCompanion({
    this.operationId = const Value.absent(),
    this.groupId = const Value.absent(),
    this.memberPeerId = const Value.absent(),
    this.prepareStatus = const Value.absent(),
    this.commitStatus = const Value.absent(),
    this.finalizeStatus = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GroupEpochSyncTableCompanion.insert({
    required String operationId,
    required String groupId,
    required String memberPeerId,
    this.prepareStatus = const Value.absent(),
    this.commitStatus = const Value.absent(),
    this.finalizeStatus = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : operationId = Value(operationId),
       groupId = Value(groupId),
       memberPeerId = Value(memberPeerId),
       updatedAt = Value(updatedAt);
  static Insertable<GroupEpochSyncEntry> custom({
    Expression<String>? operationId,
    Expression<String>? groupId,
    Expression<String>? memberPeerId,
    Expression<String>? prepareStatus,
    Expression<String>? commitStatus,
    Expression<String>? finalizeStatus,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (operationId != null) 'operation_id': operationId,
      if (groupId != null) 'group_id': groupId,
      if (memberPeerId != null) 'member_peer_id': memberPeerId,
      if (prepareStatus != null) 'prepare_status': prepareStatus,
      if (commitStatus != null) 'commit_status': commitStatus,
      if (finalizeStatus != null) 'finalize_status': finalizeStatus,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GroupEpochSyncTableCompanion copyWith({
    Value<String>? operationId,
    Value<String>? groupId,
    Value<String>? memberPeerId,
    Value<String>? prepareStatus,
    Value<String>? commitStatus,
    Value<String>? finalizeStatus,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return GroupEpochSyncTableCompanion(
      operationId: operationId ?? this.operationId,
      groupId: groupId ?? this.groupId,
      memberPeerId: memberPeerId ?? this.memberPeerId,
      prepareStatus: prepareStatus ?? this.prepareStatus,
      commitStatus: commitStatus ?? this.commitStatus,
      finalizeStatus: finalizeStatus ?? this.finalizeStatus,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (memberPeerId.present) {
      map['member_peer_id'] = Variable<String>(memberPeerId.value);
    }
    if (prepareStatus.present) {
      map['prepare_status'] = Variable<String>(prepareStatus.value);
    }
    if (commitStatus.present) {
      map['commit_status'] = Variable<String>(commitStatus.value);
    }
    if (finalizeStatus.present) {
      map['finalize_status'] = Variable<String>(finalizeStatus.value);
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
    return (StringBuffer('GroupEpochSyncTableCompanion(')
          ..write('operationId: $operationId, ')
          ..write('groupId: $groupId, ')
          ..write('memberPeerId: $memberPeerId, ')
          ..write('prepareStatus: $prepareStatus, ')
          ..write('commitStatus: $commitStatus, ')
          ..write('finalizeStatus: $finalizeStatus, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GroupMessagePayloadsTableTable extends GroupMessagePayloadsTable
    with TableInfo<$GroupMessagePayloadsTableTable, GroupMessagePayloadEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GroupMessagePayloadsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL REFERENCES groups_table(group_id) ON DELETE CASCADE',
  );
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
  static const VerificationMeta _encryptedPayloadMeta = const VerificationMeta(
    'encryptedPayload',
  );
  @override
  late final GeneratedColumn<Uint8List> encryptedPayload =
      GeneratedColumn<Uint8List>(
        'encrypted_payload',
        aliasedName,
        false,
        type: DriftSqlType.blob,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _nonceMeta = const VerificationMeta('nonce');
  @override
  late final GeneratedColumn<Uint8List> nonce = GeneratedColumn<Uint8List>(
    'nonce',
    aliasedName,
    false,
    type: DriftSqlType.blob,
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
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
    'expires_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    groupId,
    messageId,
    encryptedPayload,
    nonce,
    createdAt,
    expiresAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'group_message_payloads_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<GroupMessagePayloadEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('encrypted_payload')) {
      context.handle(
        _encryptedPayloadMeta,
        encryptedPayload.isAcceptableOrUnknown(
          data['encrypted_payload']!,
          _encryptedPayloadMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_encryptedPayloadMeta);
    }
    if (data.containsKey('nonce')) {
      context.handle(
        _nonceMeta,
        nonce.isAcceptableOrUnknown(data['nonce']!, _nonceMeta),
      );
    } else if (isInserting) {
      context.missing(_nonceMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {groupId, messageId};
  @override
  GroupMessagePayloadEntry map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GroupMessagePayloadEntry(
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      )!,
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id'],
      )!,
      encryptedPayload: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}encrypted_payload'],
      )!,
      nonce: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}nonce'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expires_at'],
      ),
    );
  }

  @override
  $GroupMessagePayloadsTableTable createAlias(String alias) {
    return $GroupMessagePayloadsTableTable(attachedDatabase, alias);
  }
}

class GroupMessagePayloadEntry extends DataClass
    implements Insertable<GroupMessagePayloadEntry> {
  /// Target group identifier, referencing GroupsTable.
  final String groupId;

  /// Unique message identifier.
  final String messageId;

  /// Binary encrypted-at-rest payload (never plaintext).
  final Uint8List encryptedPayload;

  /// Binary initialization vector / nonce used for local AEAD encryption.
  final Uint8List nonce;

  /// UTC creation timestamp.
  final DateTime createdAt;

  /// Optional UTC expiration timestamp for retention pruning.
  final DateTime? expiresAt;
  const GroupMessagePayloadEntry({
    required this.groupId,
    required this.messageId,
    required this.encryptedPayload,
    required this.nonce,
    required this.createdAt,
    this.expiresAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['group_id'] = Variable<String>(groupId);
    map['message_id'] = Variable<String>(messageId);
    map['encrypted_payload'] = Variable<Uint8List>(encryptedPayload);
    map['nonce'] = Variable<Uint8List>(nonce);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || expiresAt != null) {
      map['expires_at'] = Variable<DateTime>(expiresAt);
    }
    return map;
  }

  GroupMessagePayloadsTableCompanion toCompanion(bool nullToAbsent) {
    return GroupMessagePayloadsTableCompanion(
      groupId: Value(groupId),
      messageId: Value(messageId),
      encryptedPayload: Value(encryptedPayload),
      nonce: Value(nonce),
      createdAt: Value(createdAt),
      expiresAt: expiresAt == null && nullToAbsent
          ? const Value.absent()
          : Value(expiresAt),
    );
  }

  factory GroupMessagePayloadEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GroupMessagePayloadEntry(
      groupId: serializer.fromJson<String>(json['groupId']),
      messageId: serializer.fromJson<String>(json['messageId']),
      encryptedPayload: serializer.fromJson<Uint8List>(
        json['encryptedPayload'],
      ),
      nonce: serializer.fromJson<Uint8List>(json['nonce']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      expiresAt: serializer.fromJson<DateTime?>(json['expiresAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'groupId': serializer.toJson<String>(groupId),
      'messageId': serializer.toJson<String>(messageId),
      'encryptedPayload': serializer.toJson<Uint8List>(encryptedPayload),
      'nonce': serializer.toJson<Uint8List>(nonce),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'expiresAt': serializer.toJson<DateTime?>(expiresAt),
    };
  }

  GroupMessagePayloadEntry copyWith({
    String? groupId,
    String? messageId,
    Uint8List? encryptedPayload,
    Uint8List? nonce,
    DateTime? createdAt,
    Value<DateTime?> expiresAt = const Value.absent(),
  }) => GroupMessagePayloadEntry(
    groupId: groupId ?? this.groupId,
    messageId: messageId ?? this.messageId,
    encryptedPayload: encryptedPayload ?? this.encryptedPayload,
    nonce: nonce ?? this.nonce,
    createdAt: createdAt ?? this.createdAt,
    expiresAt: expiresAt.present ? expiresAt.value : this.expiresAt,
  );
  GroupMessagePayloadEntry copyWithCompanion(
    GroupMessagePayloadsTableCompanion data,
  ) {
    return GroupMessagePayloadEntry(
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      encryptedPayload: data.encryptedPayload.present
          ? data.encryptedPayload.value
          : this.encryptedPayload,
      nonce: data.nonce.present ? data.nonce.value : this.nonce,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GroupMessagePayloadEntry(')
          ..write('groupId: $groupId, ')
          ..write('messageId: $messageId, ')
          ..write('encryptedPayload: $encryptedPayload, ')
          ..write('nonce: $nonce, ')
          ..write('createdAt: $createdAt, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    groupId,
    messageId,
    $driftBlobEquality.hash(encryptedPayload),
    $driftBlobEquality.hash(nonce),
    createdAt,
    expiresAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GroupMessagePayloadEntry &&
          other.groupId == this.groupId &&
          other.messageId == this.messageId &&
          $driftBlobEquality.equals(
            other.encryptedPayload,
            this.encryptedPayload,
          ) &&
          $driftBlobEquality.equals(other.nonce, this.nonce) &&
          other.createdAt == this.createdAt &&
          other.expiresAt == this.expiresAt);
}

class GroupMessagePayloadsTableCompanion
    extends UpdateCompanion<GroupMessagePayloadEntry> {
  final Value<String> groupId;
  final Value<String> messageId;
  final Value<Uint8List> encryptedPayload;
  final Value<Uint8List> nonce;
  final Value<DateTime> createdAt;
  final Value<DateTime?> expiresAt;
  final Value<int> rowid;
  const GroupMessagePayloadsTableCompanion({
    this.groupId = const Value.absent(),
    this.messageId = const Value.absent(),
    this.encryptedPayload = const Value.absent(),
    this.nonce = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GroupMessagePayloadsTableCompanion.insert({
    required String groupId,
    required String messageId,
    required Uint8List encryptedPayload,
    required Uint8List nonce,
    required DateTime createdAt,
    this.expiresAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : groupId = Value(groupId),
       messageId = Value(messageId),
       encryptedPayload = Value(encryptedPayload),
       nonce = Value(nonce),
       createdAt = Value(createdAt);
  static Insertable<GroupMessagePayloadEntry> custom({
    Expression<String>? groupId,
    Expression<String>? messageId,
    Expression<Uint8List>? encryptedPayload,
    Expression<Uint8List>? nonce,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? expiresAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (groupId != null) 'group_id': groupId,
      if (messageId != null) 'message_id': messageId,
      if (encryptedPayload != null) 'encrypted_payload': encryptedPayload,
      if (nonce != null) 'nonce': nonce,
      if (createdAt != null) 'created_at': createdAt,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GroupMessagePayloadsTableCompanion copyWith({
    Value<String>? groupId,
    Value<String>? messageId,
    Value<Uint8List>? encryptedPayload,
    Value<Uint8List>? nonce,
    Value<DateTime>? createdAt,
    Value<DateTime?>? expiresAt,
    Value<int>? rowid,
  }) {
    return GroupMessagePayloadsTableCompanion(
      groupId: groupId ?? this.groupId,
      messageId: messageId ?? this.messageId,
      encryptedPayload: encryptedPayload ?? this.encryptedPayload,
      nonce: nonce ?? this.nonce,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (encryptedPayload.present) {
      map['encrypted_payload'] = Variable<Uint8List>(encryptedPayload.value);
    }
    if (nonce.present) {
      map['nonce'] = Variable<Uint8List>(nonce.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GroupMessagePayloadsTableCompanion(')
          ..write('groupId: $groupId, ')
          ..write('messageId: $messageId, ')
          ..write('encryptedPayload: $encryptedPayload, ')
          ..write('nonce: $nonce, ')
          ..write('createdAt: $createdAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GroupDeliveryQueueTableTable extends GroupDeliveryQueueTable
    with TableInfo<$GroupDeliveryQueueTableTable, GroupDeliveryQueueEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GroupDeliveryQueueTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _queueIdMeta = const VerificationMeta(
    'queueId',
  );
  @override
  late final GeneratedColumn<int> queueId = GeneratedColumn<int>(
    'queue_id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
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
  static const VerificationMeta _recipientPeerIdMeta = const VerificationMeta(
    'recipientPeerId',
  );
  @override
  late final GeneratedColumn<String> recipientPeerId = GeneratedColumn<String>(
    'recipient_peer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _epochMeta = const VerificationMeta('epoch');
  @override
  late final GeneratedColumn<int> epoch = GeneratedColumn<int>(
    'epoch',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _encryptedEnvelopeJsonMeta =
      const VerificationMeta('encryptedEnvelopeJson');
  @override
  late final GeneratedColumn<String> encryptedEnvelopeJson =
      GeneratedColumn<String>(
        'encrypted_envelope_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _failureReasonMeta = const VerificationMeta(
    'failureReason',
  );
  @override
  late final GeneratedColumn<String> failureReason = GeneratedColumn<String>(
    'failure_reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _nextRetryAtMeta = const VerificationMeta(
    'nextRetryAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextRetryAt = GeneratedColumn<DateTime>(
    'next_retry_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
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
    queueId,
    groupId,
    messageId,
    recipientPeerId,
    epoch,
    packetType,
    sessionId,
    encryptedEnvelopeJson,
    status,
    failureReason,
    retryCount,
    nextRetryAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'group_delivery_queue_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<GroupDeliveryQueueEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('queue_id')) {
      context.handle(
        _queueIdMeta,
        queueId.isAcceptableOrUnknown(data['queue_id']!, _queueIdMeta),
      );
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('recipient_peer_id')) {
      context.handle(
        _recipientPeerIdMeta,
        recipientPeerId.isAcceptableOrUnknown(
          data['recipient_peer_id']!,
          _recipientPeerIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_recipientPeerIdMeta);
    }
    if (data.containsKey('epoch')) {
      context.handle(
        _epochMeta,
        epoch.isAcceptableOrUnknown(data['epoch']!, _epochMeta),
      );
    } else if (isInserting) {
      context.missing(_epochMeta);
    }
    if (data.containsKey('packet_type')) {
      context.handle(
        _packetTypeMeta,
        packetType.isAcceptableOrUnknown(data['packet_type']!, _packetTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_packetTypeMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    }
    if (data.containsKey('encrypted_envelope_json')) {
      context.handle(
        _encryptedEnvelopeJsonMeta,
        encryptedEnvelopeJson.isAcceptableOrUnknown(
          data['encrypted_envelope_json']!,
          _encryptedEnvelopeJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_encryptedEnvelopeJsonMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('failure_reason')) {
      context.handle(
        _failureReasonMeta,
        failureReason.isAcceptableOrUnknown(
          data['failure_reason']!,
          _failureReasonMeta,
        ),
      );
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    if (data.containsKey('next_retry_at')) {
      context.handle(
        _nextRetryAtMeta,
        nextRetryAt.isAcceptableOrUnknown(
          data['next_retry_at']!,
          _nextRetryAtMeta,
        ),
      );
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
  Set<GeneratedColumn> get $primaryKey => {queueId};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {groupId, recipientPeerId, messageId},
  ];
  @override
  GroupDeliveryQueueEntry map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GroupDeliveryQueueEntry(
      queueId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}queue_id'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      )!,
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id'],
      )!,
      recipientPeerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recipient_peer_id'],
      )!,
      epoch: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}epoch'],
      )!,
      packetType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}packet_type'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      ),
      encryptedEnvelopeJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}encrypted_envelope_json'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      failureReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}failure_reason'],
      ),
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      nextRetryAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_retry_at'],
      ),
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
  $GroupDeliveryQueueTableTable createAlias(String alias) {
    return $GroupDeliveryQueueTableTable(attachedDatabase, alias);
  }
}

class GroupDeliveryQueueEntry extends DataClass
    implements Insertable<GroupDeliveryQueueEntry> {
  /// Unique queue record auto-incrementing identifier.
  final int queueId;

  /// Group identifier.
  final String groupId;

  /// Unique message identifier.
  final String messageId;

  /// Peer device identifier of recipient.
  final String recipientPeerId;

  /// Group epoch at the time of encryption.
  final int epoch;

  /// Packet type discriminator (e.g. group_message).
  final String packetType;

  /// Active pairwise session identifier (nullable if not yet connected).
  final String? sessionId;

  /// Recipient-specific encrypted wire envelope JSON (never plaintext message content).
  final String encryptedEnvelopeJson;

  /// Delivery lifecycle status.
  final String status;

  /// Failure reason discriminator (nullable).
  final String? failureReason;

  /// Number of transmission retries attempted.
  final int retryCount;

  /// Next eligible delivery attempt timestamp (UTC).
  final DateTime? nextRetryAt;

  /// UTC creation timestamp.
  final DateTime createdAt;

  /// UTC last updated timestamp.
  final DateTime updatedAt;
  const GroupDeliveryQueueEntry({
    required this.queueId,
    required this.groupId,
    required this.messageId,
    required this.recipientPeerId,
    required this.epoch,
    required this.packetType,
    this.sessionId,
    required this.encryptedEnvelopeJson,
    required this.status,
    this.failureReason,
    required this.retryCount,
    this.nextRetryAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['queue_id'] = Variable<int>(queueId);
    map['group_id'] = Variable<String>(groupId);
    map['message_id'] = Variable<String>(messageId);
    map['recipient_peer_id'] = Variable<String>(recipientPeerId);
    map['epoch'] = Variable<int>(epoch);
    map['packet_type'] = Variable<String>(packetType);
    if (!nullToAbsent || sessionId != null) {
      map['session_id'] = Variable<String>(sessionId);
    }
    map['encrypted_envelope_json'] = Variable<String>(encryptedEnvelopeJson);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || failureReason != null) {
      map['failure_reason'] = Variable<String>(failureReason);
    }
    map['retry_count'] = Variable<int>(retryCount);
    if (!nullToAbsent || nextRetryAt != null) {
      map['next_retry_at'] = Variable<DateTime>(nextRetryAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  GroupDeliveryQueueTableCompanion toCompanion(bool nullToAbsent) {
    return GroupDeliveryQueueTableCompanion(
      queueId: Value(queueId),
      groupId: Value(groupId),
      messageId: Value(messageId),
      recipientPeerId: Value(recipientPeerId),
      epoch: Value(epoch),
      packetType: Value(packetType),
      sessionId: sessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(sessionId),
      encryptedEnvelopeJson: Value(encryptedEnvelopeJson),
      status: Value(status),
      failureReason: failureReason == null && nullToAbsent
          ? const Value.absent()
          : Value(failureReason),
      retryCount: Value(retryCount),
      nextRetryAt: nextRetryAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextRetryAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory GroupDeliveryQueueEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GroupDeliveryQueueEntry(
      queueId: serializer.fromJson<int>(json['queueId']),
      groupId: serializer.fromJson<String>(json['groupId']),
      messageId: serializer.fromJson<String>(json['messageId']),
      recipientPeerId: serializer.fromJson<String>(json['recipientPeerId']),
      epoch: serializer.fromJson<int>(json['epoch']),
      packetType: serializer.fromJson<String>(json['packetType']),
      sessionId: serializer.fromJson<String?>(json['sessionId']),
      encryptedEnvelopeJson: serializer.fromJson<String>(
        json['encryptedEnvelopeJson'],
      ),
      status: serializer.fromJson<String>(json['status']),
      failureReason: serializer.fromJson<String?>(json['failureReason']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      nextRetryAt: serializer.fromJson<DateTime?>(json['nextRetryAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'queueId': serializer.toJson<int>(queueId),
      'groupId': serializer.toJson<String>(groupId),
      'messageId': serializer.toJson<String>(messageId),
      'recipientPeerId': serializer.toJson<String>(recipientPeerId),
      'epoch': serializer.toJson<int>(epoch),
      'packetType': serializer.toJson<String>(packetType),
      'sessionId': serializer.toJson<String?>(sessionId),
      'encryptedEnvelopeJson': serializer.toJson<String>(encryptedEnvelopeJson),
      'status': serializer.toJson<String>(status),
      'failureReason': serializer.toJson<String?>(failureReason),
      'retryCount': serializer.toJson<int>(retryCount),
      'nextRetryAt': serializer.toJson<DateTime?>(nextRetryAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  GroupDeliveryQueueEntry copyWith({
    int? queueId,
    String? groupId,
    String? messageId,
    String? recipientPeerId,
    int? epoch,
    String? packetType,
    Value<String?> sessionId = const Value.absent(),
    String? encryptedEnvelopeJson,
    String? status,
    Value<String?> failureReason = const Value.absent(),
    int? retryCount,
    Value<DateTime?> nextRetryAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => GroupDeliveryQueueEntry(
    queueId: queueId ?? this.queueId,
    groupId: groupId ?? this.groupId,
    messageId: messageId ?? this.messageId,
    recipientPeerId: recipientPeerId ?? this.recipientPeerId,
    epoch: epoch ?? this.epoch,
    packetType: packetType ?? this.packetType,
    sessionId: sessionId.present ? sessionId.value : this.sessionId,
    encryptedEnvelopeJson: encryptedEnvelopeJson ?? this.encryptedEnvelopeJson,
    status: status ?? this.status,
    failureReason: failureReason.present
        ? failureReason.value
        : this.failureReason,
    retryCount: retryCount ?? this.retryCount,
    nextRetryAt: nextRetryAt.present ? nextRetryAt.value : this.nextRetryAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  GroupDeliveryQueueEntry copyWithCompanion(
    GroupDeliveryQueueTableCompanion data,
  ) {
    return GroupDeliveryQueueEntry(
      queueId: data.queueId.present ? data.queueId.value : this.queueId,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      recipientPeerId: data.recipientPeerId.present
          ? data.recipientPeerId.value
          : this.recipientPeerId,
      epoch: data.epoch.present ? data.epoch.value : this.epoch,
      packetType: data.packetType.present
          ? data.packetType.value
          : this.packetType,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      encryptedEnvelopeJson: data.encryptedEnvelopeJson.present
          ? data.encryptedEnvelopeJson.value
          : this.encryptedEnvelopeJson,
      status: data.status.present ? data.status.value : this.status,
      failureReason: data.failureReason.present
          ? data.failureReason.value
          : this.failureReason,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      nextRetryAt: data.nextRetryAt.present
          ? data.nextRetryAt.value
          : this.nextRetryAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GroupDeliveryQueueEntry(')
          ..write('queueId: $queueId, ')
          ..write('groupId: $groupId, ')
          ..write('messageId: $messageId, ')
          ..write('recipientPeerId: $recipientPeerId, ')
          ..write('epoch: $epoch, ')
          ..write('packetType: $packetType, ')
          ..write('sessionId: $sessionId, ')
          ..write('encryptedEnvelopeJson: $encryptedEnvelopeJson, ')
          ..write('status: $status, ')
          ..write('failureReason: $failureReason, ')
          ..write('retryCount: $retryCount, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    queueId,
    groupId,
    messageId,
    recipientPeerId,
    epoch,
    packetType,
    sessionId,
    encryptedEnvelopeJson,
    status,
    failureReason,
    retryCount,
    nextRetryAt,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GroupDeliveryQueueEntry &&
          other.queueId == this.queueId &&
          other.groupId == this.groupId &&
          other.messageId == this.messageId &&
          other.recipientPeerId == this.recipientPeerId &&
          other.epoch == this.epoch &&
          other.packetType == this.packetType &&
          other.sessionId == this.sessionId &&
          other.encryptedEnvelopeJson == this.encryptedEnvelopeJson &&
          other.status == this.status &&
          other.failureReason == this.failureReason &&
          other.retryCount == this.retryCount &&
          other.nextRetryAt == this.nextRetryAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class GroupDeliveryQueueTableCompanion
    extends UpdateCompanion<GroupDeliveryQueueEntry> {
  final Value<int> queueId;
  final Value<String> groupId;
  final Value<String> messageId;
  final Value<String> recipientPeerId;
  final Value<int> epoch;
  final Value<String> packetType;
  final Value<String?> sessionId;
  final Value<String> encryptedEnvelopeJson;
  final Value<String> status;
  final Value<String?> failureReason;
  final Value<int> retryCount;
  final Value<DateTime?> nextRetryAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const GroupDeliveryQueueTableCompanion({
    this.queueId = const Value.absent(),
    this.groupId = const Value.absent(),
    this.messageId = const Value.absent(),
    this.recipientPeerId = const Value.absent(),
    this.epoch = const Value.absent(),
    this.packetType = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.encryptedEnvelopeJson = const Value.absent(),
    this.status = const Value.absent(),
    this.failureReason = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  GroupDeliveryQueueTableCompanion.insert({
    this.queueId = const Value.absent(),
    required String groupId,
    required String messageId,
    required String recipientPeerId,
    required int epoch,
    required String packetType,
    this.sessionId = const Value.absent(),
    required String encryptedEnvelopeJson,
    this.status = const Value.absent(),
    this.failureReason = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : groupId = Value(groupId),
       messageId = Value(messageId),
       recipientPeerId = Value(recipientPeerId),
       epoch = Value(epoch),
       packetType = Value(packetType),
       encryptedEnvelopeJson = Value(encryptedEnvelopeJson),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<GroupDeliveryQueueEntry> custom({
    Expression<int>? queueId,
    Expression<String>? groupId,
    Expression<String>? messageId,
    Expression<String>? recipientPeerId,
    Expression<int>? epoch,
    Expression<String>? packetType,
    Expression<String>? sessionId,
    Expression<String>? encryptedEnvelopeJson,
    Expression<String>? status,
    Expression<String>? failureReason,
    Expression<int>? retryCount,
    Expression<DateTime>? nextRetryAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (queueId != null) 'queue_id': queueId,
      if (groupId != null) 'group_id': groupId,
      if (messageId != null) 'message_id': messageId,
      if (recipientPeerId != null) 'recipient_peer_id': recipientPeerId,
      if (epoch != null) 'epoch': epoch,
      if (packetType != null) 'packet_type': packetType,
      if (sessionId != null) 'session_id': sessionId,
      if (encryptedEnvelopeJson != null)
        'encrypted_envelope_json': encryptedEnvelopeJson,
      if (status != null) 'status': status,
      if (failureReason != null) 'failure_reason': failureReason,
      if (retryCount != null) 'retry_count': retryCount,
      if (nextRetryAt != null) 'next_retry_at': nextRetryAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  GroupDeliveryQueueTableCompanion copyWith({
    Value<int>? queueId,
    Value<String>? groupId,
    Value<String>? messageId,
    Value<String>? recipientPeerId,
    Value<int>? epoch,
    Value<String>? packetType,
    Value<String?>? sessionId,
    Value<String>? encryptedEnvelopeJson,
    Value<String>? status,
    Value<String?>? failureReason,
    Value<int>? retryCount,
    Value<DateTime?>? nextRetryAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return GroupDeliveryQueueTableCompanion(
      queueId: queueId ?? this.queueId,
      groupId: groupId ?? this.groupId,
      messageId: messageId ?? this.messageId,
      recipientPeerId: recipientPeerId ?? this.recipientPeerId,
      epoch: epoch ?? this.epoch,
      packetType: packetType ?? this.packetType,
      sessionId: sessionId ?? this.sessionId,
      encryptedEnvelopeJson:
          encryptedEnvelopeJson ?? this.encryptedEnvelopeJson,
      status: status ?? this.status,
      failureReason: failureReason ?? this.failureReason,
      retryCount: retryCount ?? this.retryCount,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (queueId.present) {
      map['queue_id'] = Variable<int>(queueId.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (recipientPeerId.present) {
      map['recipient_peer_id'] = Variable<String>(recipientPeerId.value);
    }
    if (epoch.present) {
      map['epoch'] = Variable<int>(epoch.value);
    }
    if (packetType.present) {
      map['packet_type'] = Variable<String>(packetType.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (encryptedEnvelopeJson.present) {
      map['encrypted_envelope_json'] = Variable<String>(
        encryptedEnvelopeJson.value,
      );
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (failureReason.present) {
      map['failure_reason'] = Variable<String>(failureReason.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (nextRetryAt.present) {
      map['next_retry_at'] = Variable<DateTime>(nextRetryAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GroupDeliveryQueueTableCompanion(')
          ..write('queueId: $queueId, ')
          ..write('groupId: $groupId, ')
          ..write('messageId: $messageId, ')
          ..write('recipientPeerId: $recipientPeerId, ')
          ..write('epoch: $epoch, ')
          ..write('packetType: $packetType, ')
          ..write('sessionId: $sessionId, ')
          ..write('encryptedEnvelopeJson: $encryptedEnvelopeJson, ')
          ..write('status: $status, ')
          ..write('failureReason: $failureReason, ')
          ..write('retryCount: $retryCount, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
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
  late final $GroupsTableTable groupsTable = $GroupsTableTable(this);
  late final $GroupMembersTableTable groupMembersTable =
      $GroupMembersTableTable(this);
  late final $GroupEpochOperationsTableTable groupEpochOperationsTable =
      $GroupEpochOperationsTableTable(this);
  late final $GroupEpochSyncTableTable groupEpochSyncTable =
      $GroupEpochSyncTableTable(this);
  late final $GroupMessagePayloadsTableTable groupMessagePayloadsTable =
      $GroupMessagePayloadsTableTable(this);
  late final $GroupDeliveryQueueTableTable groupDeliveryQueueTable =
      $GroupDeliveryQueueTableTable(this);
  late final Index idxEpochOpsGroupId = Index(
    'idx_epoch_ops_group_id',
    'CREATE INDEX idx_epoch_ops_group_id ON group_epoch_operations_table (group_id)',
  );
  late final Index idxEpochOpsStatus = Index(
    'idx_epoch_ops_status',
    'CREATE INDEX idx_epoch_ops_status ON group_epoch_operations_table (operation_status)',
  );
  late final Index idxEpochOpsGroupSeq = Index(
    'idx_epoch_ops_group_seq',
    'CREATE INDEX idx_epoch_ops_group_seq ON group_epoch_operations_table (group_id, operation_sequence_number)',
  );
  late final Index idxEpochSyncGroupMember = Index(
    'idx_epoch_sync_group_member',
    'CREATE INDEX idx_epoch_sync_group_member ON group_epoch_sync_table (group_id, member_peer_id)',
  );
  late final Index idxEpochSyncPrepare = Index(
    'idx_epoch_sync_prepare',
    'CREATE INDEX idx_epoch_sync_prepare ON group_epoch_sync_table (operation_id, prepare_status)',
  );
  late final Index idxEpochSyncCommit = Index(
    'idx_epoch_sync_commit',
    'CREATE INDEX idx_epoch_sync_commit ON group_epoch_sync_table (operation_id, commit_status)',
  );
  late final Index idxEpochSyncFinalize = Index(
    'idx_epoch_sync_finalize',
    'CREATE INDEX idx_epoch_sync_finalize ON group_epoch_sync_table (operation_id, finalize_status)',
  );
  late final Index idxPayloadsCreatedAt = Index(
    'idx_payloads_created_at',
    'CREATE INDEX idx_payloads_created_at ON group_message_payloads_table (created_at)',
  );
  late final Index idxPayloadsExpiresAt = Index(
    'idx_payloads_expires_at',
    'CREATE INDEX idx_payloads_expires_at ON group_message_payloads_table (expires_at)',
  );
  late final Index idxGroupQueueRecipientStatus = Index(
    'idx_group_queue_recipient_status',
    'CREATE INDEX idx_group_queue_recipient_status ON group_delivery_queue_table (recipient_peer_id, status)',
  );
  late final Index idxGroupQueueGroupEpoch = Index(
    'idx_group_queue_group_epoch',
    'CREATE INDEX idx_group_queue_group_epoch ON group_delivery_queue_table (group_id, epoch)',
  );
  late final Index idxGroupQueueRetry = Index(
    'idx_group_queue_retry',
    'CREATE INDEX idx_group_queue_retry ON group_delivery_queue_table (status, next_retry_at)',
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
    groupsTable,
    groupMembersTable,
    groupEpochOperationsTable,
    groupEpochSyncTable,
    groupMessagePayloadsTable,
    groupDeliveryQueueTable,
    idxEpochOpsGroupId,
    idxEpochOpsStatus,
    idxEpochOpsGroupSeq,
    idxEpochSyncGroupMember,
    idxEpochSyncPrepare,
    idxEpochSyncCommit,
    idxEpochSyncFinalize,
    idxPayloadsCreatedAt,
    idxPayloadsExpiresAt,
    idxGroupQueueRecipientStatus,
    idxGroupQueueGroupEpoch,
    idxGroupQueueRetry,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'groups_table',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('group_members_table', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'groups_table',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [
        TableUpdate('group_epoch_operations_table', kind: UpdateKind.delete),
      ],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'groups_table',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [
        TableUpdate('group_message_payloads_table', kind: UpdateKind.delete),
      ],
    ),
  ]);
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
typedef $$GroupsTableTableCreateCompanionBuilder =
    GroupsTableCompanion Function({
      required String groupId,
      required String name,
      required String creatorId,
      required String adminId,
      Value<int> epoch,
      Value<bool> isReEpochPending,
      Value<String?> activeReEpochOperationId,
      Value<int?> preparedEpoch,
      Value<int> operationSequenceNumber,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$GroupsTableTableUpdateCompanionBuilder =
    GroupsTableCompanion Function({
      Value<String> groupId,
      Value<String> name,
      Value<String> creatorId,
      Value<String> adminId,
      Value<int> epoch,
      Value<bool> isReEpochPending,
      Value<String?> activeReEpochOperationId,
      Value<int?> preparedEpoch,
      Value<int> operationSequenceNumber,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$GroupsTableTableReferences
    extends BaseReferences<_$AppDatabase, $GroupsTableTable, GroupEntry> {
  $$GroupsTableTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$GroupMembersTableTable, List<GroupMemberEntry>>
  _groupMembersTableRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.groupMembersTable,
        aliasName: $_aliasNameGenerator(
          db.groupsTable.groupId,
          db.groupMembersTable.groupId,
        ),
      );

  $$GroupMembersTableTableProcessedTableManager get groupMembersTableRefs {
    final manager =
        $$GroupMembersTableTableTableManager(
          $_db,
          $_db.groupMembersTable,
        ).filter(
          (f) => f.groupId.groupId.sqlEquals($_itemColumn<String>('group_id')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _groupMembersTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $GroupEpochOperationsTableTable,
    List<GroupEpochOperationEntry>
  >
  _groupEpochOperationsTableRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.groupEpochOperationsTable,
        aliasName: $_aliasNameGenerator(
          db.groupsTable.groupId,
          db.groupEpochOperationsTable.groupId,
        ),
      );

  $$GroupEpochOperationsTableTableProcessedTableManager
  get groupEpochOperationsTableRefs {
    final manager =
        $$GroupEpochOperationsTableTableTableManager(
          $_db,
          $_db.groupEpochOperationsTable,
        ).filter(
          (f) => f.groupId.groupId.sqlEquals($_itemColumn<String>('group_id')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _groupEpochOperationsTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $GroupMessagePayloadsTableTable,
    List<GroupMessagePayloadEntry>
  >
  _groupMessagePayloadsTableRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.groupMessagePayloadsTable,
        aliasName: $_aliasNameGenerator(
          db.groupsTable.groupId,
          db.groupMessagePayloadsTable.groupId,
        ),
      );

  $$GroupMessagePayloadsTableTableProcessedTableManager
  get groupMessagePayloadsTableRefs {
    final manager =
        $$GroupMessagePayloadsTableTableTableManager(
          $_db,
          $_db.groupMessagePayloadsTable,
        ).filter(
          (f) => f.groupId.groupId.sqlEquals($_itemColumn<String>('group_id')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _groupMessagePayloadsTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$GroupsTableTableFilterComposer
    extends Composer<_$AppDatabase, $GroupsTableTable> {
  $$GroupsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get creatorId => $composableBuilder(
    column: $table.creatorId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get adminId => $composableBuilder(
    column: $table.adminId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get epoch => $composableBuilder(
    column: $table.epoch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isReEpochPending => $composableBuilder(
    column: $table.isReEpochPending,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activeReEpochOperationId => $composableBuilder(
    column: $table.activeReEpochOperationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get preparedEpoch => $composableBuilder(
    column: $table.preparedEpoch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get operationSequenceNumber => $composableBuilder(
    column: $table.operationSequenceNumber,
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

  Expression<bool> groupMembersTableRefs(
    Expression<bool> Function($$GroupMembersTableTableFilterComposer f) f,
  ) {
    final $$GroupMembersTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.groupMembersTable,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupMembersTableTableFilterComposer(
            $db: $db,
            $table: $db.groupMembersTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> groupEpochOperationsTableRefs(
    Expression<bool> Function($$GroupEpochOperationsTableTableFilterComposer f)
    f,
  ) {
    final $$GroupEpochOperationsTableTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.groupId,
          referencedTable: $db.groupEpochOperationsTable,
          getReferencedColumn: (t) => t.groupId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$GroupEpochOperationsTableTableFilterComposer(
                $db: $db,
                $table: $db.groupEpochOperationsTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> groupMessagePayloadsTableRefs(
    Expression<bool> Function($$GroupMessagePayloadsTableTableFilterComposer f)
    f,
  ) {
    final $$GroupMessagePayloadsTableTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.groupId,
          referencedTable: $db.groupMessagePayloadsTable,
          getReferencedColumn: (t) => t.groupId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$GroupMessagePayloadsTableTableFilterComposer(
                $db: $db,
                $table: $db.groupMessagePayloadsTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$GroupsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $GroupsTableTable> {
  $$GroupsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get creatorId => $composableBuilder(
    column: $table.creatorId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get adminId => $composableBuilder(
    column: $table.adminId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get epoch => $composableBuilder(
    column: $table.epoch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isReEpochPending => $composableBuilder(
    column: $table.isReEpochPending,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activeReEpochOperationId => $composableBuilder(
    column: $table.activeReEpochOperationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get preparedEpoch => $composableBuilder(
    column: $table.preparedEpoch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get operationSequenceNumber => $composableBuilder(
    column: $table.operationSequenceNumber,
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

class $$GroupsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $GroupsTableTable> {
  $$GroupsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get creatorId =>
      $composableBuilder(column: $table.creatorId, builder: (column) => column);

  GeneratedColumn<String> get adminId =>
      $composableBuilder(column: $table.adminId, builder: (column) => column);

  GeneratedColumn<int> get epoch =>
      $composableBuilder(column: $table.epoch, builder: (column) => column);

  GeneratedColumn<bool> get isReEpochPending => $composableBuilder(
    column: $table.isReEpochPending,
    builder: (column) => column,
  );

  GeneratedColumn<String> get activeReEpochOperationId => $composableBuilder(
    column: $table.activeReEpochOperationId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get preparedEpoch => $composableBuilder(
    column: $table.preparedEpoch,
    builder: (column) => column,
  );

  GeneratedColumn<int> get operationSequenceNumber => $composableBuilder(
    column: $table.operationSequenceNumber,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> groupMembersTableRefs<T extends Object>(
    Expression<T> Function($$GroupMembersTableTableAnnotationComposer a) f,
  ) {
    final $$GroupMembersTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.groupId,
          referencedTable: $db.groupMembersTable,
          getReferencedColumn: (t) => t.groupId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$GroupMembersTableTableAnnotationComposer(
                $db: $db,
                $table: $db.groupMembersTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> groupEpochOperationsTableRefs<T extends Object>(
    Expression<T> Function($$GroupEpochOperationsTableTableAnnotationComposer a)
    f,
  ) {
    final $$GroupEpochOperationsTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.groupId,
          referencedTable: $db.groupEpochOperationsTable,
          getReferencedColumn: (t) => t.groupId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$GroupEpochOperationsTableTableAnnotationComposer(
                $db: $db,
                $table: $db.groupEpochOperationsTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> groupMessagePayloadsTableRefs<T extends Object>(
    Expression<T> Function($$GroupMessagePayloadsTableTableAnnotationComposer a)
    f,
  ) {
    final $$GroupMessagePayloadsTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.groupId,
          referencedTable: $db.groupMessagePayloadsTable,
          getReferencedColumn: (t) => t.groupId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$GroupMessagePayloadsTableTableAnnotationComposer(
                $db: $db,
                $table: $db.groupMessagePayloadsTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$GroupsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GroupsTableTable,
          GroupEntry,
          $$GroupsTableTableFilterComposer,
          $$GroupsTableTableOrderingComposer,
          $$GroupsTableTableAnnotationComposer,
          $$GroupsTableTableCreateCompanionBuilder,
          $$GroupsTableTableUpdateCompanionBuilder,
          (GroupEntry, $$GroupsTableTableReferences),
          GroupEntry,
          PrefetchHooks Function({
            bool groupMembersTableRefs,
            bool groupEpochOperationsTableRefs,
            bool groupMessagePayloadsTableRefs,
          })
        > {
  $$GroupsTableTableTableManager(_$AppDatabase db, $GroupsTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GroupsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GroupsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GroupsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> groupId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> creatorId = const Value.absent(),
                Value<String> adminId = const Value.absent(),
                Value<int> epoch = const Value.absent(),
                Value<bool> isReEpochPending = const Value.absent(),
                Value<String?> activeReEpochOperationId = const Value.absent(),
                Value<int?> preparedEpoch = const Value.absent(),
                Value<int> operationSequenceNumber = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GroupsTableCompanion(
                groupId: groupId,
                name: name,
                creatorId: creatorId,
                adminId: adminId,
                epoch: epoch,
                isReEpochPending: isReEpochPending,
                activeReEpochOperationId: activeReEpochOperationId,
                preparedEpoch: preparedEpoch,
                operationSequenceNumber: operationSequenceNumber,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String groupId,
                required String name,
                required String creatorId,
                required String adminId,
                Value<int> epoch = const Value.absent(),
                Value<bool> isReEpochPending = const Value.absent(),
                Value<String?> activeReEpochOperationId = const Value.absent(),
                Value<int?> preparedEpoch = const Value.absent(),
                Value<int> operationSequenceNumber = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => GroupsTableCompanion.insert(
                groupId: groupId,
                name: name,
                creatorId: creatorId,
                adminId: adminId,
                epoch: epoch,
                isReEpochPending: isReEpochPending,
                activeReEpochOperationId: activeReEpochOperationId,
                preparedEpoch: preparedEpoch,
                operationSequenceNumber: operationSequenceNumber,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$GroupsTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                groupMembersTableRefs = false,
                groupEpochOperationsTableRefs = false,
                groupMessagePayloadsTableRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (groupMembersTableRefs) db.groupMembersTable,
                    if (groupEpochOperationsTableRefs)
                      db.groupEpochOperationsTable,
                    if (groupMessagePayloadsTableRefs)
                      db.groupMessagePayloadsTable,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (groupMembersTableRefs)
                        await $_getPrefetchedData<
                          GroupEntry,
                          $GroupsTableTable,
                          GroupMemberEntry
                        >(
                          currentTable: table,
                          referencedTable: $$GroupsTableTableReferences
                              ._groupMembersTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$GroupsTableTableReferences(
                                db,
                                table,
                                p0,
                              ).groupMembersTableRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.groupId == item.groupId,
                              ),
                          typedResults: items,
                        ),
                      if (groupEpochOperationsTableRefs)
                        await $_getPrefetchedData<
                          GroupEntry,
                          $GroupsTableTable,
                          GroupEpochOperationEntry
                        >(
                          currentTable: table,
                          referencedTable: $$GroupsTableTableReferences
                              ._groupEpochOperationsTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$GroupsTableTableReferences(
                                db,
                                table,
                                p0,
                              ).groupEpochOperationsTableRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.groupId == item.groupId,
                              ),
                          typedResults: items,
                        ),
                      if (groupMessagePayloadsTableRefs)
                        await $_getPrefetchedData<
                          GroupEntry,
                          $GroupsTableTable,
                          GroupMessagePayloadEntry
                        >(
                          currentTable: table,
                          referencedTable: $$GroupsTableTableReferences
                              ._groupMessagePayloadsTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$GroupsTableTableReferences(
                                db,
                                table,
                                p0,
                              ).groupMessagePayloadsTableRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.groupId == item.groupId,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$GroupsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GroupsTableTable,
      GroupEntry,
      $$GroupsTableTableFilterComposer,
      $$GroupsTableTableOrderingComposer,
      $$GroupsTableTableAnnotationComposer,
      $$GroupsTableTableCreateCompanionBuilder,
      $$GroupsTableTableUpdateCompanionBuilder,
      (GroupEntry, $$GroupsTableTableReferences),
      GroupEntry,
      PrefetchHooks Function({
        bool groupMembersTableRefs,
        bool groupEpochOperationsTableRefs,
        bool groupMessagePayloadsTableRefs,
      })
    >;
typedef $$GroupMembersTableTableCreateCompanionBuilder =
    GroupMembersTableCompanion Function({
      required String groupId,
      required String peerId,
      required String role,
      required String status,
      required DateTime joinedAt,
      required String invitedBy,
      Value<int> rowid,
    });
typedef $$GroupMembersTableTableUpdateCompanionBuilder =
    GroupMembersTableCompanion Function({
      Value<String> groupId,
      Value<String> peerId,
      Value<String> role,
      Value<String> status,
      Value<DateTime> joinedAt,
      Value<String> invitedBy,
      Value<int> rowid,
    });

final class $$GroupMembersTableTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $GroupMembersTableTable,
          GroupMemberEntry
        > {
  $$GroupMembersTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $GroupsTableTable _groupIdTable(_$AppDatabase db) =>
      db.groupsTable.createAlias(
        $_aliasNameGenerator(
          db.groupMembersTable.groupId,
          db.groupsTable.groupId,
        ),
      );

  $$GroupsTableTableProcessedTableManager get groupId {
    final $_column = $_itemColumn<String>('group_id')!;

    final manager = $$GroupsTableTableTableManager(
      $_db,
      $_db.groupsTable,
    ).filter((f) => f.groupId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_groupIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$GroupMembersTableTableFilterComposer
    extends Composer<_$AppDatabase, $GroupMembersTableTable> {
  $$GroupMembersTableTableFilterComposer({
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

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get joinedAt => $composableBuilder(
    column: $table.joinedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get invitedBy => $composableBuilder(
    column: $table.invitedBy,
    builder: (column) => ColumnFilters(column),
  );

  $$GroupsTableTableFilterComposer get groupId {
    final $$GroupsTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.groupsTable,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupsTableTableFilterComposer(
            $db: $db,
            $table: $db.groupsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GroupMembersTableTableOrderingComposer
    extends Composer<_$AppDatabase, $GroupMembersTableTable> {
  $$GroupMembersTableTableOrderingComposer({
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

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get joinedAt => $composableBuilder(
    column: $table.joinedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get invitedBy => $composableBuilder(
    column: $table.invitedBy,
    builder: (column) => ColumnOrderings(column),
  );

  $$GroupsTableTableOrderingComposer get groupId {
    final $$GroupsTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.groupsTable,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupsTableTableOrderingComposer(
            $db: $db,
            $table: $db.groupsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GroupMembersTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $GroupMembersTableTable> {
  $$GroupMembersTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get peerId =>
      $composableBuilder(column: $table.peerId, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get joinedAt =>
      $composableBuilder(column: $table.joinedAt, builder: (column) => column);

  GeneratedColumn<String> get invitedBy =>
      $composableBuilder(column: $table.invitedBy, builder: (column) => column);

  $$GroupsTableTableAnnotationComposer get groupId {
    final $$GroupsTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.groupsTable,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupsTableTableAnnotationComposer(
            $db: $db,
            $table: $db.groupsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GroupMembersTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GroupMembersTableTable,
          GroupMemberEntry,
          $$GroupMembersTableTableFilterComposer,
          $$GroupMembersTableTableOrderingComposer,
          $$GroupMembersTableTableAnnotationComposer,
          $$GroupMembersTableTableCreateCompanionBuilder,
          $$GroupMembersTableTableUpdateCompanionBuilder,
          (GroupMemberEntry, $$GroupMembersTableTableReferences),
          GroupMemberEntry,
          PrefetchHooks Function({bool groupId})
        > {
  $$GroupMembersTableTableTableManager(
    _$AppDatabase db,
    $GroupMembersTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GroupMembersTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GroupMembersTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GroupMembersTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> groupId = const Value.absent(),
                Value<String> peerId = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> joinedAt = const Value.absent(),
                Value<String> invitedBy = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GroupMembersTableCompanion(
                groupId: groupId,
                peerId: peerId,
                role: role,
                status: status,
                joinedAt: joinedAt,
                invitedBy: invitedBy,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String groupId,
                required String peerId,
                required String role,
                required String status,
                required DateTime joinedAt,
                required String invitedBy,
                Value<int> rowid = const Value.absent(),
              }) => GroupMembersTableCompanion.insert(
                groupId: groupId,
                peerId: peerId,
                role: role,
                status: status,
                joinedAt: joinedAt,
                invitedBy: invitedBy,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$GroupMembersTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({groupId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (groupId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.groupId,
                                referencedTable:
                                    $$GroupMembersTableTableReferences
                                        ._groupIdTable(db),
                                referencedColumn:
                                    $$GroupMembersTableTableReferences
                                        ._groupIdTable(db)
                                        .groupId,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$GroupMembersTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GroupMembersTableTable,
      GroupMemberEntry,
      $$GroupMembersTableTableFilterComposer,
      $$GroupMembersTableTableOrderingComposer,
      $$GroupMembersTableTableAnnotationComposer,
      $$GroupMembersTableTableCreateCompanionBuilder,
      $$GroupMembersTableTableUpdateCompanionBuilder,
      (GroupMemberEntry, $$GroupMembersTableTableReferences),
      GroupMemberEntry,
      PrefetchHooks Function({bool groupId})
    >;
typedef $$GroupEpochOperationsTableTableCreateCompanionBuilder =
    GroupEpochOperationsTableCompanion Function({
      required String operationId,
      required String groupId,
      required int previousEpoch,
      required int targetEpoch,
      required int operationSequenceNumber,
      required String operationStatus,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$GroupEpochOperationsTableTableUpdateCompanionBuilder =
    GroupEpochOperationsTableCompanion Function({
      Value<String> operationId,
      Value<String> groupId,
      Value<int> previousEpoch,
      Value<int> targetEpoch,
      Value<int> operationSequenceNumber,
      Value<String> operationStatus,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$GroupEpochOperationsTableTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $GroupEpochOperationsTableTable,
          GroupEpochOperationEntry
        > {
  $$GroupEpochOperationsTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $GroupsTableTable _groupIdTable(_$AppDatabase db) =>
      db.groupsTable.createAlias(
        $_aliasNameGenerator(
          db.groupEpochOperationsTable.groupId,
          db.groupsTable.groupId,
        ),
      );

  $$GroupsTableTableProcessedTableManager get groupId {
    final $_column = $_itemColumn<String>('group_id')!;

    final manager = $$GroupsTableTableTableManager(
      $_db,
      $_db.groupsTable,
    ).filter((f) => f.groupId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_groupIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$GroupEpochOperationsTableTableFilterComposer
    extends Composer<_$AppDatabase, $GroupEpochOperationsTableTable> {
  $$GroupEpochOperationsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get previousEpoch => $composableBuilder(
    column: $table.previousEpoch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetEpoch => $composableBuilder(
    column: $table.targetEpoch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get operationSequenceNumber => $composableBuilder(
    column: $table.operationSequenceNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operationStatus => $composableBuilder(
    column: $table.operationStatus,
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

  $$GroupsTableTableFilterComposer get groupId {
    final $$GroupsTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.groupsTable,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupsTableTableFilterComposer(
            $db: $db,
            $table: $db.groupsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GroupEpochOperationsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $GroupEpochOperationsTableTable> {
  $$GroupEpochOperationsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get previousEpoch => $composableBuilder(
    column: $table.previousEpoch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetEpoch => $composableBuilder(
    column: $table.targetEpoch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get operationSequenceNumber => $composableBuilder(
    column: $table.operationSequenceNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operationStatus => $composableBuilder(
    column: $table.operationStatus,
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

  $$GroupsTableTableOrderingComposer get groupId {
    final $$GroupsTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.groupsTable,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupsTableTableOrderingComposer(
            $db: $db,
            $table: $db.groupsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GroupEpochOperationsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $GroupEpochOperationsTableTable> {
  $$GroupEpochOperationsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get previousEpoch => $composableBuilder(
    column: $table.previousEpoch,
    builder: (column) => column,
  );

  GeneratedColumn<int> get targetEpoch => $composableBuilder(
    column: $table.targetEpoch,
    builder: (column) => column,
  );

  GeneratedColumn<int> get operationSequenceNumber => $composableBuilder(
    column: $table.operationSequenceNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get operationStatus => $composableBuilder(
    column: $table.operationStatus,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$GroupsTableTableAnnotationComposer get groupId {
    final $$GroupsTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.groupsTable,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupsTableTableAnnotationComposer(
            $db: $db,
            $table: $db.groupsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GroupEpochOperationsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GroupEpochOperationsTableTable,
          GroupEpochOperationEntry,
          $$GroupEpochOperationsTableTableFilterComposer,
          $$GroupEpochOperationsTableTableOrderingComposer,
          $$GroupEpochOperationsTableTableAnnotationComposer,
          $$GroupEpochOperationsTableTableCreateCompanionBuilder,
          $$GroupEpochOperationsTableTableUpdateCompanionBuilder,
          (
            GroupEpochOperationEntry,
            $$GroupEpochOperationsTableTableReferences,
          ),
          GroupEpochOperationEntry,
          PrefetchHooks Function({bool groupId})
        > {
  $$GroupEpochOperationsTableTableTableManager(
    _$AppDatabase db,
    $GroupEpochOperationsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GroupEpochOperationsTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$GroupEpochOperationsTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$GroupEpochOperationsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> operationId = const Value.absent(),
                Value<String> groupId = const Value.absent(),
                Value<int> previousEpoch = const Value.absent(),
                Value<int> targetEpoch = const Value.absent(),
                Value<int> operationSequenceNumber = const Value.absent(),
                Value<String> operationStatus = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GroupEpochOperationsTableCompanion(
                operationId: operationId,
                groupId: groupId,
                previousEpoch: previousEpoch,
                targetEpoch: targetEpoch,
                operationSequenceNumber: operationSequenceNumber,
                operationStatus: operationStatus,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String operationId,
                required String groupId,
                required int previousEpoch,
                required int targetEpoch,
                required int operationSequenceNumber,
                required String operationStatus,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => GroupEpochOperationsTableCompanion.insert(
                operationId: operationId,
                groupId: groupId,
                previousEpoch: previousEpoch,
                targetEpoch: targetEpoch,
                operationSequenceNumber: operationSequenceNumber,
                operationStatus: operationStatus,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$GroupEpochOperationsTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({groupId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (groupId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.groupId,
                                referencedTable:
                                    $$GroupEpochOperationsTableTableReferences
                                        ._groupIdTable(db),
                                referencedColumn:
                                    $$GroupEpochOperationsTableTableReferences
                                        ._groupIdTable(db)
                                        .groupId,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$GroupEpochOperationsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GroupEpochOperationsTableTable,
      GroupEpochOperationEntry,
      $$GroupEpochOperationsTableTableFilterComposer,
      $$GroupEpochOperationsTableTableOrderingComposer,
      $$GroupEpochOperationsTableTableAnnotationComposer,
      $$GroupEpochOperationsTableTableCreateCompanionBuilder,
      $$GroupEpochOperationsTableTableUpdateCompanionBuilder,
      (GroupEpochOperationEntry, $$GroupEpochOperationsTableTableReferences),
      GroupEpochOperationEntry,
      PrefetchHooks Function({bool groupId})
    >;
typedef $$GroupEpochSyncTableTableCreateCompanionBuilder =
    GroupEpochSyncTableCompanion Function({
      required String operationId,
      required String groupId,
      required String memberPeerId,
      Value<String> prepareStatus,
      Value<String> commitStatus,
      Value<String> finalizeStatus,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$GroupEpochSyncTableTableUpdateCompanionBuilder =
    GroupEpochSyncTableCompanion Function({
      Value<String> operationId,
      Value<String> groupId,
      Value<String> memberPeerId,
      Value<String> prepareStatus,
      Value<String> commitStatus,
      Value<String> finalizeStatus,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$GroupEpochSyncTableTableFilterComposer
    extends Composer<_$AppDatabase, $GroupEpochSyncTableTable> {
  $$GroupEpochSyncTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get memberPeerId => $composableBuilder(
    column: $table.memberPeerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get prepareStatus => $composableBuilder(
    column: $table.prepareStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get commitStatus => $composableBuilder(
    column: $table.commitStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get finalizeStatus => $composableBuilder(
    column: $table.finalizeStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GroupEpochSyncTableTableOrderingComposer
    extends Composer<_$AppDatabase, $GroupEpochSyncTableTable> {
  $$GroupEpochSyncTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get memberPeerId => $composableBuilder(
    column: $table.memberPeerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get prepareStatus => $composableBuilder(
    column: $table.prepareStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get commitStatus => $composableBuilder(
    column: $table.commitStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get finalizeStatus => $composableBuilder(
    column: $table.finalizeStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GroupEpochSyncTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $GroupEpochSyncTableTable> {
  $$GroupEpochSyncTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get memberPeerId => $composableBuilder(
    column: $table.memberPeerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get prepareStatus => $composableBuilder(
    column: $table.prepareStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get commitStatus => $composableBuilder(
    column: $table.commitStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get finalizeStatus => $composableBuilder(
    column: $table.finalizeStatus,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$GroupEpochSyncTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GroupEpochSyncTableTable,
          GroupEpochSyncEntry,
          $$GroupEpochSyncTableTableFilterComposer,
          $$GroupEpochSyncTableTableOrderingComposer,
          $$GroupEpochSyncTableTableAnnotationComposer,
          $$GroupEpochSyncTableTableCreateCompanionBuilder,
          $$GroupEpochSyncTableTableUpdateCompanionBuilder,
          (
            GroupEpochSyncEntry,
            BaseReferences<
              _$AppDatabase,
              $GroupEpochSyncTableTable,
              GroupEpochSyncEntry
            >,
          ),
          GroupEpochSyncEntry,
          PrefetchHooks Function()
        > {
  $$GroupEpochSyncTableTableTableManager(
    _$AppDatabase db,
    $GroupEpochSyncTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GroupEpochSyncTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GroupEpochSyncTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$GroupEpochSyncTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> operationId = const Value.absent(),
                Value<String> groupId = const Value.absent(),
                Value<String> memberPeerId = const Value.absent(),
                Value<String> prepareStatus = const Value.absent(),
                Value<String> commitStatus = const Value.absent(),
                Value<String> finalizeStatus = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GroupEpochSyncTableCompanion(
                operationId: operationId,
                groupId: groupId,
                memberPeerId: memberPeerId,
                prepareStatus: prepareStatus,
                commitStatus: commitStatus,
                finalizeStatus: finalizeStatus,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String operationId,
                required String groupId,
                required String memberPeerId,
                Value<String> prepareStatus = const Value.absent(),
                Value<String> commitStatus = const Value.absent(),
                Value<String> finalizeStatus = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => GroupEpochSyncTableCompanion.insert(
                operationId: operationId,
                groupId: groupId,
                memberPeerId: memberPeerId,
                prepareStatus: prepareStatus,
                commitStatus: commitStatus,
                finalizeStatus: finalizeStatus,
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

typedef $$GroupEpochSyncTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GroupEpochSyncTableTable,
      GroupEpochSyncEntry,
      $$GroupEpochSyncTableTableFilterComposer,
      $$GroupEpochSyncTableTableOrderingComposer,
      $$GroupEpochSyncTableTableAnnotationComposer,
      $$GroupEpochSyncTableTableCreateCompanionBuilder,
      $$GroupEpochSyncTableTableUpdateCompanionBuilder,
      (
        GroupEpochSyncEntry,
        BaseReferences<
          _$AppDatabase,
          $GroupEpochSyncTableTable,
          GroupEpochSyncEntry
        >,
      ),
      GroupEpochSyncEntry,
      PrefetchHooks Function()
    >;
typedef $$GroupMessagePayloadsTableTableCreateCompanionBuilder =
    GroupMessagePayloadsTableCompanion Function({
      required String groupId,
      required String messageId,
      required Uint8List encryptedPayload,
      required Uint8List nonce,
      required DateTime createdAt,
      Value<DateTime?> expiresAt,
      Value<int> rowid,
    });
typedef $$GroupMessagePayloadsTableTableUpdateCompanionBuilder =
    GroupMessagePayloadsTableCompanion Function({
      Value<String> groupId,
      Value<String> messageId,
      Value<Uint8List> encryptedPayload,
      Value<Uint8List> nonce,
      Value<DateTime> createdAt,
      Value<DateTime?> expiresAt,
      Value<int> rowid,
    });

final class $$GroupMessagePayloadsTableTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $GroupMessagePayloadsTableTable,
          GroupMessagePayloadEntry
        > {
  $$GroupMessagePayloadsTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $GroupsTableTable _groupIdTable(_$AppDatabase db) =>
      db.groupsTable.createAlias(
        $_aliasNameGenerator(
          db.groupMessagePayloadsTable.groupId,
          db.groupsTable.groupId,
        ),
      );

  $$GroupsTableTableProcessedTableManager get groupId {
    final $_column = $_itemColumn<String>('group_id')!;

    final manager = $$GroupsTableTableTableManager(
      $_db,
      $_db.groupsTable,
    ).filter((f) => f.groupId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_groupIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$GroupMessagePayloadsTableTableFilterComposer
    extends Composer<_$AppDatabase, $GroupMessagePayloadsTableTable> {
  $$GroupMessagePayloadsTableTableFilterComposer({
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

  ColumnFilters<Uint8List> get encryptedPayload => $composableBuilder(
    column: $table.encryptedPayload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get nonce => $composableBuilder(
    column: $table.nonce,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );

  $$GroupsTableTableFilterComposer get groupId {
    final $$GroupsTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.groupsTable,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupsTableTableFilterComposer(
            $db: $db,
            $table: $db.groupsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GroupMessagePayloadsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $GroupMessagePayloadsTableTable> {
  $$GroupMessagePayloadsTableTableOrderingComposer({
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

  ColumnOrderings<Uint8List> get encryptedPayload => $composableBuilder(
    column: $table.encryptedPayload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get nonce => $composableBuilder(
    column: $table.nonce,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$GroupsTableTableOrderingComposer get groupId {
    final $$GroupsTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.groupsTable,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupsTableTableOrderingComposer(
            $db: $db,
            $table: $db.groupsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GroupMessagePayloadsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $GroupMessagePayloadsTableTable> {
  $$GroupMessagePayloadsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<Uint8List> get encryptedPayload => $composableBuilder(
    column: $table.encryptedPayload,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get nonce =>
      $composableBuilder(column: $table.nonce, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);

  $$GroupsTableTableAnnotationComposer get groupId {
    final $$GroupsTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.groupsTable,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupsTableTableAnnotationComposer(
            $db: $db,
            $table: $db.groupsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GroupMessagePayloadsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GroupMessagePayloadsTableTable,
          GroupMessagePayloadEntry,
          $$GroupMessagePayloadsTableTableFilterComposer,
          $$GroupMessagePayloadsTableTableOrderingComposer,
          $$GroupMessagePayloadsTableTableAnnotationComposer,
          $$GroupMessagePayloadsTableTableCreateCompanionBuilder,
          $$GroupMessagePayloadsTableTableUpdateCompanionBuilder,
          (
            GroupMessagePayloadEntry,
            $$GroupMessagePayloadsTableTableReferences,
          ),
          GroupMessagePayloadEntry,
          PrefetchHooks Function({bool groupId})
        > {
  $$GroupMessagePayloadsTableTableTableManager(
    _$AppDatabase db,
    $GroupMessagePayloadsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GroupMessagePayloadsTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$GroupMessagePayloadsTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$GroupMessagePayloadsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> groupId = const Value.absent(),
                Value<String> messageId = const Value.absent(),
                Value<Uint8List> encryptedPayload = const Value.absent(),
                Value<Uint8List> nonce = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> expiresAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GroupMessagePayloadsTableCompanion(
                groupId: groupId,
                messageId: messageId,
                encryptedPayload: encryptedPayload,
                nonce: nonce,
                createdAt: createdAt,
                expiresAt: expiresAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String groupId,
                required String messageId,
                required Uint8List encryptedPayload,
                required Uint8List nonce,
                required DateTime createdAt,
                Value<DateTime?> expiresAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GroupMessagePayloadsTableCompanion.insert(
                groupId: groupId,
                messageId: messageId,
                encryptedPayload: encryptedPayload,
                nonce: nonce,
                createdAt: createdAt,
                expiresAt: expiresAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$GroupMessagePayloadsTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({groupId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (groupId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.groupId,
                                referencedTable:
                                    $$GroupMessagePayloadsTableTableReferences
                                        ._groupIdTable(db),
                                referencedColumn:
                                    $$GroupMessagePayloadsTableTableReferences
                                        ._groupIdTable(db)
                                        .groupId,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$GroupMessagePayloadsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GroupMessagePayloadsTableTable,
      GroupMessagePayloadEntry,
      $$GroupMessagePayloadsTableTableFilterComposer,
      $$GroupMessagePayloadsTableTableOrderingComposer,
      $$GroupMessagePayloadsTableTableAnnotationComposer,
      $$GroupMessagePayloadsTableTableCreateCompanionBuilder,
      $$GroupMessagePayloadsTableTableUpdateCompanionBuilder,
      (GroupMessagePayloadEntry, $$GroupMessagePayloadsTableTableReferences),
      GroupMessagePayloadEntry,
      PrefetchHooks Function({bool groupId})
    >;
typedef $$GroupDeliveryQueueTableTableCreateCompanionBuilder =
    GroupDeliveryQueueTableCompanion Function({
      Value<int> queueId,
      required String groupId,
      required String messageId,
      required String recipientPeerId,
      required int epoch,
      required String packetType,
      Value<String?> sessionId,
      required String encryptedEnvelopeJson,
      Value<String> status,
      Value<String?> failureReason,
      Value<int> retryCount,
      Value<DateTime?> nextRetryAt,
      required DateTime createdAt,
      required DateTime updatedAt,
    });
typedef $$GroupDeliveryQueueTableTableUpdateCompanionBuilder =
    GroupDeliveryQueueTableCompanion Function({
      Value<int> queueId,
      Value<String> groupId,
      Value<String> messageId,
      Value<String> recipientPeerId,
      Value<int> epoch,
      Value<String> packetType,
      Value<String?> sessionId,
      Value<String> encryptedEnvelopeJson,
      Value<String> status,
      Value<String?> failureReason,
      Value<int> retryCount,
      Value<DateTime?> nextRetryAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

class $$GroupDeliveryQueueTableTableFilterComposer
    extends Composer<_$AppDatabase, $GroupDeliveryQueueTableTable> {
  $$GroupDeliveryQueueTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get queueId => $composableBuilder(
    column: $table.queueId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recipientPeerId => $composableBuilder(
    column: $table.recipientPeerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get epoch => $composableBuilder(
    column: $table.epoch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get packetType => $composableBuilder(
    column: $table.packetType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get encryptedEnvelopeJson => $composableBuilder(
    column: $table.encryptedEnvelopeJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get failureReason => $composableBuilder(
    column: $table.failureReason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
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

class $$GroupDeliveryQueueTableTableOrderingComposer
    extends Composer<_$AppDatabase, $GroupDeliveryQueueTableTable> {
  $$GroupDeliveryQueueTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get queueId => $composableBuilder(
    column: $table.queueId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recipientPeerId => $composableBuilder(
    column: $table.recipientPeerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get epoch => $composableBuilder(
    column: $table.epoch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get packetType => $composableBuilder(
    column: $table.packetType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get encryptedEnvelopeJson => $composableBuilder(
    column: $table.encryptedEnvelopeJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get failureReason => $composableBuilder(
    column: $table.failureReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
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

class $$GroupDeliveryQueueTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $GroupDeliveryQueueTableTable> {
  $$GroupDeliveryQueueTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get queueId =>
      $composableBuilder(column: $table.queueId, builder: (column) => column);

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get recipientPeerId => $composableBuilder(
    column: $table.recipientPeerId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get epoch =>
      $composableBuilder(column: $table.epoch, builder: (column) => column);

  GeneratedColumn<String> get packetType => $composableBuilder(
    column: $table.packetType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get encryptedEnvelopeJson => $composableBuilder(
    column: $table.encryptedEnvelopeJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get failureReason => $composableBuilder(
    column: $table.failureReason,
    builder: (column) => column,
  );

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$GroupDeliveryQueueTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GroupDeliveryQueueTableTable,
          GroupDeliveryQueueEntry,
          $$GroupDeliveryQueueTableTableFilterComposer,
          $$GroupDeliveryQueueTableTableOrderingComposer,
          $$GroupDeliveryQueueTableTableAnnotationComposer,
          $$GroupDeliveryQueueTableTableCreateCompanionBuilder,
          $$GroupDeliveryQueueTableTableUpdateCompanionBuilder,
          (
            GroupDeliveryQueueEntry,
            BaseReferences<
              _$AppDatabase,
              $GroupDeliveryQueueTableTable,
              GroupDeliveryQueueEntry
            >,
          ),
          GroupDeliveryQueueEntry,
          PrefetchHooks Function()
        > {
  $$GroupDeliveryQueueTableTableTableManager(
    _$AppDatabase db,
    $GroupDeliveryQueueTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GroupDeliveryQueueTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$GroupDeliveryQueueTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$GroupDeliveryQueueTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> queueId = const Value.absent(),
                Value<String> groupId = const Value.absent(),
                Value<String> messageId = const Value.absent(),
                Value<String> recipientPeerId = const Value.absent(),
                Value<int> epoch = const Value.absent(),
                Value<String> packetType = const Value.absent(),
                Value<String?> sessionId = const Value.absent(),
                Value<String> encryptedEnvelopeJson = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> failureReason = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<DateTime?> nextRetryAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => GroupDeliveryQueueTableCompanion(
                queueId: queueId,
                groupId: groupId,
                messageId: messageId,
                recipientPeerId: recipientPeerId,
                epoch: epoch,
                packetType: packetType,
                sessionId: sessionId,
                encryptedEnvelopeJson: encryptedEnvelopeJson,
                status: status,
                failureReason: failureReason,
                retryCount: retryCount,
                nextRetryAt: nextRetryAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> queueId = const Value.absent(),
                required String groupId,
                required String messageId,
                required String recipientPeerId,
                required int epoch,
                required String packetType,
                Value<String?> sessionId = const Value.absent(),
                required String encryptedEnvelopeJson,
                Value<String> status = const Value.absent(),
                Value<String?> failureReason = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<DateTime?> nextRetryAt = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
              }) => GroupDeliveryQueueTableCompanion.insert(
                queueId: queueId,
                groupId: groupId,
                messageId: messageId,
                recipientPeerId: recipientPeerId,
                epoch: epoch,
                packetType: packetType,
                sessionId: sessionId,
                encryptedEnvelopeJson: encryptedEnvelopeJson,
                status: status,
                failureReason: failureReason,
                retryCount: retryCount,
                nextRetryAt: nextRetryAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GroupDeliveryQueueTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GroupDeliveryQueueTableTable,
      GroupDeliveryQueueEntry,
      $$GroupDeliveryQueueTableTableFilterComposer,
      $$GroupDeliveryQueueTableTableOrderingComposer,
      $$GroupDeliveryQueueTableTableAnnotationComposer,
      $$GroupDeliveryQueueTableTableCreateCompanionBuilder,
      $$GroupDeliveryQueueTableTableUpdateCompanionBuilder,
      (
        GroupDeliveryQueueEntry,
        BaseReferences<
          _$AppDatabase,
          $GroupDeliveryQueueTableTable,
          GroupDeliveryQueueEntry
        >,
      ),
      GroupDeliveryQueueEntry,
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
  $$GroupsTableTableTableManager get groupsTable =>
      $$GroupsTableTableTableManager(_db, _db.groupsTable);
  $$GroupMembersTableTableTableManager get groupMembersTable =>
      $$GroupMembersTableTableTableManager(_db, _db.groupMembersTable);
  $$GroupEpochOperationsTableTableTableManager get groupEpochOperationsTable =>
      $$GroupEpochOperationsTableTableTableManager(
        _db,
        _db.groupEpochOperationsTable,
      );
  $$GroupEpochSyncTableTableTableManager get groupEpochSyncTable =>
      $$GroupEpochSyncTableTableTableManager(_db, _db.groupEpochSyncTable);
  $$GroupMessagePayloadsTableTableTableManager get groupMessagePayloadsTable =>
      $$GroupMessagePayloadsTableTableTableManager(
        _db,
        _db.groupMessagePayloadsTable,
      );
  $$GroupDeliveryQueueTableTableTableManager get groupDeliveryQueueTable =>
      $$GroupDeliveryQueueTableTableTableManager(
        _db,
        _db.groupDeliveryQueueTable,
      );
}
