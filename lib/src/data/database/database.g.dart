// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $ShiftPatternsTable extends ShiftPatterns
    with TableInfo<$ShiftPatternsTable, ShiftPattern> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ShiftPatternsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 100,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ShiftCycleType, String>
  cycleType = GeneratedColumn<String>(
    'cycle_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<ShiftCycleType>($ShiftPatternsTable.$convertercycleType);
  static const VerificationMeta _workingWeekdaysMeta = const VerificationMeta(
    'workingWeekdays',
  );
  @override
  late final GeneratedColumn<int> workingWeekdays = GeneratedColumn<int>(
    'working_weekdays',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> archivedAt = GeneratedColumn<DateTime>(
    'archived_at',
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
    id,
    name,
    cycleType,
    workingWeekdays,
    notes,
    archivedAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shift_patterns';
  @override
  VerificationContext validateIntegrity(
    Insertable<ShiftPattern> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('working_weekdays')) {
      context.handle(
        _workingWeekdaysMeta,
        workingWeekdays.isAcceptableOrUnknown(
          data['working_weekdays']!,
          _workingWeekdaysMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_workingWeekdaysMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {name},
  ];
  @override
  ShiftPattern map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ShiftPattern(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      cycleType: $ShiftPatternsTable.$convertercycleType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}cycle_type'],
        )!,
      ),
      workingWeekdays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}working_weekdays'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}archived_at'],
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
  $ShiftPatternsTable createAlias(String alias) {
    return $ShiftPatternsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ShiftCycleType, String, String>
  $convertercycleType = const EnumNameConverter<ShiftCycleType>(
    ShiftCycleType.values,
  );
}

class ShiftPattern extends DataClass implements Insertable<ShiftPattern> {
  final String id;
  final String name;
  final ShiftCycleType cycleType;

  /// Bitmask of base working weekdays, Monday = bit 0 … Sunday = bit 6, using
  /// `DateTime.monday`-based indexing.
  ///
  /// A bitmask rather than a child table: it is a fixed seven-value set that is
  /// always read whole, and a join to answer "is Tuesday a working day" would
  /// be on the hot path of every calendar walk.
  final int workingWeekdays;
  final String? notes;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ShiftPattern({
    required this.id,
    required this.name,
    required this.cycleType,
    required this.workingWeekdays,
    this.notes,
    this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    {
      map['cycle_type'] = Variable<String>(
        $ShiftPatternsTable.$convertercycleType.toSql(cycleType),
      );
    }
    map['working_weekdays'] = Variable<int>(workingWeekdays);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<DateTime>(archivedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ShiftPatternsCompanion toCompanion(bool nullToAbsent) {
    return ShiftPatternsCompanion(
      id: Value(id),
      name: Value(name),
      cycleType: Value(cycleType),
      workingWeekdays: Value(workingWeekdays),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ShiftPattern.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ShiftPattern(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      cycleType: $ShiftPatternsTable.$convertercycleType.fromJson(
        serializer.fromJson<String>(json['cycleType']),
      ),
      workingWeekdays: serializer.fromJson<int>(json['workingWeekdays']),
      notes: serializer.fromJson<String?>(json['notes']),
      archivedAt: serializer.fromJson<DateTime?>(json['archivedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'cycleType': serializer.toJson<String>(
        $ShiftPatternsTable.$convertercycleType.toJson(cycleType),
      ),
      'workingWeekdays': serializer.toJson<int>(workingWeekdays),
      'notes': serializer.toJson<String?>(notes),
      'archivedAt': serializer.toJson<DateTime?>(archivedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ShiftPattern copyWith({
    String? id,
    String? name,
    ShiftCycleType? cycleType,
    int? workingWeekdays,
    Value<String?> notes = const Value.absent(),
    Value<DateTime?> archivedAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ShiftPattern(
    id: id ?? this.id,
    name: name ?? this.name,
    cycleType: cycleType ?? this.cycleType,
    workingWeekdays: workingWeekdays ?? this.workingWeekdays,
    notes: notes.present ? notes.value : this.notes,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ShiftPattern copyWithCompanion(ShiftPatternsCompanion data) {
    return ShiftPattern(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      cycleType: data.cycleType.present ? data.cycleType.value : this.cycleType,
      workingWeekdays: data.workingWeekdays.present
          ? data.workingWeekdays.value
          : this.workingWeekdays,
      notes: data.notes.present ? data.notes.value : this.notes,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ShiftPattern(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('cycleType: $cycleType, ')
          ..write('workingWeekdays: $workingWeekdays, ')
          ..write('notes: $notes, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    cycleType,
    workingWeekdays,
    notes,
    archivedAt,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ShiftPattern &&
          other.id == this.id &&
          other.name == this.name &&
          other.cycleType == this.cycleType &&
          other.workingWeekdays == this.workingWeekdays &&
          other.notes == this.notes &&
          other.archivedAt == this.archivedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ShiftPatternsCompanion extends UpdateCompanion<ShiftPattern> {
  final Value<String> id;
  final Value<String> name;
  final Value<ShiftCycleType> cycleType;
  final Value<int> workingWeekdays;
  final Value<String?> notes;
  final Value<DateTime?> archivedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ShiftPatternsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.cycleType = const Value.absent(),
    this.workingWeekdays = const Value.absent(),
    this.notes = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ShiftPatternsCompanion.insert({
    required String id,
    required String name,
    required ShiftCycleType cycleType,
    required int workingWeekdays,
    this.notes = const Value.absent(),
    this.archivedAt = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       cycleType = Value(cycleType),
       workingWeekdays = Value(workingWeekdays),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ShiftPattern> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? cycleType,
    Expression<int>? workingWeekdays,
    Expression<String>? notes,
    Expression<DateTime>? archivedAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (cycleType != null) 'cycle_type': cycleType,
      if (workingWeekdays != null) 'working_weekdays': workingWeekdays,
      if (notes != null) 'notes': notes,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ShiftPatternsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<ShiftCycleType>? cycleType,
    Value<int>? workingWeekdays,
    Value<String?>? notes,
    Value<DateTime?>? archivedAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ShiftPatternsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      cycleType: cycleType ?? this.cycleType,
      workingWeekdays: workingWeekdays ?? this.workingWeekdays,
      notes: notes ?? this.notes,
      archivedAt: archivedAt ?? this.archivedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (cycleType.present) {
      map['cycle_type'] = Variable<String>(
        $ShiftPatternsTable.$convertercycleType.toSql(cycleType.value),
      );
    }
    if (workingWeekdays.present) {
      map['working_weekdays'] = Variable<int>(workingWeekdays.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<DateTime>(archivedAt.value);
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
    return (StringBuffer('ShiftPatternsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('cycleType: $cycleType, ')
          ..write('workingWeekdays: $workingWeekdays, ')
          ..write('notes: $notes, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PatternShiftsTable extends PatternShifts
    with TableInfo<$PatternShiftsTable, PatternShift> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PatternShiftsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _patternIdMeta = const VerificationMeta(
    'patternId',
  );
  @override
  late final GeneratedColumn<String> patternId = GeneratedColumn<String>(
    'pattern_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES shift_patterns (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 40,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startMinuteMeta = const VerificationMeta(
    'startMinute',
  );
  @override
  late final GeneratedColumn<int> startMinute = GeneratedColumn<int>(
    'start_minute',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endMinuteMeta = const VerificationMeta(
    'endMinute',
  );
  @override
  late final GeneratedColumn<int> endMinute = GeneratedColumn<int>(
    'end_minute',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _breakSecondsMeta = const VerificationMeta(
    'breakSeconds',
  );
  @override
  late final GeneratedColumn<int> breakSeconds = GeneratedColumn<int>(
    'break_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    patternId,
    label,
    position,
    startMinute,
    endMinute,
    breakSeconds,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pattern_shifts';
  @override
  VerificationContext validateIntegrity(
    Insertable<PatternShift> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('pattern_id')) {
      context.handle(
        _patternIdMeta,
        patternId.isAcceptableOrUnknown(data['pattern_id']!, _patternIdMeta),
      );
    } else if (isInserting) {
      context.missing(_patternIdMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('start_minute')) {
      context.handle(
        _startMinuteMeta,
        startMinute.isAcceptableOrUnknown(
          data['start_minute']!,
          _startMinuteMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startMinuteMeta);
    }
    if (data.containsKey('end_minute')) {
      context.handle(
        _endMinuteMeta,
        endMinute.isAcceptableOrUnknown(data['end_minute']!, _endMinuteMeta),
      );
    } else if (isInserting) {
      context.missing(_endMinuteMeta);
    }
    if (data.containsKey('break_seconds')) {
      context.handle(
        _breakSecondsMeta,
        breakSeconds.isAcceptableOrUnknown(
          data['break_seconds']!,
          _breakSecondsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {patternId, label},
    {patternId, position},
  ];
  @override
  PatternShift map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PatternShift(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      patternId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pattern_id'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      startMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_minute'],
      )!,
      endMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_minute'],
      )!,
      breakSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}break_seconds'],
      )!,
    );
  }

  @override
  $PatternShiftsTable createAlias(String alias) {
    return $PatternShiftsTable(attachedDatabase, alias);
  }
}

class PatternShift extends DataClass implements Insertable<PatternShift> {
  final String id;
  final String patternId;

  /// What the shop floor calls it: `A`, `1st`, `Night`.
  final String label;

  /// Order within the day, from the pattern's own start. Also the index into a
  /// workcenter's operators-per-shift list (DESIGN.md §4.2), which is why it is
  /// stored rather than derived from [startMinute]: a night shift starting at
  /// 23:40 sorts first by clock time but is last in the day.
  final int position;

  /// Minutes from midnight, 0–1439.
  final int startMinute;
  final int endMinute;

  /// Unpaid break inside the window, in seconds. Subtracted from the shift's
  /// gross duration to give productive time; not placed at a specific clock
  /// time, because no input in this app is precise enough to make that
  /// placement mean anything.
  final int breakSeconds;
  const PatternShift({
    required this.id,
    required this.patternId,
    required this.label,
    required this.position,
    required this.startMinute,
    required this.endMinute,
    required this.breakSeconds,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['pattern_id'] = Variable<String>(patternId);
    map['label'] = Variable<String>(label);
    map['position'] = Variable<int>(position);
    map['start_minute'] = Variable<int>(startMinute);
    map['end_minute'] = Variable<int>(endMinute);
    map['break_seconds'] = Variable<int>(breakSeconds);
    return map;
  }

  PatternShiftsCompanion toCompanion(bool nullToAbsent) {
    return PatternShiftsCompanion(
      id: Value(id),
      patternId: Value(patternId),
      label: Value(label),
      position: Value(position),
      startMinute: Value(startMinute),
      endMinute: Value(endMinute),
      breakSeconds: Value(breakSeconds),
    );
  }

  factory PatternShift.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PatternShift(
      id: serializer.fromJson<String>(json['id']),
      patternId: serializer.fromJson<String>(json['patternId']),
      label: serializer.fromJson<String>(json['label']),
      position: serializer.fromJson<int>(json['position']),
      startMinute: serializer.fromJson<int>(json['startMinute']),
      endMinute: serializer.fromJson<int>(json['endMinute']),
      breakSeconds: serializer.fromJson<int>(json['breakSeconds']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'patternId': serializer.toJson<String>(patternId),
      'label': serializer.toJson<String>(label),
      'position': serializer.toJson<int>(position),
      'startMinute': serializer.toJson<int>(startMinute),
      'endMinute': serializer.toJson<int>(endMinute),
      'breakSeconds': serializer.toJson<int>(breakSeconds),
    };
  }

  PatternShift copyWith({
    String? id,
    String? patternId,
    String? label,
    int? position,
    int? startMinute,
    int? endMinute,
    int? breakSeconds,
  }) => PatternShift(
    id: id ?? this.id,
    patternId: patternId ?? this.patternId,
    label: label ?? this.label,
    position: position ?? this.position,
    startMinute: startMinute ?? this.startMinute,
    endMinute: endMinute ?? this.endMinute,
    breakSeconds: breakSeconds ?? this.breakSeconds,
  );
  PatternShift copyWithCompanion(PatternShiftsCompanion data) {
    return PatternShift(
      id: data.id.present ? data.id.value : this.id,
      patternId: data.patternId.present ? data.patternId.value : this.patternId,
      label: data.label.present ? data.label.value : this.label,
      position: data.position.present ? data.position.value : this.position,
      startMinute: data.startMinute.present
          ? data.startMinute.value
          : this.startMinute,
      endMinute: data.endMinute.present ? data.endMinute.value : this.endMinute,
      breakSeconds: data.breakSeconds.present
          ? data.breakSeconds.value
          : this.breakSeconds,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PatternShift(')
          ..write('id: $id, ')
          ..write('patternId: $patternId, ')
          ..write('label: $label, ')
          ..write('position: $position, ')
          ..write('startMinute: $startMinute, ')
          ..write('endMinute: $endMinute, ')
          ..write('breakSeconds: $breakSeconds')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    patternId,
    label,
    position,
    startMinute,
    endMinute,
    breakSeconds,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PatternShift &&
          other.id == this.id &&
          other.patternId == this.patternId &&
          other.label == this.label &&
          other.position == this.position &&
          other.startMinute == this.startMinute &&
          other.endMinute == this.endMinute &&
          other.breakSeconds == this.breakSeconds);
}

class PatternShiftsCompanion extends UpdateCompanion<PatternShift> {
  final Value<String> id;
  final Value<String> patternId;
  final Value<String> label;
  final Value<int> position;
  final Value<int> startMinute;
  final Value<int> endMinute;
  final Value<int> breakSeconds;
  final Value<int> rowid;
  const PatternShiftsCompanion({
    this.id = const Value.absent(),
    this.patternId = const Value.absent(),
    this.label = const Value.absent(),
    this.position = const Value.absent(),
    this.startMinute = const Value.absent(),
    this.endMinute = const Value.absent(),
    this.breakSeconds = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PatternShiftsCompanion.insert({
    required String id,
    required String patternId,
    required String label,
    required int position,
    required int startMinute,
    required int endMinute,
    this.breakSeconds = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       patternId = Value(patternId),
       label = Value(label),
       position = Value(position),
       startMinute = Value(startMinute),
       endMinute = Value(endMinute);
  static Insertable<PatternShift> custom({
    Expression<String>? id,
    Expression<String>? patternId,
    Expression<String>? label,
    Expression<int>? position,
    Expression<int>? startMinute,
    Expression<int>? endMinute,
    Expression<int>? breakSeconds,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (patternId != null) 'pattern_id': patternId,
      if (label != null) 'label': label,
      if (position != null) 'position': position,
      if (startMinute != null) 'start_minute': startMinute,
      if (endMinute != null) 'end_minute': endMinute,
      if (breakSeconds != null) 'break_seconds': breakSeconds,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PatternShiftsCompanion copyWith({
    Value<String>? id,
    Value<String>? patternId,
    Value<String>? label,
    Value<int>? position,
    Value<int>? startMinute,
    Value<int>? endMinute,
    Value<int>? breakSeconds,
    Value<int>? rowid,
  }) {
    return PatternShiftsCompanion(
      id: id ?? this.id,
      patternId: patternId ?? this.patternId,
      label: label ?? this.label,
      position: position ?? this.position,
      startMinute: startMinute ?? this.startMinute,
      endMinute: endMinute ?? this.endMinute,
      breakSeconds: breakSeconds ?? this.breakSeconds,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (patternId.present) {
      map['pattern_id'] = Variable<String>(patternId.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (startMinute.present) {
      map['start_minute'] = Variable<int>(startMinute.value);
    }
    if (endMinute.present) {
      map['end_minute'] = Variable<int>(endMinute.value);
    }
    if (breakSeconds.present) {
      map['break_seconds'] = Variable<int>(breakSeconds.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PatternShiftsCompanion(')
          ..write('id: $id, ')
          ..write('patternId: $patternId, ')
          ..write('label: $label, ')
          ..write('position: $position, ')
          ..write('startMinute: $startMinute, ')
          ..write('endMinute: $endMinute, ')
          ..write('breakSeconds: $breakSeconds, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlantsTable extends Plants with TableInfo<$PlantsTable, Plant> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlantsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 200,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 40),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> archivedAt = GeneratedColumn<DateTime>(
    'archived_at',
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
    id,
    name,
    code,
    notes,
    archivedAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'plants';
  @override
  VerificationContext validateIntegrity(
    Insertable<Plant> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {name},
  ];
  @override
  Plant map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Plant(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}archived_at'],
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
  $PlantsTable createAlias(String alias) {
    return $PlantsTable(attachedDatabase, alias);
  }
}

class Plant extends DataClass implements Insertable<Plant> {
  final String id;
  final String name;
  final String? code;
  final String? notes;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Plant({
    required this.id,
    required this.name,
    this.code,
    this.notes,
    this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || code != null) {
      map['code'] = Variable<String>(code);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<DateTime>(archivedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PlantsCompanion toCompanion(bool nullToAbsent) {
    return PlantsCompanion(
      id: Value(id),
      name: Value(name),
      code: code == null && nullToAbsent ? const Value.absent() : Value(code),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Plant.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Plant(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      code: serializer.fromJson<String?>(json['code']),
      notes: serializer.fromJson<String?>(json['notes']),
      archivedAt: serializer.fromJson<DateTime?>(json['archivedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'code': serializer.toJson<String?>(code),
      'notes': serializer.toJson<String?>(notes),
      'archivedAt': serializer.toJson<DateTime?>(archivedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Plant copyWith({
    String? id,
    String? name,
    Value<String?> code = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    Value<DateTime?> archivedAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Plant(
    id: id ?? this.id,
    name: name ?? this.name,
    code: code.present ? code.value : this.code,
    notes: notes.present ? notes.value : this.notes,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Plant copyWithCompanion(PlantsCompanion data) {
    return Plant(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      code: data.code.present ? data.code.value : this.code,
      notes: data.notes.present ? data.notes.value : this.notes,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Plant(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('code: $code, ')
          ..write('notes: $notes, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, code, notes, archivedAt, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Plant &&
          other.id == this.id &&
          other.name == this.name &&
          other.code == this.code &&
          other.notes == this.notes &&
          other.archivedAt == this.archivedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class PlantsCompanion extends UpdateCompanion<Plant> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> code;
  final Value<String?> notes;
  final Value<DateTime?> archivedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PlantsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.code = const Value.absent(),
    this.notes = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlantsCompanion.insert({
    required String id,
    required String name,
    this.code = const Value.absent(),
    this.notes = const Value.absent(),
    this.archivedAt = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Plant> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? code,
    Expression<String>? notes,
    Expression<DateTime>? archivedAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (code != null) 'code': code,
      if (notes != null) 'notes': notes,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlantsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? code,
    Value<String?>? notes,
    Value<DateTime?>? archivedAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return PlantsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      notes: notes ?? this.notes,
      archivedAt: archivedAt ?? this.archivedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<DateTime>(archivedAt.value);
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
    return (StringBuffer('PlantsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('code: $code, ')
          ..write('notes: $notes, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProductionCellsTable extends ProductionCells
    with TableInfo<$ProductionCellsTable, ProductionCell> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProductionCellsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _plantIdMeta = const VerificationMeta(
    'plantId',
  );
  @override
  late final GeneratedColumn<String> plantId = GeneratedColumn<String>(
    'plant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES plants (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 200,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> archivedAt = GeneratedColumn<DateTime>(
    'archived_at',
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
    id,
    plantId,
    name,
    notes,
    archivedAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'production_cells';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProductionCell> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('plant_id')) {
      context.handle(
        _plantIdMeta,
        plantId.isAcceptableOrUnknown(data['plant_id']!, _plantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_plantIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {plantId, name},
  ];
  @override
  ProductionCell map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProductionCell(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      plantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plant_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}archived_at'],
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
  $ProductionCellsTable createAlias(String alias) {
    return $ProductionCellsTable(attachedDatabase, alias);
  }
}

class ProductionCell extends DataClass implements Insertable<ProductionCell> {
  final String id;
  final String plantId;
  final String name;
  final String? notes;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ProductionCell({
    required this.id,
    required this.plantId,
    required this.name,
    this.notes,
    this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['plant_id'] = Variable<String>(plantId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<DateTime>(archivedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ProductionCellsCompanion toCompanion(bool nullToAbsent) {
    return ProductionCellsCompanion(
      id: Value(id),
      plantId: Value(plantId),
      name: Value(name),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ProductionCell.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProductionCell(
      id: serializer.fromJson<String>(json['id']),
      plantId: serializer.fromJson<String>(json['plantId']),
      name: serializer.fromJson<String>(json['name']),
      notes: serializer.fromJson<String?>(json['notes']),
      archivedAt: serializer.fromJson<DateTime?>(json['archivedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'plantId': serializer.toJson<String>(plantId),
      'name': serializer.toJson<String>(name),
      'notes': serializer.toJson<String?>(notes),
      'archivedAt': serializer.toJson<DateTime?>(archivedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ProductionCell copyWith({
    String? id,
    String? plantId,
    String? name,
    Value<String?> notes = const Value.absent(),
    Value<DateTime?> archivedAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ProductionCell(
    id: id ?? this.id,
    plantId: plantId ?? this.plantId,
    name: name ?? this.name,
    notes: notes.present ? notes.value : this.notes,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ProductionCell copyWithCompanion(ProductionCellsCompanion data) {
    return ProductionCell(
      id: data.id.present ? data.id.value : this.id,
      plantId: data.plantId.present ? data.plantId.value : this.plantId,
      name: data.name.present ? data.name.value : this.name,
      notes: data.notes.present ? data.notes.value : this.notes,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProductionCell(')
          ..write('id: $id, ')
          ..write('plantId: $plantId, ')
          ..write('name: $name, ')
          ..write('notes: $notes, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, plantId, name, notes, archivedAt, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProductionCell &&
          other.id == this.id &&
          other.plantId == this.plantId &&
          other.name == this.name &&
          other.notes == this.notes &&
          other.archivedAt == this.archivedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ProductionCellsCompanion extends UpdateCompanion<ProductionCell> {
  final Value<String> id;
  final Value<String> plantId;
  final Value<String> name;
  final Value<String?> notes;
  final Value<DateTime?> archivedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ProductionCellsCompanion({
    this.id = const Value.absent(),
    this.plantId = const Value.absent(),
    this.name = const Value.absent(),
    this.notes = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProductionCellsCompanion.insert({
    required String id,
    required String plantId,
    required String name,
    this.notes = const Value.absent(),
    this.archivedAt = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       plantId = Value(plantId),
       name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ProductionCell> custom({
    Expression<String>? id,
    Expression<String>? plantId,
    Expression<String>? name,
    Expression<String>? notes,
    Expression<DateTime>? archivedAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (plantId != null) 'plant_id': plantId,
      if (name != null) 'name': name,
      if (notes != null) 'notes': notes,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProductionCellsCompanion copyWith({
    Value<String>? id,
    Value<String>? plantId,
    Value<String>? name,
    Value<String?>? notes,
    Value<DateTime?>? archivedAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ProductionCellsCompanion(
      id: id ?? this.id,
      plantId: plantId ?? this.plantId,
      name: name ?? this.name,
      notes: notes ?? this.notes,
      archivedAt: archivedAt ?? this.archivedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (plantId.present) {
      map['plant_id'] = Variable<String>(plantId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<DateTime>(archivedAt.value);
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
    return (StringBuffer('ProductionCellsCompanion(')
          ..write('id: $id, ')
          ..write('plantId: $plantId, ')
          ..write('name: $name, ')
          ..write('notes: $notes, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProductionLinesTable extends ProductionLines
    with TableInfo<$ProductionLinesTable, ProductionLine> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProductionLinesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cellIdMeta = const VerificationMeta('cellId');
  @override
  late final GeneratedColumn<String> cellId = GeneratedColumn<String>(
    'cell_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES production_cells (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 200,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> archivedAt = GeneratedColumn<DateTime>(
    'archived_at',
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
    id,
    cellId,
    name,
    notes,
    archivedAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'production_lines';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProductionLine> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('cell_id')) {
      context.handle(
        _cellIdMeta,
        cellId.isAcceptableOrUnknown(data['cell_id']!, _cellIdMeta),
      );
    } else if (isInserting) {
      context.missing(_cellIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {cellId, name},
  ];
  @override
  ProductionLine map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProductionLine(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      cellId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cell_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}archived_at'],
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
  $ProductionLinesTable createAlias(String alias) {
    return $ProductionLinesTable(attachedDatabase, alias);
  }
}

class ProductionLine extends DataClass implements Insertable<ProductionLine> {
  final String id;
  final String cellId;
  final String name;
  final String? notes;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ProductionLine({
    required this.id,
    required this.cellId,
    required this.name,
    this.notes,
    this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['cell_id'] = Variable<String>(cellId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<DateTime>(archivedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ProductionLinesCompanion toCompanion(bool nullToAbsent) {
    return ProductionLinesCompanion(
      id: Value(id),
      cellId: Value(cellId),
      name: Value(name),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ProductionLine.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProductionLine(
      id: serializer.fromJson<String>(json['id']),
      cellId: serializer.fromJson<String>(json['cellId']),
      name: serializer.fromJson<String>(json['name']),
      notes: serializer.fromJson<String?>(json['notes']),
      archivedAt: serializer.fromJson<DateTime?>(json['archivedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'cellId': serializer.toJson<String>(cellId),
      'name': serializer.toJson<String>(name),
      'notes': serializer.toJson<String?>(notes),
      'archivedAt': serializer.toJson<DateTime?>(archivedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ProductionLine copyWith({
    String? id,
    String? cellId,
    String? name,
    Value<String?> notes = const Value.absent(),
    Value<DateTime?> archivedAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ProductionLine(
    id: id ?? this.id,
    cellId: cellId ?? this.cellId,
    name: name ?? this.name,
    notes: notes.present ? notes.value : this.notes,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ProductionLine copyWithCompanion(ProductionLinesCompanion data) {
    return ProductionLine(
      id: data.id.present ? data.id.value : this.id,
      cellId: data.cellId.present ? data.cellId.value : this.cellId,
      name: data.name.present ? data.name.value : this.name,
      notes: data.notes.present ? data.notes.value : this.notes,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProductionLine(')
          ..write('id: $id, ')
          ..write('cellId: $cellId, ')
          ..write('name: $name, ')
          ..write('notes: $notes, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, cellId, name, notes, archivedAt, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProductionLine &&
          other.id == this.id &&
          other.cellId == this.cellId &&
          other.name == this.name &&
          other.notes == this.notes &&
          other.archivedAt == this.archivedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ProductionLinesCompanion extends UpdateCompanion<ProductionLine> {
  final Value<String> id;
  final Value<String> cellId;
  final Value<String> name;
  final Value<String?> notes;
  final Value<DateTime?> archivedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ProductionLinesCompanion({
    this.id = const Value.absent(),
    this.cellId = const Value.absent(),
    this.name = const Value.absent(),
    this.notes = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProductionLinesCompanion.insert({
    required String id,
    required String cellId,
    required String name,
    this.notes = const Value.absent(),
    this.archivedAt = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       cellId = Value(cellId),
       name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ProductionLine> custom({
    Expression<String>? id,
    Expression<String>? cellId,
    Expression<String>? name,
    Expression<String>? notes,
    Expression<DateTime>? archivedAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (cellId != null) 'cell_id': cellId,
      if (name != null) 'name': name,
      if (notes != null) 'notes': notes,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProductionLinesCompanion copyWith({
    Value<String>? id,
    Value<String>? cellId,
    Value<String>? name,
    Value<String?>? notes,
    Value<DateTime?>? archivedAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ProductionLinesCompanion(
      id: id ?? this.id,
      cellId: cellId ?? this.cellId,
      name: name ?? this.name,
      notes: notes ?? this.notes,
      archivedAt: archivedAt ?? this.archivedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (cellId.present) {
      map['cell_id'] = Variable<String>(cellId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<DateTime>(archivedAt.value);
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
    return (StringBuffer('ProductionLinesCompanion(')
          ..write('id: $id, ')
          ..write('cellId: $cellId, ')
          ..write('name: $name, ')
          ..write('notes: $notes, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorkcenterTypesTable extends WorkcenterTypes
    with TableInfo<$WorkcenterTypesTable, WorkcenterType> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkcenterTypesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<WorkcenterIcon?, String> icon =
      GeneratedColumn<String>(
        'icon',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<WorkcenterIcon?>($WorkcenterTypesTable.$convertericonn);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 100,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isBuiltInMeta = const VerificationMeta(
    'isBuiltIn',
  );
  @override
  late final GeneratedColumn<bool> isBuiltIn = GeneratedColumn<bool>(
    'is_built_in',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_built_in" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> archivedAt = GeneratedColumn<DateTime>(
    'archived_at',
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    icon,
    name,
    isBuiltIn,
    archivedAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workcenter_types';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkcenterType> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('is_built_in')) {
      context.handle(
        _isBuiltInMeta,
        isBuiltIn.isAcceptableOrUnknown(data['is_built_in']!, _isBuiltInMeta),
      );
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {name},
  ];
  @override
  WorkcenterType map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkcenterType(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      icon: $WorkcenterTypesTable.$convertericonn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}icon'],
        ),
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      isBuiltIn: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_built_in'],
      )!,
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}archived_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $WorkcenterTypesTable createAlias(String alias) {
    return $WorkcenterTypesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<WorkcenterIcon, String, String> $convertericon =
      const EnumNameConverter<WorkcenterIcon>(WorkcenterIcon.values);
  static JsonTypeConverter2<WorkcenterIcon?, String?, String?> $convertericonn =
      JsonTypeConverter2.asNullable($convertericon);
}

class WorkcenterType extends DataClass implements Insertable<WorkcenterType> {
  final String id;

  /// Which of the icon library's glyphs a workcenter of this type is drawn
  /// with, stored as a [WorkcenterIcon] name.
  ///
  /// **A name, not a codepoint.** Flutter's icon tree-shaking drops every glyph
  /// the compiler cannot see referenced, so an `IconData` built from a stored
  /// number is a blank box in release and correct in debug. The enum resolves
  /// through an exhaustive switch, which the compiler does see.
  final WorkcenterIcon? icon;
  final String name;
  final bool isBuiltIn;
  final DateTime? archivedAt;
  final DateTime createdAt;
  const WorkcenterType({
    required this.id,
    this.icon,
    required this.name,
    required this.isBuiltIn,
    this.archivedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || icon != null) {
      map['icon'] = Variable<String>(
        $WorkcenterTypesTable.$convertericonn.toSql(icon),
      );
    }
    map['name'] = Variable<String>(name);
    map['is_built_in'] = Variable<bool>(isBuiltIn);
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<DateTime>(archivedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  WorkcenterTypesCompanion toCompanion(bool nullToAbsent) {
    return WorkcenterTypesCompanion(
      id: Value(id),
      icon: icon == null && nullToAbsent ? const Value.absent() : Value(icon),
      name: Value(name),
      isBuiltIn: Value(isBuiltIn),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
      createdAt: Value(createdAt),
    );
  }

  factory WorkcenterType.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkcenterType(
      id: serializer.fromJson<String>(json['id']),
      icon: $WorkcenterTypesTable.$convertericonn.fromJson(
        serializer.fromJson<String?>(json['icon']),
      ),
      name: serializer.fromJson<String>(json['name']),
      isBuiltIn: serializer.fromJson<bool>(json['isBuiltIn']),
      archivedAt: serializer.fromJson<DateTime?>(json['archivedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'icon': serializer.toJson<String?>(
        $WorkcenterTypesTable.$convertericonn.toJson(icon),
      ),
      'name': serializer.toJson<String>(name),
      'isBuiltIn': serializer.toJson<bool>(isBuiltIn),
      'archivedAt': serializer.toJson<DateTime?>(archivedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  WorkcenterType copyWith({
    String? id,
    Value<WorkcenterIcon?> icon = const Value.absent(),
    String? name,
    bool? isBuiltIn,
    Value<DateTime?> archivedAt = const Value.absent(),
    DateTime? createdAt,
  }) => WorkcenterType(
    id: id ?? this.id,
    icon: icon.present ? icon.value : this.icon,
    name: name ?? this.name,
    isBuiltIn: isBuiltIn ?? this.isBuiltIn,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  WorkcenterType copyWithCompanion(WorkcenterTypesCompanion data) {
    return WorkcenterType(
      id: data.id.present ? data.id.value : this.id,
      icon: data.icon.present ? data.icon.value : this.icon,
      name: data.name.present ? data.name.value : this.name,
      isBuiltIn: data.isBuiltIn.present ? data.isBuiltIn.value : this.isBuiltIn,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkcenterType(')
          ..write('id: $id, ')
          ..write('icon: $icon, ')
          ..write('name: $name, ')
          ..write('isBuiltIn: $isBuiltIn, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, icon, name, isBuiltIn, archivedAt, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkcenterType &&
          other.id == this.id &&
          other.icon == this.icon &&
          other.name == this.name &&
          other.isBuiltIn == this.isBuiltIn &&
          other.archivedAt == this.archivedAt &&
          other.createdAt == this.createdAt);
}

class WorkcenterTypesCompanion extends UpdateCompanion<WorkcenterType> {
  final Value<String> id;
  final Value<WorkcenterIcon?> icon;
  final Value<String> name;
  final Value<bool> isBuiltIn;
  final Value<DateTime?> archivedAt;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const WorkcenterTypesCompanion({
    this.id = const Value.absent(),
    this.icon = const Value.absent(),
    this.name = const Value.absent(),
    this.isBuiltIn = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkcenterTypesCompanion.insert({
    required String id,
    this.icon = const Value.absent(),
    required String name,
    this.isBuiltIn = const Value.absent(),
    this.archivedAt = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<WorkcenterType> custom({
    Expression<String>? id,
    Expression<String>? icon,
    Expression<String>? name,
    Expression<bool>? isBuiltIn,
    Expression<DateTime>? archivedAt,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (icon != null) 'icon': icon,
      if (name != null) 'name': name,
      if (isBuiltIn != null) 'is_built_in': isBuiltIn,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkcenterTypesCompanion copyWith({
    Value<String>? id,
    Value<WorkcenterIcon?>? icon,
    Value<String>? name,
    Value<bool>? isBuiltIn,
    Value<DateTime?>? archivedAt,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return WorkcenterTypesCompanion(
      id: id ?? this.id,
      icon: icon ?? this.icon,
      name: name ?? this.name,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      archivedAt: archivedAt ?? this.archivedAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(
        $WorkcenterTypesTable.$convertericonn.toSql(icon.value),
      );
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (isBuiltIn.present) {
      map['is_built_in'] = Variable<bool>(isBuiltIn.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<DateTime>(archivedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkcenterTypesCompanion(')
          ..write('id: $id, ')
          ..write('icon: $icon, ')
          ..write('name: $name, ')
          ..write('isBuiltIn: $isBuiltIn, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorkcentersTable extends Workcenters
    with TableInfo<$WorkcentersTable, Workcenter> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkcentersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _plantIdMeta = const VerificationMeta(
    'plantId',
  );
  @override
  late final GeneratedColumn<String> plantId = GeneratedColumn<String>(
    'plant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES plants (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _typeIdMeta = const VerificationMeta('typeId');
  @override
  late final GeneratedColumn<String> typeId = GeneratedColumn<String>(
    'type_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES workcenter_types (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 200,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> archivedAt = GeneratedColumn<DateTime>(
    'archived_at',
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
    id,
    plantId,
    typeId,
    name,
    notes,
    archivedAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workcenters';
  @override
  VerificationContext validateIntegrity(
    Insertable<Workcenter> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('plant_id')) {
      context.handle(
        _plantIdMeta,
        plantId.isAcceptableOrUnknown(data['plant_id']!, _plantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_plantIdMeta);
    }
    if (data.containsKey('type_id')) {
      context.handle(
        _typeIdMeta,
        typeId.isAcceptableOrUnknown(data['type_id']!, _typeIdMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {plantId, name},
  ];
  @override
  Workcenter map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Workcenter(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      plantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plant_id'],
      )!,
      typeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}archived_at'],
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
  $WorkcentersTable createAlias(String alias) {
    return $WorkcentersTable(attachedDatabase, alias);
  }
}

class Workcenter extends DataClass implements Insertable<Workcenter> {
  final String id;
  final String plantId;
  final String? typeId;

  /// What the shop floor calls it, and what the VSM process box is labelled —
  /// `CLAD04`, `BAN11`.
  ///
  /// _Rejected: a separate `code` alongside this._ It shipped in v1 and every
  /// user filled both fields with the same value, then had to read two
  /// identical columns in every picker. One name is what a workcenter has.
  final String name;
  final String? notes;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Workcenter({
    required this.id,
    required this.plantId,
    this.typeId,
    required this.name,
    this.notes,
    this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['plant_id'] = Variable<String>(plantId);
    if (!nullToAbsent || typeId != null) {
      map['type_id'] = Variable<String>(typeId);
    }
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<DateTime>(archivedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  WorkcentersCompanion toCompanion(bool nullToAbsent) {
    return WorkcentersCompanion(
      id: Value(id),
      plantId: Value(plantId),
      typeId: typeId == null && nullToAbsent
          ? const Value.absent()
          : Value(typeId),
      name: Value(name),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Workcenter.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Workcenter(
      id: serializer.fromJson<String>(json['id']),
      plantId: serializer.fromJson<String>(json['plantId']),
      typeId: serializer.fromJson<String?>(json['typeId']),
      name: serializer.fromJson<String>(json['name']),
      notes: serializer.fromJson<String?>(json['notes']),
      archivedAt: serializer.fromJson<DateTime?>(json['archivedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'plantId': serializer.toJson<String>(plantId),
      'typeId': serializer.toJson<String?>(typeId),
      'name': serializer.toJson<String>(name),
      'notes': serializer.toJson<String?>(notes),
      'archivedAt': serializer.toJson<DateTime?>(archivedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Workcenter copyWith({
    String? id,
    String? plantId,
    Value<String?> typeId = const Value.absent(),
    String? name,
    Value<String?> notes = const Value.absent(),
    Value<DateTime?> archivedAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Workcenter(
    id: id ?? this.id,
    plantId: plantId ?? this.plantId,
    typeId: typeId.present ? typeId.value : this.typeId,
    name: name ?? this.name,
    notes: notes.present ? notes.value : this.notes,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Workcenter copyWithCompanion(WorkcentersCompanion data) {
    return Workcenter(
      id: data.id.present ? data.id.value : this.id,
      plantId: data.plantId.present ? data.plantId.value : this.plantId,
      typeId: data.typeId.present ? data.typeId.value : this.typeId,
      name: data.name.present ? data.name.value : this.name,
      notes: data.notes.present ? data.notes.value : this.notes,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Workcenter(')
          ..write('id: $id, ')
          ..write('plantId: $plantId, ')
          ..write('typeId: $typeId, ')
          ..write('name: $name, ')
          ..write('notes: $notes, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    plantId,
    typeId,
    name,
    notes,
    archivedAt,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Workcenter &&
          other.id == this.id &&
          other.plantId == this.plantId &&
          other.typeId == this.typeId &&
          other.name == this.name &&
          other.notes == this.notes &&
          other.archivedAt == this.archivedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class WorkcentersCompanion extends UpdateCompanion<Workcenter> {
  final Value<String> id;
  final Value<String> plantId;
  final Value<String?> typeId;
  final Value<String> name;
  final Value<String?> notes;
  final Value<DateTime?> archivedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const WorkcentersCompanion({
    this.id = const Value.absent(),
    this.plantId = const Value.absent(),
    this.typeId = const Value.absent(),
    this.name = const Value.absent(),
    this.notes = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkcentersCompanion.insert({
    required String id,
    required String plantId,
    this.typeId = const Value.absent(),
    required String name,
    this.notes = const Value.absent(),
    this.archivedAt = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       plantId = Value(plantId),
       name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Workcenter> custom({
    Expression<String>? id,
    Expression<String>? plantId,
    Expression<String>? typeId,
    Expression<String>? name,
    Expression<String>? notes,
    Expression<DateTime>? archivedAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (plantId != null) 'plant_id': plantId,
      if (typeId != null) 'type_id': typeId,
      if (name != null) 'name': name,
      if (notes != null) 'notes': notes,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkcentersCompanion copyWith({
    Value<String>? id,
    Value<String>? plantId,
    Value<String?>? typeId,
    Value<String>? name,
    Value<String?>? notes,
    Value<DateTime?>? archivedAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return WorkcentersCompanion(
      id: id ?? this.id,
      plantId: plantId ?? this.plantId,
      typeId: typeId ?? this.typeId,
      name: name ?? this.name,
      notes: notes ?? this.notes,
      archivedAt: archivedAt ?? this.archivedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (plantId.present) {
      map['plant_id'] = Variable<String>(plantId.value);
    }
    if (typeId.present) {
      map['type_id'] = Variable<String>(typeId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<DateTime>(archivedAt.value);
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
    return (StringBuffer('WorkcentersCompanion(')
          ..write('id: $id, ')
          ..write('plantId: $plantId, ')
          ..write('typeId: $typeId, ')
          ..write('name: $name, ')
          ..write('notes: $notes, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorkcenterLinesTable extends WorkcenterLines
    with TableInfo<$WorkcenterLinesTable, WorkcenterLine> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkcenterLinesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _workcenterIdMeta = const VerificationMeta(
    'workcenterId',
  );
  @override
  late final GeneratedColumn<String> workcenterId = GeneratedColumn<String>(
    'workcenter_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES workcenters (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _lineIdMeta = const VerificationMeta('lineId');
  @override
  late final GeneratedColumn<String> lineId = GeneratedColumn<String>(
    'line_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES production_lines (id) ON DELETE CASCADE',
    ),
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
  @override
  List<GeneratedColumn> get $columns => [workcenterId, lineId, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workcenter_lines';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkcenterLine> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('workcenter_id')) {
      context.handle(
        _workcenterIdMeta,
        workcenterId.isAcceptableOrUnknown(
          data['workcenter_id']!,
          _workcenterIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_workcenterIdMeta);
    }
    if (data.containsKey('line_id')) {
      context.handle(
        _lineIdMeta,
        lineId.isAcceptableOrUnknown(data['line_id']!, _lineIdMeta),
      );
    } else if (isInserting) {
      context.missing(_lineIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {workcenterId, lineId};
  @override
  WorkcenterLine map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkcenterLine(
      workcenterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}workcenter_id'],
      )!,
      lineId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}line_id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $WorkcenterLinesTable createAlias(String alias) {
    return $WorkcenterLinesTable(attachedDatabase, alias);
  }
}

class WorkcenterLine extends DataClass implements Insertable<WorkcenterLine> {
  final String workcenterId;
  final String lineId;
  final DateTime createdAt;
  const WorkcenterLine({
    required this.workcenterId,
    required this.lineId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['workcenter_id'] = Variable<String>(workcenterId);
    map['line_id'] = Variable<String>(lineId);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  WorkcenterLinesCompanion toCompanion(bool nullToAbsent) {
    return WorkcenterLinesCompanion(
      workcenterId: Value(workcenterId),
      lineId: Value(lineId),
      createdAt: Value(createdAt),
    );
  }

  factory WorkcenterLine.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkcenterLine(
      workcenterId: serializer.fromJson<String>(json['workcenterId']),
      lineId: serializer.fromJson<String>(json['lineId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'workcenterId': serializer.toJson<String>(workcenterId),
      'lineId': serializer.toJson<String>(lineId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  WorkcenterLine copyWith({
    String? workcenterId,
    String? lineId,
    DateTime? createdAt,
  }) => WorkcenterLine(
    workcenterId: workcenterId ?? this.workcenterId,
    lineId: lineId ?? this.lineId,
    createdAt: createdAt ?? this.createdAt,
  );
  WorkcenterLine copyWithCompanion(WorkcenterLinesCompanion data) {
    return WorkcenterLine(
      workcenterId: data.workcenterId.present
          ? data.workcenterId.value
          : this.workcenterId,
      lineId: data.lineId.present ? data.lineId.value : this.lineId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkcenterLine(')
          ..write('workcenterId: $workcenterId, ')
          ..write('lineId: $lineId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(workcenterId, lineId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkcenterLine &&
          other.workcenterId == this.workcenterId &&
          other.lineId == this.lineId &&
          other.createdAt == this.createdAt);
}

class WorkcenterLinesCompanion extends UpdateCompanion<WorkcenterLine> {
  final Value<String> workcenterId;
  final Value<String> lineId;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const WorkcenterLinesCompanion({
    this.workcenterId = const Value.absent(),
    this.lineId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkcenterLinesCompanion.insert({
    required String workcenterId,
    required String lineId,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : workcenterId = Value(workcenterId),
       lineId = Value(lineId),
       createdAt = Value(createdAt);
  static Insertable<WorkcenterLine> custom({
    Expression<String>? workcenterId,
    Expression<String>? lineId,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (workcenterId != null) 'workcenter_id': workcenterId,
      if (lineId != null) 'line_id': lineId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkcenterLinesCompanion copyWith({
    Value<String>? workcenterId,
    Value<String>? lineId,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return WorkcenterLinesCompanion(
      workcenterId: workcenterId ?? this.workcenterId,
      lineId: lineId ?? this.lineId,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (workcenterId.present) {
      map['workcenter_id'] = Variable<String>(workcenterId.value);
    }
    if (lineId.present) {
      map['line_id'] = Variable<String>(lineId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkcenterLinesCompanion(')
          ..write('workcenterId: $workcenterId, ')
          ..write('lineId: $lineId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorkcenterPoolsTable extends WorkcenterPools
    with TableInfo<$WorkcenterPoolsTable, WorkcenterPool> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkcenterPoolsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _plantIdMeta = const VerificationMeta(
    'plantId',
  );
  @override
  late final GeneratedColumn<String> plantId = GeneratedColumn<String>(
    'plant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES plants (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 200,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> archivedAt = GeneratedColumn<DateTime>(
    'archived_at',
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
    id,
    plantId,
    name,
    notes,
    archivedAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workcenter_pools';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkcenterPool> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('plant_id')) {
      context.handle(
        _plantIdMeta,
        plantId.isAcceptableOrUnknown(data['plant_id']!, _plantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_plantIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {plantId, name},
  ];
  @override
  WorkcenterPool map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkcenterPool(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      plantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plant_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}archived_at'],
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
  $WorkcenterPoolsTable createAlias(String alias) {
    return $WorkcenterPoolsTable(attachedDatabase, alias);
  }
}

class WorkcenterPool extends DataClass implements Insertable<WorkcenterPool> {
  final String id;
  final String plantId;
  final String name;
  final String? notes;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  const WorkcenterPool({
    required this.id,
    required this.plantId,
    required this.name,
    this.notes,
    this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['plant_id'] = Variable<String>(plantId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<DateTime>(archivedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  WorkcenterPoolsCompanion toCompanion(bool nullToAbsent) {
    return WorkcenterPoolsCompanion(
      id: Value(id),
      plantId: Value(plantId),
      name: Value(name),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory WorkcenterPool.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkcenterPool(
      id: serializer.fromJson<String>(json['id']),
      plantId: serializer.fromJson<String>(json['plantId']),
      name: serializer.fromJson<String>(json['name']),
      notes: serializer.fromJson<String?>(json['notes']),
      archivedAt: serializer.fromJson<DateTime?>(json['archivedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'plantId': serializer.toJson<String>(plantId),
      'name': serializer.toJson<String>(name),
      'notes': serializer.toJson<String?>(notes),
      'archivedAt': serializer.toJson<DateTime?>(archivedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  WorkcenterPool copyWith({
    String? id,
    String? plantId,
    String? name,
    Value<String?> notes = const Value.absent(),
    Value<DateTime?> archivedAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => WorkcenterPool(
    id: id ?? this.id,
    plantId: plantId ?? this.plantId,
    name: name ?? this.name,
    notes: notes.present ? notes.value : this.notes,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  WorkcenterPool copyWithCompanion(WorkcenterPoolsCompanion data) {
    return WorkcenterPool(
      id: data.id.present ? data.id.value : this.id,
      plantId: data.plantId.present ? data.plantId.value : this.plantId,
      name: data.name.present ? data.name.value : this.name,
      notes: data.notes.present ? data.notes.value : this.notes,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkcenterPool(')
          ..write('id: $id, ')
          ..write('plantId: $plantId, ')
          ..write('name: $name, ')
          ..write('notes: $notes, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, plantId, name, notes, archivedAt, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkcenterPool &&
          other.id == this.id &&
          other.plantId == this.plantId &&
          other.name == this.name &&
          other.notes == this.notes &&
          other.archivedAt == this.archivedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class WorkcenterPoolsCompanion extends UpdateCompanion<WorkcenterPool> {
  final Value<String> id;
  final Value<String> plantId;
  final Value<String> name;
  final Value<String?> notes;
  final Value<DateTime?> archivedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const WorkcenterPoolsCompanion({
    this.id = const Value.absent(),
    this.plantId = const Value.absent(),
    this.name = const Value.absent(),
    this.notes = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkcenterPoolsCompanion.insert({
    required String id,
    required String plantId,
    required String name,
    this.notes = const Value.absent(),
    this.archivedAt = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       plantId = Value(plantId),
       name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<WorkcenterPool> custom({
    Expression<String>? id,
    Expression<String>? plantId,
    Expression<String>? name,
    Expression<String>? notes,
    Expression<DateTime>? archivedAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (plantId != null) 'plant_id': plantId,
      if (name != null) 'name': name,
      if (notes != null) 'notes': notes,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkcenterPoolsCompanion copyWith({
    Value<String>? id,
    Value<String>? plantId,
    Value<String>? name,
    Value<String?>? notes,
    Value<DateTime?>? archivedAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return WorkcenterPoolsCompanion(
      id: id ?? this.id,
      plantId: plantId ?? this.plantId,
      name: name ?? this.name,
      notes: notes ?? this.notes,
      archivedAt: archivedAt ?? this.archivedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (plantId.present) {
      map['plant_id'] = Variable<String>(plantId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<DateTime>(archivedAt.value);
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
    return (StringBuffer('WorkcenterPoolsCompanion(')
          ..write('id: $id, ')
          ..write('plantId: $plantId, ')
          ..write('name: $name, ')
          ..write('notes: $notes, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorkcenterPoolMembersTable extends WorkcenterPoolMembers
    with TableInfo<$WorkcenterPoolMembersTable, WorkcenterPoolMember> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkcenterPoolMembersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _poolIdMeta = const VerificationMeta('poolId');
  @override
  late final GeneratedColumn<String> poolId = GeneratedColumn<String>(
    'pool_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES workcenter_pools (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _workcenterIdMeta = const VerificationMeta(
    'workcenterId',
  );
  @override
  late final GeneratedColumn<String> workcenterId = GeneratedColumn<String>(
    'workcenter_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES workcenters (id) ON DELETE CASCADE',
    ),
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
  @override
  List<GeneratedColumn> get $columns => [poolId, workcenterId, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workcenter_pool_members';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkcenterPoolMember> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('pool_id')) {
      context.handle(
        _poolIdMeta,
        poolId.isAcceptableOrUnknown(data['pool_id']!, _poolIdMeta),
      );
    } else if (isInserting) {
      context.missing(_poolIdMeta);
    }
    if (data.containsKey('workcenter_id')) {
      context.handle(
        _workcenterIdMeta,
        workcenterId.isAcceptableOrUnknown(
          data['workcenter_id']!,
          _workcenterIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_workcenterIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {poolId, workcenterId};
  @override
  WorkcenterPoolMember map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkcenterPoolMember(
      poolId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pool_id'],
      )!,
      workcenterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}workcenter_id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $WorkcenterPoolMembersTable createAlias(String alias) {
    return $WorkcenterPoolMembersTable(attachedDatabase, alias);
  }
}

class WorkcenterPoolMember extends DataClass
    implements Insertable<WorkcenterPoolMember> {
  final String poolId;
  final String workcenterId;
  final DateTime createdAt;
  const WorkcenterPoolMember({
    required this.poolId,
    required this.workcenterId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['pool_id'] = Variable<String>(poolId);
    map['workcenter_id'] = Variable<String>(workcenterId);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  WorkcenterPoolMembersCompanion toCompanion(bool nullToAbsent) {
    return WorkcenterPoolMembersCompanion(
      poolId: Value(poolId),
      workcenterId: Value(workcenterId),
      createdAt: Value(createdAt),
    );
  }

  factory WorkcenterPoolMember.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkcenterPoolMember(
      poolId: serializer.fromJson<String>(json['poolId']),
      workcenterId: serializer.fromJson<String>(json['workcenterId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'poolId': serializer.toJson<String>(poolId),
      'workcenterId': serializer.toJson<String>(workcenterId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  WorkcenterPoolMember copyWith({
    String? poolId,
    String? workcenterId,
    DateTime? createdAt,
  }) => WorkcenterPoolMember(
    poolId: poolId ?? this.poolId,
    workcenterId: workcenterId ?? this.workcenterId,
    createdAt: createdAt ?? this.createdAt,
  );
  WorkcenterPoolMember copyWithCompanion(WorkcenterPoolMembersCompanion data) {
    return WorkcenterPoolMember(
      poolId: data.poolId.present ? data.poolId.value : this.poolId,
      workcenterId: data.workcenterId.present
          ? data.workcenterId.value
          : this.workcenterId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkcenterPoolMember(')
          ..write('poolId: $poolId, ')
          ..write('workcenterId: $workcenterId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(poolId, workcenterId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkcenterPoolMember &&
          other.poolId == this.poolId &&
          other.workcenterId == this.workcenterId &&
          other.createdAt == this.createdAt);
}

class WorkcenterPoolMembersCompanion
    extends UpdateCompanion<WorkcenterPoolMember> {
  final Value<String> poolId;
  final Value<String> workcenterId;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const WorkcenterPoolMembersCompanion({
    this.poolId = const Value.absent(),
    this.workcenterId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkcenterPoolMembersCompanion.insert({
    required String poolId,
    required String workcenterId,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : poolId = Value(poolId),
       workcenterId = Value(workcenterId),
       createdAt = Value(createdAt);
  static Insertable<WorkcenterPoolMember> custom({
    Expression<String>? poolId,
    Expression<String>? workcenterId,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (poolId != null) 'pool_id': poolId,
      if (workcenterId != null) 'workcenter_id': workcenterId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkcenterPoolMembersCompanion copyWith({
    Value<String>? poolId,
    Value<String>? workcenterId,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return WorkcenterPoolMembersCompanion(
      poolId: poolId ?? this.poolId,
      workcenterId: workcenterId ?? this.workcenterId,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (poolId.present) {
      map['pool_id'] = Variable<String>(poolId.value);
    }
    if (workcenterId.present) {
      map['workcenter_id'] = Variable<String>(workcenterId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkcenterPoolMembersCompanion(')
          ..write('poolId: $poolId, ')
          ..write('workcenterId: $workcenterId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  List<GeneratedColumn> get $columns => [key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
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
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSetting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSetting extends DataClass implements Insertable<AppSetting> {
  final String key;
  final String? value;
  final DateTime updatedAt;
  const AppSetting({required this.key, this.value, required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    if (!nullToAbsent || value != null) {
      map['value'] = Variable<String>(value);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(
      key: Value(key),
      value: value == null && nullToAbsent
          ? const Value.absent()
          : Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory AppSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSetting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String?>(json['value']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String?>(value),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AppSetting copyWith({
    String? key,
    Value<String?> value = const Value.absent(),
    DateTime? updatedAt,
  }) => AppSetting(
    key: key ?? this.key,
    value: value.present ? value.value : this.value,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  AppSetting copyWithCompanion(AppSettingsCompanion data) {
    return AppSetting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSetting(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<String> key;
  final Value<String?> value;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    this.value = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       updatedAt = Value(updatedAt);
  static Insertable<AppSetting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith({
    Value<String>? key,
    Value<String?>? value,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
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
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProjectsTable extends Projects with TableInfo<$ProjectsTable, Project> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProjectsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 200,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _plantIdMeta = const VerificationMeta(
    'plantId',
  );
  @override
  late final GeneratedColumn<String> plantId = GeneratedColumn<String>(
    'plant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES plants (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _shiftPatternIdMeta = const VerificationMeta(
    'shiftPatternId',
  );
  @override
  late final GeneratedColumn<String> shiftPatternId = GeneratedColumn<String>(
    'shift_pattern_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES shift_patterns (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> archivedAt = GeneratedColumn<DateTime>(
    'archived_at',
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
    id,
    name,
    plantId,
    shiftPatternId,
    notes,
    archivedAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'projects';
  @override
  VerificationContext validateIntegrity(
    Insertable<Project> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('plant_id')) {
      context.handle(
        _plantIdMeta,
        plantId.isAcceptableOrUnknown(data['plant_id']!, _plantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_plantIdMeta);
    }
    if (data.containsKey('shift_pattern_id')) {
      context.handle(
        _shiftPatternIdMeta,
        shiftPatternId.isAcceptableOrUnknown(
          data['shift_pattern_id']!,
          _shiftPatternIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_shiftPatternIdMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {name},
  ];
  @override
  Project map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Project(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      plantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plant_id'],
      )!,
      shiftPatternId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}shift_pattern_id'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}archived_at'],
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
  $ProjectsTable createAlias(String alias) {
    return $ProjectsTable(attachedDatabase, alias);
  }
}

class Project extends DataClass implements Insertable<Project> {
  final String id;
  final String name;

  /// Restricted rather than cascading: deleting a plant out from under a
  /// project would silently destroy months of study work. Archiving is the
  /// intended route (DESIGN.md §3), and the readiness panel reports a project
  /// whose plant is archived.
  final String plantId;

  /// The shift split every workcenter in this project's plant is staffed
  /// against (DESIGN.md §4.1).
  final String shiftPatternId;
  final String? notes;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Project({
    required this.id,
    required this.name,
    required this.plantId,
    required this.shiftPatternId,
    this.notes,
    this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['plant_id'] = Variable<String>(plantId);
    map['shift_pattern_id'] = Variable<String>(shiftPatternId);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<DateTime>(archivedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ProjectsCompanion toCompanion(bool nullToAbsent) {
    return ProjectsCompanion(
      id: Value(id),
      name: Value(name),
      plantId: Value(plantId),
      shiftPatternId: Value(shiftPatternId),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Project.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Project(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      plantId: serializer.fromJson<String>(json['plantId']),
      shiftPatternId: serializer.fromJson<String>(json['shiftPatternId']),
      notes: serializer.fromJson<String?>(json['notes']),
      archivedAt: serializer.fromJson<DateTime?>(json['archivedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'plantId': serializer.toJson<String>(plantId),
      'shiftPatternId': serializer.toJson<String>(shiftPatternId),
      'notes': serializer.toJson<String?>(notes),
      'archivedAt': serializer.toJson<DateTime?>(archivedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Project copyWith({
    String? id,
    String? name,
    String? plantId,
    String? shiftPatternId,
    Value<String?> notes = const Value.absent(),
    Value<DateTime?> archivedAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Project(
    id: id ?? this.id,
    name: name ?? this.name,
    plantId: plantId ?? this.plantId,
    shiftPatternId: shiftPatternId ?? this.shiftPatternId,
    notes: notes.present ? notes.value : this.notes,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Project copyWithCompanion(ProjectsCompanion data) {
    return Project(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      plantId: data.plantId.present ? data.plantId.value : this.plantId,
      shiftPatternId: data.shiftPatternId.present
          ? data.shiftPatternId.value
          : this.shiftPatternId,
      notes: data.notes.present ? data.notes.value : this.notes,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Project(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('plantId: $plantId, ')
          ..write('shiftPatternId: $shiftPatternId, ')
          ..write('notes: $notes, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    plantId,
    shiftPatternId,
    notes,
    archivedAt,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Project &&
          other.id == this.id &&
          other.name == this.name &&
          other.plantId == this.plantId &&
          other.shiftPatternId == this.shiftPatternId &&
          other.notes == this.notes &&
          other.archivedAt == this.archivedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ProjectsCompanion extends UpdateCompanion<Project> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> plantId;
  final Value<String> shiftPatternId;
  final Value<String?> notes;
  final Value<DateTime?> archivedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ProjectsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.plantId = const Value.absent(),
    this.shiftPatternId = const Value.absent(),
    this.notes = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProjectsCompanion.insert({
    required String id,
    required String name,
    required String plantId,
    required String shiftPatternId,
    this.notes = const Value.absent(),
    this.archivedAt = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       plantId = Value(plantId),
       shiftPatternId = Value(shiftPatternId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Project> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? plantId,
    Expression<String>? shiftPatternId,
    Expression<String>? notes,
    Expression<DateTime>? archivedAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (plantId != null) 'plant_id': plantId,
      if (shiftPatternId != null) 'shift_pattern_id': shiftPatternId,
      if (notes != null) 'notes': notes,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProjectsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? plantId,
    Value<String>? shiftPatternId,
    Value<String?>? notes,
    Value<DateTime?>? archivedAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ProjectsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      plantId: plantId ?? this.plantId,
      shiftPatternId: shiftPatternId ?? this.shiftPatternId,
      notes: notes ?? this.notes,
      archivedAt: archivedAt ?? this.archivedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (plantId.present) {
      map['plant_id'] = Variable<String>(plantId.value);
    }
    if (shiftPatternId.present) {
      map['shift_pattern_id'] = Variable<String>(shiftPatternId.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<DateTime>(archivedAt.value);
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
    return (StringBuffer('ProjectsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('plantId: $plantId, ')
          ..write('shiftPatternId: $shiftPatternId, ')
          ..write('notes: $notes, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CalendarExceptionsTable extends CalendarExceptions
    with TableInfo<$CalendarExceptionsTable, CalendarException> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CalendarExceptionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<CalendarExceptionKind, String>
  kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<CalendarExceptionKind>(
        $CalendarExceptionsTable.$converterkind,
      );
  @override
  late final GeneratedColumnWithTypeConverter<CalendarExceptionScope, String>
  scope =
      GeneratedColumn<String>(
        'scope',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<CalendarExceptionScope>(
        $CalendarExceptionsTable.$converterscope,
      );
  static const VerificationMeta _scopeIdMeta = const VerificationMeta(
    'scopeId',
  );
  @override
  late final GeneratedColumn<String> scopeId = GeneratedColumn<String>(
    'scope_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _operatorsPerShiftMeta = const VerificationMeta(
    'operatorsPerShift',
  );
  @override
  late final GeneratedColumn<String> operatorsPerShift =
      GeneratedColumn<String>(
        'operators_per_shift',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    date,
    kind,
    scope,
    scopeId,
    operatorsPerShift,
    note,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'calendar_exceptions';
  @override
  VerificationContext validateIntegrity(
    Insertable<CalendarException> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('scope_id')) {
      context.handle(
        _scopeIdMeta,
        scopeId.isAcceptableOrUnknown(data['scope_id']!, _scopeIdMeta),
      );
    }
    if (data.containsKey('operators_per_shift')) {
      context.handle(
        _operatorsPerShiftMeta,
        operatorsPerShift.isAcceptableOrUnknown(
          data['operators_per_shift']!,
          _operatorsPerShiftMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {projectId, date, scope, scopeId},
  ];
  @override
  CalendarException map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CalendarException(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      kind: $CalendarExceptionsTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      scope: $CalendarExceptionsTable.$converterscope.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}scope'],
        )!,
      ),
      scopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope_id'],
      )!,
      operatorsPerShift: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operators_per_shift'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $CalendarExceptionsTable createAlias(String alias) {
    return $CalendarExceptionsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<CalendarExceptionKind, String, String>
  $converterkind = const EnumNameConverter<CalendarExceptionKind>(
    CalendarExceptionKind.values,
  );
  static JsonTypeConverter2<CalendarExceptionScope, String, String>
  $converterscope = const EnumNameConverter<CalendarExceptionScope>(
    CalendarExceptionScope.values,
  );
}

class CalendarException extends DataClass
    implements Insertable<CalendarException> {
  final String id;
  final String projectId;

  /// Local date at midnight. Ranges are stored as one row per day: the editor
  /// expands them on entry, so every downstream lookup is a map hit rather
  /// than an interval search.
  final DateTime date;
  final CalendarExceptionKind kind;
  final CalendarExceptionScope scope;

  /// The line or workcenter this applies to, or `''` for the whole plant.
  ///
  /// **Empty string rather than null, deliberately.** SQLite treats NULLs as
  /// distinct in a UNIQUE constraint, so a nullable column would let two
  /// plant-wide exceptions exist for the same day — the exact duplicate the
  /// key below is there to prevent. The repository maps `null` to `''` at the
  /// boundary so callers never see the sentinel.
  final String scopeId;

  /// Operators per shift for an extra-working day, in the compact `1/1/1` form
  /// the shop floor writes (see `parseOperatorsPerShift`). Null means "staffed
  /// as an ordinary working day".
  final String? operatorsPerShift;
  final String? note;
  final DateTime createdAt;
  const CalendarException({
    required this.id,
    required this.projectId,
    required this.date,
    required this.kind,
    required this.scope,
    required this.scopeId,
    this.operatorsPerShift,
    this.note,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['project_id'] = Variable<String>(projectId);
    map['date'] = Variable<DateTime>(date);
    {
      map['kind'] = Variable<String>(
        $CalendarExceptionsTable.$converterkind.toSql(kind),
      );
    }
    {
      map['scope'] = Variable<String>(
        $CalendarExceptionsTable.$converterscope.toSql(scope),
      );
    }
    map['scope_id'] = Variable<String>(scopeId);
    if (!nullToAbsent || operatorsPerShift != null) {
      map['operators_per_shift'] = Variable<String>(operatorsPerShift);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CalendarExceptionsCompanion toCompanion(bool nullToAbsent) {
    return CalendarExceptionsCompanion(
      id: Value(id),
      projectId: Value(projectId),
      date: Value(date),
      kind: Value(kind),
      scope: Value(scope),
      scopeId: Value(scopeId),
      operatorsPerShift: operatorsPerShift == null && nullToAbsent
          ? const Value.absent()
          : Value(operatorsPerShift),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdAt: Value(createdAt),
    );
  }

  factory CalendarException.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CalendarException(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String>(json['projectId']),
      date: serializer.fromJson<DateTime>(json['date']),
      kind: $CalendarExceptionsTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      scope: $CalendarExceptionsTable.$converterscope.fromJson(
        serializer.fromJson<String>(json['scope']),
      ),
      scopeId: serializer.fromJson<String>(json['scopeId']),
      operatorsPerShift: serializer.fromJson<String?>(
        json['operatorsPerShift'],
      ),
      note: serializer.fromJson<String?>(json['note']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String>(projectId),
      'date': serializer.toJson<DateTime>(date),
      'kind': serializer.toJson<String>(
        $CalendarExceptionsTable.$converterkind.toJson(kind),
      ),
      'scope': serializer.toJson<String>(
        $CalendarExceptionsTable.$converterscope.toJson(scope),
      ),
      'scopeId': serializer.toJson<String>(scopeId),
      'operatorsPerShift': serializer.toJson<String?>(operatorsPerShift),
      'note': serializer.toJson<String?>(note),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  CalendarException copyWith({
    String? id,
    String? projectId,
    DateTime? date,
    CalendarExceptionKind? kind,
    CalendarExceptionScope? scope,
    String? scopeId,
    Value<String?> operatorsPerShift = const Value.absent(),
    Value<String?> note = const Value.absent(),
    DateTime? createdAt,
  }) => CalendarException(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    date: date ?? this.date,
    kind: kind ?? this.kind,
    scope: scope ?? this.scope,
    scopeId: scopeId ?? this.scopeId,
    operatorsPerShift: operatorsPerShift.present
        ? operatorsPerShift.value
        : this.operatorsPerShift,
    note: note.present ? note.value : this.note,
    createdAt: createdAt ?? this.createdAt,
  );
  CalendarException copyWithCompanion(CalendarExceptionsCompanion data) {
    return CalendarException(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      date: data.date.present ? data.date.value : this.date,
      kind: data.kind.present ? data.kind.value : this.kind,
      scope: data.scope.present ? data.scope.value : this.scope,
      scopeId: data.scopeId.present ? data.scopeId.value : this.scopeId,
      operatorsPerShift: data.operatorsPerShift.present
          ? data.operatorsPerShift.value
          : this.operatorsPerShift,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CalendarException(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('date: $date, ')
          ..write('kind: $kind, ')
          ..write('scope: $scope, ')
          ..write('scopeId: $scopeId, ')
          ..write('operatorsPerShift: $operatorsPerShift, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    projectId,
    date,
    kind,
    scope,
    scopeId,
    operatorsPerShift,
    note,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CalendarException &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.date == this.date &&
          other.kind == this.kind &&
          other.scope == this.scope &&
          other.scopeId == this.scopeId &&
          other.operatorsPerShift == this.operatorsPerShift &&
          other.note == this.note &&
          other.createdAt == this.createdAt);
}

class CalendarExceptionsCompanion extends UpdateCompanion<CalendarException> {
  final Value<String> id;
  final Value<String> projectId;
  final Value<DateTime> date;
  final Value<CalendarExceptionKind> kind;
  final Value<CalendarExceptionScope> scope;
  final Value<String> scopeId;
  final Value<String?> operatorsPerShift;
  final Value<String?> note;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const CalendarExceptionsCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.date = const Value.absent(),
    this.kind = const Value.absent(),
    this.scope = const Value.absent(),
    this.scopeId = const Value.absent(),
    this.operatorsPerShift = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CalendarExceptionsCompanion.insert({
    required String id,
    required String projectId,
    required DateTime date,
    required CalendarExceptionKind kind,
    required CalendarExceptionScope scope,
    this.scopeId = const Value.absent(),
    this.operatorsPerShift = const Value.absent(),
    this.note = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       projectId = Value(projectId),
       date = Value(date),
       kind = Value(kind),
       scope = Value(scope),
       createdAt = Value(createdAt);
  static Insertable<CalendarException> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<DateTime>? date,
    Expression<String>? kind,
    Expression<String>? scope,
    Expression<String>? scopeId,
    Expression<String>? operatorsPerShift,
    Expression<String>? note,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (date != null) 'date': date,
      if (kind != null) 'kind': kind,
      if (scope != null) 'scope': scope,
      if (scopeId != null) 'scope_id': scopeId,
      if (operatorsPerShift != null) 'operators_per_shift': operatorsPerShift,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CalendarExceptionsCompanion copyWith({
    Value<String>? id,
    Value<String>? projectId,
    Value<DateTime>? date,
    Value<CalendarExceptionKind>? kind,
    Value<CalendarExceptionScope>? scope,
    Value<String>? scopeId,
    Value<String?>? operatorsPerShift,
    Value<String?>? note,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return CalendarExceptionsCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      date: date ?? this.date,
      kind: kind ?? this.kind,
      scope: scope ?? this.scope,
      scopeId: scopeId ?? this.scopeId,
      operatorsPerShift: operatorsPerShift ?? this.operatorsPerShift,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $CalendarExceptionsTable.$converterkind.toSql(kind.value),
      );
    }
    if (scope.present) {
      map['scope'] = Variable<String>(
        $CalendarExceptionsTable.$converterscope.toSql(scope.value),
      );
    }
    if (scopeId.present) {
      map['scope_id'] = Variable<String>(scopeId.value);
    }
    if (operatorsPerShift.present) {
      map['operators_per_shift'] = Variable<String>(operatorsPerShift.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CalendarExceptionsCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('date: $date, ')
          ..write('kind: $kind, ')
          ..write('scope: $scope, ')
          ..write('scopeId: $scopeId, ')
          ..write('operatorsPerShift: $operatorsPerShift, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TaktPeriodsTable extends TaktPeriods
    with TableInfo<$TaktPeriodsTable, TaktPeriod> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TaktPeriodsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _productionLineIdMeta = const VerificationMeta(
    'productionLineId',
  );
  @override
  late final GeneratedColumn<String> productionLineId = GeneratedColumn<String>(
    'production_line_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES production_lines (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<DateTime> startDate = GeneratedColumn<DateTime>(
    'start_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endDateMeta = const VerificationMeta(
    'endDate',
  );
  @override
  late final GeneratedColumn<DateTime> endDate = GeneratedColumn<DateTime>(
    'end_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taktValueMeta = const VerificationMeta(
    'taktValue',
  );
  @override
  late final GeneratedColumn<double> taktValue = GeneratedColumn<double>(
    'takt_value',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<TaktUnit, String> taktUnit =
      GeneratedColumn<String>(
        'takt_unit',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<TaktUnit>($TaktPeriodsTable.$convertertaktUnit);
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
    id,
    projectId,
    productionLineId,
    startDate,
    endDate,
    taktValue,
    taktUnit,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'takt_periods';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaktPeriod> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('production_line_id')) {
      context.handle(
        _productionLineIdMeta,
        productionLineId.isAcceptableOrUnknown(
          data['production_line_id']!,
          _productionLineIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_productionLineIdMeta);
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('end_date')) {
      context.handle(
        _endDateMeta,
        endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta),
      );
    } else if (isInserting) {
      context.missing(_endDateMeta);
    }
    if (data.containsKey('takt_value')) {
      context.handle(
        _taktValueMeta,
        taktValue.isAcceptableOrUnknown(data['takt_value']!, _taktValueMeta),
      );
    } else if (isInserting) {
      context.missing(_taktValueMeta);
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {projectId, productionLineId, startDate},
  ];
  @override
  TaktPeriod map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaktPeriod(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      productionLineId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}production_line_id'],
      )!,
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_date'],
      )!,
      endDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_date'],
      )!,
      taktValue: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}takt_value'],
      )!,
      taktUnit: $TaktPeriodsTable.$convertertaktUnit.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}takt_unit'],
        )!,
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
  $TaktPeriodsTable createAlias(String alias) {
    return $TaktPeriodsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<TaktUnit, String, String> $convertertaktUnit =
      const EnumNameConverter<TaktUnit>(TaktUnit.values);
}

class TaktPeriod extends DataClass implements Insertable<TaktPeriod> {
  final String id;
  final String projectId;
  final String productionLineId;

  /// Inclusive local dates at midnight.
  final DateTime startDate;
  final DateTime endDate;

  /// The takt as a number in [taktUnit] — `3` for a 3-day takt.
  ///
  /// **Stored with its unit rather than as canonical seconds**, because "3
  /// days" cannot be reduced to a duration without knowing whose working day is
  /// meant, and the answer differs per workcenter: a 1-shift station and a
  /// 3-shift station have very different days. The flow equivalent resolves it
  /// per workcenter at calculation time (DESIGN.md §6.1) — one takt of *that*
  /// workcenter's capacity. Hours, minutes and seconds are literal and resolve
  /// the same everywhere.
  final double taktValue;
  final TaktUnit taktUnit;
  final DateTime createdAt;
  final DateTime updatedAt;
  const TaktPeriod({
    required this.id,
    required this.projectId,
    required this.productionLineId,
    required this.startDate,
    required this.endDate,
    required this.taktValue,
    required this.taktUnit,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['project_id'] = Variable<String>(projectId);
    map['production_line_id'] = Variable<String>(productionLineId);
    map['start_date'] = Variable<DateTime>(startDate);
    map['end_date'] = Variable<DateTime>(endDate);
    map['takt_value'] = Variable<double>(taktValue);
    {
      map['takt_unit'] = Variable<String>(
        $TaktPeriodsTable.$convertertaktUnit.toSql(taktUnit),
      );
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  TaktPeriodsCompanion toCompanion(bool nullToAbsent) {
    return TaktPeriodsCompanion(
      id: Value(id),
      projectId: Value(projectId),
      productionLineId: Value(productionLineId),
      startDate: Value(startDate),
      endDate: Value(endDate),
      taktValue: Value(taktValue),
      taktUnit: Value(taktUnit),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory TaktPeriod.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaktPeriod(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String>(json['projectId']),
      productionLineId: serializer.fromJson<String>(json['productionLineId']),
      startDate: serializer.fromJson<DateTime>(json['startDate']),
      endDate: serializer.fromJson<DateTime>(json['endDate']),
      taktValue: serializer.fromJson<double>(json['taktValue']),
      taktUnit: $TaktPeriodsTable.$convertertaktUnit.fromJson(
        serializer.fromJson<String>(json['taktUnit']),
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String>(projectId),
      'productionLineId': serializer.toJson<String>(productionLineId),
      'startDate': serializer.toJson<DateTime>(startDate),
      'endDate': serializer.toJson<DateTime>(endDate),
      'taktValue': serializer.toJson<double>(taktValue),
      'taktUnit': serializer.toJson<String>(
        $TaktPeriodsTable.$convertertaktUnit.toJson(taktUnit),
      ),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  TaktPeriod copyWith({
    String? id,
    String? projectId,
    String? productionLineId,
    DateTime? startDate,
    DateTime? endDate,
    double? taktValue,
    TaktUnit? taktUnit,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => TaktPeriod(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    productionLineId: productionLineId ?? this.productionLineId,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    taktValue: taktValue ?? this.taktValue,
    taktUnit: taktUnit ?? this.taktUnit,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  TaktPeriod copyWithCompanion(TaktPeriodsCompanion data) {
    return TaktPeriod(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      productionLineId: data.productionLineId.present
          ? data.productionLineId.value
          : this.productionLineId,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      taktValue: data.taktValue.present ? data.taktValue.value : this.taktValue,
      taktUnit: data.taktUnit.present ? data.taktUnit.value : this.taktUnit,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaktPeriod(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('productionLineId: $productionLineId, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('taktValue: $taktValue, ')
          ..write('taktUnit: $taktUnit, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    projectId,
    productionLineId,
    startDate,
    endDate,
    taktValue,
    taktUnit,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaktPeriod &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.productionLineId == this.productionLineId &&
          other.startDate == this.startDate &&
          other.endDate == this.endDate &&
          other.taktValue == this.taktValue &&
          other.taktUnit == this.taktUnit &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TaktPeriodsCompanion extends UpdateCompanion<TaktPeriod> {
  final Value<String> id;
  final Value<String> projectId;
  final Value<String> productionLineId;
  final Value<DateTime> startDate;
  final Value<DateTime> endDate;
  final Value<double> taktValue;
  final Value<TaktUnit> taktUnit;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const TaktPeriodsCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.productionLineId = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.taktValue = const Value.absent(),
    this.taktUnit = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TaktPeriodsCompanion.insert({
    required String id,
    required String projectId,
    required String productionLineId,
    required DateTime startDate,
    required DateTime endDate,
    required double taktValue,
    required TaktUnit taktUnit,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       projectId = Value(projectId),
       productionLineId = Value(productionLineId),
       startDate = Value(startDate),
       endDate = Value(endDate),
       taktValue = Value(taktValue),
       taktUnit = Value(taktUnit),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<TaktPeriod> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<String>? productionLineId,
    Expression<DateTime>? startDate,
    Expression<DateTime>? endDate,
    Expression<double>? taktValue,
    Expression<String>? taktUnit,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (productionLineId != null) 'production_line_id': productionLineId,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (taktValue != null) 'takt_value': taktValue,
      if (taktUnit != null) 'takt_unit': taktUnit,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TaktPeriodsCompanion copyWith({
    Value<String>? id,
    Value<String>? projectId,
    Value<String>? productionLineId,
    Value<DateTime>? startDate,
    Value<DateTime>? endDate,
    Value<double>? taktValue,
    Value<TaktUnit>? taktUnit,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return TaktPeriodsCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      productionLineId: productionLineId ?? this.productionLineId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      taktValue: taktValue ?? this.taktValue,
      taktUnit: taktUnit ?? this.taktUnit,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (productionLineId.present) {
      map['production_line_id'] = Variable<String>(productionLineId.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<DateTime>(startDate.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<DateTime>(endDate.value);
    }
    if (taktValue.present) {
      map['takt_value'] = Variable<double>(taktValue.value);
    }
    if (taktUnit.present) {
      map['takt_unit'] = Variable<String>(
        $TaktPeriodsTable.$convertertaktUnit.toSql(taktUnit.value),
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
    return (StringBuffer('TaktPeriodsCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('productionLineId: $productionLineId, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('taktValue: $taktValue, ')
          ..write('taktUnit: $taktUnit, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorkcenterSchedulePeriodsTable extends WorkcenterSchedulePeriods
    with TableInfo<$WorkcenterSchedulePeriodsTable, WorkcenterSchedulePeriod> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkcenterSchedulePeriodsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _workcenterIdMeta = const VerificationMeta(
    'workcenterId',
  );
  @override
  late final GeneratedColumn<String> workcenterId = GeneratedColumn<String>(
    'workcenter_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES workcenters (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<DateTime> startDate = GeneratedColumn<DateTime>(
    'start_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endDateMeta = const VerificationMeta(
    'endDate',
  );
  @override
  late final GeneratedColumn<DateTime> endDate = GeneratedColumn<DateTime>(
    'end_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operatorsPerShiftMeta = const VerificationMeta(
    'operatorsPerShift',
  );
  @override
  late final GeneratedColumn<String> operatorsPerShift =
      GeneratedColumn<String>(
        'operators_per_shift',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _availabilityMeta = const VerificationMeta(
    'availability',
  );
  @override
  late final GeneratedColumn<double> availability = GeneratedColumn<double>(
    'availability',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1.0),
  );
  static const VerificationMeta _reworkMeta = const VerificationMeta('rework');
  @override
  late final GeneratedColumn<double> rework = GeneratedColumn<double>(
    'rework',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
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
    id,
    projectId,
    workcenterId,
    startDate,
    endDate,
    operatorsPerShift,
    availability,
    rework,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workcenter_schedule_periods';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkcenterSchedulePeriod> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('workcenter_id')) {
      context.handle(
        _workcenterIdMeta,
        workcenterId.isAcceptableOrUnknown(
          data['workcenter_id']!,
          _workcenterIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_workcenterIdMeta);
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('end_date')) {
      context.handle(
        _endDateMeta,
        endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta),
      );
    } else if (isInserting) {
      context.missing(_endDateMeta);
    }
    if (data.containsKey('operators_per_shift')) {
      context.handle(
        _operatorsPerShiftMeta,
        operatorsPerShift.isAcceptableOrUnknown(
          data['operators_per_shift']!,
          _operatorsPerShiftMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operatorsPerShiftMeta);
    }
    if (data.containsKey('availability')) {
      context.handle(
        _availabilityMeta,
        availability.isAcceptableOrUnknown(
          data['availability']!,
          _availabilityMeta,
        ),
      );
    }
    if (data.containsKey('rework')) {
      context.handle(
        _reworkMeta,
        rework.isAcceptableOrUnknown(data['rework']!, _reworkMeta),
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {projectId, workcenterId, startDate},
  ];
  @override
  WorkcenterSchedulePeriod map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkcenterSchedulePeriod(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      workcenterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}workcenter_id'],
      )!,
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_date'],
      )!,
      endDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_date'],
      )!,
      operatorsPerShift: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operators_per_shift'],
      )!,
      availability: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}availability'],
      )!,
      rework: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}rework'],
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
  $WorkcenterSchedulePeriodsTable createAlias(String alias) {
    return $WorkcenterSchedulePeriodsTable(attachedDatabase, alias);
  }
}

class WorkcenterSchedulePeriod extends DataClass
    implements Insertable<WorkcenterSchedulePeriod> {
  final String id;
  final String projectId;
  final String workcenterId;
  final DateTime startDate;
  final DateTime endDate;

  /// Operators on each shift of the project's pattern, in the `1/1/1` form the
  /// spec writes. Zero means the workcenter is closed for that shift, and the
  /// displayed "Shifts: 3" is derived by counting the non-zero entries.
  ///
  /// A compact column rather than a child table: the list is short, fixed to
  /// the pattern's shift count, always read whole, and read on the hot path of
  /// every calendar walk.
  final String operatorsPerShift;

  /// Fraction of open time the workcenter can actually run, 0 < a ≤ 1.
  final double availability;

  /// Fraction of work that has to be redone, ≥ 0.
  final double rework;
  final DateTime createdAt;
  final DateTime updatedAt;
  const WorkcenterSchedulePeriod({
    required this.id,
    required this.projectId,
    required this.workcenterId,
    required this.startDate,
    required this.endDate,
    required this.operatorsPerShift,
    required this.availability,
    required this.rework,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['project_id'] = Variable<String>(projectId);
    map['workcenter_id'] = Variable<String>(workcenterId);
    map['start_date'] = Variable<DateTime>(startDate);
    map['end_date'] = Variable<DateTime>(endDate);
    map['operators_per_shift'] = Variable<String>(operatorsPerShift);
    map['availability'] = Variable<double>(availability);
    map['rework'] = Variable<double>(rework);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  WorkcenterSchedulePeriodsCompanion toCompanion(bool nullToAbsent) {
    return WorkcenterSchedulePeriodsCompanion(
      id: Value(id),
      projectId: Value(projectId),
      workcenterId: Value(workcenterId),
      startDate: Value(startDate),
      endDate: Value(endDate),
      operatorsPerShift: Value(operatorsPerShift),
      availability: Value(availability),
      rework: Value(rework),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory WorkcenterSchedulePeriod.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkcenterSchedulePeriod(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String>(json['projectId']),
      workcenterId: serializer.fromJson<String>(json['workcenterId']),
      startDate: serializer.fromJson<DateTime>(json['startDate']),
      endDate: serializer.fromJson<DateTime>(json['endDate']),
      operatorsPerShift: serializer.fromJson<String>(json['operatorsPerShift']),
      availability: serializer.fromJson<double>(json['availability']),
      rework: serializer.fromJson<double>(json['rework']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String>(projectId),
      'workcenterId': serializer.toJson<String>(workcenterId),
      'startDate': serializer.toJson<DateTime>(startDate),
      'endDate': serializer.toJson<DateTime>(endDate),
      'operatorsPerShift': serializer.toJson<String>(operatorsPerShift),
      'availability': serializer.toJson<double>(availability),
      'rework': serializer.toJson<double>(rework),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  WorkcenterSchedulePeriod copyWith({
    String? id,
    String? projectId,
    String? workcenterId,
    DateTime? startDate,
    DateTime? endDate,
    String? operatorsPerShift,
    double? availability,
    double? rework,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => WorkcenterSchedulePeriod(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    workcenterId: workcenterId ?? this.workcenterId,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    operatorsPerShift: operatorsPerShift ?? this.operatorsPerShift,
    availability: availability ?? this.availability,
    rework: rework ?? this.rework,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  WorkcenterSchedulePeriod copyWithCompanion(
    WorkcenterSchedulePeriodsCompanion data,
  ) {
    return WorkcenterSchedulePeriod(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      workcenterId: data.workcenterId.present
          ? data.workcenterId.value
          : this.workcenterId,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      operatorsPerShift: data.operatorsPerShift.present
          ? data.operatorsPerShift.value
          : this.operatorsPerShift,
      availability: data.availability.present
          ? data.availability.value
          : this.availability,
      rework: data.rework.present ? data.rework.value : this.rework,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkcenterSchedulePeriod(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('workcenterId: $workcenterId, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('operatorsPerShift: $operatorsPerShift, ')
          ..write('availability: $availability, ')
          ..write('rework: $rework, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    projectId,
    workcenterId,
    startDate,
    endDate,
    operatorsPerShift,
    availability,
    rework,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkcenterSchedulePeriod &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.workcenterId == this.workcenterId &&
          other.startDate == this.startDate &&
          other.endDate == this.endDate &&
          other.operatorsPerShift == this.operatorsPerShift &&
          other.availability == this.availability &&
          other.rework == this.rework &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class WorkcenterSchedulePeriodsCompanion
    extends UpdateCompanion<WorkcenterSchedulePeriod> {
  final Value<String> id;
  final Value<String> projectId;
  final Value<String> workcenterId;
  final Value<DateTime> startDate;
  final Value<DateTime> endDate;
  final Value<String> operatorsPerShift;
  final Value<double> availability;
  final Value<double> rework;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const WorkcenterSchedulePeriodsCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.workcenterId = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.operatorsPerShift = const Value.absent(),
    this.availability = const Value.absent(),
    this.rework = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkcenterSchedulePeriodsCompanion.insert({
    required String id,
    required String projectId,
    required String workcenterId,
    required DateTime startDate,
    required DateTime endDate,
    required String operatorsPerShift,
    this.availability = const Value.absent(),
    this.rework = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       projectId = Value(projectId),
       workcenterId = Value(workcenterId),
       startDate = Value(startDate),
       endDate = Value(endDate),
       operatorsPerShift = Value(operatorsPerShift),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<WorkcenterSchedulePeriod> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<String>? workcenterId,
    Expression<DateTime>? startDate,
    Expression<DateTime>? endDate,
    Expression<String>? operatorsPerShift,
    Expression<double>? availability,
    Expression<double>? rework,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (workcenterId != null) 'workcenter_id': workcenterId,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (operatorsPerShift != null) 'operators_per_shift': operatorsPerShift,
      if (availability != null) 'availability': availability,
      if (rework != null) 'rework': rework,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkcenterSchedulePeriodsCompanion copyWith({
    Value<String>? id,
    Value<String>? projectId,
    Value<String>? workcenterId,
    Value<DateTime>? startDate,
    Value<DateTime>? endDate,
    Value<String>? operatorsPerShift,
    Value<double>? availability,
    Value<double>? rework,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return WorkcenterSchedulePeriodsCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      workcenterId: workcenterId ?? this.workcenterId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      operatorsPerShift: operatorsPerShift ?? this.operatorsPerShift,
      availability: availability ?? this.availability,
      rework: rework ?? this.rework,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (workcenterId.present) {
      map['workcenter_id'] = Variable<String>(workcenterId.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<DateTime>(startDate.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<DateTime>(endDate.value);
    }
    if (operatorsPerShift.present) {
      map['operators_per_shift'] = Variable<String>(operatorsPerShift.value);
    }
    if (availability.present) {
      map['availability'] = Variable<double>(availability.value);
    }
    if (rework.present) {
      map['rework'] = Variable<double>(rework.value);
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
    return (StringBuffer('WorkcenterSchedulePeriodsCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('workcenterId: $workcenterId, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('operatorsPerShift: $operatorsPerShift, ')
          ..write('availability: $availability, ')
          ..write('rework: $rework, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StudiesTable extends Studies with TableInfo<$StudiesTable, Study> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StudiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _productionCellIdMeta = const VerificationMeta(
    'productionCellId',
  );
  @override
  late final GeneratedColumn<String> productionCellId = GeneratedColumn<String>(
    'production_cell_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES production_cells (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _productionLineIdMeta = const VerificationMeta(
    'productionLineId',
  );
  @override
  late final GeneratedColumn<String> productionLineId = GeneratedColumn<String>(
    'production_line_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES production_lines (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 200,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _includeInSimulationMeta =
      const VerificationMeta('includeInSimulation');
  @override
  late final GeneratedColumn<bool> includeInSimulation = GeneratedColumn<bool>(
    'include_in_simulation',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("include_in_simulation" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(100),
  );
  static const VerificationMeta _wipCapMeta = const VerificationMeta('wipCap');
  @override
  late final GeneratedColumn<int> wipCap = GeneratedColumn<int>(
    'wip_cap',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _supplierNameMeta = const VerificationMeta(
    'supplierName',
  );
  @override
  late final GeneratedColumn<String> supplierName = GeneratedColumn<String>(
    'supplier_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _customerNameMeta = const VerificationMeta(
    'customerName',
  );
  @override
  late final GeneratedColumn<String> customerName = GeneratedColumn<String>(
    'customer_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
    id,
    projectId,
    productionCellId,
    productionLineId,
    name,
    includeInSimulation,
    priority,
    wipCap,
    supplierName,
    customerName,
    notes,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'studies';
  @override
  VerificationContext validateIntegrity(
    Insertable<Study> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('production_cell_id')) {
      context.handle(
        _productionCellIdMeta,
        productionCellId.isAcceptableOrUnknown(
          data['production_cell_id']!,
          _productionCellIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_productionCellIdMeta);
    }
    if (data.containsKey('production_line_id')) {
      context.handle(
        _productionLineIdMeta,
        productionLineId.isAcceptableOrUnknown(
          data['production_line_id']!,
          _productionLineIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_productionLineIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('include_in_simulation')) {
      context.handle(
        _includeInSimulationMeta,
        includeInSimulation.isAcceptableOrUnknown(
          data['include_in_simulation']!,
          _includeInSimulationMeta,
        ),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    if (data.containsKey('wip_cap')) {
      context.handle(
        _wipCapMeta,
        wipCap.isAcceptableOrUnknown(data['wip_cap']!, _wipCapMeta),
      );
    }
    if (data.containsKey('supplier_name')) {
      context.handle(
        _supplierNameMeta,
        supplierName.isAcceptableOrUnknown(
          data['supplier_name']!,
          _supplierNameMeta,
        ),
      );
    }
    if (data.containsKey('customer_name')) {
      context.handle(
        _customerNameMeta,
        customerName.isAcceptableOrUnknown(
          data['customer_name']!,
          _customerNameMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {projectId, name},
  ];
  @override
  Study map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Study(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      productionCellId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}production_cell_id'],
      )!,
      productionLineId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}production_line_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      includeInSimulation: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}include_in_simulation'],
      )!,
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      wipCap: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}wip_cap'],
      ),
      supplierName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}supplier_name'],
      ),
      customerName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_name'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
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
  $StudiesTable createAlias(String alias) {
    return $StudiesTable(attachedDatabase, alias);
  }
}

class Study extends DataClass implements Insertable<Study> {
  final String id;
  final String projectId;
  final String productionCellId;
  final String productionLineId;
  final String name;

  /// Whether this study takes part in the next simulation run. The project
  /// enforces at most one flagged study per line before a run.
  final bool includeInSimulation;

  /// Breaks dispatch ties between studies contending for a shared workcenter
  /// (DESIGN.md §7.4). Lower runs first.
  final int priority;

  /// CONWIP cap: maximum orders open in the flow at once. Null is unlimited,
  /// the default, so a first run shows raw demand-vs-capacity behaviour
  /// (DESIGN.md §7.3).
  final int? wipCap;

  /// Endpoint labels on the map. Stored on the study rather than as nodes:
  /// they carry no data and take part in no calculation, so a row for each
  /// would be a row that can only ever be renamed.
  final String? supplierName;
  final String? customerName;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Study({
    required this.id,
    required this.projectId,
    required this.productionCellId,
    required this.productionLineId,
    required this.name,
    required this.includeInSimulation,
    required this.priority,
    this.wipCap,
    this.supplierName,
    this.customerName,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['project_id'] = Variable<String>(projectId);
    map['production_cell_id'] = Variable<String>(productionCellId);
    map['production_line_id'] = Variable<String>(productionLineId);
    map['name'] = Variable<String>(name);
    map['include_in_simulation'] = Variable<bool>(includeInSimulation);
    map['priority'] = Variable<int>(priority);
    if (!nullToAbsent || wipCap != null) {
      map['wip_cap'] = Variable<int>(wipCap);
    }
    if (!nullToAbsent || supplierName != null) {
      map['supplier_name'] = Variable<String>(supplierName);
    }
    if (!nullToAbsent || customerName != null) {
      map['customer_name'] = Variable<String>(customerName);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  StudiesCompanion toCompanion(bool nullToAbsent) {
    return StudiesCompanion(
      id: Value(id),
      projectId: Value(projectId),
      productionCellId: Value(productionCellId),
      productionLineId: Value(productionLineId),
      name: Value(name),
      includeInSimulation: Value(includeInSimulation),
      priority: Value(priority),
      wipCap: wipCap == null && nullToAbsent
          ? const Value.absent()
          : Value(wipCap),
      supplierName: supplierName == null && nullToAbsent
          ? const Value.absent()
          : Value(supplierName),
      customerName: customerName == null && nullToAbsent
          ? const Value.absent()
          : Value(customerName),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Study.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Study(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String>(json['projectId']),
      productionCellId: serializer.fromJson<String>(json['productionCellId']),
      productionLineId: serializer.fromJson<String>(json['productionLineId']),
      name: serializer.fromJson<String>(json['name']),
      includeInSimulation: serializer.fromJson<bool>(
        json['includeInSimulation'],
      ),
      priority: serializer.fromJson<int>(json['priority']),
      wipCap: serializer.fromJson<int?>(json['wipCap']),
      supplierName: serializer.fromJson<String?>(json['supplierName']),
      customerName: serializer.fromJson<String?>(json['customerName']),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String>(projectId),
      'productionCellId': serializer.toJson<String>(productionCellId),
      'productionLineId': serializer.toJson<String>(productionLineId),
      'name': serializer.toJson<String>(name),
      'includeInSimulation': serializer.toJson<bool>(includeInSimulation),
      'priority': serializer.toJson<int>(priority),
      'wipCap': serializer.toJson<int?>(wipCap),
      'supplierName': serializer.toJson<String?>(supplierName),
      'customerName': serializer.toJson<String?>(customerName),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Study copyWith({
    String? id,
    String? projectId,
    String? productionCellId,
    String? productionLineId,
    String? name,
    bool? includeInSimulation,
    int? priority,
    Value<int?> wipCap = const Value.absent(),
    Value<String?> supplierName = const Value.absent(),
    Value<String?> customerName = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Study(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    productionCellId: productionCellId ?? this.productionCellId,
    productionLineId: productionLineId ?? this.productionLineId,
    name: name ?? this.name,
    includeInSimulation: includeInSimulation ?? this.includeInSimulation,
    priority: priority ?? this.priority,
    wipCap: wipCap.present ? wipCap.value : this.wipCap,
    supplierName: supplierName.present ? supplierName.value : this.supplierName,
    customerName: customerName.present ? customerName.value : this.customerName,
    notes: notes.present ? notes.value : this.notes,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Study copyWithCompanion(StudiesCompanion data) {
    return Study(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      productionCellId: data.productionCellId.present
          ? data.productionCellId.value
          : this.productionCellId,
      productionLineId: data.productionLineId.present
          ? data.productionLineId.value
          : this.productionLineId,
      name: data.name.present ? data.name.value : this.name,
      includeInSimulation: data.includeInSimulation.present
          ? data.includeInSimulation.value
          : this.includeInSimulation,
      priority: data.priority.present ? data.priority.value : this.priority,
      wipCap: data.wipCap.present ? data.wipCap.value : this.wipCap,
      supplierName: data.supplierName.present
          ? data.supplierName.value
          : this.supplierName,
      customerName: data.customerName.present
          ? data.customerName.value
          : this.customerName,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Study(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('productionCellId: $productionCellId, ')
          ..write('productionLineId: $productionLineId, ')
          ..write('name: $name, ')
          ..write('includeInSimulation: $includeInSimulation, ')
          ..write('priority: $priority, ')
          ..write('wipCap: $wipCap, ')
          ..write('supplierName: $supplierName, ')
          ..write('customerName: $customerName, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    projectId,
    productionCellId,
    productionLineId,
    name,
    includeInSimulation,
    priority,
    wipCap,
    supplierName,
    customerName,
    notes,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Study &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.productionCellId == this.productionCellId &&
          other.productionLineId == this.productionLineId &&
          other.name == this.name &&
          other.includeInSimulation == this.includeInSimulation &&
          other.priority == this.priority &&
          other.wipCap == this.wipCap &&
          other.supplierName == this.supplierName &&
          other.customerName == this.customerName &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class StudiesCompanion extends UpdateCompanion<Study> {
  final Value<String> id;
  final Value<String> projectId;
  final Value<String> productionCellId;
  final Value<String> productionLineId;
  final Value<String> name;
  final Value<bool> includeInSimulation;
  final Value<int> priority;
  final Value<int?> wipCap;
  final Value<String?> supplierName;
  final Value<String?> customerName;
  final Value<String?> notes;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const StudiesCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.productionCellId = const Value.absent(),
    this.productionLineId = const Value.absent(),
    this.name = const Value.absent(),
    this.includeInSimulation = const Value.absent(),
    this.priority = const Value.absent(),
    this.wipCap = const Value.absent(),
    this.supplierName = const Value.absent(),
    this.customerName = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StudiesCompanion.insert({
    required String id,
    required String projectId,
    required String productionCellId,
    required String productionLineId,
    required String name,
    this.includeInSimulation = const Value.absent(),
    this.priority = const Value.absent(),
    this.wipCap = const Value.absent(),
    this.supplierName = const Value.absent(),
    this.customerName = const Value.absent(),
    this.notes = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       projectId = Value(projectId),
       productionCellId = Value(productionCellId),
       productionLineId = Value(productionLineId),
       name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Study> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<String>? productionCellId,
    Expression<String>? productionLineId,
    Expression<String>? name,
    Expression<bool>? includeInSimulation,
    Expression<int>? priority,
    Expression<int>? wipCap,
    Expression<String>? supplierName,
    Expression<String>? customerName,
    Expression<String>? notes,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (productionCellId != null) 'production_cell_id': productionCellId,
      if (productionLineId != null) 'production_line_id': productionLineId,
      if (name != null) 'name': name,
      if (includeInSimulation != null)
        'include_in_simulation': includeInSimulation,
      if (priority != null) 'priority': priority,
      if (wipCap != null) 'wip_cap': wipCap,
      if (supplierName != null) 'supplier_name': supplierName,
      if (customerName != null) 'customer_name': customerName,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StudiesCompanion copyWith({
    Value<String>? id,
    Value<String>? projectId,
    Value<String>? productionCellId,
    Value<String>? productionLineId,
    Value<String>? name,
    Value<bool>? includeInSimulation,
    Value<int>? priority,
    Value<int?>? wipCap,
    Value<String?>? supplierName,
    Value<String?>? customerName,
    Value<String?>? notes,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return StudiesCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      productionCellId: productionCellId ?? this.productionCellId,
      productionLineId: productionLineId ?? this.productionLineId,
      name: name ?? this.name,
      includeInSimulation: includeInSimulation ?? this.includeInSimulation,
      priority: priority ?? this.priority,
      wipCap: wipCap ?? this.wipCap,
      supplierName: supplierName ?? this.supplierName,
      customerName: customerName ?? this.customerName,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (productionCellId.present) {
      map['production_cell_id'] = Variable<String>(productionCellId.value);
    }
    if (productionLineId.present) {
      map['production_line_id'] = Variable<String>(productionLineId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (includeInSimulation.present) {
      map['include_in_simulation'] = Variable<bool>(includeInSimulation.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (wipCap.present) {
      map['wip_cap'] = Variable<int>(wipCap.value);
    }
    if (supplierName.present) {
      map['supplier_name'] = Variable<String>(supplierName.value);
    }
    if (customerName.present) {
      map['customer_name'] = Variable<String>(customerName.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
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
    return (StringBuffer('StudiesCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('productionCellId: $productionCellId, ')
          ..write('productionLineId: $productionLineId, ')
          ..write('name: $name, ')
          ..write('includeInSimulation: $includeInSimulation, ')
          ..write('priority: $priority, ')
          ..write('wipCap: $wipCap, ')
          ..write('supplierName: $supplierName, ')
          ..write('customerName: $customerName, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FlowNodesTable extends FlowNodes
    with TableInfo<$FlowNodesTable, FlowNode> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FlowNodesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _studyIdMeta = const VerificationMeta(
    'studyId',
  );
  @override
  late final GeneratedColumn<String> studyId = GeneratedColumn<String>(
    'study_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES studies (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<FlowNodeKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<FlowNodeKind>($FlowNodesTable.$converterkind);
  static const VerificationMeta _workcenterIdMeta = const VerificationMeta(
    'workcenterId',
  );
  @override
  late final GeneratedColumn<String> workcenterId = GeneratedColumn<String>(
    'workcenter_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES workcenters (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _poolIdMeta = const VerificationMeta('poolId');
  @override
  late final GeneratedColumn<String> poolId = GeneratedColumn<String>(
    'pool_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES workcenter_pools (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _changeoverSecondsMeta = const VerificationMeta(
    'changeoverSeconds',
  );
  @override
  late final GeneratedColumn<int> changeoverSeconds = GeneratedColumn<int>(
    'changeover_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _equivalentValueMeta = const VerificationMeta(
    'equivalentValue',
  );
  @override
  late final GeneratedColumn<double> equivalentValue = GeneratedColumn<double>(
    'equivalent_value',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<TaktUnit?, String>
  equivalentUnit = GeneratedColumn<String>(
    'equivalent_unit',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  ).withConverter<TaktUnit?>($FlowNodesTable.$converterequivalentUnitn);
  @override
  late final GeneratedColumnWithTypeConverter<InventoryMode?, String>
  inventoryMode = GeneratedColumn<String>(
    'inventory_mode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  ).withConverter<InventoryMode?>($FlowNodesTable.$converterinventoryModen);
  static const VerificationMeta _inventoryQuantityMeta = const VerificationMeta(
    'inventoryQuantity',
  );
  @override
  late final GeneratedColumn<int> inventoryQuantity = GeneratedColumn<int>(
    'inventory_quantity',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _inventorySecondsMeta = const VerificationMeta(
    'inventorySeconds',
  );
  @override
  late final GeneratedColumn<int> inventorySeconds = GeneratedColumn<int>(
    'inventory_seconds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DurationUnit?, String>
  inventoryUnit = GeneratedColumn<String>(
    'inventory_unit',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  ).withConverter<DurationUnit?>($FlowNodesTable.$converterinventoryUnitn);
  static const VerificationMeta _inventoryUsesWorkingTimeMeta =
      const VerificationMeta('inventoryUsesWorkingTime');
  @override
  late final GeneratedColumn<bool> inventoryUsesWorkingTime =
      GeneratedColumn<bool>(
        'inventory_uses_working_time',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("inventory_uses_working_time" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
      );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
    id,
    studyId,
    position,
    kind,
    workcenterId,
    poolId,
    changeoverSeconds,
    equivalentValue,
    equivalentUnit,
    inventoryMode,
    inventoryQuantity,
    inventorySeconds,
    inventoryUnit,
    inventoryUsesWorkingTime,
    label,
    notes,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'flow_nodes';
  @override
  VerificationContext validateIntegrity(
    Insertable<FlowNode> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('study_id')) {
      context.handle(
        _studyIdMeta,
        studyId.isAcceptableOrUnknown(data['study_id']!, _studyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_studyIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('workcenter_id')) {
      context.handle(
        _workcenterIdMeta,
        workcenterId.isAcceptableOrUnknown(
          data['workcenter_id']!,
          _workcenterIdMeta,
        ),
      );
    }
    if (data.containsKey('pool_id')) {
      context.handle(
        _poolIdMeta,
        poolId.isAcceptableOrUnknown(data['pool_id']!, _poolIdMeta),
      );
    }
    if (data.containsKey('changeover_seconds')) {
      context.handle(
        _changeoverSecondsMeta,
        changeoverSeconds.isAcceptableOrUnknown(
          data['changeover_seconds']!,
          _changeoverSecondsMeta,
        ),
      );
    }
    if (data.containsKey('equivalent_value')) {
      context.handle(
        _equivalentValueMeta,
        equivalentValue.isAcceptableOrUnknown(
          data['equivalent_value']!,
          _equivalentValueMeta,
        ),
      );
    }
    if (data.containsKey('inventory_quantity')) {
      context.handle(
        _inventoryQuantityMeta,
        inventoryQuantity.isAcceptableOrUnknown(
          data['inventory_quantity']!,
          _inventoryQuantityMeta,
        ),
      );
    }
    if (data.containsKey('inventory_seconds')) {
      context.handle(
        _inventorySecondsMeta,
        inventorySeconds.isAcceptableOrUnknown(
          data['inventory_seconds']!,
          _inventorySecondsMeta,
        ),
      );
    }
    if (data.containsKey('inventory_uses_working_time')) {
      context.handle(
        _inventoryUsesWorkingTimeMeta,
        inventoryUsesWorkingTime.isAcceptableOrUnknown(
          data['inventory_uses_working_time']!,
          _inventoryUsesWorkingTimeMeta,
        ),
      );
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {studyId, position},
  ];
  @override
  FlowNode map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FlowNode(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      studyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}study_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      kind: $FlowNodesTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      workcenterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}workcenter_id'],
      ),
      poolId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pool_id'],
      ),
      changeoverSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}changeover_seconds'],
      )!,
      equivalentValue: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}equivalent_value'],
      ),
      equivalentUnit: $FlowNodesTable.$converterequivalentUnitn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}equivalent_unit'],
        ),
      ),
      inventoryMode: $FlowNodesTable.$converterinventoryModen.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}inventory_mode'],
        ),
      ),
      inventoryQuantity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}inventory_quantity'],
      ),
      inventorySeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}inventory_seconds'],
      ),
      inventoryUnit: $FlowNodesTable.$converterinventoryUnitn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}inventory_unit'],
        ),
      ),
      inventoryUsesWorkingTime: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}inventory_uses_working_time'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
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
  $FlowNodesTable createAlias(String alias) {
    return $FlowNodesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<FlowNodeKind, String, String> $converterkind =
      const EnumNameConverter<FlowNodeKind>(FlowNodeKind.values);
  static JsonTypeConverter2<TaktUnit, String, String> $converterequivalentUnit =
      const EnumNameConverter<TaktUnit>(TaktUnit.values);
  static JsonTypeConverter2<TaktUnit?, String?, String?>
  $converterequivalentUnitn = JsonTypeConverter2.asNullable(
    $converterequivalentUnit,
  );
  static JsonTypeConverter2<InventoryMode, String, String>
  $converterinventoryMode = const EnumNameConverter<InventoryMode>(
    InventoryMode.values,
  );
  static JsonTypeConverter2<InventoryMode?, String?, String?>
  $converterinventoryModen = JsonTypeConverter2.asNullable(
    $converterinventoryMode,
  );
  static JsonTypeConverter2<DurationUnit, String, String>
  $converterinventoryUnit = const EnumNameConverter<DurationUnit>(
    DurationUnit.values,
  );
  static JsonTypeConverter2<DurationUnit?, String?, String?>
  $converterinventoryUnitn = JsonTypeConverter2.asNullable(
    $converterinventoryUnit,
  );
}

class FlowNode extends DataClass implements Insertable<FlowNode> {
  final String id;
  final String studyId;

  /// Order along the spine, renumbered densely on every structural edit. This
  /// is the single source of truth for sequence — the layout is derived from
  /// it, so the drawing can never disagree with the routing.
  final int position;
  final FlowNodeKind kind;

  /// Exactly one of these is set on a step, and both are null on an inventory
  /// node. Enforced by the repository and reported by the readiness panel; two
  /// nullable references cannot express "exactly one" in SQLite.
  final String? workcenterId;
  final String? poolId;

  /// Setup charged when the previous order on this workcenter was a different
  /// part number (DESIGN.md §7.6).
  final int changeoverSeconds;

  /// The flow equivalent's process time at this step, overriding one takt
  /// (DESIGN.md §6.1).
  ///
  /// A property of the **yardstick**, not of the station: an inspection that
  /// genuinely takes a fraction of a takt would otherwise drag every real
  /// part's equivalence at that step toward zero and skew the balance measure.
  /// Null follows the line's takt, which is the usual case.
  ///
  /// Stored as a value plus a [TaktUnit] — not a canonical duration — for the
  /// same reason takt is: `days` here means productive days of *this* station.
  final double? equivalentValue;
  final TaktUnit? equivalentUnit;
  final InventoryMode? inventoryMode;

  /// Pieces waiting, for [InventoryMode.quantity]. Displayed as days through
  /// the takt of the period being viewed.
  final int? inventoryQuantity;

  /// Fixed wait, for [InventoryMode.duration]. Canonical seconds.
  final int? inventorySeconds;

  /// The unit that wait was typed in, so `2 days` reads back as `2 days` rather
  /// than `48 h`. Display only — every calculation uses [inventorySeconds],
  /// because unlike a takt this unit needs no workcenter to resolve.
  final DurationUnit? inventoryUnit;

  /// Whether a duration buffer is consumed in working time or on the wall
  /// clock. A cooling rack does not stop for the weekend; a manual inspection
  /// queue does.
  final bool inventoryUsesWorkingTime;
  final String? label;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  const FlowNode({
    required this.id,
    required this.studyId,
    required this.position,
    required this.kind,
    this.workcenterId,
    this.poolId,
    required this.changeoverSeconds,
    this.equivalentValue,
    this.equivalentUnit,
    this.inventoryMode,
    this.inventoryQuantity,
    this.inventorySeconds,
    this.inventoryUnit,
    required this.inventoryUsesWorkingTime,
    this.label,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['study_id'] = Variable<String>(studyId);
    map['position'] = Variable<int>(position);
    {
      map['kind'] = Variable<String>(
        $FlowNodesTable.$converterkind.toSql(kind),
      );
    }
    if (!nullToAbsent || workcenterId != null) {
      map['workcenter_id'] = Variable<String>(workcenterId);
    }
    if (!nullToAbsent || poolId != null) {
      map['pool_id'] = Variable<String>(poolId);
    }
    map['changeover_seconds'] = Variable<int>(changeoverSeconds);
    if (!nullToAbsent || equivalentValue != null) {
      map['equivalent_value'] = Variable<double>(equivalentValue);
    }
    if (!nullToAbsent || equivalentUnit != null) {
      map['equivalent_unit'] = Variable<String>(
        $FlowNodesTable.$converterequivalentUnitn.toSql(equivalentUnit),
      );
    }
    if (!nullToAbsent || inventoryMode != null) {
      map['inventory_mode'] = Variable<String>(
        $FlowNodesTable.$converterinventoryModen.toSql(inventoryMode),
      );
    }
    if (!nullToAbsent || inventoryQuantity != null) {
      map['inventory_quantity'] = Variable<int>(inventoryQuantity);
    }
    if (!nullToAbsent || inventorySeconds != null) {
      map['inventory_seconds'] = Variable<int>(inventorySeconds);
    }
    if (!nullToAbsent || inventoryUnit != null) {
      map['inventory_unit'] = Variable<String>(
        $FlowNodesTable.$converterinventoryUnitn.toSql(inventoryUnit),
      );
    }
    map['inventory_uses_working_time'] = Variable<bool>(
      inventoryUsesWorkingTime,
    );
    if (!nullToAbsent || label != null) {
      map['label'] = Variable<String>(label);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  FlowNodesCompanion toCompanion(bool nullToAbsent) {
    return FlowNodesCompanion(
      id: Value(id),
      studyId: Value(studyId),
      position: Value(position),
      kind: Value(kind),
      workcenterId: workcenterId == null && nullToAbsent
          ? const Value.absent()
          : Value(workcenterId),
      poolId: poolId == null && nullToAbsent
          ? const Value.absent()
          : Value(poolId),
      changeoverSeconds: Value(changeoverSeconds),
      equivalentValue: equivalentValue == null && nullToAbsent
          ? const Value.absent()
          : Value(equivalentValue),
      equivalentUnit: equivalentUnit == null && nullToAbsent
          ? const Value.absent()
          : Value(equivalentUnit),
      inventoryMode: inventoryMode == null && nullToAbsent
          ? const Value.absent()
          : Value(inventoryMode),
      inventoryQuantity: inventoryQuantity == null && nullToAbsent
          ? const Value.absent()
          : Value(inventoryQuantity),
      inventorySeconds: inventorySeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(inventorySeconds),
      inventoryUnit: inventoryUnit == null && nullToAbsent
          ? const Value.absent()
          : Value(inventoryUnit),
      inventoryUsesWorkingTime: Value(inventoryUsesWorkingTime),
      label: label == null && nullToAbsent
          ? const Value.absent()
          : Value(label),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory FlowNode.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FlowNode(
      id: serializer.fromJson<String>(json['id']),
      studyId: serializer.fromJson<String>(json['studyId']),
      position: serializer.fromJson<int>(json['position']),
      kind: $FlowNodesTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      workcenterId: serializer.fromJson<String?>(json['workcenterId']),
      poolId: serializer.fromJson<String?>(json['poolId']),
      changeoverSeconds: serializer.fromJson<int>(json['changeoverSeconds']),
      equivalentValue: serializer.fromJson<double?>(json['equivalentValue']),
      equivalentUnit: $FlowNodesTable.$converterequivalentUnitn.fromJson(
        serializer.fromJson<String?>(json['equivalentUnit']),
      ),
      inventoryMode: $FlowNodesTable.$converterinventoryModen.fromJson(
        serializer.fromJson<String?>(json['inventoryMode']),
      ),
      inventoryQuantity: serializer.fromJson<int?>(json['inventoryQuantity']),
      inventorySeconds: serializer.fromJson<int?>(json['inventorySeconds']),
      inventoryUnit: $FlowNodesTable.$converterinventoryUnitn.fromJson(
        serializer.fromJson<String?>(json['inventoryUnit']),
      ),
      inventoryUsesWorkingTime: serializer.fromJson<bool>(
        json['inventoryUsesWorkingTime'],
      ),
      label: serializer.fromJson<String?>(json['label']),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'studyId': serializer.toJson<String>(studyId),
      'position': serializer.toJson<int>(position),
      'kind': serializer.toJson<String>(
        $FlowNodesTable.$converterkind.toJson(kind),
      ),
      'workcenterId': serializer.toJson<String?>(workcenterId),
      'poolId': serializer.toJson<String?>(poolId),
      'changeoverSeconds': serializer.toJson<int>(changeoverSeconds),
      'equivalentValue': serializer.toJson<double?>(equivalentValue),
      'equivalentUnit': serializer.toJson<String?>(
        $FlowNodesTable.$converterequivalentUnitn.toJson(equivalentUnit),
      ),
      'inventoryMode': serializer.toJson<String?>(
        $FlowNodesTable.$converterinventoryModen.toJson(inventoryMode),
      ),
      'inventoryQuantity': serializer.toJson<int?>(inventoryQuantity),
      'inventorySeconds': serializer.toJson<int?>(inventorySeconds),
      'inventoryUnit': serializer.toJson<String?>(
        $FlowNodesTable.$converterinventoryUnitn.toJson(inventoryUnit),
      ),
      'inventoryUsesWorkingTime': serializer.toJson<bool>(
        inventoryUsesWorkingTime,
      ),
      'label': serializer.toJson<String?>(label),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  FlowNode copyWith({
    String? id,
    String? studyId,
    int? position,
    FlowNodeKind? kind,
    Value<String?> workcenterId = const Value.absent(),
    Value<String?> poolId = const Value.absent(),
    int? changeoverSeconds,
    Value<double?> equivalentValue = const Value.absent(),
    Value<TaktUnit?> equivalentUnit = const Value.absent(),
    Value<InventoryMode?> inventoryMode = const Value.absent(),
    Value<int?> inventoryQuantity = const Value.absent(),
    Value<int?> inventorySeconds = const Value.absent(),
    Value<DurationUnit?> inventoryUnit = const Value.absent(),
    bool? inventoryUsesWorkingTime,
    Value<String?> label = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => FlowNode(
    id: id ?? this.id,
    studyId: studyId ?? this.studyId,
    position: position ?? this.position,
    kind: kind ?? this.kind,
    workcenterId: workcenterId.present ? workcenterId.value : this.workcenterId,
    poolId: poolId.present ? poolId.value : this.poolId,
    changeoverSeconds: changeoverSeconds ?? this.changeoverSeconds,
    equivalentValue: equivalentValue.present
        ? equivalentValue.value
        : this.equivalentValue,
    equivalentUnit: equivalentUnit.present
        ? equivalentUnit.value
        : this.equivalentUnit,
    inventoryMode: inventoryMode.present
        ? inventoryMode.value
        : this.inventoryMode,
    inventoryQuantity: inventoryQuantity.present
        ? inventoryQuantity.value
        : this.inventoryQuantity,
    inventorySeconds: inventorySeconds.present
        ? inventorySeconds.value
        : this.inventorySeconds,
    inventoryUnit: inventoryUnit.present
        ? inventoryUnit.value
        : this.inventoryUnit,
    inventoryUsesWorkingTime:
        inventoryUsesWorkingTime ?? this.inventoryUsesWorkingTime,
    label: label.present ? label.value : this.label,
    notes: notes.present ? notes.value : this.notes,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  FlowNode copyWithCompanion(FlowNodesCompanion data) {
    return FlowNode(
      id: data.id.present ? data.id.value : this.id,
      studyId: data.studyId.present ? data.studyId.value : this.studyId,
      position: data.position.present ? data.position.value : this.position,
      kind: data.kind.present ? data.kind.value : this.kind,
      workcenterId: data.workcenterId.present
          ? data.workcenterId.value
          : this.workcenterId,
      poolId: data.poolId.present ? data.poolId.value : this.poolId,
      changeoverSeconds: data.changeoverSeconds.present
          ? data.changeoverSeconds.value
          : this.changeoverSeconds,
      equivalentValue: data.equivalentValue.present
          ? data.equivalentValue.value
          : this.equivalentValue,
      equivalentUnit: data.equivalentUnit.present
          ? data.equivalentUnit.value
          : this.equivalentUnit,
      inventoryMode: data.inventoryMode.present
          ? data.inventoryMode.value
          : this.inventoryMode,
      inventoryQuantity: data.inventoryQuantity.present
          ? data.inventoryQuantity.value
          : this.inventoryQuantity,
      inventorySeconds: data.inventorySeconds.present
          ? data.inventorySeconds.value
          : this.inventorySeconds,
      inventoryUnit: data.inventoryUnit.present
          ? data.inventoryUnit.value
          : this.inventoryUnit,
      inventoryUsesWorkingTime: data.inventoryUsesWorkingTime.present
          ? data.inventoryUsesWorkingTime.value
          : this.inventoryUsesWorkingTime,
      label: data.label.present ? data.label.value : this.label,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FlowNode(')
          ..write('id: $id, ')
          ..write('studyId: $studyId, ')
          ..write('position: $position, ')
          ..write('kind: $kind, ')
          ..write('workcenterId: $workcenterId, ')
          ..write('poolId: $poolId, ')
          ..write('changeoverSeconds: $changeoverSeconds, ')
          ..write('equivalentValue: $equivalentValue, ')
          ..write('equivalentUnit: $equivalentUnit, ')
          ..write('inventoryMode: $inventoryMode, ')
          ..write('inventoryQuantity: $inventoryQuantity, ')
          ..write('inventorySeconds: $inventorySeconds, ')
          ..write('inventoryUnit: $inventoryUnit, ')
          ..write('inventoryUsesWorkingTime: $inventoryUsesWorkingTime, ')
          ..write('label: $label, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    studyId,
    position,
    kind,
    workcenterId,
    poolId,
    changeoverSeconds,
    equivalentValue,
    equivalentUnit,
    inventoryMode,
    inventoryQuantity,
    inventorySeconds,
    inventoryUnit,
    inventoryUsesWorkingTime,
    label,
    notes,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FlowNode &&
          other.id == this.id &&
          other.studyId == this.studyId &&
          other.position == this.position &&
          other.kind == this.kind &&
          other.workcenterId == this.workcenterId &&
          other.poolId == this.poolId &&
          other.changeoverSeconds == this.changeoverSeconds &&
          other.equivalentValue == this.equivalentValue &&
          other.equivalentUnit == this.equivalentUnit &&
          other.inventoryMode == this.inventoryMode &&
          other.inventoryQuantity == this.inventoryQuantity &&
          other.inventorySeconds == this.inventorySeconds &&
          other.inventoryUnit == this.inventoryUnit &&
          other.inventoryUsesWorkingTime == this.inventoryUsesWorkingTime &&
          other.label == this.label &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class FlowNodesCompanion extends UpdateCompanion<FlowNode> {
  final Value<String> id;
  final Value<String> studyId;
  final Value<int> position;
  final Value<FlowNodeKind> kind;
  final Value<String?> workcenterId;
  final Value<String?> poolId;
  final Value<int> changeoverSeconds;
  final Value<double?> equivalentValue;
  final Value<TaktUnit?> equivalentUnit;
  final Value<InventoryMode?> inventoryMode;
  final Value<int?> inventoryQuantity;
  final Value<int?> inventorySeconds;
  final Value<DurationUnit?> inventoryUnit;
  final Value<bool> inventoryUsesWorkingTime;
  final Value<String?> label;
  final Value<String?> notes;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const FlowNodesCompanion({
    this.id = const Value.absent(),
    this.studyId = const Value.absent(),
    this.position = const Value.absent(),
    this.kind = const Value.absent(),
    this.workcenterId = const Value.absent(),
    this.poolId = const Value.absent(),
    this.changeoverSeconds = const Value.absent(),
    this.equivalentValue = const Value.absent(),
    this.equivalentUnit = const Value.absent(),
    this.inventoryMode = const Value.absent(),
    this.inventoryQuantity = const Value.absent(),
    this.inventorySeconds = const Value.absent(),
    this.inventoryUnit = const Value.absent(),
    this.inventoryUsesWorkingTime = const Value.absent(),
    this.label = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FlowNodesCompanion.insert({
    required String id,
    required String studyId,
    required int position,
    required FlowNodeKind kind,
    this.workcenterId = const Value.absent(),
    this.poolId = const Value.absent(),
    this.changeoverSeconds = const Value.absent(),
    this.equivalentValue = const Value.absent(),
    this.equivalentUnit = const Value.absent(),
    this.inventoryMode = const Value.absent(),
    this.inventoryQuantity = const Value.absent(),
    this.inventorySeconds = const Value.absent(),
    this.inventoryUnit = const Value.absent(),
    this.inventoryUsesWorkingTime = const Value.absent(),
    this.label = const Value.absent(),
    this.notes = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       studyId = Value(studyId),
       position = Value(position),
       kind = Value(kind),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<FlowNode> custom({
    Expression<String>? id,
    Expression<String>? studyId,
    Expression<int>? position,
    Expression<String>? kind,
    Expression<String>? workcenterId,
    Expression<String>? poolId,
    Expression<int>? changeoverSeconds,
    Expression<double>? equivalentValue,
    Expression<String>? equivalentUnit,
    Expression<String>? inventoryMode,
    Expression<int>? inventoryQuantity,
    Expression<int>? inventorySeconds,
    Expression<String>? inventoryUnit,
    Expression<bool>? inventoryUsesWorkingTime,
    Expression<String>? label,
    Expression<String>? notes,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (studyId != null) 'study_id': studyId,
      if (position != null) 'position': position,
      if (kind != null) 'kind': kind,
      if (workcenterId != null) 'workcenter_id': workcenterId,
      if (poolId != null) 'pool_id': poolId,
      if (changeoverSeconds != null) 'changeover_seconds': changeoverSeconds,
      if (equivalentValue != null) 'equivalent_value': equivalentValue,
      if (equivalentUnit != null) 'equivalent_unit': equivalentUnit,
      if (inventoryMode != null) 'inventory_mode': inventoryMode,
      if (inventoryQuantity != null) 'inventory_quantity': inventoryQuantity,
      if (inventorySeconds != null) 'inventory_seconds': inventorySeconds,
      if (inventoryUnit != null) 'inventory_unit': inventoryUnit,
      if (inventoryUsesWorkingTime != null)
        'inventory_uses_working_time': inventoryUsesWorkingTime,
      if (label != null) 'label': label,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FlowNodesCompanion copyWith({
    Value<String>? id,
    Value<String>? studyId,
    Value<int>? position,
    Value<FlowNodeKind>? kind,
    Value<String?>? workcenterId,
    Value<String?>? poolId,
    Value<int>? changeoverSeconds,
    Value<double?>? equivalentValue,
    Value<TaktUnit?>? equivalentUnit,
    Value<InventoryMode?>? inventoryMode,
    Value<int?>? inventoryQuantity,
    Value<int?>? inventorySeconds,
    Value<DurationUnit?>? inventoryUnit,
    Value<bool>? inventoryUsesWorkingTime,
    Value<String?>? label,
    Value<String?>? notes,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return FlowNodesCompanion(
      id: id ?? this.id,
      studyId: studyId ?? this.studyId,
      position: position ?? this.position,
      kind: kind ?? this.kind,
      workcenterId: workcenterId ?? this.workcenterId,
      poolId: poolId ?? this.poolId,
      changeoverSeconds: changeoverSeconds ?? this.changeoverSeconds,
      equivalentValue: equivalentValue ?? this.equivalentValue,
      equivalentUnit: equivalentUnit ?? this.equivalentUnit,
      inventoryMode: inventoryMode ?? this.inventoryMode,
      inventoryQuantity: inventoryQuantity ?? this.inventoryQuantity,
      inventorySeconds: inventorySeconds ?? this.inventorySeconds,
      inventoryUnit: inventoryUnit ?? this.inventoryUnit,
      inventoryUsesWorkingTime:
          inventoryUsesWorkingTime ?? this.inventoryUsesWorkingTime,
      label: label ?? this.label,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (studyId.present) {
      map['study_id'] = Variable<String>(studyId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $FlowNodesTable.$converterkind.toSql(kind.value),
      );
    }
    if (workcenterId.present) {
      map['workcenter_id'] = Variable<String>(workcenterId.value);
    }
    if (poolId.present) {
      map['pool_id'] = Variable<String>(poolId.value);
    }
    if (changeoverSeconds.present) {
      map['changeover_seconds'] = Variable<int>(changeoverSeconds.value);
    }
    if (equivalentValue.present) {
      map['equivalent_value'] = Variable<double>(equivalentValue.value);
    }
    if (equivalentUnit.present) {
      map['equivalent_unit'] = Variable<String>(
        $FlowNodesTable.$converterequivalentUnitn.toSql(equivalentUnit.value),
      );
    }
    if (inventoryMode.present) {
      map['inventory_mode'] = Variable<String>(
        $FlowNodesTable.$converterinventoryModen.toSql(inventoryMode.value),
      );
    }
    if (inventoryQuantity.present) {
      map['inventory_quantity'] = Variable<int>(inventoryQuantity.value);
    }
    if (inventorySeconds.present) {
      map['inventory_seconds'] = Variable<int>(inventorySeconds.value);
    }
    if (inventoryUnit.present) {
      map['inventory_unit'] = Variable<String>(
        $FlowNodesTable.$converterinventoryUnitn.toSql(inventoryUnit.value),
      );
    }
    if (inventoryUsesWorkingTime.present) {
      map['inventory_uses_working_time'] = Variable<bool>(
        inventoryUsesWorkingTime.value,
      );
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
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
    return (StringBuffer('FlowNodesCompanion(')
          ..write('id: $id, ')
          ..write('studyId: $studyId, ')
          ..write('position: $position, ')
          ..write('kind: $kind, ')
          ..write('workcenterId: $workcenterId, ')
          ..write('poolId: $poolId, ')
          ..write('changeoverSeconds: $changeoverSeconds, ')
          ..write('equivalentValue: $equivalentValue, ')
          ..write('equivalentUnit: $equivalentUnit, ')
          ..write('inventoryMode: $inventoryMode, ')
          ..write('inventoryQuantity: $inventoryQuantity, ')
          ..write('inventorySeconds: $inventorySeconds, ')
          ..write('inventoryUnit: $inventoryUnit, ')
          ..write('inventoryUsesWorkingTime: $inventoryUsesWorkingTime, ')
          ..write('label: $label, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FlowAnnotationsTable extends FlowAnnotations
    with TableInfo<$FlowAnnotationsTable, FlowAnnotation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FlowAnnotationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _studyIdMeta = const VerificationMeta(
    'studyId',
  );
  @override
  late final GeneratedColumn<String> studyId = GeneratedColumn<String>(
    'study_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES studies (id) ON DELETE CASCADE',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<AnnotationSymbol, String> symbol =
      GeneratedColumn<String>(
        'symbol',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<AnnotationSymbol>($FlowAnnotationsTable.$convertersymbol);
  static const VerificationMeta _xMeta = const VerificationMeta('x');
  @override
  late final GeneratedColumn<double> x = GeneratedColumn<double>(
    'x',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _yMeta = const VerificationMeta('y');
  @override
  late final GeneratedColumn<double> y = GeneratedColumn<double>(
    'y',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _captionMeta = const VerificationMeta(
    'caption',
  );
  @override
  late final GeneratedColumn<String> caption = GeneratedColumn<String>(
    'caption',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
    id,
    studyId,
    symbol,
    x,
    y,
    caption,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'flow_annotations';
  @override
  VerificationContext validateIntegrity(
    Insertable<FlowAnnotation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('study_id')) {
      context.handle(
        _studyIdMeta,
        studyId.isAcceptableOrUnknown(data['study_id']!, _studyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_studyIdMeta);
    }
    if (data.containsKey('x')) {
      context.handle(_xMeta, x.isAcceptableOrUnknown(data['x']!, _xMeta));
    } else if (isInserting) {
      context.missing(_xMeta);
    }
    if (data.containsKey('y')) {
      context.handle(_yMeta, y.isAcceptableOrUnknown(data['y']!, _yMeta));
    } else if (isInserting) {
      context.missing(_yMeta);
    }
    if (data.containsKey('caption')) {
      context.handle(
        _captionMeta,
        caption.isAcceptableOrUnknown(data['caption']!, _captionMeta),
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FlowAnnotation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FlowAnnotation(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      studyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}study_id'],
      )!,
      symbol: $FlowAnnotationsTable.$convertersymbol.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}symbol'],
        )!,
      ),
      x: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}x'],
      )!,
      y: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}y'],
      )!,
      caption: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}caption'],
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
  $FlowAnnotationsTable createAlias(String alias) {
    return $FlowAnnotationsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<AnnotationSymbol, String, String> $convertersymbol =
      const EnumNameConverter<AnnotationSymbol>(AnnotationSymbol.values);
}

class FlowAnnotation extends DataClass implements Insertable<FlowAnnotation> {
  final String id;
  final String studyId;
  final AnnotationSymbol symbol;

  /// Canvas coordinates in logical pixels, relative to the spine's origin so
  /// an annotation stays beside the step it comments on when the map is zoomed
  /// or exported.
  final double x;
  final double y;

  /// The words on a note or a kaizen burst. Named `caption` rather than `text`
  /// because `Table.text()` is Drift's column builder.
  final String? caption;
  final DateTime createdAt;
  final DateTime updatedAt;
  const FlowAnnotation({
    required this.id,
    required this.studyId,
    required this.symbol,
    required this.x,
    required this.y,
    this.caption,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['study_id'] = Variable<String>(studyId);
    {
      map['symbol'] = Variable<String>(
        $FlowAnnotationsTable.$convertersymbol.toSql(symbol),
      );
    }
    map['x'] = Variable<double>(x);
    map['y'] = Variable<double>(y);
    if (!nullToAbsent || caption != null) {
      map['caption'] = Variable<String>(caption);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  FlowAnnotationsCompanion toCompanion(bool nullToAbsent) {
    return FlowAnnotationsCompanion(
      id: Value(id),
      studyId: Value(studyId),
      symbol: Value(symbol),
      x: Value(x),
      y: Value(y),
      caption: caption == null && nullToAbsent
          ? const Value.absent()
          : Value(caption),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory FlowAnnotation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FlowAnnotation(
      id: serializer.fromJson<String>(json['id']),
      studyId: serializer.fromJson<String>(json['studyId']),
      symbol: $FlowAnnotationsTable.$convertersymbol.fromJson(
        serializer.fromJson<String>(json['symbol']),
      ),
      x: serializer.fromJson<double>(json['x']),
      y: serializer.fromJson<double>(json['y']),
      caption: serializer.fromJson<String?>(json['caption']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'studyId': serializer.toJson<String>(studyId),
      'symbol': serializer.toJson<String>(
        $FlowAnnotationsTable.$convertersymbol.toJson(symbol),
      ),
      'x': serializer.toJson<double>(x),
      'y': serializer.toJson<double>(y),
      'caption': serializer.toJson<String?>(caption),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  FlowAnnotation copyWith({
    String? id,
    String? studyId,
    AnnotationSymbol? symbol,
    double? x,
    double? y,
    Value<String?> caption = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => FlowAnnotation(
    id: id ?? this.id,
    studyId: studyId ?? this.studyId,
    symbol: symbol ?? this.symbol,
    x: x ?? this.x,
    y: y ?? this.y,
    caption: caption.present ? caption.value : this.caption,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  FlowAnnotation copyWithCompanion(FlowAnnotationsCompanion data) {
    return FlowAnnotation(
      id: data.id.present ? data.id.value : this.id,
      studyId: data.studyId.present ? data.studyId.value : this.studyId,
      symbol: data.symbol.present ? data.symbol.value : this.symbol,
      x: data.x.present ? data.x.value : this.x,
      y: data.y.present ? data.y.value : this.y,
      caption: data.caption.present ? data.caption.value : this.caption,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FlowAnnotation(')
          ..write('id: $id, ')
          ..write('studyId: $studyId, ')
          ..write('symbol: $symbol, ')
          ..write('x: $x, ')
          ..write('y: $y, ')
          ..write('caption: $caption, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, studyId, symbol, x, y, caption, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FlowAnnotation &&
          other.id == this.id &&
          other.studyId == this.studyId &&
          other.symbol == this.symbol &&
          other.x == this.x &&
          other.y == this.y &&
          other.caption == this.caption &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class FlowAnnotationsCompanion extends UpdateCompanion<FlowAnnotation> {
  final Value<String> id;
  final Value<String> studyId;
  final Value<AnnotationSymbol> symbol;
  final Value<double> x;
  final Value<double> y;
  final Value<String?> caption;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const FlowAnnotationsCompanion({
    this.id = const Value.absent(),
    this.studyId = const Value.absent(),
    this.symbol = const Value.absent(),
    this.x = const Value.absent(),
    this.y = const Value.absent(),
    this.caption = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FlowAnnotationsCompanion.insert({
    required String id,
    required String studyId,
    required AnnotationSymbol symbol,
    required double x,
    required double y,
    this.caption = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       studyId = Value(studyId),
       symbol = Value(symbol),
       x = Value(x),
       y = Value(y),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<FlowAnnotation> custom({
    Expression<String>? id,
    Expression<String>? studyId,
    Expression<String>? symbol,
    Expression<double>? x,
    Expression<double>? y,
    Expression<String>? caption,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (studyId != null) 'study_id': studyId,
      if (symbol != null) 'symbol': symbol,
      if (x != null) 'x': x,
      if (y != null) 'y': y,
      if (caption != null) 'caption': caption,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FlowAnnotationsCompanion copyWith({
    Value<String>? id,
    Value<String>? studyId,
    Value<AnnotationSymbol>? symbol,
    Value<double>? x,
    Value<double>? y,
    Value<String?>? caption,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return FlowAnnotationsCompanion(
      id: id ?? this.id,
      studyId: studyId ?? this.studyId,
      symbol: symbol ?? this.symbol,
      x: x ?? this.x,
      y: y ?? this.y,
      caption: caption ?? this.caption,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (studyId.present) {
      map['study_id'] = Variable<String>(studyId.value);
    }
    if (symbol.present) {
      map['symbol'] = Variable<String>(
        $FlowAnnotationsTable.$convertersymbol.toSql(symbol.value),
      );
    }
    if (x.present) {
      map['x'] = Variable<double>(x.value);
    }
    if (y.present) {
      map['y'] = Variable<double>(y.value);
    }
    if (caption.present) {
      map['caption'] = Variable<String>(caption.value);
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
    return (StringBuffer('FlowAnnotationsCompanion(')
          ..write('id: $id, ')
          ..write('studyId: $studyId, ')
          ..write('symbol: $symbol, ')
          ..write('x: $x, ')
          ..write('y: $y, ')
          ..write('caption: $caption, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DemandPartsTable extends DemandParts
    with TableInfo<$DemandPartsTable, DemandPart> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DemandPartsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _studyIdMeta = const VerificationMeta(
    'studyId',
  );
  @override
  late final GeneratedColumn<String> studyId = GeneratedColumn<String>(
    'study_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES studies (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _partNumberMeta = const VerificationMeta(
    'partNumber',
  );
  @override
  late final GeneratedColumn<String> partNumber = GeneratedColumn<String>(
    'part_number',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 100,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _customerProjectMeta = const VerificationMeta(
    'customerProject',
  );
  @override
  late final GeneratedColumn<String> customerProject = GeneratedColumn<String>(
    'customer_project',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
    id,
    studyId,
    partNumber,
    customerProject,
    description,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'demand_parts';
  @override
  VerificationContext validateIntegrity(
    Insertable<DemandPart> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('study_id')) {
      context.handle(
        _studyIdMeta,
        studyId.isAcceptableOrUnknown(data['study_id']!, _studyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_studyIdMeta);
    }
    if (data.containsKey('part_number')) {
      context.handle(
        _partNumberMeta,
        partNumber.isAcceptableOrUnknown(data['part_number']!, _partNumberMeta),
      );
    } else if (isInserting) {
      context.missing(_partNumberMeta);
    }
    if (data.containsKey('customer_project')) {
      context.handle(
        _customerProjectMeta,
        customerProject.isAcceptableOrUnknown(
          data['customer_project']!,
          _customerProjectMeta,
        ),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {studyId, customerProject, partNumber},
  ];
  @override
  DemandPart map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DemandPart(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      studyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}study_id'],
      )!,
      partNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}part_number'],
      )!,
      customerProject: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_project'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
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
  $DemandPartsTable createAlias(String alias) {
    return $DemandPartsTable(attachedDatabase, alias);
  }
}

class DemandPart extends DataClass implements Insertable<DemandPart> {
  final String id;
  final String studyId;

  /// `PN2` — what the sequence, the MM3 chart and every report call it.
  final String partNumber;

  /// The **customer's** project this part belongs to — their programme or
  /// contract, not the FlowMap project this study sits in.
  ///
  /// **Part of the part's identity**, not a label on it: a part number is the
  /// id of a part or a piece of equipment, and different clients' projects
  /// legitimately order the same one. `PN2 on Wing 7` and `PN2 on Wing 9` are
  /// two rows of demand with their own process times and their own place in the
  /// sequence.
  ///
  /// **Empty string rather than null**, for the reason
  /// [CalendarExceptions.scopeId] is: SQLite treats NULLs as distinct in a
  /// UNIQUE constraint, so a nullable column would let two unprojected `PN2`s
  /// exist side by side — the exact duplicate the key below exists to prevent.
  final String customerProject;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;
  const DemandPart({
    required this.id,
    required this.studyId,
    required this.partNumber,
    required this.customerProject,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['study_id'] = Variable<String>(studyId);
    map['part_number'] = Variable<String>(partNumber);
    map['customer_project'] = Variable<String>(customerProject);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  DemandPartsCompanion toCompanion(bool nullToAbsent) {
    return DemandPartsCompanion(
      id: Value(id),
      studyId: Value(studyId),
      partNumber: Value(partNumber),
      customerProject: Value(customerProject),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory DemandPart.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DemandPart(
      id: serializer.fromJson<String>(json['id']),
      studyId: serializer.fromJson<String>(json['studyId']),
      partNumber: serializer.fromJson<String>(json['partNumber']),
      customerProject: serializer.fromJson<String>(json['customerProject']),
      description: serializer.fromJson<String?>(json['description']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'studyId': serializer.toJson<String>(studyId),
      'partNumber': serializer.toJson<String>(partNumber),
      'customerProject': serializer.toJson<String>(customerProject),
      'description': serializer.toJson<String?>(description),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  DemandPart copyWith({
    String? id,
    String? studyId,
    String? partNumber,
    String? customerProject,
    Value<String?> description = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => DemandPart(
    id: id ?? this.id,
    studyId: studyId ?? this.studyId,
    partNumber: partNumber ?? this.partNumber,
    customerProject: customerProject ?? this.customerProject,
    description: description.present ? description.value : this.description,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  DemandPart copyWithCompanion(DemandPartsCompanion data) {
    return DemandPart(
      id: data.id.present ? data.id.value : this.id,
      studyId: data.studyId.present ? data.studyId.value : this.studyId,
      partNumber: data.partNumber.present
          ? data.partNumber.value
          : this.partNumber,
      customerProject: data.customerProject.present
          ? data.customerProject.value
          : this.customerProject,
      description: data.description.present
          ? data.description.value
          : this.description,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DemandPart(')
          ..write('id: $id, ')
          ..write('studyId: $studyId, ')
          ..write('partNumber: $partNumber, ')
          ..write('customerProject: $customerProject, ')
          ..write('description: $description, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    studyId,
    partNumber,
    customerProject,
    description,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DemandPart &&
          other.id == this.id &&
          other.studyId == this.studyId &&
          other.partNumber == this.partNumber &&
          other.customerProject == this.customerProject &&
          other.description == this.description &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class DemandPartsCompanion extends UpdateCompanion<DemandPart> {
  final Value<String> id;
  final Value<String> studyId;
  final Value<String> partNumber;
  final Value<String> customerProject;
  final Value<String?> description;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const DemandPartsCompanion({
    this.id = const Value.absent(),
    this.studyId = const Value.absent(),
    this.partNumber = const Value.absent(),
    this.customerProject = const Value.absent(),
    this.description = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DemandPartsCompanion.insert({
    required String id,
    required String studyId,
    required String partNumber,
    this.customerProject = const Value.absent(),
    this.description = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       studyId = Value(studyId),
       partNumber = Value(partNumber),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<DemandPart> custom({
    Expression<String>? id,
    Expression<String>? studyId,
    Expression<String>? partNumber,
    Expression<String>? customerProject,
    Expression<String>? description,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (studyId != null) 'study_id': studyId,
      if (partNumber != null) 'part_number': partNumber,
      if (customerProject != null) 'customer_project': customerProject,
      if (description != null) 'description': description,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DemandPartsCompanion copyWith({
    Value<String>? id,
    Value<String>? studyId,
    Value<String>? partNumber,
    Value<String>? customerProject,
    Value<String?>? description,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return DemandPartsCompanion(
      id: id ?? this.id,
      studyId: studyId ?? this.studyId,
      partNumber: partNumber ?? this.partNumber,
      customerProject: customerProject ?? this.customerProject,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (studyId.present) {
      map['study_id'] = Variable<String>(studyId.value);
    }
    if (partNumber.present) {
      map['part_number'] = Variable<String>(partNumber.value);
    }
    if (customerProject.present) {
      map['customer_project'] = Variable<String>(customerProject.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
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
    return (StringBuffer('DemandPartsCompanion(')
          ..write('id: $id, ')
          ..write('studyId: $studyId, ')
          ..write('partNumber: $partNumber, ')
          ..write('customerProject: $customerProject, ')
          ..write('description: $description, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PartProcessTimesTable extends PartProcessTimes
    with TableInfo<$PartProcessTimesTable, PartProcessTime> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PartProcessTimesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _partIdMeta = const VerificationMeta('partId');
  @override
  late final GeneratedColumn<String> partId = GeneratedColumn<String>(
    'part_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES demand_parts (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _targetIdMeta = const VerificationMeta(
    'targetId',
  );
  @override
  late final GeneratedColumn<String> targetId = GeneratedColumn<String>(
    'target_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _secondsMeta = const VerificationMeta(
    'seconds',
  );
  @override
  late final GeneratedColumn<int> seconds = GeneratedColumn<int>(
    'seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [partId, targetId, seconds];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'part_process_times';
  @override
  VerificationContext validateIntegrity(
    Insertable<PartProcessTime> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('part_id')) {
      context.handle(
        _partIdMeta,
        partId.isAcceptableOrUnknown(data['part_id']!, _partIdMeta),
      );
    } else if (isInserting) {
      context.missing(_partIdMeta);
    }
    if (data.containsKey('target_id')) {
      context.handle(
        _targetIdMeta,
        targetId.isAcceptableOrUnknown(data['target_id']!, _targetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_targetIdMeta);
    }
    if (data.containsKey('seconds')) {
      context.handle(
        _secondsMeta,
        seconds.isAcceptableOrUnknown(data['seconds']!, _secondsMeta),
      );
    } else if (isInserting) {
      context.missing(_secondsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {partId, targetId};
  @override
  PartProcessTime map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PartProcessTime(
      partId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}part_id'],
      )!,
      targetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_id'],
      )!,
      seconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seconds'],
      )!,
    );
  }

  @override
  $PartProcessTimesTable createAlias(String alias) {
    return $PartProcessTimesTable(attachedDatabase, alias);
  }
}

class PartProcessTime extends DataClass implements Insertable<PartProcessTime> {
  final String partId;

  /// The workcenter or pool the step targets.
  final String targetId;

  /// **Per piece**, in canonical seconds (§7.6, §12.4). An order of batch 10
  /// occupies its workcenter for ten times this, which is what makes batch size
  /// a real lever rather than metadata.
  final int seconds;
  const PartProcessTime({
    required this.partId,
    required this.targetId,
    required this.seconds,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['part_id'] = Variable<String>(partId);
    map['target_id'] = Variable<String>(targetId);
    map['seconds'] = Variable<int>(seconds);
    return map;
  }

  PartProcessTimesCompanion toCompanion(bool nullToAbsent) {
    return PartProcessTimesCompanion(
      partId: Value(partId),
      targetId: Value(targetId),
      seconds: Value(seconds),
    );
  }

  factory PartProcessTime.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PartProcessTime(
      partId: serializer.fromJson<String>(json['partId']),
      targetId: serializer.fromJson<String>(json['targetId']),
      seconds: serializer.fromJson<int>(json['seconds']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'partId': serializer.toJson<String>(partId),
      'targetId': serializer.toJson<String>(targetId),
      'seconds': serializer.toJson<int>(seconds),
    };
  }

  PartProcessTime copyWith({String? partId, String? targetId, int? seconds}) =>
      PartProcessTime(
        partId: partId ?? this.partId,
        targetId: targetId ?? this.targetId,
        seconds: seconds ?? this.seconds,
      );
  PartProcessTime copyWithCompanion(PartProcessTimesCompanion data) {
    return PartProcessTime(
      partId: data.partId.present ? data.partId.value : this.partId,
      targetId: data.targetId.present ? data.targetId.value : this.targetId,
      seconds: data.seconds.present ? data.seconds.value : this.seconds,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PartProcessTime(')
          ..write('partId: $partId, ')
          ..write('targetId: $targetId, ')
          ..write('seconds: $seconds')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(partId, targetId, seconds);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PartProcessTime &&
          other.partId == this.partId &&
          other.targetId == this.targetId &&
          other.seconds == this.seconds);
}

class PartProcessTimesCompanion extends UpdateCompanion<PartProcessTime> {
  final Value<String> partId;
  final Value<String> targetId;
  final Value<int> seconds;
  final Value<int> rowid;
  const PartProcessTimesCompanion({
    this.partId = const Value.absent(),
    this.targetId = const Value.absent(),
    this.seconds = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PartProcessTimesCompanion.insert({
    required String partId,
    required String targetId,
    required int seconds,
    this.rowid = const Value.absent(),
  }) : partId = Value(partId),
       targetId = Value(targetId),
       seconds = Value(seconds);
  static Insertable<PartProcessTime> custom({
    Expression<String>? partId,
    Expression<String>? targetId,
    Expression<int>? seconds,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (partId != null) 'part_id': partId,
      if (targetId != null) 'target_id': targetId,
      if (seconds != null) 'seconds': seconds,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PartProcessTimesCompanion copyWith({
    Value<String>? partId,
    Value<String>? targetId,
    Value<int>? seconds,
    Value<int>? rowid,
  }) {
    return PartProcessTimesCompanion(
      partId: partId ?? this.partId,
      targetId: targetId ?? this.targetId,
      seconds: seconds ?? this.seconds,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (partId.present) {
      map['part_id'] = Variable<String>(partId.value);
    }
    if (targetId.present) {
      map['target_id'] = Variable<String>(targetId.value);
    }
    if (seconds.present) {
      map['seconds'] = Variable<int>(seconds.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PartProcessTimesCompanion(')
          ..write('partId: $partId, ')
          ..write('targetId: $targetId, ')
          ..write('seconds: $seconds, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DemandOrdersTable extends DemandOrders
    with TableInfo<$DemandOrdersTable, DemandOrder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DemandOrdersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _studyIdMeta = const VerificationMeta(
    'studyId',
  );
  @override
  late final GeneratedColumn<String> studyId = GeneratedColumn<String>(
    'study_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES studies (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _partIdMeta = const VerificationMeta('partId');
  @override
  late final GeneratedColumn<String> partId = GeneratedColumn<String>(
    'part_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES demand_parts (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _sequenceMeta = const VerificationMeta(
    'sequence',
  );
  @override
  late final GeneratedColumn<int> sequence = GeneratedColumn<int>(
    'sequence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _batchSizeMeta = const VerificationMeta(
    'batchSize',
  );
  @override
  late final GeneratedColumn<int> batchSize = GeneratedColumn<int>(
    'batch_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _needDateMeta = const VerificationMeta(
    'needDate',
  );
  @override
  late final GeneratedColumn<DateTime> needDate = GeneratedColumn<DateTime>(
    'need_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _materialDateMeta = const VerificationMeta(
    'materialDate',
  );
  @override
  late final GeneratedColumn<DateTime> materialDate = GeneratedColumn<DateTime>(
    'material_date',
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
    id,
    studyId,
    partId,
    sequence,
    batchSize,
    needDate,
    materialDate,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'demand_orders';
  @override
  VerificationContext validateIntegrity(
    Insertable<DemandOrder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('study_id')) {
      context.handle(
        _studyIdMeta,
        studyId.isAcceptableOrUnknown(data['study_id']!, _studyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_studyIdMeta);
    }
    if (data.containsKey('part_id')) {
      context.handle(
        _partIdMeta,
        partId.isAcceptableOrUnknown(data['part_id']!, _partIdMeta),
      );
    } else if (isInserting) {
      context.missing(_partIdMeta);
    }
    if (data.containsKey('sequence')) {
      context.handle(
        _sequenceMeta,
        sequence.isAcceptableOrUnknown(data['sequence']!, _sequenceMeta),
      );
    } else if (isInserting) {
      context.missing(_sequenceMeta);
    }
    if (data.containsKey('batch_size')) {
      context.handle(
        _batchSizeMeta,
        batchSize.isAcceptableOrUnknown(data['batch_size']!, _batchSizeMeta),
      );
    }
    if (data.containsKey('need_date')) {
      context.handle(
        _needDateMeta,
        needDate.isAcceptableOrUnknown(data['need_date']!, _needDateMeta),
      );
    } else if (isInserting) {
      context.missing(_needDateMeta);
    }
    if (data.containsKey('material_date')) {
      context.handle(
        _materialDateMeta,
        materialDate.isAcceptableOrUnknown(
          data['material_date']!,
          _materialDateMeta,
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {studyId, sequence},
  ];
  @override
  DemandOrder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DemandOrder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      studyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}study_id'],
      )!,
      partId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}part_id'],
      )!,
      sequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sequence'],
      )!,
      batchSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}batch_size'],
      )!,
      needDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}need_date'],
      )!,
      materialDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}material_date'],
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
  $DemandOrdersTable createAlias(String alias) {
    return $DemandOrdersTable(attachedDatabase, alias);
  }
}

class DemandOrder extends DataClass implements Insertable<DemandOrder> {
  final String id;
  final String studyId;
  final String partId;

  /// Position in the release sequence — dense and zero-based, renumbered on
  /// every structural edit, the same convention the flow spine uses.
  ///
  /// The sequence is the thing under study: the engine releases from its head
  /// and never reorders it (§7.2), and MM3 measures how smooth it is (§6.3).
  final int sequence;

  /// Pieces in the order. Process times are per piece, so this multiplies the
  /// work at every step (§7.6).
  final int batchSize;
  final DateTime needDate;

  /// When material is on hand. Null means unconstrained — the order may take
  /// the first release slot it is offered (§7.2).
  final DateTime? materialDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  const DemandOrder({
    required this.id,
    required this.studyId,
    required this.partId,
    required this.sequence,
    required this.batchSize,
    required this.needDate,
    this.materialDate,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['study_id'] = Variable<String>(studyId);
    map['part_id'] = Variable<String>(partId);
    map['sequence'] = Variable<int>(sequence);
    map['batch_size'] = Variable<int>(batchSize);
    map['need_date'] = Variable<DateTime>(needDate);
    if (!nullToAbsent || materialDate != null) {
      map['material_date'] = Variable<DateTime>(materialDate);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  DemandOrdersCompanion toCompanion(bool nullToAbsent) {
    return DemandOrdersCompanion(
      id: Value(id),
      studyId: Value(studyId),
      partId: Value(partId),
      sequence: Value(sequence),
      batchSize: Value(batchSize),
      needDate: Value(needDate),
      materialDate: materialDate == null && nullToAbsent
          ? const Value.absent()
          : Value(materialDate),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory DemandOrder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DemandOrder(
      id: serializer.fromJson<String>(json['id']),
      studyId: serializer.fromJson<String>(json['studyId']),
      partId: serializer.fromJson<String>(json['partId']),
      sequence: serializer.fromJson<int>(json['sequence']),
      batchSize: serializer.fromJson<int>(json['batchSize']),
      needDate: serializer.fromJson<DateTime>(json['needDate']),
      materialDate: serializer.fromJson<DateTime?>(json['materialDate']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'studyId': serializer.toJson<String>(studyId),
      'partId': serializer.toJson<String>(partId),
      'sequence': serializer.toJson<int>(sequence),
      'batchSize': serializer.toJson<int>(batchSize),
      'needDate': serializer.toJson<DateTime>(needDate),
      'materialDate': serializer.toJson<DateTime?>(materialDate),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  DemandOrder copyWith({
    String? id,
    String? studyId,
    String? partId,
    int? sequence,
    int? batchSize,
    DateTime? needDate,
    Value<DateTime?> materialDate = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => DemandOrder(
    id: id ?? this.id,
    studyId: studyId ?? this.studyId,
    partId: partId ?? this.partId,
    sequence: sequence ?? this.sequence,
    batchSize: batchSize ?? this.batchSize,
    needDate: needDate ?? this.needDate,
    materialDate: materialDate.present ? materialDate.value : this.materialDate,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  DemandOrder copyWithCompanion(DemandOrdersCompanion data) {
    return DemandOrder(
      id: data.id.present ? data.id.value : this.id,
      studyId: data.studyId.present ? data.studyId.value : this.studyId,
      partId: data.partId.present ? data.partId.value : this.partId,
      sequence: data.sequence.present ? data.sequence.value : this.sequence,
      batchSize: data.batchSize.present ? data.batchSize.value : this.batchSize,
      needDate: data.needDate.present ? data.needDate.value : this.needDate,
      materialDate: data.materialDate.present
          ? data.materialDate.value
          : this.materialDate,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DemandOrder(')
          ..write('id: $id, ')
          ..write('studyId: $studyId, ')
          ..write('partId: $partId, ')
          ..write('sequence: $sequence, ')
          ..write('batchSize: $batchSize, ')
          ..write('needDate: $needDate, ')
          ..write('materialDate: $materialDate, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    studyId,
    partId,
    sequence,
    batchSize,
    needDate,
    materialDate,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DemandOrder &&
          other.id == this.id &&
          other.studyId == this.studyId &&
          other.partId == this.partId &&
          other.sequence == this.sequence &&
          other.batchSize == this.batchSize &&
          other.needDate == this.needDate &&
          other.materialDate == this.materialDate &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class DemandOrdersCompanion extends UpdateCompanion<DemandOrder> {
  final Value<String> id;
  final Value<String> studyId;
  final Value<String> partId;
  final Value<int> sequence;
  final Value<int> batchSize;
  final Value<DateTime> needDate;
  final Value<DateTime?> materialDate;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const DemandOrdersCompanion({
    this.id = const Value.absent(),
    this.studyId = const Value.absent(),
    this.partId = const Value.absent(),
    this.sequence = const Value.absent(),
    this.batchSize = const Value.absent(),
    this.needDate = const Value.absent(),
    this.materialDate = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DemandOrdersCompanion.insert({
    required String id,
    required String studyId,
    required String partId,
    required int sequence,
    this.batchSize = const Value.absent(),
    required DateTime needDate,
    this.materialDate = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       studyId = Value(studyId),
       partId = Value(partId),
       sequence = Value(sequence),
       needDate = Value(needDate),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<DemandOrder> custom({
    Expression<String>? id,
    Expression<String>? studyId,
    Expression<String>? partId,
    Expression<int>? sequence,
    Expression<int>? batchSize,
    Expression<DateTime>? needDate,
    Expression<DateTime>? materialDate,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (studyId != null) 'study_id': studyId,
      if (partId != null) 'part_id': partId,
      if (sequence != null) 'sequence': sequence,
      if (batchSize != null) 'batch_size': batchSize,
      if (needDate != null) 'need_date': needDate,
      if (materialDate != null) 'material_date': materialDate,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DemandOrdersCompanion copyWith({
    Value<String>? id,
    Value<String>? studyId,
    Value<String>? partId,
    Value<int>? sequence,
    Value<int>? batchSize,
    Value<DateTime>? needDate,
    Value<DateTime?>? materialDate,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return DemandOrdersCompanion(
      id: id ?? this.id,
      studyId: studyId ?? this.studyId,
      partId: partId ?? this.partId,
      sequence: sequence ?? this.sequence,
      batchSize: batchSize ?? this.batchSize,
      needDate: needDate ?? this.needDate,
      materialDate: materialDate ?? this.materialDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (studyId.present) {
      map['study_id'] = Variable<String>(studyId.value);
    }
    if (partId.present) {
      map['part_id'] = Variable<String>(partId.value);
    }
    if (sequence.present) {
      map['sequence'] = Variable<int>(sequence.value);
    }
    if (batchSize.present) {
      map['batch_size'] = Variable<int>(batchSize.value);
    }
    if (needDate.present) {
      map['need_date'] = Variable<DateTime>(needDate.value);
    }
    if (materialDate.present) {
      map['material_date'] = Variable<DateTime>(materialDate.value);
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
    return (StringBuffer('DemandOrdersCompanion(')
          ..write('id: $id, ')
          ..write('studyId: $studyId, ')
          ..write('partId: $partId, ')
          ..write('sequence: $sequence, ')
          ..write('batchSize: $batchSize, ')
          ..write('needDate: $needDate, ')
          ..write('materialDate: $materialDate, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ShiftPatternsTable shiftPatterns = $ShiftPatternsTable(this);
  late final $PatternShiftsTable patternShifts = $PatternShiftsTable(this);
  late final $PlantsTable plants = $PlantsTable(this);
  late final $ProductionCellsTable productionCells = $ProductionCellsTable(
    this,
  );
  late final $ProductionLinesTable productionLines = $ProductionLinesTable(
    this,
  );
  late final $WorkcenterTypesTable workcenterTypes = $WorkcenterTypesTable(
    this,
  );
  late final $WorkcentersTable workcenters = $WorkcentersTable(this);
  late final $WorkcenterLinesTable workcenterLines = $WorkcenterLinesTable(
    this,
  );
  late final $WorkcenterPoolsTable workcenterPools = $WorkcenterPoolsTable(
    this,
  );
  late final $WorkcenterPoolMembersTable workcenterPoolMembers =
      $WorkcenterPoolMembersTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $ProjectsTable projects = $ProjectsTable(this);
  late final $CalendarExceptionsTable calendarExceptions =
      $CalendarExceptionsTable(this);
  late final $TaktPeriodsTable taktPeriods = $TaktPeriodsTable(this);
  late final $WorkcenterSchedulePeriodsTable workcenterSchedulePeriods =
      $WorkcenterSchedulePeriodsTable(this);
  late final $StudiesTable studies = $StudiesTable(this);
  late final $FlowNodesTable flowNodes = $FlowNodesTable(this);
  late final $FlowAnnotationsTable flowAnnotations = $FlowAnnotationsTable(
    this,
  );
  late final $DemandPartsTable demandParts = $DemandPartsTable(this);
  late final $PartProcessTimesTable partProcessTimes = $PartProcessTimesTable(
    this,
  );
  late final $DemandOrdersTable demandOrders = $DemandOrdersTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    shiftPatterns,
    patternShifts,
    plants,
    productionCells,
    productionLines,
    workcenterTypes,
    workcenters,
    workcenterLines,
    workcenterPools,
    workcenterPoolMembers,
    appSettings,
    projects,
    calendarExceptions,
    taktPeriods,
    workcenterSchedulePeriods,
    studies,
    flowNodes,
    flowAnnotations,
    demandParts,
    partProcessTimes,
    demandOrders,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'shift_patterns',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('pattern_shifts', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'plants',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('production_cells', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'production_cells',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('production_lines', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'plants',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('workcenters', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'workcenter_types',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('workcenters', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'workcenters',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('workcenter_lines', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'production_lines',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('workcenter_lines', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'plants',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('workcenter_pools', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'workcenter_pools',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('workcenter_pool_members', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'workcenters',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('workcenter_pool_members', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'projects',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('calendar_exceptions', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'projects',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('takt_periods', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'production_lines',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('takt_periods', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'projects',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [
        TableUpdate('workcenter_schedule_periods', kind: UpdateKind.delete),
      ],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'workcenters',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [
        TableUpdate('workcenter_schedule_periods', kind: UpdateKind.delete),
      ],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'projects',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('studies', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'production_cells',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('studies', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'production_lines',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('studies', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'studies',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('flow_nodes', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'workcenters',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('flow_nodes', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'workcenter_pools',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('flow_nodes', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'studies',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('flow_annotations', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'studies',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('demand_parts', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'demand_parts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('part_process_times', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'studies',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('demand_orders', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'demand_parts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('demand_orders', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$ShiftPatternsTableCreateCompanionBuilder =
    ShiftPatternsCompanion Function({
      required String id,
      required String name,
      required ShiftCycleType cycleType,
      required int workingWeekdays,
      Value<String?> notes,
      Value<DateTime?> archivedAt,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ShiftPatternsTableUpdateCompanionBuilder =
    ShiftPatternsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<ShiftCycleType> cycleType,
      Value<int> workingWeekdays,
      Value<String?> notes,
      Value<DateTime?> archivedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$ShiftPatternsTableReferences
    extends BaseReferences<_$AppDatabase, $ShiftPatternsTable, ShiftPattern> {
  $$ShiftPatternsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$PatternShiftsTable, List<PatternShift>>
  _patternShiftsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.patternShifts,
    aliasName: 'shift_patterns__id__pattern_shifts__pattern_id',
  );

  $$PatternShiftsTableProcessedTableManager get patternShiftsRefs {
    final manager = $$PatternShiftsTableTableManager(
      $_db,
      $_db.patternShifts,
    ).filter((f) => f.patternId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_patternShiftsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ProjectsTable, List<Project>> _projectsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.projects,
    aliasName: 'shift_patterns__id__projects__shift_pattern_id',
  );

  $$ProjectsTableProcessedTableManager get projectsRefs {
    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.shiftPatternId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_projectsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ShiftPatternsTableFilterComposer
    extends Composer<_$AppDatabase, $ShiftPatternsTable> {
  $$ShiftPatternsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ShiftCycleType, ShiftCycleType, String>
  get cycleType => $composableBuilder(
    column: $table.cycleType,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get workingWeekdays => $composableBuilder(
    column: $table.workingWeekdays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
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

  Expression<bool> patternShiftsRefs(
    Expression<bool> Function($$PatternShiftsTableFilterComposer f) f,
  ) {
    final $$PatternShiftsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.patternShifts,
      getReferencedColumn: (t) => t.patternId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PatternShiftsTableFilterComposer(
            $db: $db,
            $table: $db.patternShifts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> projectsRefs(
    Expression<bool> Function($$ProjectsTableFilterComposer f) f,
  ) {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.shiftPatternId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ShiftPatternsTableOrderingComposer
    extends Composer<_$AppDatabase, $ShiftPatternsTable> {
  $$ShiftPatternsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cycleType => $composableBuilder(
    column: $table.cycleType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get workingWeekdays => $composableBuilder(
    column: $table.workingWeekdays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
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

class $$ShiftPatternsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ShiftPatternsTable> {
  $$ShiftPatternsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ShiftCycleType, String> get cycleType =>
      $composableBuilder(column: $table.cycleType, builder: (column) => column);

  GeneratedColumn<int> get workingWeekdays => $composableBuilder(
    column: $table.workingWeekdays,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> patternShiftsRefs<T extends Object>(
    Expression<T> Function($$PatternShiftsTableAnnotationComposer a) f,
  ) {
    final $$PatternShiftsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.patternShifts,
      getReferencedColumn: (t) => t.patternId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PatternShiftsTableAnnotationComposer(
            $db: $db,
            $table: $db.patternShifts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> projectsRefs<T extends Object>(
    Expression<T> Function($$ProjectsTableAnnotationComposer a) f,
  ) {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.shiftPatternId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ShiftPatternsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ShiftPatternsTable,
          ShiftPattern,
          $$ShiftPatternsTableFilterComposer,
          $$ShiftPatternsTableOrderingComposer,
          $$ShiftPatternsTableAnnotationComposer,
          $$ShiftPatternsTableCreateCompanionBuilder,
          $$ShiftPatternsTableUpdateCompanionBuilder,
          (ShiftPattern, $$ShiftPatternsTableReferences),
          ShiftPattern,
          PrefetchHooks Function({bool patternShiftsRefs, bool projectsRefs})
        > {
  $$ShiftPatternsTableTableManager(_$AppDatabase db, $ShiftPatternsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ShiftPatternsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ShiftPatternsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ShiftPatternsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<ShiftCycleType> cycleType = const Value.absent(),
                Value<int> workingWeekdays = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ShiftPatternsCompanion(
                id: id,
                name: name,
                cycleType: cycleType,
                workingWeekdays: workingWeekdays,
                notes: notes,
                archivedAt: archivedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required ShiftCycleType cycleType,
                required int workingWeekdays,
                Value<String?> notes = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ShiftPatternsCompanion.insert(
                id: id,
                name: name,
                cycleType: cycleType,
                workingWeekdays: workingWeekdays,
                notes: notes,
                archivedAt: archivedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ShiftPatternsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({patternShiftsRefs = false, projectsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (patternShiftsRefs) db.patternShifts,
                    if (projectsRefs) db.projects,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (patternShiftsRefs)
                        await $_getPrefetchedData<
                          ShiftPattern,
                          $ShiftPatternsTable,
                          PatternShift
                        >(
                          currentTable: table,
                          referencedTable: $$ShiftPatternsTableReferences
                              ._patternShiftsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ShiftPatternsTableReferences(
                                db,
                                table,
                                p0,
                              ).patternShiftsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.patternId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (projectsRefs)
                        await $_getPrefetchedData<
                          ShiftPattern,
                          $ShiftPatternsTable,
                          Project
                        >(
                          currentTable: table,
                          referencedTable: $$ShiftPatternsTableReferences
                              ._projectsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ShiftPatternsTableReferences(
                                db,
                                table,
                                p0,
                              ).projectsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.shiftPatternId == item.id,
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

typedef $$ShiftPatternsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ShiftPatternsTable,
      ShiftPattern,
      $$ShiftPatternsTableFilterComposer,
      $$ShiftPatternsTableOrderingComposer,
      $$ShiftPatternsTableAnnotationComposer,
      $$ShiftPatternsTableCreateCompanionBuilder,
      $$ShiftPatternsTableUpdateCompanionBuilder,
      (ShiftPattern, $$ShiftPatternsTableReferences),
      ShiftPattern,
      PrefetchHooks Function({bool patternShiftsRefs, bool projectsRefs})
    >;
typedef $$PatternShiftsTableCreateCompanionBuilder =
    PatternShiftsCompanion Function({
      required String id,
      required String patternId,
      required String label,
      required int position,
      required int startMinute,
      required int endMinute,
      Value<int> breakSeconds,
      Value<int> rowid,
    });
typedef $$PatternShiftsTableUpdateCompanionBuilder =
    PatternShiftsCompanion Function({
      Value<String> id,
      Value<String> patternId,
      Value<String> label,
      Value<int> position,
      Value<int> startMinute,
      Value<int> endMinute,
      Value<int> breakSeconds,
      Value<int> rowid,
    });

final class $$PatternShiftsTableReferences
    extends BaseReferences<_$AppDatabase, $PatternShiftsTable, PatternShift> {
  $$PatternShiftsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ShiftPatternsTable _patternIdTable(_$AppDatabase db) => db
      .shiftPatterns
      .createAlias('pattern_shifts__pattern_id__shift_patterns__id');

  $$ShiftPatternsTableProcessedTableManager get patternId {
    final $_column = $_itemColumn<String>('pattern_id')!;

    final manager = $$ShiftPatternsTableTableManager(
      $_db,
      $_db.shiftPatterns,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_patternIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PatternShiftsTableFilterComposer
    extends Composer<_$AppDatabase, $PatternShiftsTable> {
  $$PatternShiftsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endMinute => $composableBuilder(
    column: $table.endMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get breakSeconds => $composableBuilder(
    column: $table.breakSeconds,
    builder: (column) => ColumnFilters(column),
  );

  $$ShiftPatternsTableFilterComposer get patternId {
    final $$ShiftPatternsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.patternId,
      referencedTable: $db.shiftPatterns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShiftPatternsTableFilterComposer(
            $db: $db,
            $table: $db.shiftPatterns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PatternShiftsTableOrderingComposer
    extends Composer<_$AppDatabase, $PatternShiftsTable> {
  $$PatternShiftsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endMinute => $composableBuilder(
    column: $table.endMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get breakSeconds => $composableBuilder(
    column: $table.breakSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  $$ShiftPatternsTableOrderingComposer get patternId {
    final $$ShiftPatternsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.patternId,
      referencedTable: $db.shiftPatterns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShiftPatternsTableOrderingComposer(
            $db: $db,
            $table: $db.shiftPatterns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PatternShiftsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PatternShiftsTable> {
  $$PatternShiftsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endMinute =>
      $composableBuilder(column: $table.endMinute, builder: (column) => column);

  GeneratedColumn<int> get breakSeconds => $composableBuilder(
    column: $table.breakSeconds,
    builder: (column) => column,
  );

  $$ShiftPatternsTableAnnotationComposer get patternId {
    final $$ShiftPatternsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.patternId,
      referencedTable: $db.shiftPatterns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShiftPatternsTableAnnotationComposer(
            $db: $db,
            $table: $db.shiftPatterns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PatternShiftsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PatternShiftsTable,
          PatternShift,
          $$PatternShiftsTableFilterComposer,
          $$PatternShiftsTableOrderingComposer,
          $$PatternShiftsTableAnnotationComposer,
          $$PatternShiftsTableCreateCompanionBuilder,
          $$PatternShiftsTableUpdateCompanionBuilder,
          (PatternShift, $$PatternShiftsTableReferences),
          PatternShift,
          PrefetchHooks Function({bool patternId})
        > {
  $$PatternShiftsTableTableManager(_$AppDatabase db, $PatternShiftsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PatternShiftsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PatternShiftsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PatternShiftsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> patternId = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> startMinute = const Value.absent(),
                Value<int> endMinute = const Value.absent(),
                Value<int> breakSeconds = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PatternShiftsCompanion(
                id: id,
                patternId: patternId,
                label: label,
                position: position,
                startMinute: startMinute,
                endMinute: endMinute,
                breakSeconds: breakSeconds,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String patternId,
                required String label,
                required int position,
                required int startMinute,
                required int endMinute,
                Value<int> breakSeconds = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PatternShiftsCompanion.insert(
                id: id,
                patternId: patternId,
                label: label,
                position: position,
                startMinute: startMinute,
                endMinute: endMinute,
                breakSeconds: breakSeconds,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PatternShiftsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({patternId = false}) {
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
                    if (patternId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.patternId,
                                referencedTable: $$PatternShiftsTableReferences
                                    ._patternIdTable(db),
                                referencedColumn: $$PatternShiftsTableReferences
                                    ._patternIdTable(db)
                                    .id,
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

typedef $$PatternShiftsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PatternShiftsTable,
      PatternShift,
      $$PatternShiftsTableFilterComposer,
      $$PatternShiftsTableOrderingComposer,
      $$PatternShiftsTableAnnotationComposer,
      $$PatternShiftsTableCreateCompanionBuilder,
      $$PatternShiftsTableUpdateCompanionBuilder,
      (PatternShift, $$PatternShiftsTableReferences),
      PatternShift,
      PrefetchHooks Function({bool patternId})
    >;
typedef $$PlantsTableCreateCompanionBuilder =
    PlantsCompanion Function({
      required String id,
      required String name,
      Value<String?> code,
      Value<String?> notes,
      Value<DateTime?> archivedAt,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$PlantsTableUpdateCompanionBuilder =
    PlantsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> code,
      Value<String?> notes,
      Value<DateTime?> archivedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$PlantsTableReferences
    extends BaseReferences<_$AppDatabase, $PlantsTable, Plant> {
  $$PlantsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ProductionCellsTable, List<ProductionCell>>
  _productionCellsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.productionCells,
    aliasName: 'plants__id__production_cells__plant_id',
  );

  $$ProductionCellsTableProcessedTableManager get productionCellsRefs {
    final manager = $$ProductionCellsTableTableManager(
      $_db,
      $_db.productionCells,
    ).filter((f) => f.plantId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _productionCellsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$WorkcentersTable, List<Workcenter>>
  _workcentersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.workcenters,
    aliasName: 'plants__id__workcenters__plant_id',
  );

  $$WorkcentersTableProcessedTableManager get workcentersRefs {
    final manager = $$WorkcentersTableTableManager(
      $_db,
      $_db.workcenters,
    ).filter((f) => f.plantId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_workcentersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$WorkcenterPoolsTable, List<WorkcenterPool>>
  _workcenterPoolsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.workcenterPools,
    aliasName: 'plants__id__workcenter_pools__plant_id',
  );

  $$WorkcenterPoolsTableProcessedTableManager get workcenterPoolsRefs {
    final manager = $$WorkcenterPoolsTableTableManager(
      $_db,
      $_db.workcenterPools,
    ).filter((f) => f.plantId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _workcenterPoolsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ProjectsTable, List<Project>> _projectsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.projects,
    aliasName: 'plants__id__projects__plant_id',
  );

  $$ProjectsTableProcessedTableManager get projectsRefs {
    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.plantId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_projectsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PlantsTableFilterComposer
    extends Composer<_$AppDatabase, $PlantsTable> {
  $$PlantsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
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

  Expression<bool> productionCellsRefs(
    Expression<bool> Function($$ProductionCellsTableFilterComposer f) f,
  ) {
    final $$ProductionCellsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.productionCells,
      getReferencedColumn: (t) => t.plantId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductionCellsTableFilterComposer(
            $db: $db,
            $table: $db.productionCells,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> workcentersRefs(
    Expression<bool> Function($$WorkcentersTableFilterComposer f) f,
  ) {
    final $$WorkcentersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workcenters,
      getReferencedColumn: (t) => t.plantId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkcentersTableFilterComposer(
            $db: $db,
            $table: $db.workcenters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> workcenterPoolsRefs(
    Expression<bool> Function($$WorkcenterPoolsTableFilterComposer f) f,
  ) {
    final $$WorkcenterPoolsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workcenterPools,
      getReferencedColumn: (t) => t.plantId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkcenterPoolsTableFilterComposer(
            $db: $db,
            $table: $db.workcenterPools,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> projectsRefs(
    Expression<bool> Function($$ProjectsTableFilterComposer f) f,
  ) {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.plantId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PlantsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlantsTable> {
  $$PlantsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
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

class $$PlantsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlantsTable> {
  $$PlantsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> productionCellsRefs<T extends Object>(
    Expression<T> Function($$ProductionCellsTableAnnotationComposer a) f,
  ) {
    final $$ProductionCellsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.productionCells,
      getReferencedColumn: (t) => t.plantId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductionCellsTableAnnotationComposer(
            $db: $db,
            $table: $db.productionCells,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> workcentersRefs<T extends Object>(
    Expression<T> Function($$WorkcentersTableAnnotationComposer a) f,
  ) {
    final $$WorkcentersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workcenters,
      getReferencedColumn: (t) => t.plantId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkcentersTableAnnotationComposer(
            $db: $db,
            $table: $db.workcenters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> workcenterPoolsRefs<T extends Object>(
    Expression<T> Function($$WorkcenterPoolsTableAnnotationComposer a) f,
  ) {
    final $$WorkcenterPoolsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workcenterPools,
      getReferencedColumn: (t) => t.plantId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkcenterPoolsTableAnnotationComposer(
            $db: $db,
            $table: $db.workcenterPools,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> projectsRefs<T extends Object>(
    Expression<T> Function($$ProjectsTableAnnotationComposer a) f,
  ) {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.plantId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PlantsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlantsTable,
          Plant,
          $$PlantsTableFilterComposer,
          $$PlantsTableOrderingComposer,
          $$PlantsTableAnnotationComposer,
          $$PlantsTableCreateCompanionBuilder,
          $$PlantsTableUpdateCompanionBuilder,
          (Plant, $$PlantsTableReferences),
          Plant,
          PrefetchHooks Function({
            bool productionCellsRefs,
            bool workcentersRefs,
            bool workcenterPoolsRefs,
            bool projectsRefs,
          })
        > {
  $$PlantsTableTableManager(_$AppDatabase db, $PlantsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlantsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlantsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlantsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> code = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlantsCompanion(
                id: id,
                name: name,
                code: code,
                notes: notes,
                archivedAt: archivedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> code = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => PlantsCompanion.insert(
                id: id,
                name: name,
                code: code,
                notes: notes,
                archivedAt: archivedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$PlantsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                productionCellsRefs = false,
                workcentersRefs = false,
                workcenterPoolsRefs = false,
                projectsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (productionCellsRefs) db.productionCells,
                    if (workcentersRefs) db.workcenters,
                    if (workcenterPoolsRefs) db.workcenterPools,
                    if (projectsRefs) db.projects,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (productionCellsRefs)
                        await $_getPrefetchedData<
                          Plant,
                          $PlantsTable,
                          ProductionCell
                        >(
                          currentTable: table,
                          referencedTable: $$PlantsTableReferences
                              ._productionCellsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlantsTableReferences(
                                db,
                                table,
                                p0,
                              ).productionCellsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.plantId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (workcentersRefs)
                        await $_getPrefetchedData<
                          Plant,
                          $PlantsTable,
                          Workcenter
                        >(
                          currentTable: table,
                          referencedTable: $$PlantsTableReferences
                              ._workcentersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlantsTableReferences(
                                db,
                                table,
                                p0,
                              ).workcentersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.plantId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (workcenterPoolsRefs)
                        await $_getPrefetchedData<
                          Plant,
                          $PlantsTable,
                          WorkcenterPool
                        >(
                          currentTable: table,
                          referencedTable: $$PlantsTableReferences
                              ._workcenterPoolsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlantsTableReferences(
                                db,
                                table,
                                p0,
                              ).workcenterPoolsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.plantId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (projectsRefs)
                        await $_getPrefetchedData<Plant, $PlantsTable, Project>(
                          currentTable: table,
                          referencedTable: $$PlantsTableReferences
                              ._projectsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlantsTableReferences(
                                db,
                                table,
                                p0,
                              ).projectsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.plantId == item.id,
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

typedef $$PlantsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlantsTable,
      Plant,
      $$PlantsTableFilterComposer,
      $$PlantsTableOrderingComposer,
      $$PlantsTableAnnotationComposer,
      $$PlantsTableCreateCompanionBuilder,
      $$PlantsTableUpdateCompanionBuilder,
      (Plant, $$PlantsTableReferences),
      Plant,
      PrefetchHooks Function({
        bool productionCellsRefs,
        bool workcentersRefs,
        bool workcenterPoolsRefs,
        bool projectsRefs,
      })
    >;
typedef $$ProductionCellsTableCreateCompanionBuilder =
    ProductionCellsCompanion Function({
      required String id,
      required String plantId,
      required String name,
      Value<String?> notes,
      Value<DateTime?> archivedAt,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ProductionCellsTableUpdateCompanionBuilder =
    ProductionCellsCompanion Function({
      Value<String> id,
      Value<String> plantId,
      Value<String> name,
      Value<String?> notes,
      Value<DateTime?> archivedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$ProductionCellsTableReferences
    extends
        BaseReferences<_$AppDatabase, $ProductionCellsTable, ProductionCell> {
  $$ProductionCellsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PlantsTable _plantIdTable(_$AppDatabase db) =>
      db.plants.createAlias('production_cells__plant_id__plants__id');

  $$PlantsTableProcessedTableManager get plantId {
    final $_column = $_itemColumn<String>('plant_id')!;

    final manager = $$PlantsTableTableManager(
      $_db,
      $_db.plants,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_plantIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ProductionLinesTable, List<ProductionLine>>
  _productionLinesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.productionLines,
    aliasName: 'production_cells__id__production_lines__cell_id',
  );

  $$ProductionLinesTableProcessedTableManager get productionLinesRefs {
    final manager = $$ProductionLinesTableTableManager(
      $_db,
      $_db.productionLines,
    ).filter((f) => f.cellId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _productionLinesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$StudiesTable, List<Study>> _studiesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.studies,
    aliasName: 'production_cells__id__studies__production_cell_id',
  );

  $$StudiesTableProcessedTableManager get studiesRefs {
    final manager = $$StudiesTableTableManager($_db, $_db.studies).filter(
      (f) => f.productionCellId.id.sqlEquals($_itemColumn<String>('id')!),
    );

    final cache = $_typedResult.readTableOrNull(_studiesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ProductionCellsTableFilterComposer
    extends Composer<_$AppDatabase, $ProductionCellsTable> {
  $$ProductionCellsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
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

  $$PlantsTableFilterComposer get plantId {
    final $$PlantsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.plantId,
      referencedTable: $db.plants,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlantsTableFilterComposer(
            $db: $db,
            $table: $db.plants,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> productionLinesRefs(
    Expression<bool> Function($$ProductionLinesTableFilterComposer f) f,
  ) {
    final $$ProductionLinesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.productionLines,
      getReferencedColumn: (t) => t.cellId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductionLinesTableFilterComposer(
            $db: $db,
            $table: $db.productionLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> studiesRefs(
    Expression<bool> Function($$StudiesTableFilterComposer f) f,
  ) {
    final $$StudiesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.studies,
      getReferencedColumn: (t) => t.productionCellId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudiesTableFilterComposer(
            $db: $db,
            $table: $db.studies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProductionCellsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProductionCellsTable> {
  $$ProductionCellsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
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

  $$PlantsTableOrderingComposer get plantId {
    final $$PlantsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.plantId,
      referencedTable: $db.plants,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlantsTableOrderingComposer(
            $db: $db,
            $table: $db.plants,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProductionCellsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProductionCellsTable> {
  $$ProductionCellsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$PlantsTableAnnotationComposer get plantId {
    final $$PlantsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.plantId,
      referencedTable: $db.plants,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlantsTableAnnotationComposer(
            $db: $db,
            $table: $db.plants,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> productionLinesRefs<T extends Object>(
    Expression<T> Function($$ProductionLinesTableAnnotationComposer a) f,
  ) {
    final $$ProductionLinesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.productionLines,
      getReferencedColumn: (t) => t.cellId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductionLinesTableAnnotationComposer(
            $db: $db,
            $table: $db.productionLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> studiesRefs<T extends Object>(
    Expression<T> Function($$StudiesTableAnnotationComposer a) f,
  ) {
    final $$StudiesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.studies,
      getReferencedColumn: (t) => t.productionCellId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudiesTableAnnotationComposer(
            $db: $db,
            $table: $db.studies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProductionCellsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProductionCellsTable,
          ProductionCell,
          $$ProductionCellsTableFilterComposer,
          $$ProductionCellsTableOrderingComposer,
          $$ProductionCellsTableAnnotationComposer,
          $$ProductionCellsTableCreateCompanionBuilder,
          $$ProductionCellsTableUpdateCompanionBuilder,
          (ProductionCell, $$ProductionCellsTableReferences),
          ProductionCell,
          PrefetchHooks Function({
            bool plantId,
            bool productionLinesRefs,
            bool studiesRefs,
          })
        > {
  $$ProductionCellsTableTableManager(
    _$AppDatabase db,
    $ProductionCellsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProductionCellsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProductionCellsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProductionCellsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> plantId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProductionCellsCompanion(
                id: id,
                plantId: plantId,
                name: name,
                notes: notes,
                archivedAt: archivedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String plantId,
                required String name,
                Value<String?> notes = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ProductionCellsCompanion.insert(
                id: id,
                plantId: plantId,
                name: name,
                notes: notes,
                archivedAt: archivedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ProductionCellsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                plantId = false,
                productionLinesRefs = false,
                studiesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (productionLinesRefs) db.productionLines,
                    if (studiesRefs) db.studies,
                  ],
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
                        if (plantId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.plantId,
                                    referencedTable:
                                        $$ProductionCellsTableReferences
                                            ._plantIdTable(db),
                                    referencedColumn:
                                        $$ProductionCellsTableReferences
                                            ._plantIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (productionLinesRefs)
                        await $_getPrefetchedData<
                          ProductionCell,
                          $ProductionCellsTable,
                          ProductionLine
                        >(
                          currentTable: table,
                          referencedTable: $$ProductionCellsTableReferences
                              ._productionLinesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProductionCellsTableReferences(
                                db,
                                table,
                                p0,
                              ).productionLinesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.cellId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (studiesRefs)
                        await $_getPrefetchedData<
                          ProductionCell,
                          $ProductionCellsTable,
                          Study
                        >(
                          currentTable: table,
                          referencedTable: $$ProductionCellsTableReferences
                              ._studiesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProductionCellsTableReferences(
                                db,
                                table,
                                p0,
                              ).studiesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.productionCellId == item.id,
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

typedef $$ProductionCellsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProductionCellsTable,
      ProductionCell,
      $$ProductionCellsTableFilterComposer,
      $$ProductionCellsTableOrderingComposer,
      $$ProductionCellsTableAnnotationComposer,
      $$ProductionCellsTableCreateCompanionBuilder,
      $$ProductionCellsTableUpdateCompanionBuilder,
      (ProductionCell, $$ProductionCellsTableReferences),
      ProductionCell,
      PrefetchHooks Function({
        bool plantId,
        bool productionLinesRefs,
        bool studiesRefs,
      })
    >;
typedef $$ProductionLinesTableCreateCompanionBuilder =
    ProductionLinesCompanion Function({
      required String id,
      required String cellId,
      required String name,
      Value<String?> notes,
      Value<DateTime?> archivedAt,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ProductionLinesTableUpdateCompanionBuilder =
    ProductionLinesCompanion Function({
      Value<String> id,
      Value<String> cellId,
      Value<String> name,
      Value<String?> notes,
      Value<DateTime?> archivedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$ProductionLinesTableReferences
    extends
        BaseReferences<_$AppDatabase, $ProductionLinesTable, ProductionLine> {
  $$ProductionLinesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ProductionCellsTable _cellIdTable(_$AppDatabase db) => db
      .productionCells
      .createAlias('production_lines__cell_id__production_cells__id');

  $$ProductionCellsTableProcessedTableManager get cellId {
    final $_column = $_itemColumn<String>('cell_id')!;

    final manager = $$ProductionCellsTableTableManager(
      $_db,
      $_db.productionCells,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_cellIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$WorkcenterLinesTable, List<WorkcenterLine>>
  _workcenterLinesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.workcenterLines,
    aliasName: 'production_lines__id__workcenter_lines__line_id',
  );

  $$WorkcenterLinesTableProcessedTableManager get workcenterLinesRefs {
    final manager = $$WorkcenterLinesTableTableManager(
      $_db,
      $_db.workcenterLines,
    ).filter((f) => f.lineId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _workcenterLinesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TaktPeriodsTable, List<TaktPeriod>>
  _taktPeriodsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.taktPeriods,
    aliasName: 'production_lines__id__takt_periods__production_line_id',
  );

  $$TaktPeriodsTableProcessedTableManager get taktPeriodsRefs {
    final manager = $$TaktPeriodsTableTableManager($_db, $_db.taktPeriods)
        .filter(
          (f) => f.productionLineId.id.sqlEquals($_itemColumn<String>('id')!),
        );

    final cache = $_typedResult.readTableOrNull(_taktPeriodsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$StudiesTable, List<Study>> _studiesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.studies,
    aliasName: 'production_lines__id__studies__production_line_id',
  );

  $$StudiesTableProcessedTableManager get studiesRefs {
    final manager = $$StudiesTableTableManager($_db, $_db.studies).filter(
      (f) => f.productionLineId.id.sqlEquals($_itemColumn<String>('id')!),
    );

    final cache = $_typedResult.readTableOrNull(_studiesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ProductionLinesTableFilterComposer
    extends Composer<_$AppDatabase, $ProductionLinesTable> {
  $$ProductionLinesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
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

  $$ProductionCellsTableFilterComposer get cellId {
    final $$ProductionCellsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cellId,
      referencedTable: $db.productionCells,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductionCellsTableFilterComposer(
            $db: $db,
            $table: $db.productionCells,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> workcenterLinesRefs(
    Expression<bool> Function($$WorkcenterLinesTableFilterComposer f) f,
  ) {
    final $$WorkcenterLinesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workcenterLines,
      getReferencedColumn: (t) => t.lineId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkcenterLinesTableFilterComposer(
            $db: $db,
            $table: $db.workcenterLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> taktPeriodsRefs(
    Expression<bool> Function($$TaktPeriodsTableFilterComposer f) f,
  ) {
    final $$TaktPeriodsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taktPeriods,
      getReferencedColumn: (t) => t.productionLineId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaktPeriodsTableFilterComposer(
            $db: $db,
            $table: $db.taktPeriods,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> studiesRefs(
    Expression<bool> Function($$StudiesTableFilterComposer f) f,
  ) {
    final $$StudiesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.studies,
      getReferencedColumn: (t) => t.productionLineId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudiesTableFilterComposer(
            $db: $db,
            $table: $db.studies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProductionLinesTableOrderingComposer
    extends Composer<_$AppDatabase, $ProductionLinesTable> {
  $$ProductionLinesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
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

  $$ProductionCellsTableOrderingComposer get cellId {
    final $$ProductionCellsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cellId,
      referencedTable: $db.productionCells,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductionCellsTableOrderingComposer(
            $db: $db,
            $table: $db.productionCells,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProductionLinesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProductionLinesTable> {
  $$ProductionLinesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$ProductionCellsTableAnnotationComposer get cellId {
    final $$ProductionCellsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cellId,
      referencedTable: $db.productionCells,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductionCellsTableAnnotationComposer(
            $db: $db,
            $table: $db.productionCells,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> workcenterLinesRefs<T extends Object>(
    Expression<T> Function($$WorkcenterLinesTableAnnotationComposer a) f,
  ) {
    final $$WorkcenterLinesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workcenterLines,
      getReferencedColumn: (t) => t.lineId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkcenterLinesTableAnnotationComposer(
            $db: $db,
            $table: $db.workcenterLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> taktPeriodsRefs<T extends Object>(
    Expression<T> Function($$TaktPeriodsTableAnnotationComposer a) f,
  ) {
    final $$TaktPeriodsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taktPeriods,
      getReferencedColumn: (t) => t.productionLineId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaktPeriodsTableAnnotationComposer(
            $db: $db,
            $table: $db.taktPeriods,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> studiesRefs<T extends Object>(
    Expression<T> Function($$StudiesTableAnnotationComposer a) f,
  ) {
    final $$StudiesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.studies,
      getReferencedColumn: (t) => t.productionLineId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudiesTableAnnotationComposer(
            $db: $db,
            $table: $db.studies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProductionLinesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProductionLinesTable,
          ProductionLine,
          $$ProductionLinesTableFilterComposer,
          $$ProductionLinesTableOrderingComposer,
          $$ProductionLinesTableAnnotationComposer,
          $$ProductionLinesTableCreateCompanionBuilder,
          $$ProductionLinesTableUpdateCompanionBuilder,
          (ProductionLine, $$ProductionLinesTableReferences),
          ProductionLine,
          PrefetchHooks Function({
            bool cellId,
            bool workcenterLinesRefs,
            bool taktPeriodsRefs,
            bool studiesRefs,
          })
        > {
  $$ProductionLinesTableTableManager(
    _$AppDatabase db,
    $ProductionLinesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProductionLinesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProductionLinesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProductionLinesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> cellId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProductionLinesCompanion(
                id: id,
                cellId: cellId,
                name: name,
                notes: notes,
                archivedAt: archivedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String cellId,
                required String name,
                Value<String?> notes = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ProductionLinesCompanion.insert(
                id: id,
                cellId: cellId,
                name: name,
                notes: notes,
                archivedAt: archivedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ProductionLinesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                cellId = false,
                workcenterLinesRefs = false,
                taktPeriodsRefs = false,
                studiesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (workcenterLinesRefs) db.workcenterLines,
                    if (taktPeriodsRefs) db.taktPeriods,
                    if (studiesRefs) db.studies,
                  ],
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
                        if (cellId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.cellId,
                                    referencedTable:
                                        $$ProductionLinesTableReferences
                                            ._cellIdTable(db),
                                    referencedColumn:
                                        $$ProductionLinesTableReferences
                                            ._cellIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (workcenterLinesRefs)
                        await $_getPrefetchedData<
                          ProductionLine,
                          $ProductionLinesTable,
                          WorkcenterLine
                        >(
                          currentTable: table,
                          referencedTable: $$ProductionLinesTableReferences
                              ._workcenterLinesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProductionLinesTableReferences(
                                db,
                                table,
                                p0,
                              ).workcenterLinesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.lineId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (taktPeriodsRefs)
                        await $_getPrefetchedData<
                          ProductionLine,
                          $ProductionLinesTable,
                          TaktPeriod
                        >(
                          currentTable: table,
                          referencedTable: $$ProductionLinesTableReferences
                              ._taktPeriodsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProductionLinesTableReferences(
                                db,
                                table,
                                p0,
                              ).taktPeriodsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.productionLineId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (studiesRefs)
                        await $_getPrefetchedData<
                          ProductionLine,
                          $ProductionLinesTable,
                          Study
                        >(
                          currentTable: table,
                          referencedTable: $$ProductionLinesTableReferences
                              ._studiesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProductionLinesTableReferences(
                                db,
                                table,
                                p0,
                              ).studiesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.productionLineId == item.id,
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

typedef $$ProductionLinesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProductionLinesTable,
      ProductionLine,
      $$ProductionLinesTableFilterComposer,
      $$ProductionLinesTableOrderingComposer,
      $$ProductionLinesTableAnnotationComposer,
      $$ProductionLinesTableCreateCompanionBuilder,
      $$ProductionLinesTableUpdateCompanionBuilder,
      (ProductionLine, $$ProductionLinesTableReferences),
      ProductionLine,
      PrefetchHooks Function({
        bool cellId,
        bool workcenterLinesRefs,
        bool taktPeriodsRefs,
        bool studiesRefs,
      })
    >;
typedef $$WorkcenterTypesTableCreateCompanionBuilder =
    WorkcenterTypesCompanion Function({
      required String id,
      Value<WorkcenterIcon?> icon,
      required String name,
      Value<bool> isBuiltIn,
      Value<DateTime?> archivedAt,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$WorkcenterTypesTableUpdateCompanionBuilder =
    WorkcenterTypesCompanion Function({
      Value<String> id,
      Value<WorkcenterIcon?> icon,
      Value<String> name,
      Value<bool> isBuiltIn,
      Value<DateTime?> archivedAt,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$WorkcenterTypesTableReferences
    extends
        BaseReferences<_$AppDatabase, $WorkcenterTypesTable, WorkcenterType> {
  $$WorkcenterTypesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$WorkcentersTable, List<Workcenter>>
  _workcentersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.workcenters,
    aliasName: 'workcenter_types__id__workcenters__type_id',
  );

  $$WorkcentersTableProcessedTableManager get workcentersRefs {
    final manager = $$WorkcentersTableTableManager(
      $_db,
      $_db.workcenters,
    ).filter((f) => f.typeId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_workcentersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$WorkcenterTypesTableFilterComposer
    extends Composer<_$AppDatabase, $WorkcenterTypesTable> {
  $$WorkcenterTypesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<WorkcenterIcon?, WorkcenterIcon, String>
  get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isBuiltIn => $composableBuilder(
    column: $table.isBuiltIn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> workcentersRefs(
    Expression<bool> Function($$WorkcentersTableFilterComposer f) f,
  ) {
    final $$WorkcentersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workcenters,
      getReferencedColumn: (t) => t.typeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkcentersTableFilterComposer(
            $db: $db,
            $table: $db.workcenters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WorkcenterTypesTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkcenterTypesTable> {
  $$WorkcenterTypesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isBuiltIn => $composableBuilder(
    column: $table.isBuiltIn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WorkcenterTypesTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkcenterTypesTable> {
  $$WorkcenterTypesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<WorkcenterIcon?, String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get isBuiltIn =>
      $composableBuilder(column: $table.isBuiltIn, builder: (column) => column);

  GeneratedColumn<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> workcentersRefs<T extends Object>(
    Expression<T> Function($$WorkcentersTableAnnotationComposer a) f,
  ) {
    final $$WorkcentersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workcenters,
      getReferencedColumn: (t) => t.typeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkcentersTableAnnotationComposer(
            $db: $db,
            $table: $db.workcenters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WorkcenterTypesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkcenterTypesTable,
          WorkcenterType,
          $$WorkcenterTypesTableFilterComposer,
          $$WorkcenterTypesTableOrderingComposer,
          $$WorkcenterTypesTableAnnotationComposer,
          $$WorkcenterTypesTableCreateCompanionBuilder,
          $$WorkcenterTypesTableUpdateCompanionBuilder,
          (WorkcenterType, $$WorkcenterTypesTableReferences),
          WorkcenterType,
          PrefetchHooks Function({bool workcentersRefs})
        > {
  $$WorkcenterTypesTableTableManager(
    _$AppDatabase db,
    $WorkcenterTypesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkcenterTypesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkcenterTypesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkcenterTypesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<WorkcenterIcon?> icon = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<bool> isBuiltIn = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkcenterTypesCompanion(
                id: id,
                icon: icon,
                name: name,
                isBuiltIn: isBuiltIn,
                archivedAt: archivedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<WorkcenterIcon?> icon = const Value.absent(),
                required String name,
                Value<bool> isBuiltIn = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => WorkcenterTypesCompanion.insert(
                id: id,
                icon: icon,
                name: name,
                isBuiltIn: isBuiltIn,
                archivedAt: archivedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$WorkcenterTypesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({workcentersRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (workcentersRefs) db.workcenters],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (workcentersRefs)
                    await $_getPrefetchedData<
                      WorkcenterType,
                      $WorkcenterTypesTable,
                      Workcenter
                    >(
                      currentTable: table,
                      referencedTable: $$WorkcenterTypesTableReferences
                          ._workcentersRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$WorkcenterTypesTableReferences(
                            db,
                            table,
                            p0,
                          ).workcentersRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.typeId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$WorkcenterTypesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkcenterTypesTable,
      WorkcenterType,
      $$WorkcenterTypesTableFilterComposer,
      $$WorkcenterTypesTableOrderingComposer,
      $$WorkcenterTypesTableAnnotationComposer,
      $$WorkcenterTypesTableCreateCompanionBuilder,
      $$WorkcenterTypesTableUpdateCompanionBuilder,
      (WorkcenterType, $$WorkcenterTypesTableReferences),
      WorkcenterType,
      PrefetchHooks Function({bool workcentersRefs})
    >;
typedef $$WorkcentersTableCreateCompanionBuilder =
    WorkcentersCompanion Function({
      required String id,
      required String plantId,
      Value<String?> typeId,
      required String name,
      Value<String?> notes,
      Value<DateTime?> archivedAt,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$WorkcentersTableUpdateCompanionBuilder =
    WorkcentersCompanion Function({
      Value<String> id,
      Value<String> plantId,
      Value<String?> typeId,
      Value<String> name,
      Value<String?> notes,
      Value<DateTime?> archivedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$WorkcentersTableReferences
    extends BaseReferences<_$AppDatabase, $WorkcentersTable, Workcenter> {
  $$WorkcentersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PlantsTable _plantIdTable(_$AppDatabase db) =>
      db.plants.createAlias('workcenters__plant_id__plants__id');

  $$PlantsTableProcessedTableManager get plantId {
    final $_column = $_itemColumn<String>('plant_id')!;

    final manager = $$PlantsTableTableManager(
      $_db,
      $_db.plants,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_plantIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $WorkcenterTypesTable _typeIdTable(_$AppDatabase db) => db
      .workcenterTypes
      .createAlias('workcenters__type_id__workcenter_types__id');

  $$WorkcenterTypesTableProcessedTableManager? get typeId {
    final $_column = $_itemColumn<String>('type_id');
    if ($_column == null) return null;
    final manager = $$WorkcenterTypesTableTableManager(
      $_db,
      $_db.workcenterTypes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_typeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$WorkcenterLinesTable, List<WorkcenterLine>>
  _workcenterLinesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.workcenterLines,
    aliasName: 'workcenters__id__workcenter_lines__workcenter_id',
  );

  $$WorkcenterLinesTableProcessedTableManager get workcenterLinesRefs {
    final manager = $$WorkcenterLinesTableTableManager(
      $_db,
      $_db.workcenterLines,
    ).filter((f) => f.workcenterId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _workcenterLinesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $WorkcenterPoolMembersTable,
    List<WorkcenterPoolMember>
  >
  _workcenterPoolMembersRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.workcenterPoolMembers,
        aliasName: 'workcenters__id__workcenter_pool_members__workcenter_id',
      );

  $$WorkcenterPoolMembersTableProcessedTableManager
  get workcenterPoolMembersRefs {
    final manager = $$WorkcenterPoolMembersTableTableManager(
      $_db,
      $_db.workcenterPoolMembers,
    ).filter((f) => f.workcenterId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _workcenterPoolMembersRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $WorkcenterSchedulePeriodsTable,
    List<WorkcenterSchedulePeriod>
  >
  _workcenterSchedulePeriodsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.workcenterSchedulePeriods,
        aliasName:
            'workcenters__id__workcenter_schedule_periods__workcenter_id',
      );

  $$WorkcenterSchedulePeriodsTableProcessedTableManager
  get workcenterSchedulePeriodsRefs {
    final manager = $$WorkcenterSchedulePeriodsTableTableManager(
      $_db,
      $_db.workcenterSchedulePeriods,
    ).filter((f) => f.workcenterId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _workcenterSchedulePeriodsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$FlowNodesTable, List<FlowNode>>
  _flowNodesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.flowNodes,
    aliasName: 'workcenters__id__flow_nodes__workcenter_id',
  );

  $$FlowNodesTableProcessedTableManager get flowNodesRefs {
    final manager = $$FlowNodesTableTableManager(
      $_db,
      $_db.flowNodes,
    ).filter((f) => f.workcenterId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_flowNodesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$WorkcentersTableFilterComposer
    extends Composer<_$AppDatabase, $WorkcentersTable> {
  $$WorkcentersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
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

  $$PlantsTableFilterComposer get plantId {
    final $$PlantsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.plantId,
      referencedTable: $db.plants,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlantsTableFilterComposer(
            $db: $db,
            $table: $db.plants,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WorkcenterTypesTableFilterComposer get typeId {
    final $$WorkcenterTypesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.typeId,
      referencedTable: $db.workcenterTypes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkcenterTypesTableFilterComposer(
            $db: $db,
            $table: $db.workcenterTypes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> workcenterLinesRefs(
    Expression<bool> Function($$WorkcenterLinesTableFilterComposer f) f,
  ) {
    final $$WorkcenterLinesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workcenterLines,
      getReferencedColumn: (t) => t.workcenterId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkcenterLinesTableFilterComposer(
            $db: $db,
            $table: $db.workcenterLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> workcenterPoolMembersRefs(
    Expression<bool> Function($$WorkcenterPoolMembersTableFilterComposer f) f,
  ) {
    final $$WorkcenterPoolMembersTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.workcenterPoolMembers,
          getReferencedColumn: (t) => t.workcenterId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$WorkcenterPoolMembersTableFilterComposer(
                $db: $db,
                $table: $db.workcenterPoolMembers,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> workcenterSchedulePeriodsRefs(
    Expression<bool> Function($$WorkcenterSchedulePeriodsTableFilterComposer f)
    f,
  ) {
    final $$WorkcenterSchedulePeriodsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.workcenterSchedulePeriods,
          getReferencedColumn: (t) => t.workcenterId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$WorkcenterSchedulePeriodsTableFilterComposer(
                $db: $db,
                $table: $db.workcenterSchedulePeriods,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> flowNodesRefs(
    Expression<bool> Function($$FlowNodesTableFilterComposer f) f,
  ) {
    final $$FlowNodesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.flowNodes,
      getReferencedColumn: (t) => t.workcenterId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FlowNodesTableFilterComposer(
            $db: $db,
            $table: $db.flowNodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WorkcentersTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkcentersTable> {
  $$WorkcentersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
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

  $$PlantsTableOrderingComposer get plantId {
    final $$PlantsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.plantId,
      referencedTable: $db.plants,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlantsTableOrderingComposer(
            $db: $db,
            $table: $db.plants,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WorkcenterTypesTableOrderingComposer get typeId {
    final $$WorkcenterTypesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.typeId,
      referencedTable: $db.workcenterTypes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkcenterTypesTableOrderingComposer(
            $db: $db,
            $table: $db.workcenterTypes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkcentersTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkcentersTable> {
  $$WorkcentersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$PlantsTableAnnotationComposer get plantId {
    final $$PlantsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.plantId,
      referencedTable: $db.plants,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlantsTableAnnotationComposer(
            $db: $db,
            $table: $db.plants,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WorkcenterTypesTableAnnotationComposer get typeId {
    final $$WorkcenterTypesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.typeId,
      referencedTable: $db.workcenterTypes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkcenterTypesTableAnnotationComposer(
            $db: $db,
            $table: $db.workcenterTypes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> workcenterLinesRefs<T extends Object>(
    Expression<T> Function($$WorkcenterLinesTableAnnotationComposer a) f,
  ) {
    final $$WorkcenterLinesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workcenterLines,
      getReferencedColumn: (t) => t.workcenterId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkcenterLinesTableAnnotationComposer(
            $db: $db,
            $table: $db.workcenterLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> workcenterPoolMembersRefs<T extends Object>(
    Expression<T> Function($$WorkcenterPoolMembersTableAnnotationComposer a) f,
  ) {
    final $$WorkcenterPoolMembersTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.workcenterPoolMembers,
          getReferencedColumn: (t) => t.workcenterId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$WorkcenterPoolMembersTableAnnotationComposer(
                $db: $db,
                $table: $db.workcenterPoolMembers,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> workcenterSchedulePeriodsRefs<T extends Object>(
    Expression<T> Function($$WorkcenterSchedulePeriodsTableAnnotationComposer a)
    f,
  ) {
    final $$WorkcenterSchedulePeriodsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.workcenterSchedulePeriods,
          getReferencedColumn: (t) => t.workcenterId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$WorkcenterSchedulePeriodsTableAnnotationComposer(
                $db: $db,
                $table: $db.workcenterSchedulePeriods,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> flowNodesRefs<T extends Object>(
    Expression<T> Function($$FlowNodesTableAnnotationComposer a) f,
  ) {
    final $$FlowNodesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.flowNodes,
      getReferencedColumn: (t) => t.workcenterId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FlowNodesTableAnnotationComposer(
            $db: $db,
            $table: $db.flowNodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WorkcentersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkcentersTable,
          Workcenter,
          $$WorkcentersTableFilterComposer,
          $$WorkcentersTableOrderingComposer,
          $$WorkcentersTableAnnotationComposer,
          $$WorkcentersTableCreateCompanionBuilder,
          $$WorkcentersTableUpdateCompanionBuilder,
          (Workcenter, $$WorkcentersTableReferences),
          Workcenter,
          PrefetchHooks Function({
            bool plantId,
            bool typeId,
            bool workcenterLinesRefs,
            bool workcenterPoolMembersRefs,
            bool workcenterSchedulePeriodsRefs,
            bool flowNodesRefs,
          })
        > {
  $$WorkcentersTableTableManager(_$AppDatabase db, $WorkcentersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkcentersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkcentersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkcentersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> plantId = const Value.absent(),
                Value<String?> typeId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkcentersCompanion(
                id: id,
                plantId: plantId,
                typeId: typeId,
                name: name,
                notes: notes,
                archivedAt: archivedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String plantId,
                Value<String?> typeId = const Value.absent(),
                required String name,
                Value<String?> notes = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => WorkcentersCompanion.insert(
                id: id,
                plantId: plantId,
                typeId: typeId,
                name: name,
                notes: notes,
                archivedAt: archivedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$WorkcentersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                plantId = false,
                typeId = false,
                workcenterLinesRefs = false,
                workcenterPoolMembersRefs = false,
                workcenterSchedulePeriodsRefs = false,
                flowNodesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (workcenterLinesRefs) db.workcenterLines,
                    if (workcenterPoolMembersRefs) db.workcenterPoolMembers,
                    if (workcenterSchedulePeriodsRefs)
                      db.workcenterSchedulePeriods,
                    if (flowNodesRefs) db.flowNodes,
                  ],
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
                        if (plantId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.plantId,
                                    referencedTable:
                                        $$WorkcentersTableReferences
                                            ._plantIdTable(db),
                                    referencedColumn:
                                        $$WorkcentersTableReferences
                                            ._plantIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (typeId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.typeId,
                                    referencedTable:
                                        $$WorkcentersTableReferences
                                            ._typeIdTable(db),
                                    referencedColumn:
                                        $$WorkcentersTableReferences
                                            ._typeIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (workcenterLinesRefs)
                        await $_getPrefetchedData<
                          Workcenter,
                          $WorkcentersTable,
                          WorkcenterLine
                        >(
                          currentTable: table,
                          referencedTable: $$WorkcentersTableReferences
                              ._workcenterLinesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$WorkcentersTableReferences(
                                db,
                                table,
                                p0,
                              ).workcenterLinesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.workcenterId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (workcenterPoolMembersRefs)
                        await $_getPrefetchedData<
                          Workcenter,
                          $WorkcentersTable,
                          WorkcenterPoolMember
                        >(
                          currentTable: table,
                          referencedTable: $$WorkcentersTableReferences
                              ._workcenterPoolMembersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$WorkcentersTableReferences(
                                db,
                                table,
                                p0,
                              ).workcenterPoolMembersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.workcenterId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (workcenterSchedulePeriodsRefs)
                        await $_getPrefetchedData<
                          Workcenter,
                          $WorkcentersTable,
                          WorkcenterSchedulePeriod
                        >(
                          currentTable: table,
                          referencedTable: $$WorkcentersTableReferences
                              ._workcenterSchedulePeriodsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$WorkcentersTableReferences(
                                db,
                                table,
                                p0,
                              ).workcenterSchedulePeriodsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.workcenterId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (flowNodesRefs)
                        await $_getPrefetchedData<
                          Workcenter,
                          $WorkcentersTable,
                          FlowNode
                        >(
                          currentTable: table,
                          referencedTable: $$WorkcentersTableReferences
                              ._flowNodesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$WorkcentersTableReferences(
                                db,
                                table,
                                p0,
                              ).flowNodesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.workcenterId == item.id,
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

typedef $$WorkcentersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkcentersTable,
      Workcenter,
      $$WorkcentersTableFilterComposer,
      $$WorkcentersTableOrderingComposer,
      $$WorkcentersTableAnnotationComposer,
      $$WorkcentersTableCreateCompanionBuilder,
      $$WorkcentersTableUpdateCompanionBuilder,
      (Workcenter, $$WorkcentersTableReferences),
      Workcenter,
      PrefetchHooks Function({
        bool plantId,
        bool typeId,
        bool workcenterLinesRefs,
        bool workcenterPoolMembersRefs,
        bool workcenterSchedulePeriodsRefs,
        bool flowNodesRefs,
      })
    >;
typedef $$WorkcenterLinesTableCreateCompanionBuilder =
    WorkcenterLinesCompanion Function({
      required String workcenterId,
      required String lineId,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$WorkcenterLinesTableUpdateCompanionBuilder =
    WorkcenterLinesCompanion Function({
      Value<String> workcenterId,
      Value<String> lineId,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$WorkcenterLinesTableReferences
    extends
        BaseReferences<_$AppDatabase, $WorkcenterLinesTable, WorkcenterLine> {
  $$WorkcenterLinesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $WorkcentersTable _workcenterIdTable(_$AppDatabase db) => db
      .workcenters
      .createAlias('workcenter_lines__workcenter_id__workcenters__id');

  $$WorkcentersTableProcessedTableManager get workcenterId {
    final $_column = $_itemColumn<String>('workcenter_id')!;

    final manager = $$WorkcentersTableTableManager(
      $_db,
      $_db.workcenters,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_workcenterIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ProductionLinesTable _lineIdTable(_$AppDatabase db) => db
      .productionLines
      .createAlias('workcenter_lines__line_id__production_lines__id');

  $$ProductionLinesTableProcessedTableManager get lineId {
    final $_column = $_itemColumn<String>('line_id')!;

    final manager = $$ProductionLinesTableTableManager(
      $_db,
      $_db.productionLines,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_lineIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$WorkcenterLinesTableFilterComposer
    extends Composer<_$AppDatabase, $WorkcenterLinesTable> {
  $$WorkcenterLinesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$WorkcentersTableFilterComposer get workcenterId {
    final $$WorkcentersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workcenterId,
      referencedTable: $db.workcenters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkcentersTableFilterComposer(
            $db: $db,
            $table: $db.workcenters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProductionLinesTableFilterComposer get lineId {
    final $$ProductionLinesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.lineId,
      referencedTable: $db.productionLines,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductionLinesTableFilterComposer(
            $db: $db,
            $table: $db.productionLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkcenterLinesTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkcenterLinesTable> {
  $$WorkcenterLinesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$WorkcentersTableOrderingComposer get workcenterId {
    final $$WorkcentersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workcenterId,
      referencedTable: $db.workcenters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkcentersTableOrderingComposer(
            $db: $db,
            $table: $db.workcenters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProductionLinesTableOrderingComposer get lineId {
    final $$ProductionLinesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.lineId,
      referencedTable: $db.productionLines,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductionLinesTableOrderingComposer(
            $db: $db,
            $table: $db.productionLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkcenterLinesTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkcenterLinesTable> {
  $$WorkcenterLinesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$WorkcentersTableAnnotationComposer get workcenterId {
    final $$WorkcentersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workcenterId,
      referencedTable: $db.workcenters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkcentersTableAnnotationComposer(
            $db: $db,
            $table: $db.workcenters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProductionLinesTableAnnotationComposer get lineId {
    final $$ProductionLinesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.lineId,
      referencedTable: $db.productionLines,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductionLinesTableAnnotationComposer(
            $db: $db,
            $table: $db.productionLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkcenterLinesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkcenterLinesTable,
          WorkcenterLine,
          $$WorkcenterLinesTableFilterComposer,
          $$WorkcenterLinesTableOrderingComposer,
          $$WorkcenterLinesTableAnnotationComposer,
          $$WorkcenterLinesTableCreateCompanionBuilder,
          $$WorkcenterLinesTableUpdateCompanionBuilder,
          (WorkcenterLine, $$WorkcenterLinesTableReferences),
          WorkcenterLine,
          PrefetchHooks Function({bool workcenterId, bool lineId})
        > {
  $$WorkcenterLinesTableTableManager(
    _$AppDatabase db,
    $WorkcenterLinesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkcenterLinesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkcenterLinesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkcenterLinesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> workcenterId = const Value.absent(),
                Value<String> lineId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkcenterLinesCompanion(
                workcenterId: workcenterId,
                lineId: lineId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String workcenterId,
                required String lineId,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => WorkcenterLinesCompanion.insert(
                workcenterId: workcenterId,
                lineId: lineId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$WorkcenterLinesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({workcenterId = false, lineId = false}) {
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
                    if (workcenterId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.workcenterId,
                                referencedTable:
                                    $$WorkcenterLinesTableReferences
                                        ._workcenterIdTable(db),
                                referencedColumn:
                                    $$WorkcenterLinesTableReferences
                                        ._workcenterIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (lineId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.lineId,
                                referencedTable:
                                    $$WorkcenterLinesTableReferences
                                        ._lineIdTable(db),
                                referencedColumn:
                                    $$WorkcenterLinesTableReferences
                                        ._lineIdTable(db)
                                        .id,
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

typedef $$WorkcenterLinesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkcenterLinesTable,
      WorkcenterLine,
      $$WorkcenterLinesTableFilterComposer,
      $$WorkcenterLinesTableOrderingComposer,
      $$WorkcenterLinesTableAnnotationComposer,
      $$WorkcenterLinesTableCreateCompanionBuilder,
      $$WorkcenterLinesTableUpdateCompanionBuilder,
      (WorkcenterLine, $$WorkcenterLinesTableReferences),
      WorkcenterLine,
      PrefetchHooks Function({bool workcenterId, bool lineId})
    >;
typedef $$WorkcenterPoolsTableCreateCompanionBuilder =
    WorkcenterPoolsCompanion Function({
      required String id,
      required String plantId,
      required String name,
      Value<String?> notes,
      Value<DateTime?> archivedAt,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$WorkcenterPoolsTableUpdateCompanionBuilder =
    WorkcenterPoolsCompanion Function({
      Value<String> id,
      Value<String> plantId,
      Value<String> name,
      Value<String?> notes,
      Value<DateTime?> archivedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$WorkcenterPoolsTableReferences
    extends
        BaseReferences<_$AppDatabase, $WorkcenterPoolsTable, WorkcenterPool> {
  $$WorkcenterPoolsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PlantsTable _plantIdTable(_$AppDatabase db) =>
      db.plants.createAlias('workcenter_pools__plant_id__plants__id');

  $$PlantsTableProcessedTableManager get plantId {
    final $_column = $_itemColumn<String>('plant_id')!;

    final manager = $$PlantsTableTableManager(
      $_db,
      $_db.plants,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_plantIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<
    $WorkcenterPoolMembersTable,
    List<WorkcenterPoolMember>
  >
  _workcenterPoolMembersRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.workcenterPoolMembers,
        aliasName: 'workcenter_pools__id__workcenter_pool_members__pool_id',
      );

  $$WorkcenterPoolMembersTableProcessedTableManager
  get workcenterPoolMembersRefs {
    final manager = $$WorkcenterPoolMembersTableTableManager(
      $_db,
      $_db.workcenterPoolMembers,
    ).filter((f) => f.poolId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _workcenterPoolMembersRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$FlowNodesTable, List<FlowNode>>
  _flowNodesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.flowNodes,
    aliasName: 'workcenter_pools__id__flow_nodes__pool_id',
  );

  $$FlowNodesTableProcessedTableManager get flowNodesRefs {
    final manager = $$FlowNodesTableTableManager(
      $_db,
      $_db.flowNodes,
    ).filter((f) => f.poolId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_flowNodesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$WorkcenterPoolsTableFilterComposer
    extends Composer<_$AppDatabase, $WorkcenterPoolsTable> {
  $$WorkcenterPoolsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
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

  $$PlantsTableFilterComposer get plantId {
    final $$PlantsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.plantId,
      referencedTable: $db.plants,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlantsTableFilterComposer(
            $db: $db,
            $table: $db.plants,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> workcenterPoolMembersRefs(
    Expression<bool> Function($$WorkcenterPoolMembersTableFilterComposer f) f,
  ) {
    final $$WorkcenterPoolMembersTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.workcenterPoolMembers,
          getReferencedColumn: (t) => t.poolId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$WorkcenterPoolMembersTableFilterComposer(
                $db: $db,
                $table: $db.workcenterPoolMembers,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> flowNodesRefs(
    Expression<bool> Function($$FlowNodesTableFilterComposer f) f,
  ) {
    final $$FlowNodesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.flowNodes,
      getReferencedColumn: (t) => t.poolId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FlowNodesTableFilterComposer(
            $db: $db,
            $table: $db.flowNodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WorkcenterPoolsTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkcenterPoolsTable> {
  $$WorkcenterPoolsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
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

  $$PlantsTableOrderingComposer get plantId {
    final $$PlantsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.plantId,
      referencedTable: $db.plants,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlantsTableOrderingComposer(
            $db: $db,
            $table: $db.plants,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkcenterPoolsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkcenterPoolsTable> {
  $$WorkcenterPoolsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$PlantsTableAnnotationComposer get plantId {
    final $$PlantsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.plantId,
      referencedTable: $db.plants,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlantsTableAnnotationComposer(
            $db: $db,
            $table: $db.plants,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> workcenterPoolMembersRefs<T extends Object>(
    Expression<T> Function($$WorkcenterPoolMembersTableAnnotationComposer a) f,
  ) {
    final $$WorkcenterPoolMembersTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.workcenterPoolMembers,
          getReferencedColumn: (t) => t.poolId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$WorkcenterPoolMembersTableAnnotationComposer(
                $db: $db,
                $table: $db.workcenterPoolMembers,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> flowNodesRefs<T extends Object>(
    Expression<T> Function($$FlowNodesTableAnnotationComposer a) f,
  ) {
    final $$FlowNodesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.flowNodes,
      getReferencedColumn: (t) => t.poolId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FlowNodesTableAnnotationComposer(
            $db: $db,
            $table: $db.flowNodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WorkcenterPoolsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkcenterPoolsTable,
          WorkcenterPool,
          $$WorkcenterPoolsTableFilterComposer,
          $$WorkcenterPoolsTableOrderingComposer,
          $$WorkcenterPoolsTableAnnotationComposer,
          $$WorkcenterPoolsTableCreateCompanionBuilder,
          $$WorkcenterPoolsTableUpdateCompanionBuilder,
          (WorkcenterPool, $$WorkcenterPoolsTableReferences),
          WorkcenterPool,
          PrefetchHooks Function({
            bool plantId,
            bool workcenterPoolMembersRefs,
            bool flowNodesRefs,
          })
        > {
  $$WorkcenterPoolsTableTableManager(
    _$AppDatabase db,
    $WorkcenterPoolsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkcenterPoolsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkcenterPoolsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkcenterPoolsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> plantId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkcenterPoolsCompanion(
                id: id,
                plantId: plantId,
                name: name,
                notes: notes,
                archivedAt: archivedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String plantId,
                required String name,
                Value<String?> notes = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => WorkcenterPoolsCompanion.insert(
                id: id,
                plantId: plantId,
                name: name,
                notes: notes,
                archivedAt: archivedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$WorkcenterPoolsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                plantId = false,
                workcenterPoolMembersRefs = false,
                flowNodesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (workcenterPoolMembersRefs) db.workcenterPoolMembers,
                    if (flowNodesRefs) db.flowNodes,
                  ],
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
                        if (plantId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.plantId,
                                    referencedTable:
                                        $$WorkcenterPoolsTableReferences
                                            ._plantIdTable(db),
                                    referencedColumn:
                                        $$WorkcenterPoolsTableReferences
                                            ._plantIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (workcenterPoolMembersRefs)
                        await $_getPrefetchedData<
                          WorkcenterPool,
                          $WorkcenterPoolsTable,
                          WorkcenterPoolMember
                        >(
                          currentTable: table,
                          referencedTable: $$WorkcenterPoolsTableReferences
                              ._workcenterPoolMembersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$WorkcenterPoolsTableReferences(
                                db,
                                table,
                                p0,
                              ).workcenterPoolMembersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.poolId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (flowNodesRefs)
                        await $_getPrefetchedData<
                          WorkcenterPool,
                          $WorkcenterPoolsTable,
                          FlowNode
                        >(
                          currentTable: table,
                          referencedTable: $$WorkcenterPoolsTableReferences
                              ._flowNodesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$WorkcenterPoolsTableReferences(
                                db,
                                table,
                                p0,
                              ).flowNodesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.poolId == item.id,
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

typedef $$WorkcenterPoolsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkcenterPoolsTable,
      WorkcenterPool,
      $$WorkcenterPoolsTableFilterComposer,
      $$WorkcenterPoolsTableOrderingComposer,
      $$WorkcenterPoolsTableAnnotationComposer,
      $$WorkcenterPoolsTableCreateCompanionBuilder,
      $$WorkcenterPoolsTableUpdateCompanionBuilder,
      (WorkcenterPool, $$WorkcenterPoolsTableReferences),
      WorkcenterPool,
      PrefetchHooks Function({
        bool plantId,
        bool workcenterPoolMembersRefs,
        bool flowNodesRefs,
      })
    >;
typedef $$WorkcenterPoolMembersTableCreateCompanionBuilder =
    WorkcenterPoolMembersCompanion Function({
      required String poolId,
      required String workcenterId,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$WorkcenterPoolMembersTableUpdateCompanionBuilder =
    WorkcenterPoolMembersCompanion Function({
      Value<String> poolId,
      Value<String> workcenterId,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$WorkcenterPoolMembersTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $WorkcenterPoolMembersTable,
          WorkcenterPoolMember
        > {
  $$WorkcenterPoolMembersTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $WorkcenterPoolsTable _poolIdTable(_$AppDatabase db) => db
      .workcenterPools
      .createAlias('workcenter_pool_members__pool_id__workcenter_pools__id');

  $$WorkcenterPoolsTableProcessedTableManager get poolId {
    final $_column = $_itemColumn<String>('pool_id')!;

    final manager = $$WorkcenterPoolsTableTableManager(
      $_db,
      $_db.workcenterPools,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_poolIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $WorkcentersTable _workcenterIdTable(_$AppDatabase db) => db
      .workcenters
      .createAlias('workcenter_pool_members__workcenter_id__workcenters__id');

  $$WorkcentersTableProcessedTableManager get workcenterId {
    final $_column = $_itemColumn<String>('workcenter_id')!;

    final manager = $$WorkcentersTableTableManager(
      $_db,
      $_db.workcenters,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_workcenterIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$WorkcenterPoolMembersTableFilterComposer
    extends Composer<_$AppDatabase, $WorkcenterPoolMembersTable> {
  $$WorkcenterPoolMembersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$WorkcenterPoolsTableFilterComposer get poolId {
    final $$WorkcenterPoolsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.poolId,
      referencedTable: $db.workcenterPools,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkcenterPoolsTableFilterComposer(
            $db: $db,
            $table: $db.workcenterPools,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WorkcentersTableFilterComposer get workcenterId {
    final $$WorkcentersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workcenterId,
      referencedTable: $db.workcenters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkcentersTableFilterComposer(
            $db: $db,
            $table: $db.workcenters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkcenterPoolMembersTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkcenterPoolMembersTable> {
  $$WorkcenterPoolMembersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$WorkcenterPoolsTableOrderingComposer get poolId {
    final $$WorkcenterPoolsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.poolId,
      referencedTable: $db.workcenterPools,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkcenterPoolsTableOrderingComposer(
            $db: $db,
            $table: $db.workcenterPools,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WorkcentersTableOrderingComposer get workcenterId {
    final $$WorkcentersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workcenterId,
      referencedTable: $db.workcenters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkcentersTableOrderingComposer(
            $db: $db,
            $table: $db.workcenters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkcenterPoolMembersTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkcenterPoolMembersTable> {
  $$WorkcenterPoolMembersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$WorkcenterPoolsTableAnnotationComposer get poolId {
    final $$WorkcenterPoolsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.poolId,
      referencedTable: $db.workcenterPools,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkcenterPoolsTableAnnotationComposer(
            $db: $db,
            $table: $db.workcenterPools,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WorkcentersTableAnnotationComposer get workcenterId {
    final $$WorkcentersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workcenterId,
      referencedTable: $db.workcenters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkcentersTableAnnotationComposer(
            $db: $db,
            $table: $db.workcenters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkcenterPoolMembersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkcenterPoolMembersTable,
          WorkcenterPoolMember,
          $$WorkcenterPoolMembersTableFilterComposer,
          $$WorkcenterPoolMembersTableOrderingComposer,
          $$WorkcenterPoolMembersTableAnnotationComposer,
          $$WorkcenterPoolMembersTableCreateCompanionBuilder,
          $$WorkcenterPoolMembersTableUpdateCompanionBuilder,
          (WorkcenterPoolMember, $$WorkcenterPoolMembersTableReferences),
          WorkcenterPoolMember,
          PrefetchHooks Function({bool poolId, bool workcenterId})
        > {
  $$WorkcenterPoolMembersTableTableManager(
    _$AppDatabase db,
    $WorkcenterPoolMembersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkcenterPoolMembersTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$WorkcenterPoolMembersTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$WorkcenterPoolMembersTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> poolId = const Value.absent(),
                Value<String> workcenterId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkcenterPoolMembersCompanion(
                poolId: poolId,
                workcenterId: workcenterId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String poolId,
                required String workcenterId,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => WorkcenterPoolMembersCompanion.insert(
                poolId: poolId,
                workcenterId: workcenterId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$WorkcenterPoolMembersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({poolId = false, workcenterId = false}) {
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
                    if (poolId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.poolId,
                                referencedTable:
                                    $$WorkcenterPoolMembersTableReferences
                                        ._poolIdTable(db),
                                referencedColumn:
                                    $$WorkcenterPoolMembersTableReferences
                                        ._poolIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (workcenterId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.workcenterId,
                                referencedTable:
                                    $$WorkcenterPoolMembersTableReferences
                                        ._workcenterIdTable(db),
                                referencedColumn:
                                    $$WorkcenterPoolMembersTableReferences
                                        ._workcenterIdTable(db)
                                        .id,
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

typedef $$WorkcenterPoolMembersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkcenterPoolMembersTable,
      WorkcenterPoolMember,
      $$WorkcenterPoolMembersTableFilterComposer,
      $$WorkcenterPoolMembersTableOrderingComposer,
      $$WorkcenterPoolMembersTableAnnotationComposer,
      $$WorkcenterPoolMembersTableCreateCompanionBuilder,
      $$WorkcenterPoolMembersTableUpdateCompanionBuilder,
      (WorkcenterPoolMember, $$WorkcenterPoolMembersTableReferences),
      WorkcenterPoolMember,
      PrefetchHooks Function({bool poolId, bool workcenterId})
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      required String key,
      Value<String?> value,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<String> key,
      Value<String?> value,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          AppSetting,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            AppSetting,
            BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
          ),
          AppSetting,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String?> value = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                Value<String?> value = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                key: key,
                value: value,
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

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      AppSetting,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSetting,
        BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
      ),
      AppSetting,
      PrefetchHooks Function()
    >;
typedef $$ProjectsTableCreateCompanionBuilder =
    ProjectsCompanion Function({
      required String id,
      required String name,
      required String plantId,
      required String shiftPatternId,
      Value<String?> notes,
      Value<DateTime?> archivedAt,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ProjectsTableUpdateCompanionBuilder =
    ProjectsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> plantId,
      Value<String> shiftPatternId,
      Value<String?> notes,
      Value<DateTime?> archivedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$ProjectsTableReferences
    extends BaseReferences<_$AppDatabase, $ProjectsTable, Project> {
  $$ProjectsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PlantsTable _plantIdTable(_$AppDatabase db) =>
      db.plants.createAlias('projects__plant_id__plants__id');

  $$PlantsTableProcessedTableManager get plantId {
    final $_column = $_itemColumn<String>('plant_id')!;

    final manager = $$PlantsTableTableManager(
      $_db,
      $_db.plants,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_plantIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ShiftPatternsTable _shiftPatternIdTable(_$AppDatabase db) => db
      .shiftPatterns
      .createAlias('projects__shift_pattern_id__shift_patterns__id');

  $$ShiftPatternsTableProcessedTableManager get shiftPatternId {
    final $_column = $_itemColumn<String>('shift_pattern_id')!;

    final manager = $$ShiftPatternsTableTableManager(
      $_db,
      $_db.shiftPatterns,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_shiftPatternIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$CalendarExceptionsTable, List<CalendarException>>
  _calendarExceptionsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.calendarExceptions,
        aliasName: 'projects__id__calendar_exceptions__project_id',
      );

  $$CalendarExceptionsTableProcessedTableManager get calendarExceptionsRefs {
    final manager = $$CalendarExceptionsTableTableManager(
      $_db,
      $_db.calendarExceptions,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _calendarExceptionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TaktPeriodsTable, List<TaktPeriod>>
  _taktPeriodsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.taktPeriods,
    aliasName: 'projects__id__takt_periods__project_id',
  );

  $$TaktPeriodsTableProcessedTableManager get taktPeriodsRefs {
    final manager = $$TaktPeriodsTableTableManager(
      $_db,
      $_db.taktPeriods,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_taktPeriodsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $WorkcenterSchedulePeriodsTable,
    List<WorkcenterSchedulePeriod>
  >
  _workcenterSchedulePeriodsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.workcenterSchedulePeriods,
        aliasName: 'projects__id__workcenter_schedule_periods__project_id',
      );

  $$WorkcenterSchedulePeriodsTableProcessedTableManager
  get workcenterSchedulePeriodsRefs {
    final manager = $$WorkcenterSchedulePeriodsTableTableManager(
      $_db,
      $_db.workcenterSchedulePeriods,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _workcenterSchedulePeriodsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$StudiesTable, List<Study>> _studiesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.studies,
    aliasName: 'projects__id__studies__project_id',
  );

  $$StudiesTableProcessedTableManager get studiesRefs {
    final manager = $$StudiesTableTableManager(
      $_db,
      $_db.studies,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_studiesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ProjectsTableFilterComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
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

  $$PlantsTableFilterComposer get plantId {
    final $$PlantsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.plantId,
      referencedTable: $db.plants,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlantsTableFilterComposer(
            $db: $db,
            $table: $db.plants,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ShiftPatternsTableFilterComposer get shiftPatternId {
    final $$ShiftPatternsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.shiftPatternId,
      referencedTable: $db.shiftPatterns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShiftPatternsTableFilterComposer(
            $db: $db,
            $table: $db.shiftPatterns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> calendarExceptionsRefs(
    Expression<bool> Function($$CalendarExceptionsTableFilterComposer f) f,
  ) {
    final $$CalendarExceptionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.calendarExceptions,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CalendarExceptionsTableFilterComposer(
            $db: $db,
            $table: $db.calendarExceptions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> taktPeriodsRefs(
    Expression<bool> Function($$TaktPeriodsTableFilterComposer f) f,
  ) {
    final $$TaktPeriodsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taktPeriods,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaktPeriodsTableFilterComposer(
            $db: $db,
            $table: $db.taktPeriods,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> workcenterSchedulePeriodsRefs(
    Expression<bool> Function($$WorkcenterSchedulePeriodsTableFilterComposer f)
    f,
  ) {
    final $$WorkcenterSchedulePeriodsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.workcenterSchedulePeriods,
          getReferencedColumn: (t) => t.projectId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$WorkcenterSchedulePeriodsTableFilterComposer(
                $db: $db,
                $table: $db.workcenterSchedulePeriods,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> studiesRefs(
    Expression<bool> Function($$StudiesTableFilterComposer f) f,
  ) {
    final $$StudiesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.studies,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudiesTableFilterComposer(
            $db: $db,
            $table: $db.studies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProjectsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
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

  $$PlantsTableOrderingComposer get plantId {
    final $$PlantsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.plantId,
      referencedTable: $db.plants,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlantsTableOrderingComposer(
            $db: $db,
            $table: $db.plants,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ShiftPatternsTableOrderingComposer get shiftPatternId {
    final $$ShiftPatternsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.shiftPatternId,
      referencedTable: $db.shiftPatterns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShiftPatternsTableOrderingComposer(
            $db: $db,
            $table: $db.shiftPatterns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProjectsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$PlantsTableAnnotationComposer get plantId {
    final $$PlantsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.plantId,
      referencedTable: $db.plants,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlantsTableAnnotationComposer(
            $db: $db,
            $table: $db.plants,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ShiftPatternsTableAnnotationComposer get shiftPatternId {
    final $$ShiftPatternsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.shiftPatternId,
      referencedTable: $db.shiftPatterns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShiftPatternsTableAnnotationComposer(
            $db: $db,
            $table: $db.shiftPatterns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> calendarExceptionsRefs<T extends Object>(
    Expression<T> Function($$CalendarExceptionsTableAnnotationComposer a) f,
  ) {
    final $$CalendarExceptionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.calendarExceptions,
          getReferencedColumn: (t) => t.projectId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CalendarExceptionsTableAnnotationComposer(
                $db: $db,
                $table: $db.calendarExceptions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> taktPeriodsRefs<T extends Object>(
    Expression<T> Function($$TaktPeriodsTableAnnotationComposer a) f,
  ) {
    final $$TaktPeriodsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taktPeriods,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaktPeriodsTableAnnotationComposer(
            $db: $db,
            $table: $db.taktPeriods,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> workcenterSchedulePeriodsRefs<T extends Object>(
    Expression<T> Function($$WorkcenterSchedulePeriodsTableAnnotationComposer a)
    f,
  ) {
    final $$WorkcenterSchedulePeriodsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.workcenterSchedulePeriods,
          getReferencedColumn: (t) => t.projectId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$WorkcenterSchedulePeriodsTableAnnotationComposer(
                $db: $db,
                $table: $db.workcenterSchedulePeriods,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> studiesRefs<T extends Object>(
    Expression<T> Function($$StudiesTableAnnotationComposer a) f,
  ) {
    final $$StudiesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.studies,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudiesTableAnnotationComposer(
            $db: $db,
            $table: $db.studies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProjectsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProjectsTable,
          Project,
          $$ProjectsTableFilterComposer,
          $$ProjectsTableOrderingComposer,
          $$ProjectsTableAnnotationComposer,
          $$ProjectsTableCreateCompanionBuilder,
          $$ProjectsTableUpdateCompanionBuilder,
          (Project, $$ProjectsTableReferences),
          Project,
          PrefetchHooks Function({
            bool plantId,
            bool shiftPatternId,
            bool calendarExceptionsRefs,
            bool taktPeriodsRefs,
            bool workcenterSchedulePeriodsRefs,
            bool studiesRefs,
          })
        > {
  $$ProjectsTableTableManager(_$AppDatabase db, $ProjectsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProjectsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProjectsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProjectsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> plantId = const Value.absent(),
                Value<String> shiftPatternId = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProjectsCompanion(
                id: id,
                name: name,
                plantId: plantId,
                shiftPatternId: shiftPatternId,
                notes: notes,
                archivedAt: archivedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String plantId,
                required String shiftPatternId,
                Value<String?> notes = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ProjectsCompanion.insert(
                id: id,
                name: name,
                plantId: plantId,
                shiftPatternId: shiftPatternId,
                notes: notes,
                archivedAt: archivedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ProjectsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                plantId = false,
                shiftPatternId = false,
                calendarExceptionsRefs = false,
                taktPeriodsRefs = false,
                workcenterSchedulePeriodsRefs = false,
                studiesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (calendarExceptionsRefs) db.calendarExceptions,
                    if (taktPeriodsRefs) db.taktPeriods,
                    if (workcenterSchedulePeriodsRefs)
                      db.workcenterSchedulePeriods,
                    if (studiesRefs) db.studies,
                  ],
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
                        if (plantId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.plantId,
                                    referencedTable: $$ProjectsTableReferences
                                        ._plantIdTable(db),
                                    referencedColumn: $$ProjectsTableReferences
                                        ._plantIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (shiftPatternId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.shiftPatternId,
                                    referencedTable: $$ProjectsTableReferences
                                        ._shiftPatternIdTable(db),
                                    referencedColumn: $$ProjectsTableReferences
                                        ._shiftPatternIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (calendarExceptionsRefs)
                        await $_getPrefetchedData<
                          Project,
                          $ProjectsTable,
                          CalendarException
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._calendarExceptionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).calendarExceptionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.projectId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (taktPeriodsRefs)
                        await $_getPrefetchedData<
                          Project,
                          $ProjectsTable,
                          TaktPeriod
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._taktPeriodsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).taktPeriodsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.projectId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (workcenterSchedulePeriodsRefs)
                        await $_getPrefetchedData<
                          Project,
                          $ProjectsTable,
                          WorkcenterSchedulePeriod
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._workcenterSchedulePeriodsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).workcenterSchedulePeriodsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.projectId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (studiesRefs)
                        await $_getPrefetchedData<
                          Project,
                          $ProjectsTable,
                          Study
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._studiesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).studiesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.projectId == item.id,
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

typedef $$ProjectsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProjectsTable,
      Project,
      $$ProjectsTableFilterComposer,
      $$ProjectsTableOrderingComposer,
      $$ProjectsTableAnnotationComposer,
      $$ProjectsTableCreateCompanionBuilder,
      $$ProjectsTableUpdateCompanionBuilder,
      (Project, $$ProjectsTableReferences),
      Project,
      PrefetchHooks Function({
        bool plantId,
        bool shiftPatternId,
        bool calendarExceptionsRefs,
        bool taktPeriodsRefs,
        bool workcenterSchedulePeriodsRefs,
        bool studiesRefs,
      })
    >;
typedef $$CalendarExceptionsTableCreateCompanionBuilder =
    CalendarExceptionsCompanion Function({
      required String id,
      required String projectId,
      required DateTime date,
      required CalendarExceptionKind kind,
      required CalendarExceptionScope scope,
      Value<String> scopeId,
      Value<String?> operatorsPerShift,
      Value<String?> note,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$CalendarExceptionsTableUpdateCompanionBuilder =
    CalendarExceptionsCompanion Function({
      Value<String> id,
      Value<String> projectId,
      Value<DateTime> date,
      Value<CalendarExceptionKind> kind,
      Value<CalendarExceptionScope> scope,
      Value<String> scopeId,
      Value<String?> operatorsPerShift,
      Value<String?> note,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$CalendarExceptionsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $CalendarExceptionsTable,
          CalendarException
        > {
  $$CalendarExceptionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ProjectsTable _projectIdTable(_$AppDatabase db) =>
      db.projects.createAlias('calendar_exceptions__project_id__projects__id');

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<String>('project_id')!;

    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CalendarExceptionsTableFilterComposer
    extends Composer<_$AppDatabase, $CalendarExceptionsTable> {
  $$CalendarExceptionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<
    CalendarExceptionKind,
    CalendarExceptionKind,
    String
  >
  get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<
    CalendarExceptionScope,
    CalendarExceptionScope,
    String
  >
  get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get scopeId => $composableBuilder(
    column: $table.scopeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operatorsPerShift => $composableBuilder(
    column: $table.operatorsPerShift,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CalendarExceptionsTableOrderingComposer
    extends Composer<_$AppDatabase, $CalendarExceptionsTable> {
  $$CalendarExceptionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scopeId => $composableBuilder(
    column: $table.scopeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operatorsPerShift => $composableBuilder(
    column: $table.operatorsPerShift,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CalendarExceptionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CalendarExceptionsTable> {
  $$CalendarExceptionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumnWithTypeConverter<CalendarExceptionKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumnWithTypeConverter<CalendarExceptionScope, String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<String> get scopeId =>
      $composableBuilder(column: $table.scopeId, builder: (column) => column);

  GeneratedColumn<String> get operatorsPerShift => $composableBuilder(
    column: $table.operatorsPerShift,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CalendarExceptionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CalendarExceptionsTable,
          CalendarException,
          $$CalendarExceptionsTableFilterComposer,
          $$CalendarExceptionsTableOrderingComposer,
          $$CalendarExceptionsTableAnnotationComposer,
          $$CalendarExceptionsTableCreateCompanionBuilder,
          $$CalendarExceptionsTableUpdateCompanionBuilder,
          (CalendarException, $$CalendarExceptionsTableReferences),
          CalendarException,
          PrefetchHooks Function({bool projectId})
        > {
  $$CalendarExceptionsTableTableManager(
    _$AppDatabase db,
    $CalendarExceptionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CalendarExceptionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CalendarExceptionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CalendarExceptionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<CalendarExceptionKind> kind = const Value.absent(),
                Value<CalendarExceptionScope> scope = const Value.absent(),
                Value<String> scopeId = const Value.absent(),
                Value<String?> operatorsPerShift = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CalendarExceptionsCompanion(
                id: id,
                projectId: projectId,
                date: date,
                kind: kind,
                scope: scope,
                scopeId: scopeId,
                operatorsPerShift: operatorsPerShift,
                note: note,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String projectId,
                required DateTime date,
                required CalendarExceptionKind kind,
                required CalendarExceptionScope scope,
                Value<String> scopeId = const Value.absent(),
                Value<String?> operatorsPerShift = const Value.absent(),
                Value<String?> note = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => CalendarExceptionsCompanion.insert(
                id: id,
                projectId: projectId,
                date: date,
                kind: kind,
                scope: scope,
                scopeId: scopeId,
                operatorsPerShift: operatorsPerShift,
                note: note,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CalendarExceptionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({projectId = false}) {
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
                    if (projectId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.projectId,
                                referencedTable:
                                    $$CalendarExceptionsTableReferences
                                        ._projectIdTable(db),
                                referencedColumn:
                                    $$CalendarExceptionsTableReferences
                                        ._projectIdTable(db)
                                        .id,
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

typedef $$CalendarExceptionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CalendarExceptionsTable,
      CalendarException,
      $$CalendarExceptionsTableFilterComposer,
      $$CalendarExceptionsTableOrderingComposer,
      $$CalendarExceptionsTableAnnotationComposer,
      $$CalendarExceptionsTableCreateCompanionBuilder,
      $$CalendarExceptionsTableUpdateCompanionBuilder,
      (CalendarException, $$CalendarExceptionsTableReferences),
      CalendarException,
      PrefetchHooks Function({bool projectId})
    >;
typedef $$TaktPeriodsTableCreateCompanionBuilder =
    TaktPeriodsCompanion Function({
      required String id,
      required String projectId,
      required String productionLineId,
      required DateTime startDate,
      required DateTime endDate,
      required double taktValue,
      required TaktUnit taktUnit,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$TaktPeriodsTableUpdateCompanionBuilder =
    TaktPeriodsCompanion Function({
      Value<String> id,
      Value<String> projectId,
      Value<String> productionLineId,
      Value<DateTime> startDate,
      Value<DateTime> endDate,
      Value<double> taktValue,
      Value<TaktUnit> taktUnit,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$TaktPeriodsTableReferences
    extends BaseReferences<_$AppDatabase, $TaktPeriodsTable, TaktPeriod> {
  $$TaktPeriodsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProjectsTable _projectIdTable(_$AppDatabase db) =>
      db.projects.createAlias('takt_periods__project_id__projects__id');

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<String>('project_id')!;

    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ProductionLinesTable _productionLineIdTable(_$AppDatabase db) => db
      .productionLines
      .createAlias('takt_periods__production_line_id__production_lines__id');

  $$ProductionLinesTableProcessedTableManager get productionLineId {
    final $_column = $_itemColumn<String>('production_line_id')!;

    final manager = $$ProductionLinesTableTableManager(
      $_db,
      $_db.productionLines,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_productionLineIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TaktPeriodsTableFilterComposer
    extends Composer<_$AppDatabase, $TaktPeriodsTable> {
  $$TaktPeriodsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get taktValue => $composableBuilder(
    column: $table.taktValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<TaktUnit, TaktUnit, String> get taktUnit =>
      $composableBuilder(
        column: $table.taktUnit,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProductionLinesTableFilterComposer get productionLineId {
    final $$ProductionLinesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productionLineId,
      referencedTable: $db.productionLines,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductionLinesTableFilterComposer(
            $db: $db,
            $table: $db.productionLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TaktPeriodsTableOrderingComposer
    extends Composer<_$AppDatabase, $TaktPeriodsTable> {
  $$TaktPeriodsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get taktValue => $composableBuilder(
    column: $table.taktValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taktUnit => $composableBuilder(
    column: $table.taktUnit,
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

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProductionLinesTableOrderingComposer get productionLineId {
    final $$ProductionLinesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productionLineId,
      referencedTable: $db.productionLines,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductionLinesTableOrderingComposer(
            $db: $db,
            $table: $db.productionLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TaktPeriodsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TaktPeriodsTable> {
  $$TaktPeriodsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<DateTime> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumn<double> get taktValue =>
      $composableBuilder(column: $table.taktValue, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TaktUnit, String> get taktUnit =>
      $composableBuilder(column: $table.taktUnit, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProductionLinesTableAnnotationComposer get productionLineId {
    final $$ProductionLinesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productionLineId,
      referencedTable: $db.productionLines,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductionLinesTableAnnotationComposer(
            $db: $db,
            $table: $db.productionLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TaktPeriodsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TaktPeriodsTable,
          TaktPeriod,
          $$TaktPeriodsTableFilterComposer,
          $$TaktPeriodsTableOrderingComposer,
          $$TaktPeriodsTableAnnotationComposer,
          $$TaktPeriodsTableCreateCompanionBuilder,
          $$TaktPeriodsTableUpdateCompanionBuilder,
          (TaktPeriod, $$TaktPeriodsTableReferences),
          TaktPeriod,
          PrefetchHooks Function({bool projectId, bool productionLineId})
        > {
  $$TaktPeriodsTableTableManager(_$AppDatabase db, $TaktPeriodsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TaktPeriodsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TaktPeriodsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TaktPeriodsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<String> productionLineId = const Value.absent(),
                Value<DateTime> startDate = const Value.absent(),
                Value<DateTime> endDate = const Value.absent(),
                Value<double> taktValue = const Value.absent(),
                Value<TaktUnit> taktUnit = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TaktPeriodsCompanion(
                id: id,
                projectId: projectId,
                productionLineId: productionLineId,
                startDate: startDate,
                endDate: endDate,
                taktValue: taktValue,
                taktUnit: taktUnit,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String projectId,
                required String productionLineId,
                required DateTime startDate,
                required DateTime endDate,
                required double taktValue,
                required TaktUnit taktUnit,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => TaktPeriodsCompanion.insert(
                id: id,
                projectId: projectId,
                productionLineId: productionLineId,
                startDate: startDate,
                endDate: endDate,
                taktValue: taktValue,
                taktUnit: taktUnit,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TaktPeriodsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({projectId = false, productionLineId = false}) {
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
                        if (projectId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.projectId,
                                    referencedTable:
                                        $$TaktPeriodsTableReferences
                                            ._projectIdTable(db),
                                    referencedColumn:
                                        $$TaktPeriodsTableReferences
                                            ._projectIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (productionLineId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.productionLineId,
                                    referencedTable:
                                        $$TaktPeriodsTableReferences
                                            ._productionLineIdTable(db),
                                    referencedColumn:
                                        $$TaktPeriodsTableReferences
                                            ._productionLineIdTable(db)
                                            .id,
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

typedef $$TaktPeriodsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TaktPeriodsTable,
      TaktPeriod,
      $$TaktPeriodsTableFilterComposer,
      $$TaktPeriodsTableOrderingComposer,
      $$TaktPeriodsTableAnnotationComposer,
      $$TaktPeriodsTableCreateCompanionBuilder,
      $$TaktPeriodsTableUpdateCompanionBuilder,
      (TaktPeriod, $$TaktPeriodsTableReferences),
      TaktPeriod,
      PrefetchHooks Function({bool projectId, bool productionLineId})
    >;
typedef $$WorkcenterSchedulePeriodsTableCreateCompanionBuilder =
    WorkcenterSchedulePeriodsCompanion Function({
      required String id,
      required String projectId,
      required String workcenterId,
      required DateTime startDate,
      required DateTime endDate,
      required String operatorsPerShift,
      Value<double> availability,
      Value<double> rework,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$WorkcenterSchedulePeriodsTableUpdateCompanionBuilder =
    WorkcenterSchedulePeriodsCompanion Function({
      Value<String> id,
      Value<String> projectId,
      Value<String> workcenterId,
      Value<DateTime> startDate,
      Value<DateTime> endDate,
      Value<String> operatorsPerShift,
      Value<double> availability,
      Value<double> rework,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$WorkcenterSchedulePeriodsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $WorkcenterSchedulePeriodsTable,
          WorkcenterSchedulePeriod
        > {
  $$WorkcenterSchedulePeriodsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ProjectsTable _projectIdTable(_$AppDatabase db) => db.projects
      .createAlias('workcenter_schedule_periods__project_id__projects__id');

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<String>('project_id')!;

    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $WorkcentersTable _workcenterIdTable(_$AppDatabase db) =>
      db.workcenters.createAlias(
        'workcenter_schedule_periods__workcenter_id__workcenters__id',
      );

  $$WorkcentersTableProcessedTableManager get workcenterId {
    final $_column = $_itemColumn<String>('workcenter_id')!;

    final manager = $$WorkcentersTableTableManager(
      $_db,
      $_db.workcenters,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_workcenterIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$WorkcenterSchedulePeriodsTableFilterComposer
    extends Composer<_$AppDatabase, $WorkcenterSchedulePeriodsTable> {
  $$WorkcenterSchedulePeriodsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operatorsPerShift => $composableBuilder(
    column: $table.operatorsPerShift,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get availability => $composableBuilder(
    column: $table.availability,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get rework => $composableBuilder(
    column: $table.rework,
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

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WorkcentersTableFilterComposer get workcenterId {
    final $$WorkcentersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workcenterId,
      referencedTable: $db.workcenters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkcentersTableFilterComposer(
            $db: $db,
            $table: $db.workcenters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkcenterSchedulePeriodsTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkcenterSchedulePeriodsTable> {
  $$WorkcenterSchedulePeriodsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operatorsPerShift => $composableBuilder(
    column: $table.operatorsPerShift,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get availability => $composableBuilder(
    column: $table.availability,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get rework => $composableBuilder(
    column: $table.rework,
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

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WorkcentersTableOrderingComposer get workcenterId {
    final $$WorkcentersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workcenterId,
      referencedTable: $db.workcenters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkcentersTableOrderingComposer(
            $db: $db,
            $table: $db.workcenters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkcenterSchedulePeriodsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkcenterSchedulePeriodsTable> {
  $$WorkcenterSchedulePeriodsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<DateTime> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumn<String> get operatorsPerShift => $composableBuilder(
    column: $table.operatorsPerShift,
    builder: (column) => column,
  );

  GeneratedColumn<double> get availability => $composableBuilder(
    column: $table.availability,
    builder: (column) => column,
  );

  GeneratedColumn<double> get rework =>
      $composableBuilder(column: $table.rework, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WorkcentersTableAnnotationComposer get workcenterId {
    final $$WorkcentersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workcenterId,
      referencedTable: $db.workcenters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkcentersTableAnnotationComposer(
            $db: $db,
            $table: $db.workcenters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkcenterSchedulePeriodsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkcenterSchedulePeriodsTable,
          WorkcenterSchedulePeriod,
          $$WorkcenterSchedulePeriodsTableFilterComposer,
          $$WorkcenterSchedulePeriodsTableOrderingComposer,
          $$WorkcenterSchedulePeriodsTableAnnotationComposer,
          $$WorkcenterSchedulePeriodsTableCreateCompanionBuilder,
          $$WorkcenterSchedulePeriodsTableUpdateCompanionBuilder,
          (
            WorkcenterSchedulePeriod,
            $$WorkcenterSchedulePeriodsTableReferences,
          ),
          WorkcenterSchedulePeriod,
          PrefetchHooks Function({bool projectId, bool workcenterId})
        > {
  $$WorkcenterSchedulePeriodsTableTableManager(
    _$AppDatabase db,
    $WorkcenterSchedulePeriodsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkcenterSchedulePeriodsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$WorkcenterSchedulePeriodsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$WorkcenterSchedulePeriodsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<String> workcenterId = const Value.absent(),
                Value<DateTime> startDate = const Value.absent(),
                Value<DateTime> endDate = const Value.absent(),
                Value<String> operatorsPerShift = const Value.absent(),
                Value<double> availability = const Value.absent(),
                Value<double> rework = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkcenterSchedulePeriodsCompanion(
                id: id,
                projectId: projectId,
                workcenterId: workcenterId,
                startDate: startDate,
                endDate: endDate,
                operatorsPerShift: operatorsPerShift,
                availability: availability,
                rework: rework,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String projectId,
                required String workcenterId,
                required DateTime startDate,
                required DateTime endDate,
                required String operatorsPerShift,
                Value<double> availability = const Value.absent(),
                Value<double> rework = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => WorkcenterSchedulePeriodsCompanion.insert(
                id: id,
                projectId: projectId,
                workcenterId: workcenterId,
                startDate: startDate,
                endDate: endDate,
                operatorsPerShift: operatorsPerShift,
                availability: availability,
                rework: rework,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$WorkcenterSchedulePeriodsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({projectId = false, workcenterId = false}) {
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
                    if (projectId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.projectId,
                                referencedTable:
                                    $$WorkcenterSchedulePeriodsTableReferences
                                        ._projectIdTable(db),
                                referencedColumn:
                                    $$WorkcenterSchedulePeriodsTableReferences
                                        ._projectIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (workcenterId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.workcenterId,
                                referencedTable:
                                    $$WorkcenterSchedulePeriodsTableReferences
                                        ._workcenterIdTable(db),
                                referencedColumn:
                                    $$WorkcenterSchedulePeriodsTableReferences
                                        ._workcenterIdTable(db)
                                        .id,
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

typedef $$WorkcenterSchedulePeriodsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkcenterSchedulePeriodsTable,
      WorkcenterSchedulePeriod,
      $$WorkcenterSchedulePeriodsTableFilterComposer,
      $$WorkcenterSchedulePeriodsTableOrderingComposer,
      $$WorkcenterSchedulePeriodsTableAnnotationComposer,
      $$WorkcenterSchedulePeriodsTableCreateCompanionBuilder,
      $$WorkcenterSchedulePeriodsTableUpdateCompanionBuilder,
      (WorkcenterSchedulePeriod, $$WorkcenterSchedulePeriodsTableReferences),
      WorkcenterSchedulePeriod,
      PrefetchHooks Function({bool projectId, bool workcenterId})
    >;
typedef $$StudiesTableCreateCompanionBuilder =
    StudiesCompanion Function({
      required String id,
      required String projectId,
      required String productionCellId,
      required String productionLineId,
      required String name,
      Value<bool> includeInSimulation,
      Value<int> priority,
      Value<int?> wipCap,
      Value<String?> supplierName,
      Value<String?> customerName,
      Value<String?> notes,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$StudiesTableUpdateCompanionBuilder =
    StudiesCompanion Function({
      Value<String> id,
      Value<String> projectId,
      Value<String> productionCellId,
      Value<String> productionLineId,
      Value<String> name,
      Value<bool> includeInSimulation,
      Value<int> priority,
      Value<int?> wipCap,
      Value<String?> supplierName,
      Value<String?> customerName,
      Value<String?> notes,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$StudiesTableReferences
    extends BaseReferences<_$AppDatabase, $StudiesTable, Study> {
  $$StudiesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProjectsTable _projectIdTable(_$AppDatabase db) =>
      db.projects.createAlias('studies__project_id__projects__id');

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<String>('project_id')!;

    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ProductionCellsTable _productionCellIdTable(_$AppDatabase db) => db
      .productionCells
      .createAlias('studies__production_cell_id__production_cells__id');

  $$ProductionCellsTableProcessedTableManager get productionCellId {
    final $_column = $_itemColumn<String>('production_cell_id')!;

    final manager = $$ProductionCellsTableTableManager(
      $_db,
      $_db.productionCells,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_productionCellIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ProductionLinesTable _productionLineIdTable(_$AppDatabase db) => db
      .productionLines
      .createAlias('studies__production_line_id__production_lines__id');

  $$ProductionLinesTableProcessedTableManager get productionLineId {
    final $_column = $_itemColumn<String>('production_line_id')!;

    final manager = $$ProductionLinesTableTableManager(
      $_db,
      $_db.productionLines,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_productionLineIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$FlowNodesTable, List<FlowNode>>
  _flowNodesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.flowNodes,
    aliasName: 'studies__id__flow_nodes__study_id',
  );

  $$FlowNodesTableProcessedTableManager get flowNodesRefs {
    final manager = $$FlowNodesTableTableManager(
      $_db,
      $_db.flowNodes,
    ).filter((f) => f.studyId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_flowNodesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$FlowAnnotationsTable, List<FlowAnnotation>>
  _flowAnnotationsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.flowAnnotations,
    aliasName: 'studies__id__flow_annotations__study_id',
  );

  $$FlowAnnotationsTableProcessedTableManager get flowAnnotationsRefs {
    final manager = $$FlowAnnotationsTableTableManager(
      $_db,
      $_db.flowAnnotations,
    ).filter((f) => f.studyId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _flowAnnotationsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DemandPartsTable, List<DemandPart>>
  _demandPartsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.demandParts,
    aliasName: 'studies__id__demand_parts__study_id',
  );

  $$DemandPartsTableProcessedTableManager get demandPartsRefs {
    final manager = $$DemandPartsTableTableManager(
      $_db,
      $_db.demandParts,
    ).filter((f) => f.studyId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_demandPartsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DemandOrdersTable, List<DemandOrder>>
  _demandOrdersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.demandOrders,
    aliasName: 'studies__id__demand_orders__study_id',
  );

  $$DemandOrdersTableProcessedTableManager get demandOrdersRefs {
    final manager = $$DemandOrdersTableTableManager(
      $_db,
      $_db.demandOrders,
    ).filter((f) => f.studyId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_demandOrdersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$StudiesTableFilterComposer
    extends Composer<_$AppDatabase, $StudiesTable> {
  $$StudiesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get includeInSimulation => $composableBuilder(
    column: $table.includeInSimulation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get wipCap => $composableBuilder(
    column: $table.wipCap,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get supplierName => $composableBuilder(
    column: $table.supplierName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customerName => $composableBuilder(
    column: $table.customerName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
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

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProductionCellsTableFilterComposer get productionCellId {
    final $$ProductionCellsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productionCellId,
      referencedTable: $db.productionCells,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductionCellsTableFilterComposer(
            $db: $db,
            $table: $db.productionCells,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProductionLinesTableFilterComposer get productionLineId {
    final $$ProductionLinesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productionLineId,
      referencedTable: $db.productionLines,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductionLinesTableFilterComposer(
            $db: $db,
            $table: $db.productionLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> flowNodesRefs(
    Expression<bool> Function($$FlowNodesTableFilterComposer f) f,
  ) {
    final $$FlowNodesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.flowNodes,
      getReferencedColumn: (t) => t.studyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FlowNodesTableFilterComposer(
            $db: $db,
            $table: $db.flowNodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> flowAnnotationsRefs(
    Expression<bool> Function($$FlowAnnotationsTableFilterComposer f) f,
  ) {
    final $$FlowAnnotationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.flowAnnotations,
      getReferencedColumn: (t) => t.studyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FlowAnnotationsTableFilterComposer(
            $db: $db,
            $table: $db.flowAnnotations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> demandPartsRefs(
    Expression<bool> Function($$DemandPartsTableFilterComposer f) f,
  ) {
    final $$DemandPartsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.demandParts,
      getReferencedColumn: (t) => t.studyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DemandPartsTableFilterComposer(
            $db: $db,
            $table: $db.demandParts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> demandOrdersRefs(
    Expression<bool> Function($$DemandOrdersTableFilterComposer f) f,
  ) {
    final $$DemandOrdersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.demandOrders,
      getReferencedColumn: (t) => t.studyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DemandOrdersTableFilterComposer(
            $db: $db,
            $table: $db.demandOrders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$StudiesTableOrderingComposer
    extends Composer<_$AppDatabase, $StudiesTable> {
  $$StudiesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get includeInSimulation => $composableBuilder(
    column: $table.includeInSimulation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get wipCap => $composableBuilder(
    column: $table.wipCap,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get supplierName => $composableBuilder(
    column: $table.supplierName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customerName => $composableBuilder(
    column: $table.customerName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
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

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProductionCellsTableOrderingComposer get productionCellId {
    final $$ProductionCellsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productionCellId,
      referencedTable: $db.productionCells,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductionCellsTableOrderingComposer(
            $db: $db,
            $table: $db.productionCells,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProductionLinesTableOrderingComposer get productionLineId {
    final $$ProductionLinesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productionLineId,
      referencedTable: $db.productionLines,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductionLinesTableOrderingComposer(
            $db: $db,
            $table: $db.productionLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StudiesTableAnnotationComposer
    extends Composer<_$AppDatabase, $StudiesTable> {
  $$StudiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get includeInSimulation => $composableBuilder(
    column: $table.includeInSimulation,
    builder: (column) => column,
  );

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<int> get wipCap =>
      $composableBuilder(column: $table.wipCap, builder: (column) => column);

  GeneratedColumn<String> get supplierName => $composableBuilder(
    column: $table.supplierName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get customerName => $composableBuilder(
    column: $table.customerName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProductionCellsTableAnnotationComposer get productionCellId {
    final $$ProductionCellsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productionCellId,
      referencedTable: $db.productionCells,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductionCellsTableAnnotationComposer(
            $db: $db,
            $table: $db.productionCells,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProductionLinesTableAnnotationComposer get productionLineId {
    final $$ProductionLinesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productionLineId,
      referencedTable: $db.productionLines,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductionLinesTableAnnotationComposer(
            $db: $db,
            $table: $db.productionLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> flowNodesRefs<T extends Object>(
    Expression<T> Function($$FlowNodesTableAnnotationComposer a) f,
  ) {
    final $$FlowNodesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.flowNodes,
      getReferencedColumn: (t) => t.studyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FlowNodesTableAnnotationComposer(
            $db: $db,
            $table: $db.flowNodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> flowAnnotationsRefs<T extends Object>(
    Expression<T> Function($$FlowAnnotationsTableAnnotationComposer a) f,
  ) {
    final $$FlowAnnotationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.flowAnnotations,
      getReferencedColumn: (t) => t.studyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FlowAnnotationsTableAnnotationComposer(
            $db: $db,
            $table: $db.flowAnnotations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> demandPartsRefs<T extends Object>(
    Expression<T> Function($$DemandPartsTableAnnotationComposer a) f,
  ) {
    final $$DemandPartsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.demandParts,
      getReferencedColumn: (t) => t.studyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DemandPartsTableAnnotationComposer(
            $db: $db,
            $table: $db.demandParts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> demandOrdersRefs<T extends Object>(
    Expression<T> Function($$DemandOrdersTableAnnotationComposer a) f,
  ) {
    final $$DemandOrdersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.demandOrders,
      getReferencedColumn: (t) => t.studyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DemandOrdersTableAnnotationComposer(
            $db: $db,
            $table: $db.demandOrders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$StudiesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StudiesTable,
          Study,
          $$StudiesTableFilterComposer,
          $$StudiesTableOrderingComposer,
          $$StudiesTableAnnotationComposer,
          $$StudiesTableCreateCompanionBuilder,
          $$StudiesTableUpdateCompanionBuilder,
          (Study, $$StudiesTableReferences),
          Study,
          PrefetchHooks Function({
            bool projectId,
            bool productionCellId,
            bool productionLineId,
            bool flowNodesRefs,
            bool flowAnnotationsRefs,
            bool demandPartsRefs,
            bool demandOrdersRefs,
          })
        > {
  $$StudiesTableTableManager(_$AppDatabase db, $StudiesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StudiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StudiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StudiesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<String> productionCellId = const Value.absent(),
                Value<String> productionLineId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<bool> includeInSimulation = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<int?> wipCap = const Value.absent(),
                Value<String?> supplierName = const Value.absent(),
                Value<String?> customerName = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StudiesCompanion(
                id: id,
                projectId: projectId,
                productionCellId: productionCellId,
                productionLineId: productionLineId,
                name: name,
                includeInSimulation: includeInSimulation,
                priority: priority,
                wipCap: wipCap,
                supplierName: supplierName,
                customerName: customerName,
                notes: notes,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String projectId,
                required String productionCellId,
                required String productionLineId,
                required String name,
                Value<bool> includeInSimulation = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<int?> wipCap = const Value.absent(),
                Value<String?> supplierName = const Value.absent(),
                Value<String?> customerName = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => StudiesCompanion.insert(
                id: id,
                projectId: projectId,
                productionCellId: productionCellId,
                productionLineId: productionLineId,
                name: name,
                includeInSimulation: includeInSimulation,
                priority: priority,
                wipCap: wipCap,
                supplierName: supplierName,
                customerName: customerName,
                notes: notes,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$StudiesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                projectId = false,
                productionCellId = false,
                productionLineId = false,
                flowNodesRefs = false,
                flowAnnotationsRefs = false,
                demandPartsRefs = false,
                demandOrdersRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (flowNodesRefs) db.flowNodes,
                    if (flowAnnotationsRefs) db.flowAnnotations,
                    if (demandPartsRefs) db.demandParts,
                    if (demandOrdersRefs) db.demandOrders,
                  ],
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
                        if (projectId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.projectId,
                                    referencedTable: $$StudiesTableReferences
                                        ._projectIdTable(db),
                                    referencedColumn: $$StudiesTableReferences
                                        ._projectIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (productionCellId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.productionCellId,
                                    referencedTable: $$StudiesTableReferences
                                        ._productionCellIdTable(db),
                                    referencedColumn: $$StudiesTableReferences
                                        ._productionCellIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (productionLineId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.productionLineId,
                                    referencedTable: $$StudiesTableReferences
                                        ._productionLineIdTable(db),
                                    referencedColumn: $$StudiesTableReferences
                                        ._productionLineIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (flowNodesRefs)
                        await $_getPrefetchedData<
                          Study,
                          $StudiesTable,
                          FlowNode
                        >(
                          currentTable: table,
                          referencedTable: $$StudiesTableReferences
                              ._flowNodesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$StudiesTableReferences(
                                db,
                                table,
                                p0,
                              ).flowNodesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.studyId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (flowAnnotationsRefs)
                        await $_getPrefetchedData<
                          Study,
                          $StudiesTable,
                          FlowAnnotation
                        >(
                          currentTable: table,
                          referencedTable: $$StudiesTableReferences
                              ._flowAnnotationsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$StudiesTableReferences(
                                db,
                                table,
                                p0,
                              ).flowAnnotationsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.studyId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (demandPartsRefs)
                        await $_getPrefetchedData<
                          Study,
                          $StudiesTable,
                          DemandPart
                        >(
                          currentTable: table,
                          referencedTable: $$StudiesTableReferences
                              ._demandPartsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$StudiesTableReferences(
                                db,
                                table,
                                p0,
                              ).demandPartsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.studyId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (demandOrdersRefs)
                        await $_getPrefetchedData<
                          Study,
                          $StudiesTable,
                          DemandOrder
                        >(
                          currentTable: table,
                          referencedTable: $$StudiesTableReferences
                              ._demandOrdersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$StudiesTableReferences(
                                db,
                                table,
                                p0,
                              ).demandOrdersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.studyId == item.id,
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

typedef $$StudiesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StudiesTable,
      Study,
      $$StudiesTableFilterComposer,
      $$StudiesTableOrderingComposer,
      $$StudiesTableAnnotationComposer,
      $$StudiesTableCreateCompanionBuilder,
      $$StudiesTableUpdateCompanionBuilder,
      (Study, $$StudiesTableReferences),
      Study,
      PrefetchHooks Function({
        bool projectId,
        bool productionCellId,
        bool productionLineId,
        bool flowNodesRefs,
        bool flowAnnotationsRefs,
        bool demandPartsRefs,
        bool demandOrdersRefs,
      })
    >;
typedef $$FlowNodesTableCreateCompanionBuilder =
    FlowNodesCompanion Function({
      required String id,
      required String studyId,
      required int position,
      required FlowNodeKind kind,
      Value<String?> workcenterId,
      Value<String?> poolId,
      Value<int> changeoverSeconds,
      Value<double?> equivalentValue,
      Value<TaktUnit?> equivalentUnit,
      Value<InventoryMode?> inventoryMode,
      Value<int?> inventoryQuantity,
      Value<int?> inventorySeconds,
      Value<DurationUnit?> inventoryUnit,
      Value<bool> inventoryUsesWorkingTime,
      Value<String?> label,
      Value<String?> notes,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$FlowNodesTableUpdateCompanionBuilder =
    FlowNodesCompanion Function({
      Value<String> id,
      Value<String> studyId,
      Value<int> position,
      Value<FlowNodeKind> kind,
      Value<String?> workcenterId,
      Value<String?> poolId,
      Value<int> changeoverSeconds,
      Value<double?> equivalentValue,
      Value<TaktUnit?> equivalentUnit,
      Value<InventoryMode?> inventoryMode,
      Value<int?> inventoryQuantity,
      Value<int?> inventorySeconds,
      Value<DurationUnit?> inventoryUnit,
      Value<bool> inventoryUsesWorkingTime,
      Value<String?> label,
      Value<String?> notes,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$FlowNodesTableReferences
    extends BaseReferences<_$AppDatabase, $FlowNodesTable, FlowNode> {
  $$FlowNodesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $StudiesTable _studyIdTable(_$AppDatabase db) =>
      db.studies.createAlias('flow_nodes__study_id__studies__id');

  $$StudiesTableProcessedTableManager get studyId {
    final $_column = $_itemColumn<String>('study_id')!;

    final manager = $$StudiesTableTableManager(
      $_db,
      $_db.studies,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_studyIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $WorkcentersTable _workcenterIdTable(_$AppDatabase db) =>
      db.workcenters.createAlias('flow_nodes__workcenter_id__workcenters__id');

  $$WorkcentersTableProcessedTableManager? get workcenterId {
    final $_column = $_itemColumn<String>('workcenter_id');
    if ($_column == null) return null;
    final manager = $$WorkcentersTableTableManager(
      $_db,
      $_db.workcenters,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_workcenterIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $WorkcenterPoolsTable _poolIdTable(_$AppDatabase db) => db
      .workcenterPools
      .createAlias('flow_nodes__pool_id__workcenter_pools__id');

  $$WorkcenterPoolsTableProcessedTableManager? get poolId {
    final $_column = $_itemColumn<String>('pool_id');
    if ($_column == null) return null;
    final manager = $$WorkcenterPoolsTableTableManager(
      $_db,
      $_db.workcenterPools,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_poolIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FlowNodesTableFilterComposer
    extends Composer<_$AppDatabase, $FlowNodesTable> {
  $$FlowNodesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<FlowNodeKind, FlowNodeKind, String> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get changeoverSeconds => $composableBuilder(
    column: $table.changeoverSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get equivalentValue => $composableBuilder(
    column: $table.equivalentValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<TaktUnit?, TaktUnit, String>
  get equivalentUnit => $composableBuilder(
    column: $table.equivalentUnit,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<InventoryMode?, InventoryMode, String>
  get inventoryMode => $composableBuilder(
    column: $table.inventoryMode,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get inventoryQuantity => $composableBuilder(
    column: $table.inventoryQuantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get inventorySeconds => $composableBuilder(
    column: $table.inventorySeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DurationUnit?, DurationUnit, String>
  get inventoryUnit => $composableBuilder(
    column: $table.inventoryUnit,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<bool> get inventoryUsesWorkingTime => $composableBuilder(
    column: $table.inventoryUsesWorkingTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
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

  $$StudiesTableFilterComposer get studyId {
    final $$StudiesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.studyId,
      referencedTable: $db.studies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudiesTableFilterComposer(
            $db: $db,
            $table: $db.studies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WorkcentersTableFilterComposer get workcenterId {
    final $$WorkcentersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workcenterId,
      referencedTable: $db.workcenters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkcentersTableFilterComposer(
            $db: $db,
            $table: $db.workcenters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WorkcenterPoolsTableFilterComposer get poolId {
    final $$WorkcenterPoolsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.poolId,
      referencedTable: $db.workcenterPools,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkcenterPoolsTableFilterComposer(
            $db: $db,
            $table: $db.workcenterPools,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FlowNodesTableOrderingComposer
    extends Composer<_$AppDatabase, $FlowNodesTable> {
  $$FlowNodesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get changeoverSeconds => $composableBuilder(
    column: $table.changeoverSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get equivalentValue => $composableBuilder(
    column: $table.equivalentValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get equivalentUnit => $composableBuilder(
    column: $table.equivalentUnit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get inventoryMode => $composableBuilder(
    column: $table.inventoryMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get inventoryQuantity => $composableBuilder(
    column: $table.inventoryQuantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get inventorySeconds => $composableBuilder(
    column: $table.inventorySeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get inventoryUnit => $composableBuilder(
    column: $table.inventoryUnit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get inventoryUsesWorkingTime => $composableBuilder(
    column: $table.inventoryUsesWorkingTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
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

  $$StudiesTableOrderingComposer get studyId {
    final $$StudiesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.studyId,
      referencedTable: $db.studies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudiesTableOrderingComposer(
            $db: $db,
            $table: $db.studies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WorkcentersTableOrderingComposer get workcenterId {
    final $$WorkcentersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workcenterId,
      referencedTable: $db.workcenters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkcentersTableOrderingComposer(
            $db: $db,
            $table: $db.workcenters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WorkcenterPoolsTableOrderingComposer get poolId {
    final $$WorkcenterPoolsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.poolId,
      referencedTable: $db.workcenterPools,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkcenterPoolsTableOrderingComposer(
            $db: $db,
            $table: $db.workcenterPools,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FlowNodesTableAnnotationComposer
    extends Composer<_$AppDatabase, $FlowNodesTable> {
  $$FlowNodesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumnWithTypeConverter<FlowNodeKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get changeoverSeconds => $composableBuilder(
    column: $table.changeoverSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<double> get equivalentValue => $composableBuilder(
    column: $table.equivalentValue,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<TaktUnit?, String> get equivalentUnit =>
      $composableBuilder(
        column: $table.equivalentUnit,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<InventoryMode?, String> get inventoryMode =>
      $composableBuilder(
        column: $table.inventoryMode,
        builder: (column) => column,
      );

  GeneratedColumn<int> get inventoryQuantity => $composableBuilder(
    column: $table.inventoryQuantity,
    builder: (column) => column,
  );

  GeneratedColumn<int> get inventorySeconds => $composableBuilder(
    column: $table.inventorySeconds,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DurationUnit?, String> get inventoryUnit =>
      $composableBuilder(
        column: $table.inventoryUnit,
        builder: (column) => column,
      );

  GeneratedColumn<bool> get inventoryUsesWorkingTime => $composableBuilder(
    column: $table.inventoryUsesWorkingTime,
    builder: (column) => column,
  );

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$StudiesTableAnnotationComposer get studyId {
    final $$StudiesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.studyId,
      referencedTable: $db.studies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudiesTableAnnotationComposer(
            $db: $db,
            $table: $db.studies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WorkcentersTableAnnotationComposer get workcenterId {
    final $$WorkcentersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workcenterId,
      referencedTable: $db.workcenters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkcentersTableAnnotationComposer(
            $db: $db,
            $table: $db.workcenters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WorkcenterPoolsTableAnnotationComposer get poolId {
    final $$WorkcenterPoolsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.poolId,
      referencedTable: $db.workcenterPools,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkcenterPoolsTableAnnotationComposer(
            $db: $db,
            $table: $db.workcenterPools,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FlowNodesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FlowNodesTable,
          FlowNode,
          $$FlowNodesTableFilterComposer,
          $$FlowNodesTableOrderingComposer,
          $$FlowNodesTableAnnotationComposer,
          $$FlowNodesTableCreateCompanionBuilder,
          $$FlowNodesTableUpdateCompanionBuilder,
          (FlowNode, $$FlowNodesTableReferences),
          FlowNode,
          PrefetchHooks Function({bool studyId, bool workcenterId, bool poolId})
        > {
  $$FlowNodesTableTableManager(_$AppDatabase db, $FlowNodesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FlowNodesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FlowNodesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FlowNodesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> studyId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<FlowNodeKind> kind = const Value.absent(),
                Value<String?> workcenterId = const Value.absent(),
                Value<String?> poolId = const Value.absent(),
                Value<int> changeoverSeconds = const Value.absent(),
                Value<double?> equivalentValue = const Value.absent(),
                Value<TaktUnit?> equivalentUnit = const Value.absent(),
                Value<InventoryMode?> inventoryMode = const Value.absent(),
                Value<int?> inventoryQuantity = const Value.absent(),
                Value<int?> inventorySeconds = const Value.absent(),
                Value<DurationUnit?> inventoryUnit = const Value.absent(),
                Value<bool> inventoryUsesWorkingTime = const Value.absent(),
                Value<String?> label = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FlowNodesCompanion(
                id: id,
                studyId: studyId,
                position: position,
                kind: kind,
                workcenterId: workcenterId,
                poolId: poolId,
                changeoverSeconds: changeoverSeconds,
                equivalentValue: equivalentValue,
                equivalentUnit: equivalentUnit,
                inventoryMode: inventoryMode,
                inventoryQuantity: inventoryQuantity,
                inventorySeconds: inventorySeconds,
                inventoryUnit: inventoryUnit,
                inventoryUsesWorkingTime: inventoryUsesWorkingTime,
                label: label,
                notes: notes,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String studyId,
                required int position,
                required FlowNodeKind kind,
                Value<String?> workcenterId = const Value.absent(),
                Value<String?> poolId = const Value.absent(),
                Value<int> changeoverSeconds = const Value.absent(),
                Value<double?> equivalentValue = const Value.absent(),
                Value<TaktUnit?> equivalentUnit = const Value.absent(),
                Value<InventoryMode?> inventoryMode = const Value.absent(),
                Value<int?> inventoryQuantity = const Value.absent(),
                Value<int?> inventorySeconds = const Value.absent(),
                Value<DurationUnit?> inventoryUnit = const Value.absent(),
                Value<bool> inventoryUsesWorkingTime = const Value.absent(),
                Value<String?> label = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => FlowNodesCompanion.insert(
                id: id,
                studyId: studyId,
                position: position,
                kind: kind,
                workcenterId: workcenterId,
                poolId: poolId,
                changeoverSeconds: changeoverSeconds,
                equivalentValue: equivalentValue,
                equivalentUnit: equivalentUnit,
                inventoryMode: inventoryMode,
                inventoryQuantity: inventoryQuantity,
                inventorySeconds: inventorySeconds,
                inventoryUnit: inventoryUnit,
                inventoryUsesWorkingTime: inventoryUsesWorkingTime,
                label: label,
                notes: notes,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FlowNodesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({studyId = false, workcenterId = false, poolId = false}) {
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
                        if (studyId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.studyId,
                                    referencedTable: $$FlowNodesTableReferences
                                        ._studyIdTable(db),
                                    referencedColumn: $$FlowNodesTableReferences
                                        ._studyIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (workcenterId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.workcenterId,
                                    referencedTable: $$FlowNodesTableReferences
                                        ._workcenterIdTable(db),
                                    referencedColumn: $$FlowNodesTableReferences
                                        ._workcenterIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (poolId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.poolId,
                                    referencedTable: $$FlowNodesTableReferences
                                        ._poolIdTable(db),
                                    referencedColumn: $$FlowNodesTableReferences
                                        ._poolIdTable(db)
                                        .id,
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

typedef $$FlowNodesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FlowNodesTable,
      FlowNode,
      $$FlowNodesTableFilterComposer,
      $$FlowNodesTableOrderingComposer,
      $$FlowNodesTableAnnotationComposer,
      $$FlowNodesTableCreateCompanionBuilder,
      $$FlowNodesTableUpdateCompanionBuilder,
      (FlowNode, $$FlowNodesTableReferences),
      FlowNode,
      PrefetchHooks Function({bool studyId, bool workcenterId, bool poolId})
    >;
typedef $$FlowAnnotationsTableCreateCompanionBuilder =
    FlowAnnotationsCompanion Function({
      required String id,
      required String studyId,
      required AnnotationSymbol symbol,
      required double x,
      required double y,
      Value<String?> caption,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$FlowAnnotationsTableUpdateCompanionBuilder =
    FlowAnnotationsCompanion Function({
      Value<String> id,
      Value<String> studyId,
      Value<AnnotationSymbol> symbol,
      Value<double> x,
      Value<double> y,
      Value<String?> caption,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$FlowAnnotationsTableReferences
    extends
        BaseReferences<_$AppDatabase, $FlowAnnotationsTable, FlowAnnotation> {
  $$FlowAnnotationsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $StudiesTable _studyIdTable(_$AppDatabase db) =>
      db.studies.createAlias('flow_annotations__study_id__studies__id');

  $$StudiesTableProcessedTableManager get studyId {
    final $_column = $_itemColumn<String>('study_id')!;

    final manager = $$StudiesTableTableManager(
      $_db,
      $_db.studies,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_studyIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FlowAnnotationsTableFilterComposer
    extends Composer<_$AppDatabase, $FlowAnnotationsTable> {
  $$FlowAnnotationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<AnnotationSymbol, AnnotationSymbol, String>
  get symbol => $composableBuilder(
    column: $table.symbol,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<double> get x => $composableBuilder(
    column: $table.x,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get y => $composableBuilder(
    column: $table.y,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get caption => $composableBuilder(
    column: $table.caption,
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

  $$StudiesTableFilterComposer get studyId {
    final $$StudiesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.studyId,
      referencedTable: $db.studies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudiesTableFilterComposer(
            $db: $db,
            $table: $db.studies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FlowAnnotationsTableOrderingComposer
    extends Composer<_$AppDatabase, $FlowAnnotationsTable> {
  $$FlowAnnotationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get symbol => $composableBuilder(
    column: $table.symbol,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get x => $composableBuilder(
    column: $table.x,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get y => $composableBuilder(
    column: $table.y,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get caption => $composableBuilder(
    column: $table.caption,
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

  $$StudiesTableOrderingComposer get studyId {
    final $$StudiesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.studyId,
      referencedTable: $db.studies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudiesTableOrderingComposer(
            $db: $db,
            $table: $db.studies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FlowAnnotationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FlowAnnotationsTable> {
  $$FlowAnnotationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<AnnotationSymbol, String> get symbol =>
      $composableBuilder(column: $table.symbol, builder: (column) => column);

  GeneratedColumn<double> get x =>
      $composableBuilder(column: $table.x, builder: (column) => column);

  GeneratedColumn<double> get y =>
      $composableBuilder(column: $table.y, builder: (column) => column);

  GeneratedColumn<String> get caption =>
      $composableBuilder(column: $table.caption, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$StudiesTableAnnotationComposer get studyId {
    final $$StudiesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.studyId,
      referencedTable: $db.studies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudiesTableAnnotationComposer(
            $db: $db,
            $table: $db.studies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FlowAnnotationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FlowAnnotationsTable,
          FlowAnnotation,
          $$FlowAnnotationsTableFilterComposer,
          $$FlowAnnotationsTableOrderingComposer,
          $$FlowAnnotationsTableAnnotationComposer,
          $$FlowAnnotationsTableCreateCompanionBuilder,
          $$FlowAnnotationsTableUpdateCompanionBuilder,
          (FlowAnnotation, $$FlowAnnotationsTableReferences),
          FlowAnnotation,
          PrefetchHooks Function({bool studyId})
        > {
  $$FlowAnnotationsTableTableManager(
    _$AppDatabase db,
    $FlowAnnotationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FlowAnnotationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FlowAnnotationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FlowAnnotationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> studyId = const Value.absent(),
                Value<AnnotationSymbol> symbol = const Value.absent(),
                Value<double> x = const Value.absent(),
                Value<double> y = const Value.absent(),
                Value<String?> caption = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FlowAnnotationsCompanion(
                id: id,
                studyId: studyId,
                symbol: symbol,
                x: x,
                y: y,
                caption: caption,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String studyId,
                required AnnotationSymbol symbol,
                required double x,
                required double y,
                Value<String?> caption = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => FlowAnnotationsCompanion.insert(
                id: id,
                studyId: studyId,
                symbol: symbol,
                x: x,
                y: y,
                caption: caption,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FlowAnnotationsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({studyId = false}) {
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
                    if (studyId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.studyId,
                                referencedTable:
                                    $$FlowAnnotationsTableReferences
                                        ._studyIdTable(db),
                                referencedColumn:
                                    $$FlowAnnotationsTableReferences
                                        ._studyIdTable(db)
                                        .id,
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

typedef $$FlowAnnotationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FlowAnnotationsTable,
      FlowAnnotation,
      $$FlowAnnotationsTableFilterComposer,
      $$FlowAnnotationsTableOrderingComposer,
      $$FlowAnnotationsTableAnnotationComposer,
      $$FlowAnnotationsTableCreateCompanionBuilder,
      $$FlowAnnotationsTableUpdateCompanionBuilder,
      (FlowAnnotation, $$FlowAnnotationsTableReferences),
      FlowAnnotation,
      PrefetchHooks Function({bool studyId})
    >;
typedef $$DemandPartsTableCreateCompanionBuilder =
    DemandPartsCompanion Function({
      required String id,
      required String studyId,
      required String partNumber,
      Value<String> customerProject,
      Value<String?> description,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$DemandPartsTableUpdateCompanionBuilder =
    DemandPartsCompanion Function({
      Value<String> id,
      Value<String> studyId,
      Value<String> partNumber,
      Value<String> customerProject,
      Value<String?> description,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$DemandPartsTableReferences
    extends BaseReferences<_$AppDatabase, $DemandPartsTable, DemandPart> {
  $$DemandPartsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $StudiesTable _studyIdTable(_$AppDatabase db) =>
      db.studies.createAlias('demand_parts__study_id__studies__id');

  $$StudiesTableProcessedTableManager get studyId {
    final $_column = $_itemColumn<String>('study_id')!;

    final manager = $$StudiesTableTableManager(
      $_db,
      $_db.studies,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_studyIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$PartProcessTimesTable, List<PartProcessTime>>
  _partProcessTimesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.partProcessTimes,
    aliasName: 'demand_parts__id__part_process_times__part_id',
  );

  $$PartProcessTimesTableProcessedTableManager get partProcessTimesRefs {
    final manager = $$PartProcessTimesTableTableManager(
      $_db,
      $_db.partProcessTimes,
    ).filter((f) => f.partId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _partProcessTimesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DemandOrdersTable, List<DemandOrder>>
  _demandOrdersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.demandOrders,
    aliasName: 'demand_parts__id__demand_orders__part_id',
  );

  $$DemandOrdersTableProcessedTableManager get demandOrdersRefs {
    final manager = $$DemandOrdersTableTableManager(
      $_db,
      $_db.demandOrders,
    ).filter((f) => f.partId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_demandOrdersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DemandPartsTableFilterComposer
    extends Composer<_$AppDatabase, $DemandPartsTable> {
  $$DemandPartsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get partNumber => $composableBuilder(
    column: $table.partNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customerProject => $composableBuilder(
    column: $table.customerProject,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
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

  $$StudiesTableFilterComposer get studyId {
    final $$StudiesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.studyId,
      referencedTable: $db.studies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudiesTableFilterComposer(
            $db: $db,
            $table: $db.studies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> partProcessTimesRefs(
    Expression<bool> Function($$PartProcessTimesTableFilterComposer f) f,
  ) {
    final $$PartProcessTimesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.partProcessTimes,
      getReferencedColumn: (t) => t.partId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PartProcessTimesTableFilterComposer(
            $db: $db,
            $table: $db.partProcessTimes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> demandOrdersRefs(
    Expression<bool> Function($$DemandOrdersTableFilterComposer f) f,
  ) {
    final $$DemandOrdersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.demandOrders,
      getReferencedColumn: (t) => t.partId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DemandOrdersTableFilterComposer(
            $db: $db,
            $table: $db.demandOrders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DemandPartsTableOrderingComposer
    extends Composer<_$AppDatabase, $DemandPartsTable> {
  $$DemandPartsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get partNumber => $composableBuilder(
    column: $table.partNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customerProject => $composableBuilder(
    column: $table.customerProject,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
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

  $$StudiesTableOrderingComposer get studyId {
    final $$StudiesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.studyId,
      referencedTable: $db.studies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudiesTableOrderingComposer(
            $db: $db,
            $table: $db.studies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DemandPartsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DemandPartsTable> {
  $$DemandPartsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get partNumber => $composableBuilder(
    column: $table.partNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get customerProject => $composableBuilder(
    column: $table.customerProject,
    builder: (column) => column,
  );

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$StudiesTableAnnotationComposer get studyId {
    final $$StudiesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.studyId,
      referencedTable: $db.studies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudiesTableAnnotationComposer(
            $db: $db,
            $table: $db.studies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> partProcessTimesRefs<T extends Object>(
    Expression<T> Function($$PartProcessTimesTableAnnotationComposer a) f,
  ) {
    final $$PartProcessTimesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.partProcessTimes,
      getReferencedColumn: (t) => t.partId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PartProcessTimesTableAnnotationComposer(
            $db: $db,
            $table: $db.partProcessTimes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> demandOrdersRefs<T extends Object>(
    Expression<T> Function($$DemandOrdersTableAnnotationComposer a) f,
  ) {
    final $$DemandOrdersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.demandOrders,
      getReferencedColumn: (t) => t.partId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DemandOrdersTableAnnotationComposer(
            $db: $db,
            $table: $db.demandOrders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DemandPartsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DemandPartsTable,
          DemandPart,
          $$DemandPartsTableFilterComposer,
          $$DemandPartsTableOrderingComposer,
          $$DemandPartsTableAnnotationComposer,
          $$DemandPartsTableCreateCompanionBuilder,
          $$DemandPartsTableUpdateCompanionBuilder,
          (DemandPart, $$DemandPartsTableReferences),
          DemandPart,
          PrefetchHooks Function({
            bool studyId,
            bool partProcessTimesRefs,
            bool demandOrdersRefs,
          })
        > {
  $$DemandPartsTableTableManager(_$AppDatabase db, $DemandPartsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DemandPartsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DemandPartsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DemandPartsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> studyId = const Value.absent(),
                Value<String> partNumber = const Value.absent(),
                Value<String> customerProject = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DemandPartsCompanion(
                id: id,
                studyId: studyId,
                partNumber: partNumber,
                customerProject: customerProject,
                description: description,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String studyId,
                required String partNumber,
                Value<String> customerProject = const Value.absent(),
                Value<String?> description = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => DemandPartsCompanion.insert(
                id: id,
                studyId: studyId,
                partNumber: partNumber,
                customerProject: customerProject,
                description: description,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DemandPartsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                studyId = false,
                partProcessTimesRefs = false,
                demandOrdersRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (partProcessTimesRefs) db.partProcessTimes,
                    if (demandOrdersRefs) db.demandOrders,
                  ],
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
                        if (studyId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.studyId,
                                    referencedTable:
                                        $$DemandPartsTableReferences
                                            ._studyIdTable(db),
                                    referencedColumn:
                                        $$DemandPartsTableReferences
                                            ._studyIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (partProcessTimesRefs)
                        await $_getPrefetchedData<
                          DemandPart,
                          $DemandPartsTable,
                          PartProcessTime
                        >(
                          currentTable: table,
                          referencedTable: $$DemandPartsTableReferences
                              ._partProcessTimesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DemandPartsTableReferences(
                                db,
                                table,
                                p0,
                              ).partProcessTimesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.partId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (demandOrdersRefs)
                        await $_getPrefetchedData<
                          DemandPart,
                          $DemandPartsTable,
                          DemandOrder
                        >(
                          currentTable: table,
                          referencedTable: $$DemandPartsTableReferences
                              ._demandOrdersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DemandPartsTableReferences(
                                db,
                                table,
                                p0,
                              ).demandOrdersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.partId == item.id,
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

typedef $$DemandPartsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DemandPartsTable,
      DemandPart,
      $$DemandPartsTableFilterComposer,
      $$DemandPartsTableOrderingComposer,
      $$DemandPartsTableAnnotationComposer,
      $$DemandPartsTableCreateCompanionBuilder,
      $$DemandPartsTableUpdateCompanionBuilder,
      (DemandPart, $$DemandPartsTableReferences),
      DemandPart,
      PrefetchHooks Function({
        bool studyId,
        bool partProcessTimesRefs,
        bool demandOrdersRefs,
      })
    >;
typedef $$PartProcessTimesTableCreateCompanionBuilder =
    PartProcessTimesCompanion Function({
      required String partId,
      required String targetId,
      required int seconds,
      Value<int> rowid,
    });
typedef $$PartProcessTimesTableUpdateCompanionBuilder =
    PartProcessTimesCompanion Function({
      Value<String> partId,
      Value<String> targetId,
      Value<int> seconds,
      Value<int> rowid,
    });

final class $$PartProcessTimesTableReferences
    extends
        BaseReferences<_$AppDatabase, $PartProcessTimesTable, PartProcessTime> {
  $$PartProcessTimesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $DemandPartsTable _partIdTable(_$AppDatabase db) => db.demandParts
      .createAlias('part_process_times__part_id__demand_parts__id');

  $$DemandPartsTableProcessedTableManager get partId {
    final $_column = $_itemColumn<String>('part_id')!;

    final manager = $$DemandPartsTableTableManager(
      $_db,
      $_db.demandParts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_partIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PartProcessTimesTableFilterComposer
    extends Composer<_$AppDatabase, $PartProcessTimesTable> {
  $$PartProcessTimesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get targetId => $composableBuilder(
    column: $table.targetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seconds => $composableBuilder(
    column: $table.seconds,
    builder: (column) => ColumnFilters(column),
  );

  $$DemandPartsTableFilterComposer get partId {
    final $$DemandPartsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.partId,
      referencedTable: $db.demandParts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DemandPartsTableFilterComposer(
            $db: $db,
            $table: $db.demandParts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PartProcessTimesTableOrderingComposer
    extends Composer<_$AppDatabase, $PartProcessTimesTable> {
  $$PartProcessTimesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get targetId => $composableBuilder(
    column: $table.targetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seconds => $composableBuilder(
    column: $table.seconds,
    builder: (column) => ColumnOrderings(column),
  );

  $$DemandPartsTableOrderingComposer get partId {
    final $$DemandPartsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.partId,
      referencedTable: $db.demandParts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DemandPartsTableOrderingComposer(
            $db: $db,
            $table: $db.demandParts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PartProcessTimesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PartProcessTimesTable> {
  $$PartProcessTimesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get targetId =>
      $composableBuilder(column: $table.targetId, builder: (column) => column);

  GeneratedColumn<int> get seconds =>
      $composableBuilder(column: $table.seconds, builder: (column) => column);

  $$DemandPartsTableAnnotationComposer get partId {
    final $$DemandPartsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.partId,
      referencedTable: $db.demandParts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DemandPartsTableAnnotationComposer(
            $db: $db,
            $table: $db.demandParts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PartProcessTimesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PartProcessTimesTable,
          PartProcessTime,
          $$PartProcessTimesTableFilterComposer,
          $$PartProcessTimesTableOrderingComposer,
          $$PartProcessTimesTableAnnotationComposer,
          $$PartProcessTimesTableCreateCompanionBuilder,
          $$PartProcessTimesTableUpdateCompanionBuilder,
          (PartProcessTime, $$PartProcessTimesTableReferences),
          PartProcessTime,
          PrefetchHooks Function({bool partId})
        > {
  $$PartProcessTimesTableTableManager(
    _$AppDatabase db,
    $PartProcessTimesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PartProcessTimesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PartProcessTimesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PartProcessTimesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> partId = const Value.absent(),
                Value<String> targetId = const Value.absent(),
                Value<int> seconds = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PartProcessTimesCompanion(
                partId: partId,
                targetId: targetId,
                seconds: seconds,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String partId,
                required String targetId,
                required int seconds,
                Value<int> rowid = const Value.absent(),
              }) => PartProcessTimesCompanion.insert(
                partId: partId,
                targetId: targetId,
                seconds: seconds,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PartProcessTimesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({partId = false}) {
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
                    if (partId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.partId,
                                referencedTable:
                                    $$PartProcessTimesTableReferences
                                        ._partIdTable(db),
                                referencedColumn:
                                    $$PartProcessTimesTableReferences
                                        ._partIdTable(db)
                                        .id,
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

typedef $$PartProcessTimesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PartProcessTimesTable,
      PartProcessTime,
      $$PartProcessTimesTableFilterComposer,
      $$PartProcessTimesTableOrderingComposer,
      $$PartProcessTimesTableAnnotationComposer,
      $$PartProcessTimesTableCreateCompanionBuilder,
      $$PartProcessTimesTableUpdateCompanionBuilder,
      (PartProcessTime, $$PartProcessTimesTableReferences),
      PartProcessTime,
      PrefetchHooks Function({bool partId})
    >;
typedef $$DemandOrdersTableCreateCompanionBuilder =
    DemandOrdersCompanion Function({
      required String id,
      required String studyId,
      required String partId,
      required int sequence,
      Value<int> batchSize,
      required DateTime needDate,
      Value<DateTime?> materialDate,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$DemandOrdersTableUpdateCompanionBuilder =
    DemandOrdersCompanion Function({
      Value<String> id,
      Value<String> studyId,
      Value<String> partId,
      Value<int> sequence,
      Value<int> batchSize,
      Value<DateTime> needDate,
      Value<DateTime?> materialDate,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$DemandOrdersTableReferences
    extends BaseReferences<_$AppDatabase, $DemandOrdersTable, DemandOrder> {
  $$DemandOrdersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $StudiesTable _studyIdTable(_$AppDatabase db) =>
      db.studies.createAlias('demand_orders__study_id__studies__id');

  $$StudiesTableProcessedTableManager get studyId {
    final $_column = $_itemColumn<String>('study_id')!;

    final manager = $$StudiesTableTableManager(
      $_db,
      $_db.studies,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_studyIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $DemandPartsTable _partIdTable(_$AppDatabase db) =>
      db.demandParts.createAlias('demand_orders__part_id__demand_parts__id');

  $$DemandPartsTableProcessedTableManager get partId {
    final $_column = $_itemColumn<String>('part_id')!;

    final manager = $$DemandPartsTableTableManager(
      $_db,
      $_db.demandParts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_partIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DemandOrdersTableFilterComposer
    extends Composer<_$AppDatabase, $DemandOrdersTable> {
  $$DemandOrdersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get batchSize => $composableBuilder(
    column: $table.batchSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get needDate => $composableBuilder(
    column: $table.needDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get materialDate => $composableBuilder(
    column: $table.materialDate,
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

  $$StudiesTableFilterComposer get studyId {
    final $$StudiesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.studyId,
      referencedTable: $db.studies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudiesTableFilterComposer(
            $db: $db,
            $table: $db.studies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DemandPartsTableFilterComposer get partId {
    final $$DemandPartsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.partId,
      referencedTable: $db.demandParts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DemandPartsTableFilterComposer(
            $db: $db,
            $table: $db.demandParts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DemandOrdersTableOrderingComposer
    extends Composer<_$AppDatabase, $DemandOrdersTable> {
  $$DemandOrdersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get batchSize => $composableBuilder(
    column: $table.batchSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get needDate => $composableBuilder(
    column: $table.needDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get materialDate => $composableBuilder(
    column: $table.materialDate,
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

  $$StudiesTableOrderingComposer get studyId {
    final $$StudiesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.studyId,
      referencedTable: $db.studies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudiesTableOrderingComposer(
            $db: $db,
            $table: $db.studies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DemandPartsTableOrderingComposer get partId {
    final $$DemandPartsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.partId,
      referencedTable: $db.demandParts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DemandPartsTableOrderingComposer(
            $db: $db,
            $table: $db.demandParts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DemandOrdersTableAnnotationComposer
    extends Composer<_$AppDatabase, $DemandOrdersTable> {
  $$DemandOrdersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get sequence =>
      $composableBuilder(column: $table.sequence, builder: (column) => column);

  GeneratedColumn<int> get batchSize =>
      $composableBuilder(column: $table.batchSize, builder: (column) => column);

  GeneratedColumn<DateTime> get needDate =>
      $composableBuilder(column: $table.needDate, builder: (column) => column);

  GeneratedColumn<DateTime> get materialDate => $composableBuilder(
    column: $table.materialDate,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$StudiesTableAnnotationComposer get studyId {
    final $$StudiesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.studyId,
      referencedTable: $db.studies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudiesTableAnnotationComposer(
            $db: $db,
            $table: $db.studies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DemandPartsTableAnnotationComposer get partId {
    final $$DemandPartsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.partId,
      referencedTable: $db.demandParts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DemandPartsTableAnnotationComposer(
            $db: $db,
            $table: $db.demandParts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DemandOrdersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DemandOrdersTable,
          DemandOrder,
          $$DemandOrdersTableFilterComposer,
          $$DemandOrdersTableOrderingComposer,
          $$DemandOrdersTableAnnotationComposer,
          $$DemandOrdersTableCreateCompanionBuilder,
          $$DemandOrdersTableUpdateCompanionBuilder,
          (DemandOrder, $$DemandOrdersTableReferences),
          DemandOrder,
          PrefetchHooks Function({bool studyId, bool partId})
        > {
  $$DemandOrdersTableTableManager(_$AppDatabase db, $DemandOrdersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DemandOrdersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DemandOrdersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DemandOrdersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> studyId = const Value.absent(),
                Value<String> partId = const Value.absent(),
                Value<int> sequence = const Value.absent(),
                Value<int> batchSize = const Value.absent(),
                Value<DateTime> needDate = const Value.absent(),
                Value<DateTime?> materialDate = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DemandOrdersCompanion(
                id: id,
                studyId: studyId,
                partId: partId,
                sequence: sequence,
                batchSize: batchSize,
                needDate: needDate,
                materialDate: materialDate,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String studyId,
                required String partId,
                required int sequence,
                Value<int> batchSize = const Value.absent(),
                required DateTime needDate,
                Value<DateTime?> materialDate = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => DemandOrdersCompanion.insert(
                id: id,
                studyId: studyId,
                partId: partId,
                sequence: sequence,
                batchSize: batchSize,
                needDate: needDate,
                materialDate: materialDate,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DemandOrdersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({studyId = false, partId = false}) {
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
                    if (studyId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.studyId,
                                referencedTable: $$DemandOrdersTableReferences
                                    ._studyIdTable(db),
                                referencedColumn: $$DemandOrdersTableReferences
                                    ._studyIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (partId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.partId,
                                referencedTable: $$DemandOrdersTableReferences
                                    ._partIdTable(db),
                                referencedColumn: $$DemandOrdersTableReferences
                                    ._partIdTable(db)
                                    .id,
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

typedef $$DemandOrdersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DemandOrdersTable,
      DemandOrder,
      $$DemandOrdersTableFilterComposer,
      $$DemandOrdersTableOrderingComposer,
      $$DemandOrdersTableAnnotationComposer,
      $$DemandOrdersTableCreateCompanionBuilder,
      $$DemandOrdersTableUpdateCompanionBuilder,
      (DemandOrder, $$DemandOrdersTableReferences),
      DemandOrder,
      PrefetchHooks Function({bool studyId, bool partId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ShiftPatternsTableTableManager get shiftPatterns =>
      $$ShiftPatternsTableTableManager(_db, _db.shiftPatterns);
  $$PatternShiftsTableTableManager get patternShifts =>
      $$PatternShiftsTableTableManager(_db, _db.patternShifts);
  $$PlantsTableTableManager get plants =>
      $$PlantsTableTableManager(_db, _db.plants);
  $$ProductionCellsTableTableManager get productionCells =>
      $$ProductionCellsTableTableManager(_db, _db.productionCells);
  $$ProductionLinesTableTableManager get productionLines =>
      $$ProductionLinesTableTableManager(_db, _db.productionLines);
  $$WorkcenterTypesTableTableManager get workcenterTypes =>
      $$WorkcenterTypesTableTableManager(_db, _db.workcenterTypes);
  $$WorkcentersTableTableManager get workcenters =>
      $$WorkcentersTableTableManager(_db, _db.workcenters);
  $$WorkcenterLinesTableTableManager get workcenterLines =>
      $$WorkcenterLinesTableTableManager(_db, _db.workcenterLines);
  $$WorkcenterPoolsTableTableManager get workcenterPools =>
      $$WorkcenterPoolsTableTableManager(_db, _db.workcenterPools);
  $$WorkcenterPoolMembersTableTableManager get workcenterPoolMembers =>
      $$WorkcenterPoolMembersTableTableManager(_db, _db.workcenterPoolMembers);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$ProjectsTableTableManager get projects =>
      $$ProjectsTableTableManager(_db, _db.projects);
  $$CalendarExceptionsTableTableManager get calendarExceptions =>
      $$CalendarExceptionsTableTableManager(_db, _db.calendarExceptions);
  $$TaktPeriodsTableTableManager get taktPeriods =>
      $$TaktPeriodsTableTableManager(_db, _db.taktPeriods);
  $$WorkcenterSchedulePeriodsTableTableManager get workcenterSchedulePeriods =>
      $$WorkcenterSchedulePeriodsTableTableManager(
        _db,
        _db.workcenterSchedulePeriods,
      );
  $$StudiesTableTableManager get studies =>
      $$StudiesTableTableManager(_db, _db.studies);
  $$FlowNodesTableTableManager get flowNodes =>
      $$FlowNodesTableTableManager(_db, _db.flowNodes);
  $$FlowAnnotationsTableTableManager get flowAnnotations =>
      $$FlowAnnotationsTableTableManager(_db, _db.flowAnnotations);
  $$DemandPartsTableTableManager get demandParts =>
      $$DemandPartsTableTableManager(_db, _db.demandParts);
  $$PartProcessTimesTableTableManager get partProcessTimes =>
      $$PartProcessTimesTableTableManager(_db, _db.partProcessTimes);
  $$DemandOrdersTableTableManager get demandOrders =>
      $$DemandOrdersTableTableManager(_db, _db.demandOrders);
}
