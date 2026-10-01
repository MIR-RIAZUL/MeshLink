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

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $MessagesTableTable messagesTable = $MessagesTableTable(this);
  late final $PeerIdentitiesTableTable peerIdentitiesTable =
      $PeerIdentitiesTableTable(this);
  late final $SeenPacketsTableTable seenPacketsTable = $SeenPacketsTableTable(
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

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$MessagesTableTableTableManager get messagesTable =>
      $$MessagesTableTableTableManager(_db, _db.messagesTable);
  $$PeerIdentitiesTableTableTableManager get peerIdentitiesTable =>
      $$PeerIdentitiesTableTableTableManager(_db, _db.peerIdentitiesTable);
  $$SeenPacketsTableTableTableManager get seenPacketsTable =>
      $$SeenPacketsTableTableTableManager(_db, _db.seenPacketsTable);
}
