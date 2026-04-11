// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $PhonemesTable extends Phonemes with TableInfo<$PhonemesTable, Phoneme> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PhonemesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _symbolMeta = const VerificationMeta('symbol');
  @override
  late final GeneratedColumn<String> symbol = GeneratedColumn<String>(
    'symbol',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mannerMeta = const VerificationMeta('manner');
  @override
  late final GeneratedColumn<String> manner = GeneratedColumn<String>(
    'manner',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _placeMeta = const VerificationMeta('place');
  @override
  late final GeneratedColumn<String> place = GeneratedColumn<String>(
    'place',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _voicingMeta = const VerificationMeta(
    'voicing',
  );
  @override
  late final GeneratedColumn<String> voicing = GeneratedColumn<String>(
    'voicing',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<String> height = GeneratedColumn<String>(
    'height',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _backnessMeta = const VerificationMeta(
    'backness',
  );
  @override
  late final GeneratedColumn<String> backness = GeneratedColumn<String>(
    'backness',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _roundedMeta = const VerificationMeta(
    'rounded',
  );
  @override
  late final GeneratedColumn<bool> rounded = GeneratedColumn<bool>(
    'rounded',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("rounded" IN (0, 1))',
    ),
  );
  static const VerificationMeta _customPropertiesMeta = const VerificationMeta(
    'customProperties',
  );
  @override
  late final GeneratedColumn<String> customProperties = GeneratedColumn<String>(
    'custom_properties',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    symbol,
    type,
    manner,
    place,
    voicing,
    height,
    backness,
    rounded,
    customProperties,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'phonemes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Phoneme> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('symbol')) {
      context.handle(
        _symbolMeta,
        symbol.isAcceptableOrUnknown(data['symbol']!, _symbolMeta),
      );
    } else if (isInserting) {
      context.missing(_symbolMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('manner')) {
      context.handle(
        _mannerMeta,
        manner.isAcceptableOrUnknown(data['manner']!, _mannerMeta),
      );
    }
    if (data.containsKey('place')) {
      context.handle(
        _placeMeta,
        place.isAcceptableOrUnknown(data['place']!, _placeMeta),
      );
    }
    if (data.containsKey('voicing')) {
      context.handle(
        _voicingMeta,
        voicing.isAcceptableOrUnknown(data['voicing']!, _voicingMeta),
      );
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    }
    if (data.containsKey('backness')) {
      context.handle(
        _backnessMeta,
        backness.isAcceptableOrUnknown(data['backness']!, _backnessMeta),
      );
    }
    if (data.containsKey('rounded')) {
      context.handle(
        _roundedMeta,
        rounded.isAcceptableOrUnknown(data['rounded']!, _roundedMeta),
      );
    }
    if (data.containsKey('custom_properties')) {
      context.handle(
        _customPropertiesMeta,
        customProperties.isAcceptableOrUnknown(
          data['custom_properties']!,
          _customPropertiesMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Phoneme map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Phoneme(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      symbol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      manner: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}manner'],
      ),
      place: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}place'],
      ),
      voicing: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}voicing'],
      ),
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}height'],
      ),
      backness: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}backness'],
      ),
      rounded: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}rounded'],
      ),
      customProperties: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}custom_properties'],
      ),
    );
  }

  @override
  $PhonemesTable createAlias(String alias) {
    return $PhonemesTable(attachedDatabase, alias);
  }
}

class Phoneme extends DataClass implements Insertable<Phoneme> {
  final int id;
  final String symbol;
  final String type;
  final String? manner;
  final String? place;
  final String? voicing;
  final String? height;
  final String? backness;
  final bool? rounded;
  final String? customProperties;
  const Phoneme({
    required this.id,
    required this.symbol,
    required this.type,
    this.manner,
    this.place,
    this.voicing,
    this.height,
    this.backness,
    this.rounded,
    this.customProperties,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['symbol'] = Variable<String>(symbol);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || manner != null) {
      map['manner'] = Variable<String>(manner);
    }
    if (!nullToAbsent || place != null) {
      map['place'] = Variable<String>(place);
    }
    if (!nullToAbsent || voicing != null) {
      map['voicing'] = Variable<String>(voicing);
    }
    if (!nullToAbsent || height != null) {
      map['height'] = Variable<String>(height);
    }
    if (!nullToAbsent || backness != null) {
      map['backness'] = Variable<String>(backness);
    }
    if (!nullToAbsent || rounded != null) {
      map['rounded'] = Variable<bool>(rounded);
    }
    if (!nullToAbsent || customProperties != null) {
      map['custom_properties'] = Variable<String>(customProperties);
    }
    return map;
  }

  PhonemesCompanion toCompanion(bool nullToAbsent) {
    return PhonemesCompanion(
      id: Value(id),
      symbol: Value(symbol),
      type: Value(type),
      manner: manner == null && nullToAbsent
          ? const Value.absent()
          : Value(manner),
      place: place == null && nullToAbsent
          ? const Value.absent()
          : Value(place),
      voicing: voicing == null && nullToAbsent
          ? const Value.absent()
          : Value(voicing),
      height: height == null && nullToAbsent
          ? const Value.absent()
          : Value(height),
      backness: backness == null && nullToAbsent
          ? const Value.absent()
          : Value(backness),
      rounded: rounded == null && nullToAbsent
          ? const Value.absent()
          : Value(rounded),
      customProperties: customProperties == null && nullToAbsent
          ? const Value.absent()
          : Value(customProperties),
    );
  }

  factory Phoneme.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Phoneme(
      id: serializer.fromJson<int>(json['id']),
      symbol: serializer.fromJson<String>(json['symbol']),
      type: serializer.fromJson<String>(json['type']),
      manner: serializer.fromJson<String?>(json['manner']),
      place: serializer.fromJson<String?>(json['place']),
      voicing: serializer.fromJson<String?>(json['voicing']),
      height: serializer.fromJson<String?>(json['height']),
      backness: serializer.fromJson<String?>(json['backness']),
      rounded: serializer.fromJson<bool?>(json['rounded']),
      customProperties: serializer.fromJson<String?>(json['customProperties']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'symbol': serializer.toJson<String>(symbol),
      'type': serializer.toJson<String>(type),
      'manner': serializer.toJson<String?>(manner),
      'place': serializer.toJson<String?>(place),
      'voicing': serializer.toJson<String?>(voicing),
      'height': serializer.toJson<String?>(height),
      'backness': serializer.toJson<String?>(backness),
      'rounded': serializer.toJson<bool?>(rounded),
      'customProperties': serializer.toJson<String?>(customProperties),
    };
  }

  Phoneme copyWith({
    int? id,
    String? symbol,
    String? type,
    Value<String?> manner = const Value.absent(),
    Value<String?> place = const Value.absent(),
    Value<String?> voicing = const Value.absent(),
    Value<String?> height = const Value.absent(),
    Value<String?> backness = const Value.absent(),
    Value<bool?> rounded = const Value.absent(),
    Value<String?> customProperties = const Value.absent(),
  }) => Phoneme(
    id: id ?? this.id,
    symbol: symbol ?? this.symbol,
    type: type ?? this.type,
    manner: manner.present ? manner.value : this.manner,
    place: place.present ? place.value : this.place,
    voicing: voicing.present ? voicing.value : this.voicing,
    height: height.present ? height.value : this.height,
    backness: backness.present ? backness.value : this.backness,
    rounded: rounded.present ? rounded.value : this.rounded,
    customProperties: customProperties.present
        ? customProperties.value
        : this.customProperties,
  );
  Phoneme copyWithCompanion(PhonemesCompanion data) {
    return Phoneme(
      id: data.id.present ? data.id.value : this.id,
      symbol: data.symbol.present ? data.symbol.value : this.symbol,
      type: data.type.present ? data.type.value : this.type,
      manner: data.manner.present ? data.manner.value : this.manner,
      place: data.place.present ? data.place.value : this.place,
      voicing: data.voicing.present ? data.voicing.value : this.voicing,
      height: data.height.present ? data.height.value : this.height,
      backness: data.backness.present ? data.backness.value : this.backness,
      rounded: data.rounded.present ? data.rounded.value : this.rounded,
      customProperties: data.customProperties.present
          ? data.customProperties.value
          : this.customProperties,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Phoneme(')
          ..write('id: $id, ')
          ..write('symbol: $symbol, ')
          ..write('type: $type, ')
          ..write('manner: $manner, ')
          ..write('place: $place, ')
          ..write('voicing: $voicing, ')
          ..write('height: $height, ')
          ..write('backness: $backness, ')
          ..write('rounded: $rounded, ')
          ..write('customProperties: $customProperties')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    symbol,
    type,
    manner,
    place,
    voicing,
    height,
    backness,
    rounded,
    customProperties,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Phoneme &&
          other.id == this.id &&
          other.symbol == this.symbol &&
          other.type == this.type &&
          other.manner == this.manner &&
          other.place == this.place &&
          other.voicing == this.voicing &&
          other.height == this.height &&
          other.backness == this.backness &&
          other.rounded == this.rounded &&
          other.customProperties == this.customProperties);
}

class PhonemesCompanion extends UpdateCompanion<Phoneme> {
  final Value<int> id;
  final Value<String> symbol;
  final Value<String> type;
  final Value<String?> manner;
  final Value<String?> place;
  final Value<String?> voicing;
  final Value<String?> height;
  final Value<String?> backness;
  final Value<bool?> rounded;
  final Value<String?> customProperties;
  const PhonemesCompanion({
    this.id = const Value.absent(),
    this.symbol = const Value.absent(),
    this.type = const Value.absent(),
    this.manner = const Value.absent(),
    this.place = const Value.absent(),
    this.voicing = const Value.absent(),
    this.height = const Value.absent(),
    this.backness = const Value.absent(),
    this.rounded = const Value.absent(),
    this.customProperties = const Value.absent(),
  });
  PhonemesCompanion.insert({
    this.id = const Value.absent(),
    required String symbol,
    required String type,
    this.manner = const Value.absent(),
    this.place = const Value.absent(),
    this.voicing = const Value.absent(),
    this.height = const Value.absent(),
    this.backness = const Value.absent(),
    this.rounded = const Value.absent(),
    this.customProperties = const Value.absent(),
  }) : symbol = Value(symbol),
       type = Value(type);
  static Insertable<Phoneme> custom({
    Expression<int>? id,
    Expression<String>? symbol,
    Expression<String>? type,
    Expression<String>? manner,
    Expression<String>? place,
    Expression<String>? voicing,
    Expression<String>? height,
    Expression<String>? backness,
    Expression<bool>? rounded,
    Expression<String>? customProperties,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (symbol != null) 'symbol': symbol,
      if (type != null) 'type': type,
      if (manner != null) 'manner': manner,
      if (place != null) 'place': place,
      if (voicing != null) 'voicing': voicing,
      if (height != null) 'height': height,
      if (backness != null) 'backness': backness,
      if (rounded != null) 'rounded': rounded,
      if (customProperties != null) 'custom_properties': customProperties,
    });
  }

  PhonemesCompanion copyWith({
    Value<int>? id,
    Value<String>? symbol,
    Value<String>? type,
    Value<String?>? manner,
    Value<String?>? place,
    Value<String?>? voicing,
    Value<String?>? height,
    Value<String?>? backness,
    Value<bool?>? rounded,
    Value<String?>? customProperties,
  }) {
    return PhonemesCompanion(
      id: id ?? this.id,
      symbol: symbol ?? this.symbol,
      type: type ?? this.type,
      manner: manner ?? this.manner,
      place: place ?? this.place,
      voicing: voicing ?? this.voicing,
      height: height ?? this.height,
      backness: backness ?? this.backness,
      rounded: rounded ?? this.rounded,
      customProperties: customProperties ?? this.customProperties,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (symbol.present) {
      map['symbol'] = Variable<String>(symbol.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (manner.present) {
      map['manner'] = Variable<String>(manner.value);
    }
    if (place.present) {
      map['place'] = Variable<String>(place.value);
    }
    if (voicing.present) {
      map['voicing'] = Variable<String>(voicing.value);
    }
    if (height.present) {
      map['height'] = Variable<String>(height.value);
    }
    if (backness.present) {
      map['backness'] = Variable<String>(backness.value);
    }
    if (rounded.present) {
      map['rounded'] = Variable<bool>(rounded.value);
    }
    if (customProperties.present) {
      map['custom_properties'] = Variable<String>(customProperties.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PhonemesCompanion(')
          ..write('id: $id, ')
          ..write('symbol: $symbol, ')
          ..write('type: $type, ')
          ..write('manner: $manner, ')
          ..write('place: $place, ')
          ..write('voicing: $voicing, ')
          ..write('height: $height, ')
          ..write('backness: $backness, ')
          ..write('rounded: $rounded, ')
          ..write('customProperties: $customProperties')
          ..write(')'))
        .toString();
  }
}

class $NaturalClassesTable extends NaturalClasses
    with TableInfo<$NaturalClassesTable, NaturalClassesData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NaturalClassesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
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
  static const VerificationMeta _phonemeIdsMeta = const VerificationMeta(
    'phonemeIds',
  );
  @override
  late final GeneratedColumn<String> phonemeIds = GeneratedColumn<String>(
    'phoneme_ids',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, phonemeIds];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'natural_classes';
  @override
  VerificationContext validateIntegrity(
    Insertable<NaturalClassesData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('phoneme_ids')) {
      context.handle(
        _phonemeIdsMeta,
        phonemeIds.isAcceptableOrUnknown(data['phoneme_ids']!, _phonemeIdsMeta),
      );
    } else if (isInserting) {
      context.missing(_phonemeIdsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NaturalClassesData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NaturalClassesData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      phonemeIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phoneme_ids'],
      )!,
    );
  }

  @override
  $NaturalClassesTable createAlias(String alias) {
    return $NaturalClassesTable(attachedDatabase, alias);
  }
}

class NaturalClassesData extends DataClass
    implements Insertable<NaturalClassesData> {
  final int id;
  final String name;
  final String phonemeIds;
  const NaturalClassesData({
    required this.id,
    required this.name,
    required this.phonemeIds,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['phoneme_ids'] = Variable<String>(phonemeIds);
    return map;
  }

  NaturalClassesCompanion toCompanion(bool nullToAbsent) {
    return NaturalClassesCompanion(
      id: Value(id),
      name: Value(name),
      phonemeIds: Value(phonemeIds),
    );
  }

  factory NaturalClassesData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NaturalClassesData(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      phonemeIds: serializer.fromJson<String>(json['phonemeIds']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'phonemeIds': serializer.toJson<String>(phonemeIds),
    };
  }

  NaturalClassesData copyWith({int? id, String? name, String? phonemeIds}) =>
      NaturalClassesData(
        id: id ?? this.id,
        name: name ?? this.name,
        phonemeIds: phonemeIds ?? this.phonemeIds,
      );
  NaturalClassesData copyWithCompanion(NaturalClassesCompanion data) {
    return NaturalClassesData(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      phonemeIds: data.phonemeIds.present
          ? data.phonemeIds.value
          : this.phonemeIds,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NaturalClassesData(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('phonemeIds: $phonemeIds')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, phonemeIds);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NaturalClassesData &&
          other.id == this.id &&
          other.name == this.name &&
          other.phonemeIds == this.phonemeIds);
}

class NaturalClassesCompanion extends UpdateCompanion<NaturalClassesData> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> phonemeIds;
  const NaturalClassesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.phonemeIds = const Value.absent(),
  });
  NaturalClassesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String phonemeIds,
  }) : name = Value(name),
       phonemeIds = Value(phonemeIds);
  static Insertable<NaturalClassesData> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? phonemeIds,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (phonemeIds != null) 'phoneme_ids': phonemeIds,
    });
  }

  NaturalClassesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? phonemeIds,
  }) {
    return NaturalClassesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      phonemeIds: phonemeIds ?? this.phonemeIds,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (phonemeIds.present) {
      map['phoneme_ids'] = Variable<String>(phonemeIds.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NaturalClassesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('phonemeIds: $phonemeIds')
          ..write(')'))
        .toString();
  }
}

class $PhonotacticTemplatesTable extends PhonotacticTemplates
    with TableInfo<$PhonotacticTemplatesTable, PhonotacticTemplate> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PhonotacticTemplatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _patternMeta = const VerificationMeta(
    'pattern',
  );
  @override
  late final GeneratedColumn<String> pattern = GeneratedColumn<String>(
    'pattern',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [id, pattern, description, isActive];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'phonotactic_templates';
  @override
  VerificationContext validateIntegrity(
    Insertable<PhonotacticTemplate> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('pattern')) {
      context.handle(
        _patternMeta,
        pattern.isAcceptableOrUnknown(data['pattern']!, _patternMeta),
      );
    } else if (isInserting) {
      context.missing(_patternMeta);
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
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PhonotacticTemplate map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PhonotacticTemplate(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      pattern: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pattern'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
    );
  }

  @override
  $PhonotacticTemplatesTable createAlias(String alias) {
    return $PhonotacticTemplatesTable(attachedDatabase, alias);
  }
}

class PhonotacticTemplate extends DataClass
    implements Insertable<PhonotacticTemplate> {
  final int id;
  final String pattern;
  final String? description;
  final bool isActive;
  const PhonotacticTemplate({
    required this.id,
    required this.pattern,
    this.description,
    required this.isActive,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['pattern'] = Variable<String>(pattern);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['is_active'] = Variable<bool>(isActive);
    return map;
  }

  PhonotacticTemplatesCompanion toCompanion(bool nullToAbsent) {
    return PhonotacticTemplatesCompanion(
      id: Value(id),
      pattern: Value(pattern),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      isActive: Value(isActive),
    );
  }

  factory PhonotacticTemplate.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PhonotacticTemplate(
      id: serializer.fromJson<int>(json['id']),
      pattern: serializer.fromJson<String>(json['pattern']),
      description: serializer.fromJson<String?>(json['description']),
      isActive: serializer.fromJson<bool>(json['isActive']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'pattern': serializer.toJson<String>(pattern),
      'description': serializer.toJson<String?>(description),
      'isActive': serializer.toJson<bool>(isActive),
    };
  }

  PhonotacticTemplate copyWith({
    int? id,
    String? pattern,
    Value<String?> description = const Value.absent(),
    bool? isActive,
  }) => PhonotacticTemplate(
    id: id ?? this.id,
    pattern: pattern ?? this.pattern,
    description: description.present ? description.value : this.description,
    isActive: isActive ?? this.isActive,
  );
  PhonotacticTemplate copyWithCompanion(PhonotacticTemplatesCompanion data) {
    return PhonotacticTemplate(
      id: data.id.present ? data.id.value : this.id,
      pattern: data.pattern.present ? data.pattern.value : this.pattern,
      description: data.description.present
          ? data.description.value
          : this.description,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PhonotacticTemplate(')
          ..write('id: $id, ')
          ..write('pattern: $pattern, ')
          ..write('description: $description, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, pattern, description, isActive);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PhonotacticTemplate &&
          other.id == this.id &&
          other.pattern == this.pattern &&
          other.description == this.description &&
          other.isActive == this.isActive);
}

class PhonotacticTemplatesCompanion
    extends UpdateCompanion<PhonotacticTemplate> {
  final Value<int> id;
  final Value<String> pattern;
  final Value<String?> description;
  final Value<bool> isActive;
  const PhonotacticTemplatesCompanion({
    this.id = const Value.absent(),
    this.pattern = const Value.absent(),
    this.description = const Value.absent(),
    this.isActive = const Value.absent(),
  });
  PhonotacticTemplatesCompanion.insert({
    this.id = const Value.absent(),
    required String pattern,
    this.description = const Value.absent(),
    this.isActive = const Value.absent(),
  }) : pattern = Value(pattern);
  static Insertable<PhonotacticTemplate> custom({
    Expression<int>? id,
    Expression<String>? pattern,
    Expression<String>? description,
    Expression<bool>? isActive,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (pattern != null) 'pattern': pattern,
      if (description != null) 'description': description,
      if (isActive != null) 'is_active': isActive,
    });
  }

  PhonotacticTemplatesCompanion copyWith({
    Value<int>? id,
    Value<String>? pattern,
    Value<String?>? description,
    Value<bool>? isActive,
  }) {
    return PhonotacticTemplatesCompanion(
      id: id ?? this.id,
      pattern: pattern ?? this.pattern,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (pattern.present) {
      map['pattern'] = Variable<String>(pattern.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PhonotacticTemplatesCompanion(')
          ..write('id: $id, ')
          ..write('pattern: $pattern, ')
          ..write('description: $description, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }
}

class $PhonotacticConstraintsTable extends PhonotacticConstraints
    with TableInfo<$PhonotacticConstraintsTable, PhonotacticConstraint> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PhonotacticConstraintsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _patternMeta = const VerificationMeta(
    'pattern',
  );
  @override
  late final GeneratedColumn<String> pattern = GeneratedColumn<String>(
    'pattern',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<String> position = GeneratedColumn<String>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('anywhere'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    pattern,
    description,
    isActive,
    position,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'phonotactic_constraints';
  @override
  VerificationContext validateIntegrity(
    Insertable<PhonotacticConstraint> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('pattern')) {
      context.handle(
        _patternMeta,
        pattern.isAcceptableOrUnknown(data['pattern']!, _patternMeta),
      );
    } else if (isInserting) {
      context.missing(_patternMeta);
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
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PhonotacticConstraint map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PhonotacticConstraint(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      pattern: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pattern'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $PhonotacticConstraintsTable createAlias(String alias) {
    return $PhonotacticConstraintsTable(attachedDatabase, alias);
  }
}

class PhonotacticConstraint extends DataClass
    implements Insertable<PhonotacticConstraint> {
  final int id;
  final String pattern;
  final String? description;
  final bool isActive;

  /// Position constraint: 'anywhere' (default), 'start', 'end'.
  final String position;
  const PhonotacticConstraint({
    required this.id,
    required this.pattern,
    this.description,
    required this.isActive,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['pattern'] = Variable<String>(pattern);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['is_active'] = Variable<bool>(isActive);
    map['position'] = Variable<String>(position);
    return map;
  }

  PhonotacticConstraintsCompanion toCompanion(bool nullToAbsent) {
    return PhonotacticConstraintsCompanion(
      id: Value(id),
      pattern: Value(pattern),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      isActive: Value(isActive),
      position: Value(position),
    );
  }

  factory PhonotacticConstraint.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PhonotacticConstraint(
      id: serializer.fromJson<int>(json['id']),
      pattern: serializer.fromJson<String>(json['pattern']),
      description: serializer.fromJson<String?>(json['description']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      position: serializer.fromJson<String>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'pattern': serializer.toJson<String>(pattern),
      'description': serializer.toJson<String?>(description),
      'isActive': serializer.toJson<bool>(isActive),
      'position': serializer.toJson<String>(position),
    };
  }

  PhonotacticConstraint copyWith({
    int? id,
    String? pattern,
    Value<String?> description = const Value.absent(),
    bool? isActive,
    String? position,
  }) => PhonotacticConstraint(
    id: id ?? this.id,
    pattern: pattern ?? this.pattern,
    description: description.present ? description.value : this.description,
    isActive: isActive ?? this.isActive,
    position: position ?? this.position,
  );
  PhonotacticConstraint copyWithCompanion(
    PhonotacticConstraintsCompanion data,
  ) {
    return PhonotacticConstraint(
      id: data.id.present ? data.id.value : this.id,
      pattern: data.pattern.present ? data.pattern.value : this.pattern,
      description: data.description.present
          ? data.description.value
          : this.description,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PhonotacticConstraint(')
          ..write('id: $id, ')
          ..write('pattern: $pattern, ')
          ..write('description: $description, ')
          ..write('isActive: $isActive, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, pattern, description, isActive, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PhonotacticConstraint &&
          other.id == this.id &&
          other.pattern == this.pattern &&
          other.description == this.description &&
          other.isActive == this.isActive &&
          other.position == this.position);
}

class PhonotacticConstraintsCompanion
    extends UpdateCompanion<PhonotacticConstraint> {
  final Value<int> id;
  final Value<String> pattern;
  final Value<String?> description;
  final Value<bool> isActive;
  final Value<String> position;
  const PhonotacticConstraintsCompanion({
    this.id = const Value.absent(),
    this.pattern = const Value.absent(),
    this.description = const Value.absent(),
    this.isActive = const Value.absent(),
    this.position = const Value.absent(),
  });
  PhonotacticConstraintsCompanion.insert({
    this.id = const Value.absent(),
    required String pattern,
    this.description = const Value.absent(),
    this.isActive = const Value.absent(),
    this.position = const Value.absent(),
  }) : pattern = Value(pattern);
  static Insertable<PhonotacticConstraint> custom({
    Expression<int>? id,
    Expression<String>? pattern,
    Expression<String>? description,
    Expression<bool>? isActive,
    Expression<String>? position,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (pattern != null) 'pattern': pattern,
      if (description != null) 'description': description,
      if (isActive != null) 'is_active': isActive,
      if (position != null) 'position': position,
    });
  }

  PhonotacticConstraintsCompanion copyWith({
    Value<int>? id,
    Value<String>? pattern,
    Value<String?>? description,
    Value<bool>? isActive,
    Value<String>? position,
  }) {
    return PhonotacticConstraintsCompanion(
      id: id ?? this.id,
      pattern: pattern ?? this.pattern,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      position: position ?? this.position,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (pattern.present) {
      map['pattern'] = Variable<String>(pattern.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (position.present) {
      map['position'] = Variable<String>(position.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PhonotacticConstraintsCompanion(')
          ..write('id: $id, ')
          ..write('pattern: $pattern, ')
          ..write('description: $description, ')
          ..write('isActive: $isActive, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }
}

class $RomanizationMappingsTable extends RomanizationMappings
    with TableInfo<$RomanizationMappingsTable, RomanizationMapping> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RomanizationMappingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _ipaSymbolMeta = const VerificationMeta(
    'ipaSymbol',
  );
  @override
  late final GeneratedColumn<String> ipaSymbol = GeneratedColumn<String>(
    'ipa_symbol',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _latinMappingMeta = const VerificationMeta(
    'latinMapping',
  );
  @override
  late final GeneratedColumn<String> latinMapping = GeneratedColumn<String>(
    'latin_mapping',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, ipaSymbol, latinMapping];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'romanization_mappings';
  @override
  VerificationContext validateIntegrity(
    Insertable<RomanizationMapping> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('ipa_symbol')) {
      context.handle(
        _ipaSymbolMeta,
        ipaSymbol.isAcceptableOrUnknown(data['ipa_symbol']!, _ipaSymbolMeta),
      );
    } else if (isInserting) {
      context.missing(_ipaSymbolMeta);
    }
    if (data.containsKey('latin_mapping')) {
      context.handle(
        _latinMappingMeta,
        latinMapping.isAcceptableOrUnknown(
          data['latin_mapping']!,
          _latinMappingMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_latinMappingMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RomanizationMapping map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RomanizationMapping(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      ipaSymbol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ipa_symbol'],
      )!,
      latinMapping: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}latin_mapping'],
      )!,
    );
  }

  @override
  $RomanizationMappingsTable createAlias(String alias) {
    return $RomanizationMappingsTable(attachedDatabase, alias);
  }
}

class RomanizationMapping extends DataClass
    implements Insertable<RomanizationMapping> {
  final int id;
  final String ipaSymbol;
  final String latinMapping;
  const RomanizationMapping({
    required this.id,
    required this.ipaSymbol,
    required this.latinMapping,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['ipa_symbol'] = Variable<String>(ipaSymbol);
    map['latin_mapping'] = Variable<String>(latinMapping);
    return map;
  }

  RomanizationMappingsCompanion toCompanion(bool nullToAbsent) {
    return RomanizationMappingsCompanion(
      id: Value(id),
      ipaSymbol: Value(ipaSymbol),
      latinMapping: Value(latinMapping),
    );
  }

  factory RomanizationMapping.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RomanizationMapping(
      id: serializer.fromJson<int>(json['id']),
      ipaSymbol: serializer.fromJson<String>(json['ipaSymbol']),
      latinMapping: serializer.fromJson<String>(json['latinMapping']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'ipaSymbol': serializer.toJson<String>(ipaSymbol),
      'latinMapping': serializer.toJson<String>(latinMapping),
    };
  }

  RomanizationMapping copyWith({
    int? id,
    String? ipaSymbol,
    String? latinMapping,
  }) => RomanizationMapping(
    id: id ?? this.id,
    ipaSymbol: ipaSymbol ?? this.ipaSymbol,
    latinMapping: latinMapping ?? this.latinMapping,
  );
  RomanizationMapping copyWithCompanion(RomanizationMappingsCompanion data) {
    return RomanizationMapping(
      id: data.id.present ? data.id.value : this.id,
      ipaSymbol: data.ipaSymbol.present ? data.ipaSymbol.value : this.ipaSymbol,
      latinMapping: data.latinMapping.present
          ? data.latinMapping.value
          : this.latinMapping,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RomanizationMapping(')
          ..write('id: $id, ')
          ..write('ipaSymbol: $ipaSymbol, ')
          ..write('latinMapping: $latinMapping')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, ipaSymbol, latinMapping);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RomanizationMapping &&
          other.id == this.id &&
          other.ipaSymbol == this.ipaSymbol &&
          other.latinMapping == this.latinMapping);
}

class RomanizationMappingsCompanion
    extends UpdateCompanion<RomanizationMapping> {
  final Value<int> id;
  final Value<String> ipaSymbol;
  final Value<String> latinMapping;
  const RomanizationMappingsCompanion({
    this.id = const Value.absent(),
    this.ipaSymbol = const Value.absent(),
    this.latinMapping = const Value.absent(),
  });
  RomanizationMappingsCompanion.insert({
    this.id = const Value.absent(),
    required String ipaSymbol,
    required String latinMapping,
  }) : ipaSymbol = Value(ipaSymbol),
       latinMapping = Value(latinMapping);
  static Insertable<RomanizationMapping> custom({
    Expression<int>? id,
    Expression<String>? ipaSymbol,
    Expression<String>? latinMapping,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ipaSymbol != null) 'ipa_symbol': ipaSymbol,
      if (latinMapping != null) 'latin_mapping': latinMapping,
    });
  }

  RomanizationMappingsCompanion copyWith({
    Value<int>? id,
    Value<String>? ipaSymbol,
    Value<String>? latinMapping,
  }) {
    return RomanizationMappingsCompanion(
      id: id ?? this.id,
      ipaSymbol: ipaSymbol ?? this.ipaSymbol,
      latinMapping: latinMapping ?? this.latinMapping,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (ipaSymbol.present) {
      map['ipa_symbol'] = Variable<String>(ipaSymbol.value);
    }
    if (latinMapping.present) {
      map['latin_mapping'] = Variable<String>(latinMapping.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RomanizationMappingsCompanion(')
          ..write('id: $id, ')
          ..write('ipaSymbol: $ipaSymbol, ')
          ..write('latinMapping: $latinMapping')
          ..write(')'))
        .toString();
  }
}

class $LexemesTable extends Lexemes with TableInfo<$LexemesTable, Lexeme> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LexemesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _ipaMeta = const VerificationMeta('ipa');
  @override
  late final GeneratedColumn<String> ipa = GeneratedColumn<String>(
    'ipa',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rootIdMeta = const VerificationMeta('rootId');
  @override
  late final GeneratedColumn<String> rootId = GeneratedColumn<String>(
    'root_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ruleIdsMeta = const VerificationMeta(
    'ruleIds',
  );
  @override
  late final GeneratedColumn<String> ruleIds = GeneratedColumn<String>(
    'rule_ids',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _computedFormMeta = const VerificationMeta(
    'computedForm',
  );
  @override
  late final GeneratedColumn<String> computedForm = GeneratedColumn<String>(
    'computed_form',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _romanizationMeta = const VerificationMeta(
    'romanization',
  );
  @override
  late final GeneratedColumn<String> romanization = GeneratedColumn<String>(
    'romanization',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _meaningMeta = const VerificationMeta(
    'meaning',
  );
  @override
  late final GeneratedColumn<String> meaning = GeneratedColumn<String>(
    'meaning',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _partOfSpeechMeta = const VerificationMeta(
    'partOfSpeech',
  );
  @override
  late final GeneratedColumn<String> partOfSpeech = GeneratedColumn<String>(
    'part_of_speech',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isPhonologicalExceptionMeta =
      const VerificationMeta('isPhonologicalException');
  @override
  late final GeneratedColumn<bool> isPhonologicalException =
      GeneratedColumn<bool>(
        'is_phonological_exception',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_phonological_exception" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
      );
  static const VerificationMeta _skippedDimensionsJsonMeta =
      const VerificationMeta('skippedDimensionsJson');
  @override
  late final GeneratedColumn<String> skippedDimensionsJson =
      GeneratedColumn<String>(
        'skipped_dimensions_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ipa,
    rootId,
    ruleIds,
    computedForm,
    romanization,
    meaning,
    partOfSpeech,
    isPhonologicalException,
    skippedDimensionsJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lexemes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Lexeme> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('ipa')) {
      context.handle(
        _ipaMeta,
        ipa.isAcceptableOrUnknown(data['ipa']!, _ipaMeta),
      );
    } else if (isInserting) {
      context.missing(_ipaMeta);
    }
    if (data.containsKey('root_id')) {
      context.handle(
        _rootIdMeta,
        rootId.isAcceptableOrUnknown(data['root_id']!, _rootIdMeta),
      );
    }
    if (data.containsKey('rule_ids')) {
      context.handle(
        _ruleIdsMeta,
        ruleIds.isAcceptableOrUnknown(data['rule_ids']!, _ruleIdsMeta),
      );
    }
    if (data.containsKey('computed_form')) {
      context.handle(
        _computedFormMeta,
        computedForm.isAcceptableOrUnknown(
          data['computed_form']!,
          _computedFormMeta,
        ),
      );
    }
    if (data.containsKey('romanization')) {
      context.handle(
        _romanizationMeta,
        romanization.isAcceptableOrUnknown(
          data['romanization']!,
          _romanizationMeta,
        ),
      );
    }
    if (data.containsKey('meaning')) {
      context.handle(
        _meaningMeta,
        meaning.isAcceptableOrUnknown(data['meaning']!, _meaningMeta),
      );
    }
    if (data.containsKey('part_of_speech')) {
      context.handle(
        _partOfSpeechMeta,
        partOfSpeech.isAcceptableOrUnknown(
          data['part_of_speech']!,
          _partOfSpeechMeta,
        ),
      );
    }
    if (data.containsKey('is_phonological_exception')) {
      context.handle(
        _isPhonologicalExceptionMeta,
        isPhonologicalException.isAcceptableOrUnknown(
          data['is_phonological_exception']!,
          _isPhonologicalExceptionMeta,
        ),
      );
    }
    if (data.containsKey('skipped_dimensions_json')) {
      context.handle(
        _skippedDimensionsJsonMeta,
        skippedDimensionsJson.isAcceptableOrUnknown(
          data['skipped_dimensions_json']!,
          _skippedDimensionsJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Lexeme map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Lexeme(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      ipa: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ipa'],
      )!,
      rootId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}root_id'],
      ),
      ruleIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rule_ids'],
      ),
      computedForm: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}computed_form'],
      ),
      romanization: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}romanization'],
      ),
      meaning: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meaning'],
      ),
      partOfSpeech: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}part_of_speech'],
      ),
      isPhonologicalException: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_phonological_exception'],
      )!,
      skippedDimensionsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}skipped_dimensions_json'],
      ),
    );
  }

  @override
  $LexemesTable createAlias(String alias) {
    return $LexemesTable(attachedDatabase, alias);
  }
}

class Lexeme extends DataClass implements Insertable<Lexeme> {
  final int id;
  final String ipa;
  final String? rootId;
  final String? ruleIds;
  final String? computedForm;
  final String? romanization;
  final String? meaning;
  final String? partOfSpeech;

  /// Marks this word as exempt from phonotactic violation highlighting.
  /// Defaults to false. Added in schema v7.
  final bool isPhonologicalException;

  /// Phase 4 D-07 — per-word dimension opt-out. JSON array of dimension ids
  /// this word explicitly skips (e.g. mass nouns skip number). Null = no skips.
  /// Added in schema v8.
  final String? skippedDimensionsJson;
  const Lexeme({
    required this.id,
    required this.ipa,
    this.rootId,
    this.ruleIds,
    this.computedForm,
    this.romanization,
    this.meaning,
    this.partOfSpeech,
    required this.isPhonologicalException,
    this.skippedDimensionsJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['ipa'] = Variable<String>(ipa);
    if (!nullToAbsent || rootId != null) {
      map['root_id'] = Variable<String>(rootId);
    }
    if (!nullToAbsent || ruleIds != null) {
      map['rule_ids'] = Variable<String>(ruleIds);
    }
    if (!nullToAbsent || computedForm != null) {
      map['computed_form'] = Variable<String>(computedForm);
    }
    if (!nullToAbsent || romanization != null) {
      map['romanization'] = Variable<String>(romanization);
    }
    if (!nullToAbsent || meaning != null) {
      map['meaning'] = Variable<String>(meaning);
    }
    if (!nullToAbsent || partOfSpeech != null) {
      map['part_of_speech'] = Variable<String>(partOfSpeech);
    }
    map['is_phonological_exception'] = Variable<bool>(isPhonologicalException);
    if (!nullToAbsent || skippedDimensionsJson != null) {
      map['skipped_dimensions_json'] = Variable<String>(skippedDimensionsJson);
    }
    return map;
  }

  LexemesCompanion toCompanion(bool nullToAbsent) {
    return LexemesCompanion(
      id: Value(id),
      ipa: Value(ipa),
      rootId: rootId == null && nullToAbsent
          ? const Value.absent()
          : Value(rootId),
      ruleIds: ruleIds == null && nullToAbsent
          ? const Value.absent()
          : Value(ruleIds),
      computedForm: computedForm == null && nullToAbsent
          ? const Value.absent()
          : Value(computedForm),
      romanization: romanization == null && nullToAbsent
          ? const Value.absent()
          : Value(romanization),
      meaning: meaning == null && nullToAbsent
          ? const Value.absent()
          : Value(meaning),
      partOfSpeech: partOfSpeech == null && nullToAbsent
          ? const Value.absent()
          : Value(partOfSpeech),
      isPhonologicalException: Value(isPhonologicalException),
      skippedDimensionsJson: skippedDimensionsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(skippedDimensionsJson),
    );
  }

  factory Lexeme.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Lexeme(
      id: serializer.fromJson<int>(json['id']),
      ipa: serializer.fromJson<String>(json['ipa']),
      rootId: serializer.fromJson<String?>(json['rootId']),
      ruleIds: serializer.fromJson<String?>(json['ruleIds']),
      computedForm: serializer.fromJson<String?>(json['computedForm']),
      romanization: serializer.fromJson<String?>(json['romanization']),
      meaning: serializer.fromJson<String?>(json['meaning']),
      partOfSpeech: serializer.fromJson<String?>(json['partOfSpeech']),
      isPhonologicalException: serializer.fromJson<bool>(
        json['isPhonologicalException'],
      ),
      skippedDimensionsJson: serializer.fromJson<String?>(
        json['skippedDimensionsJson'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'ipa': serializer.toJson<String>(ipa),
      'rootId': serializer.toJson<String?>(rootId),
      'ruleIds': serializer.toJson<String?>(ruleIds),
      'computedForm': serializer.toJson<String?>(computedForm),
      'romanization': serializer.toJson<String?>(romanization),
      'meaning': serializer.toJson<String?>(meaning),
      'partOfSpeech': serializer.toJson<String?>(partOfSpeech),
      'isPhonologicalException': serializer.toJson<bool>(
        isPhonologicalException,
      ),
      'skippedDimensionsJson': serializer.toJson<String?>(
        skippedDimensionsJson,
      ),
    };
  }

  Lexeme copyWith({
    int? id,
    String? ipa,
    Value<String?> rootId = const Value.absent(),
    Value<String?> ruleIds = const Value.absent(),
    Value<String?> computedForm = const Value.absent(),
    Value<String?> romanization = const Value.absent(),
    Value<String?> meaning = const Value.absent(),
    Value<String?> partOfSpeech = const Value.absent(),
    bool? isPhonologicalException,
    Value<String?> skippedDimensionsJson = const Value.absent(),
  }) => Lexeme(
    id: id ?? this.id,
    ipa: ipa ?? this.ipa,
    rootId: rootId.present ? rootId.value : this.rootId,
    ruleIds: ruleIds.present ? ruleIds.value : this.ruleIds,
    computedForm: computedForm.present ? computedForm.value : this.computedForm,
    romanization: romanization.present ? romanization.value : this.romanization,
    meaning: meaning.present ? meaning.value : this.meaning,
    partOfSpeech: partOfSpeech.present ? partOfSpeech.value : this.partOfSpeech,
    isPhonologicalException:
        isPhonologicalException ?? this.isPhonologicalException,
    skippedDimensionsJson: skippedDimensionsJson.present
        ? skippedDimensionsJson.value
        : this.skippedDimensionsJson,
  );
  Lexeme copyWithCompanion(LexemesCompanion data) {
    return Lexeme(
      id: data.id.present ? data.id.value : this.id,
      ipa: data.ipa.present ? data.ipa.value : this.ipa,
      rootId: data.rootId.present ? data.rootId.value : this.rootId,
      ruleIds: data.ruleIds.present ? data.ruleIds.value : this.ruleIds,
      computedForm: data.computedForm.present
          ? data.computedForm.value
          : this.computedForm,
      romanization: data.romanization.present
          ? data.romanization.value
          : this.romanization,
      meaning: data.meaning.present ? data.meaning.value : this.meaning,
      partOfSpeech: data.partOfSpeech.present
          ? data.partOfSpeech.value
          : this.partOfSpeech,
      isPhonologicalException: data.isPhonologicalException.present
          ? data.isPhonologicalException.value
          : this.isPhonologicalException,
      skippedDimensionsJson: data.skippedDimensionsJson.present
          ? data.skippedDimensionsJson.value
          : this.skippedDimensionsJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Lexeme(')
          ..write('id: $id, ')
          ..write('ipa: $ipa, ')
          ..write('rootId: $rootId, ')
          ..write('ruleIds: $ruleIds, ')
          ..write('computedForm: $computedForm, ')
          ..write('romanization: $romanization, ')
          ..write('meaning: $meaning, ')
          ..write('partOfSpeech: $partOfSpeech, ')
          ..write('isPhonologicalException: $isPhonologicalException, ')
          ..write('skippedDimensionsJson: $skippedDimensionsJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ipa,
    rootId,
    ruleIds,
    computedForm,
    romanization,
    meaning,
    partOfSpeech,
    isPhonologicalException,
    skippedDimensionsJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Lexeme &&
          other.id == this.id &&
          other.ipa == this.ipa &&
          other.rootId == this.rootId &&
          other.ruleIds == this.ruleIds &&
          other.computedForm == this.computedForm &&
          other.romanization == this.romanization &&
          other.meaning == this.meaning &&
          other.partOfSpeech == this.partOfSpeech &&
          other.isPhonologicalException == this.isPhonologicalException &&
          other.skippedDimensionsJson == this.skippedDimensionsJson);
}

class LexemesCompanion extends UpdateCompanion<Lexeme> {
  final Value<int> id;
  final Value<String> ipa;
  final Value<String?> rootId;
  final Value<String?> ruleIds;
  final Value<String?> computedForm;
  final Value<String?> romanization;
  final Value<String?> meaning;
  final Value<String?> partOfSpeech;
  final Value<bool> isPhonologicalException;
  final Value<String?> skippedDimensionsJson;
  const LexemesCompanion({
    this.id = const Value.absent(),
    this.ipa = const Value.absent(),
    this.rootId = const Value.absent(),
    this.ruleIds = const Value.absent(),
    this.computedForm = const Value.absent(),
    this.romanization = const Value.absent(),
    this.meaning = const Value.absent(),
    this.partOfSpeech = const Value.absent(),
    this.isPhonologicalException = const Value.absent(),
    this.skippedDimensionsJson = const Value.absent(),
  });
  LexemesCompanion.insert({
    this.id = const Value.absent(),
    required String ipa,
    this.rootId = const Value.absent(),
    this.ruleIds = const Value.absent(),
    this.computedForm = const Value.absent(),
    this.romanization = const Value.absent(),
    this.meaning = const Value.absent(),
    this.partOfSpeech = const Value.absent(),
    this.isPhonologicalException = const Value.absent(),
    this.skippedDimensionsJson = const Value.absent(),
  }) : ipa = Value(ipa);
  static Insertable<Lexeme> custom({
    Expression<int>? id,
    Expression<String>? ipa,
    Expression<String>? rootId,
    Expression<String>? ruleIds,
    Expression<String>? computedForm,
    Expression<String>? romanization,
    Expression<String>? meaning,
    Expression<String>? partOfSpeech,
    Expression<bool>? isPhonologicalException,
    Expression<String>? skippedDimensionsJson,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ipa != null) 'ipa': ipa,
      if (rootId != null) 'root_id': rootId,
      if (ruleIds != null) 'rule_ids': ruleIds,
      if (computedForm != null) 'computed_form': computedForm,
      if (romanization != null) 'romanization': romanization,
      if (meaning != null) 'meaning': meaning,
      if (partOfSpeech != null) 'part_of_speech': partOfSpeech,
      if (isPhonologicalException != null)
        'is_phonological_exception': isPhonologicalException,
      if (skippedDimensionsJson != null)
        'skipped_dimensions_json': skippedDimensionsJson,
    });
  }

  LexemesCompanion copyWith({
    Value<int>? id,
    Value<String>? ipa,
    Value<String?>? rootId,
    Value<String?>? ruleIds,
    Value<String?>? computedForm,
    Value<String?>? romanization,
    Value<String?>? meaning,
    Value<String?>? partOfSpeech,
    Value<bool>? isPhonologicalException,
    Value<String?>? skippedDimensionsJson,
  }) {
    return LexemesCompanion(
      id: id ?? this.id,
      ipa: ipa ?? this.ipa,
      rootId: rootId ?? this.rootId,
      ruleIds: ruleIds ?? this.ruleIds,
      computedForm: computedForm ?? this.computedForm,
      romanization: romanization ?? this.romanization,
      meaning: meaning ?? this.meaning,
      partOfSpeech: partOfSpeech ?? this.partOfSpeech,
      isPhonologicalException:
          isPhonologicalException ?? this.isPhonologicalException,
      skippedDimensionsJson:
          skippedDimensionsJson ?? this.skippedDimensionsJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (ipa.present) {
      map['ipa'] = Variable<String>(ipa.value);
    }
    if (rootId.present) {
      map['root_id'] = Variable<String>(rootId.value);
    }
    if (ruleIds.present) {
      map['rule_ids'] = Variable<String>(ruleIds.value);
    }
    if (computedForm.present) {
      map['computed_form'] = Variable<String>(computedForm.value);
    }
    if (romanization.present) {
      map['romanization'] = Variable<String>(romanization.value);
    }
    if (meaning.present) {
      map['meaning'] = Variable<String>(meaning.value);
    }
    if (partOfSpeech.present) {
      map['part_of_speech'] = Variable<String>(partOfSpeech.value);
    }
    if (isPhonologicalException.present) {
      map['is_phonological_exception'] = Variable<bool>(
        isPhonologicalException.value,
      );
    }
    if (skippedDimensionsJson.present) {
      map['skipped_dimensions_json'] = Variable<String>(
        skippedDimensionsJson.value,
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LexemesCompanion(')
          ..write('id: $id, ')
          ..write('ipa: $ipa, ')
          ..write('rootId: $rootId, ')
          ..write('ruleIds: $ruleIds, ')
          ..write('computedForm: $computedForm, ')
          ..write('romanization: $romanization, ')
          ..write('meaning: $meaning, ')
          ..write('partOfSpeech: $partOfSpeech, ')
          ..write('isPhonologicalException: $isPhonologicalException, ')
          ..write('skippedDimensionsJson: $skippedDimensionsJson')
          ..write(')'))
        .toString();
  }
}

class $RewriteRulesTable extends RewriteRules
    with TableInfo<$RewriteRulesTable, RewriteRule> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RewriteRulesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _orderingMeta = const VerificationMeta(
    'ordering',
  );
  @override
  late final GeneratedColumn<int> ordering = GeneratedColumn<int>(
    'ordering',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [id, source, ordering];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rewrite_rules';
  @override
  VerificationContext validateIntegrity(
    Insertable<RewriteRule> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('ordering')) {
      context.handle(
        _orderingMeta,
        ordering.isAcceptableOrUnknown(data['ordering']!, _orderingMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RewriteRule map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RewriteRule(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      ordering: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ordering'],
      )!,
    );
  }

  @override
  $RewriteRulesTable createAlias(String alias) {
    return $RewriteRulesTable(attachedDatabase, alias);
  }
}

class RewriteRule extends DataClass implements Insertable<RewriteRule> {
  final int id;
  final String source;
  final int ordering;
  const RewriteRule({
    required this.id,
    required this.source,
    required this.ordering,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['source'] = Variable<String>(source);
    map['ordering'] = Variable<int>(ordering);
    return map;
  }

  RewriteRulesCompanion toCompanion(bool nullToAbsent) {
    return RewriteRulesCompanion(
      id: Value(id),
      source: Value(source),
      ordering: Value(ordering),
    );
  }

  factory RewriteRule.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RewriteRule(
      id: serializer.fromJson<int>(json['id']),
      source: serializer.fromJson<String>(json['source']),
      ordering: serializer.fromJson<int>(json['ordering']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'source': serializer.toJson<String>(source),
      'ordering': serializer.toJson<int>(ordering),
    };
  }

  RewriteRule copyWith({int? id, String? source, int? ordering}) => RewriteRule(
    id: id ?? this.id,
    source: source ?? this.source,
    ordering: ordering ?? this.ordering,
  );
  RewriteRule copyWithCompanion(RewriteRulesCompanion data) {
    return RewriteRule(
      id: data.id.present ? data.id.value : this.id,
      source: data.source.present ? data.source.value : this.source,
      ordering: data.ordering.present ? data.ordering.value : this.ordering,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RewriteRule(')
          ..write('id: $id, ')
          ..write('source: $source, ')
          ..write('ordering: $ordering')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, source, ordering);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RewriteRule &&
          other.id == this.id &&
          other.source == this.source &&
          other.ordering == this.ordering);
}

class RewriteRulesCompanion extends UpdateCompanion<RewriteRule> {
  final Value<int> id;
  final Value<String> source;
  final Value<int> ordering;
  const RewriteRulesCompanion({
    this.id = const Value.absent(),
    this.source = const Value.absent(),
    this.ordering = const Value.absent(),
  });
  RewriteRulesCompanion.insert({
    this.id = const Value.absent(),
    required String source,
    this.ordering = const Value.absent(),
  }) : source = Value(source);
  static Insertable<RewriteRule> custom({
    Expression<int>? id,
    Expression<String>? source,
    Expression<int>? ordering,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (source != null) 'source': source,
      if (ordering != null) 'ordering': ordering,
    });
  }

  RewriteRulesCompanion copyWith({
    Value<int>? id,
    Value<String>? source,
    Value<int>? ordering,
  }) {
    return RewriteRulesCompanion(
      id: id ?? this.id,
      source: source ?? this.source,
      ordering: ordering ?? this.ordering,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (ordering.present) {
      map['ordering'] = Variable<int>(ordering.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RewriteRulesCompanion(')
          ..write('id: $id, ')
          ..write('source: $source, ')
          ..write('ordering: $ordering')
          ..write(')'))
        .toString();
  }
}

class $ProjectSettingsTable extends ProjectSettings
    with TableInfo<$ProjectSettingsTable, ProjectSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProjectSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'project_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProjectSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
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
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProjectSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProjectSetting(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $ProjectSettingsTable createAlias(String alias) {
    return $ProjectSettingsTable(attachedDatabase, alias);
  }
}

class ProjectSetting extends DataClass implements Insertable<ProjectSetting> {
  final int id;
  final String key;
  final String value;
  const ProjectSetting({
    required this.id,
    required this.key,
    required this.value,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  ProjectSettingsCompanion toCompanion(bool nullToAbsent) {
    return ProjectSettingsCompanion(
      id: Value(id),
      key: Value(key),
      value: Value(value),
    );
  }

  factory ProjectSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProjectSetting(
      id: serializer.fromJson<int>(json['id']),
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  ProjectSetting copyWith({int? id, String? key, String? value}) =>
      ProjectSetting(
        id: id ?? this.id,
        key: key ?? this.key,
        value: value ?? this.value,
      );
  ProjectSetting copyWithCompanion(ProjectSettingsCompanion data) {
    return ProjectSetting(
      id: data.id.present ? data.id.value : this.id,
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProjectSetting(')
          ..write('id: $id, ')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProjectSetting &&
          other.id == this.id &&
          other.key == this.key &&
          other.value == this.value);
}

class ProjectSettingsCompanion extends UpdateCompanion<ProjectSetting> {
  final Value<int> id;
  final Value<String> key;
  final Value<String> value;
  const ProjectSettingsCompanion({
    this.id = const Value.absent(),
    this.key = const Value.absent(),
    this.value = const Value.absent(),
  });
  ProjectSettingsCompanion.insert({
    this.id = const Value.absent(),
    required String key,
    required String value,
  }) : key = Value(key),
       value = Value(value);
  static Insertable<ProjectSetting> custom({
    Expression<int>? id,
    Expression<String>? key,
    Expression<String>? value,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (key != null) 'key': key,
      if (value != null) 'value': value,
    });
  }

  ProjectSettingsCompanion copyWith({
    Value<int>? id,
    Value<String>? key,
    Value<String>? value,
  }) {
    return ProjectSettingsCompanion(
      id: id ?? this.id,
      key: key ?? this.key,
      value: value ?? this.value,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProjectSettingsCompanion(')
          ..write('id: $id, ')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }
}

class $PartsOfSpeechTable extends PartsOfSpeech
    with TableInfo<$PartsOfSpeechTable, PartsOfSpeechData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PartsOfSpeechTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
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
  static const VerificationMeta _abbreviationMeta = const VerificationMeta(
    'abbreviation',
  );
  @override
  late final GeneratedColumn<String> abbreviation = GeneratedColumn<String>(
    'abbreviation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, abbreviation];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'parts_of_speech';
  @override
  VerificationContext validateIntegrity(
    Insertable<PartsOfSpeechData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('abbreviation')) {
      context.handle(
        _abbreviationMeta,
        abbreviation.isAcceptableOrUnknown(
          data['abbreviation']!,
          _abbreviationMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_abbreviationMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PartsOfSpeechData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PartsOfSpeechData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      abbreviation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}abbreviation'],
      )!,
    );
  }

  @override
  $PartsOfSpeechTable createAlias(String alias) {
    return $PartsOfSpeechTable(attachedDatabase, alias);
  }
}

class PartsOfSpeechData extends DataClass
    implements Insertable<PartsOfSpeechData> {
  final int id;
  final String name;
  final String abbreviation;
  const PartsOfSpeechData({
    required this.id,
    required this.name,
    required this.abbreviation,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['abbreviation'] = Variable<String>(abbreviation);
    return map;
  }

  PartsOfSpeechCompanion toCompanion(bool nullToAbsent) {
    return PartsOfSpeechCompanion(
      id: Value(id),
      name: Value(name),
      abbreviation: Value(abbreviation),
    );
  }

  factory PartsOfSpeechData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PartsOfSpeechData(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      abbreviation: serializer.fromJson<String>(json['abbreviation']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'abbreviation': serializer.toJson<String>(abbreviation),
    };
  }

  PartsOfSpeechData copyWith({int? id, String? name, String? abbreviation}) =>
      PartsOfSpeechData(
        id: id ?? this.id,
        name: name ?? this.name,
        abbreviation: abbreviation ?? this.abbreviation,
      );
  PartsOfSpeechData copyWithCompanion(PartsOfSpeechCompanion data) {
    return PartsOfSpeechData(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      abbreviation: data.abbreviation.present
          ? data.abbreviation.value
          : this.abbreviation,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PartsOfSpeechData(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('abbreviation: $abbreviation')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, abbreviation);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PartsOfSpeechData &&
          other.id == this.id &&
          other.name == this.name &&
          other.abbreviation == this.abbreviation);
}

class PartsOfSpeechCompanion extends UpdateCompanion<PartsOfSpeechData> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> abbreviation;
  const PartsOfSpeechCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.abbreviation = const Value.absent(),
  });
  PartsOfSpeechCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String abbreviation,
  }) : name = Value(name),
       abbreviation = Value(abbreviation);
  static Insertable<PartsOfSpeechData> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? abbreviation,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (abbreviation != null) 'abbreviation': abbreviation,
    });
  }

  PartsOfSpeechCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? abbreviation,
  }) {
    return PartsOfSpeechCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      abbreviation: abbreviation ?? this.abbreviation,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (abbreviation.present) {
      map['abbreviation'] = Variable<String>(abbreviation.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PartsOfSpeechCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('abbreviation: $abbreviation')
          ..write(')'))
        .toString();
  }
}

class $MorphologicalRulesTable extends MorphologicalRules
    with TableInfo<$MorphologicalRulesTable, MorphologicalRule> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MorphologicalRulesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
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
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _orderingMeta = const VerificationMeta(
    'ordering',
  );
  @override
  late final GeneratedColumn<int> ordering = GeneratedColumn<int>(
    'ordering',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _posIdMeta = const VerificationMeta('posId');
  @override
  late final GeneratedColumn<int> posId = GeneratedColumn<int>(
    'pos_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES parts_of_speech (id)',
    ),
  );
  static const VerificationMeta _posIdsMeta = const VerificationMeta('posIds');
  @override
  late final GeneratedColumn<String> posIds = GeneratedColumn<String>(
    'pos_ids',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('derivational'),
  );
  @override
  late final GeneratedColumnWithTypeConverter<FeatureBindings, String>
  featureBindings =
      GeneratedColumn<String>(
        'feature_bindings',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('{}'),
      ).withConverter<FeatureBindings>(
        $MorphologicalRulesTable.$converterfeatureBindings,
      );
  static const VerificationMeta _inputPosIdMeta = const VerificationMeta(
    'inputPosId',
  );
  @override
  late final GeneratedColumn<int> inputPosId = GeneratedColumn<int>(
    'input_pos_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES parts_of_speech (id)',
    ),
  );
  static const VerificationMeta _outputPosIdMeta = const VerificationMeta(
    'outputPosId',
  );
  @override
  late final GeneratedColumn<int> outputPosId = GeneratedColumn<int>(
    'output_pos_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES parts_of_speech (id)',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    source,
    ordering,
    isActive,
    posId,
    posIds,
    kind,
    featureBindings,
    inputPosId,
    outputPosId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'morphological_rules';
  @override
  VerificationContext validateIntegrity(
    Insertable<MorphologicalRule> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('ordering')) {
      context.handle(
        _orderingMeta,
        ordering.isAcceptableOrUnknown(data['ordering']!, _orderingMeta),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('pos_id')) {
      context.handle(
        _posIdMeta,
        posId.isAcceptableOrUnknown(data['pos_id']!, _posIdMeta),
      );
    }
    if (data.containsKey('pos_ids')) {
      context.handle(
        _posIdsMeta,
        posIds.isAcceptableOrUnknown(data['pos_ids']!, _posIdsMeta),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('input_pos_id')) {
      context.handle(
        _inputPosIdMeta,
        inputPosId.isAcceptableOrUnknown(
          data['input_pos_id']!,
          _inputPosIdMeta,
        ),
      );
    }
    if (data.containsKey('output_pos_id')) {
      context.handle(
        _outputPosIdMeta,
        outputPosId.isAcceptableOrUnknown(
          data['output_pos_id']!,
          _outputPosIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MorphologicalRule map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MorphologicalRule(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      ordering: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ordering'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      posId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pos_id'],
      ),
      posIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pos_ids'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      featureBindings: $MorphologicalRulesTable.$converterfeatureBindings
          .fromSql(
            attachedDatabase.typeMapping.read(
              DriftSqlType.string,
              data['${effectivePrefix}feature_bindings'],
            )!,
          ),
      inputPosId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}input_pos_id'],
      ),
      outputPosId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}output_pos_id'],
      ),
    );
  }

  @override
  $MorphologicalRulesTable createAlias(String alias) {
    return $MorphologicalRulesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<FeatureBindings, String, Map<String, dynamic>>
  $converterfeatureBindings = const FeatureBindingsConverter();
}

class MorphologicalRule extends DataClass
    implements Insertable<MorphologicalRule> {
  final int id;
  final String name;
  final String source;
  final int ordering;
  final bool isActive;
  final int? posId;

  /// Legacy v6 column. Comma-separated POS IDs (e.g. "1,3,5") — preserved
  /// for migration safety per Phase 4 research recommendation A9
  /// (keep-and-ignore). Do NOT write in v8+; replaced by [featureBindings]
  /// `{pos: [...]}`.
  final String posIds;

  /// v8+ — Phase 4 CONTEXT.md D-17. 'inflectional' | 'derivational'.
  /// Default 'derivational' matches the v7→v8 silent reclassification (D-18).
  final String kind;

  /// v8+ — Phase 4 CONTEXT.md D-09 / D-19. JSON of [FeatureBindings].
  final FeatureBindings featureBindings;

  /// v8+ — source POS for derivational rules (D-20). Nullable for inflectional.
  final int? inputPosId;

  /// v8+ — output POS for derivational rules (D-20). Defaults to inputPosId on migration.
  final int? outputPosId;
  const MorphologicalRule({
    required this.id,
    required this.name,
    required this.source,
    required this.ordering,
    required this.isActive,
    this.posId,
    required this.posIds,
    required this.kind,
    required this.featureBindings,
    this.inputPosId,
    this.outputPosId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['source'] = Variable<String>(source);
    map['ordering'] = Variable<int>(ordering);
    map['is_active'] = Variable<bool>(isActive);
    if (!nullToAbsent || posId != null) {
      map['pos_id'] = Variable<int>(posId);
    }
    map['pos_ids'] = Variable<String>(posIds);
    map['kind'] = Variable<String>(kind);
    {
      map['feature_bindings'] = Variable<String>(
        $MorphologicalRulesTable.$converterfeatureBindings.toSql(
          featureBindings,
        ),
      );
    }
    if (!nullToAbsent || inputPosId != null) {
      map['input_pos_id'] = Variable<int>(inputPosId);
    }
    if (!nullToAbsent || outputPosId != null) {
      map['output_pos_id'] = Variable<int>(outputPosId);
    }
    return map;
  }

  MorphologicalRulesCompanion toCompanion(bool nullToAbsent) {
    return MorphologicalRulesCompanion(
      id: Value(id),
      name: Value(name),
      source: Value(source),
      ordering: Value(ordering),
      isActive: Value(isActive),
      posId: posId == null && nullToAbsent
          ? const Value.absent()
          : Value(posId),
      posIds: Value(posIds),
      kind: Value(kind),
      featureBindings: Value(featureBindings),
      inputPosId: inputPosId == null && nullToAbsent
          ? const Value.absent()
          : Value(inputPosId),
      outputPosId: outputPosId == null && nullToAbsent
          ? const Value.absent()
          : Value(outputPosId),
    );
  }

  factory MorphologicalRule.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MorphologicalRule(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      source: serializer.fromJson<String>(json['source']),
      ordering: serializer.fromJson<int>(json['ordering']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      posId: serializer.fromJson<int?>(json['posId']),
      posIds: serializer.fromJson<String>(json['posIds']),
      kind: serializer.fromJson<String>(json['kind']),
      featureBindings: $MorphologicalRulesTable.$converterfeatureBindings
          .fromJson(
            serializer.fromJson<Map<String, dynamic>>(json['featureBindings']),
          ),
      inputPosId: serializer.fromJson<int?>(json['inputPosId']),
      outputPosId: serializer.fromJson<int?>(json['outputPosId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'source': serializer.toJson<String>(source),
      'ordering': serializer.toJson<int>(ordering),
      'isActive': serializer.toJson<bool>(isActive),
      'posId': serializer.toJson<int?>(posId),
      'posIds': serializer.toJson<String>(posIds),
      'kind': serializer.toJson<String>(kind),
      'featureBindings': serializer.toJson<Map<String, dynamic>>(
        $MorphologicalRulesTable.$converterfeatureBindings.toJson(
          featureBindings,
        ),
      ),
      'inputPosId': serializer.toJson<int?>(inputPosId),
      'outputPosId': serializer.toJson<int?>(outputPosId),
    };
  }

  MorphologicalRule copyWith({
    int? id,
    String? name,
    String? source,
    int? ordering,
    bool? isActive,
    Value<int?> posId = const Value.absent(),
    String? posIds,
    String? kind,
    FeatureBindings? featureBindings,
    Value<int?> inputPosId = const Value.absent(),
    Value<int?> outputPosId = const Value.absent(),
  }) => MorphologicalRule(
    id: id ?? this.id,
    name: name ?? this.name,
    source: source ?? this.source,
    ordering: ordering ?? this.ordering,
    isActive: isActive ?? this.isActive,
    posId: posId.present ? posId.value : this.posId,
    posIds: posIds ?? this.posIds,
    kind: kind ?? this.kind,
    featureBindings: featureBindings ?? this.featureBindings,
    inputPosId: inputPosId.present ? inputPosId.value : this.inputPosId,
    outputPosId: outputPosId.present ? outputPosId.value : this.outputPosId,
  );
  MorphologicalRule copyWithCompanion(MorphologicalRulesCompanion data) {
    return MorphologicalRule(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      source: data.source.present ? data.source.value : this.source,
      ordering: data.ordering.present ? data.ordering.value : this.ordering,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      posId: data.posId.present ? data.posId.value : this.posId,
      posIds: data.posIds.present ? data.posIds.value : this.posIds,
      kind: data.kind.present ? data.kind.value : this.kind,
      featureBindings: data.featureBindings.present
          ? data.featureBindings.value
          : this.featureBindings,
      inputPosId: data.inputPosId.present
          ? data.inputPosId.value
          : this.inputPosId,
      outputPosId: data.outputPosId.present
          ? data.outputPosId.value
          : this.outputPosId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MorphologicalRule(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('source: $source, ')
          ..write('ordering: $ordering, ')
          ..write('isActive: $isActive, ')
          ..write('posId: $posId, ')
          ..write('posIds: $posIds, ')
          ..write('kind: $kind, ')
          ..write('featureBindings: $featureBindings, ')
          ..write('inputPosId: $inputPosId, ')
          ..write('outputPosId: $outputPosId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    source,
    ordering,
    isActive,
    posId,
    posIds,
    kind,
    featureBindings,
    inputPosId,
    outputPosId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MorphologicalRule &&
          other.id == this.id &&
          other.name == this.name &&
          other.source == this.source &&
          other.ordering == this.ordering &&
          other.isActive == this.isActive &&
          other.posId == this.posId &&
          other.posIds == this.posIds &&
          other.kind == this.kind &&
          other.featureBindings == this.featureBindings &&
          other.inputPosId == this.inputPosId &&
          other.outputPosId == this.outputPosId);
}

class MorphologicalRulesCompanion extends UpdateCompanion<MorphologicalRule> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> source;
  final Value<int> ordering;
  final Value<bool> isActive;
  final Value<int?> posId;
  final Value<String> posIds;
  final Value<String> kind;
  final Value<FeatureBindings> featureBindings;
  final Value<int?> inputPosId;
  final Value<int?> outputPosId;
  const MorphologicalRulesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.source = const Value.absent(),
    this.ordering = const Value.absent(),
    this.isActive = const Value.absent(),
    this.posId = const Value.absent(),
    this.posIds = const Value.absent(),
    this.kind = const Value.absent(),
    this.featureBindings = const Value.absent(),
    this.inputPosId = const Value.absent(),
    this.outputPosId = const Value.absent(),
  });
  MorphologicalRulesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String source,
    this.ordering = const Value.absent(),
    this.isActive = const Value.absent(),
    this.posId = const Value.absent(),
    this.posIds = const Value.absent(),
    this.kind = const Value.absent(),
    this.featureBindings = const Value.absent(),
    this.inputPosId = const Value.absent(),
    this.outputPosId = const Value.absent(),
  }) : name = Value(name),
       source = Value(source);
  static Insertable<MorphologicalRule> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? source,
    Expression<int>? ordering,
    Expression<bool>? isActive,
    Expression<int>? posId,
    Expression<String>? posIds,
    Expression<String>? kind,
    Expression<String>? featureBindings,
    Expression<int>? inputPosId,
    Expression<int>? outputPosId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (source != null) 'source': source,
      if (ordering != null) 'ordering': ordering,
      if (isActive != null) 'is_active': isActive,
      if (posId != null) 'pos_id': posId,
      if (posIds != null) 'pos_ids': posIds,
      if (kind != null) 'kind': kind,
      if (featureBindings != null) 'feature_bindings': featureBindings,
      if (inputPosId != null) 'input_pos_id': inputPosId,
      if (outputPosId != null) 'output_pos_id': outputPosId,
    });
  }

  MorphologicalRulesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? source,
    Value<int>? ordering,
    Value<bool>? isActive,
    Value<int?>? posId,
    Value<String>? posIds,
    Value<String>? kind,
    Value<FeatureBindings>? featureBindings,
    Value<int?>? inputPosId,
    Value<int?>? outputPosId,
  }) {
    return MorphologicalRulesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      source: source ?? this.source,
      ordering: ordering ?? this.ordering,
      isActive: isActive ?? this.isActive,
      posId: posId ?? this.posId,
      posIds: posIds ?? this.posIds,
      kind: kind ?? this.kind,
      featureBindings: featureBindings ?? this.featureBindings,
      inputPosId: inputPosId ?? this.inputPosId,
      outputPosId: outputPosId ?? this.outputPosId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (ordering.present) {
      map['ordering'] = Variable<int>(ordering.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (posId.present) {
      map['pos_id'] = Variable<int>(posId.value);
    }
    if (posIds.present) {
      map['pos_ids'] = Variable<String>(posIds.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (featureBindings.present) {
      map['feature_bindings'] = Variable<String>(
        $MorphologicalRulesTable.$converterfeatureBindings.toSql(
          featureBindings.value,
        ),
      );
    }
    if (inputPosId.present) {
      map['input_pos_id'] = Variable<int>(inputPosId.value);
    }
    if (outputPosId.present) {
      map['output_pos_id'] = Variable<int>(outputPosId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MorphologicalRulesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('source: $source, ')
          ..write('ordering: $ordering, ')
          ..write('isActive: $isActive, ')
          ..write('posId: $posId, ')
          ..write('posIds: $posIds, ')
          ..write('kind: $kind, ')
          ..write('featureBindings: $featureBindings, ')
          ..write('inputPosId: $inputPosId, ')
          ..write('outputPosId: $outputPosId')
          ..write(')'))
        .toString();
  }
}

class $MorphologicalRuleExceptionsTable extends MorphologicalRuleExceptions
    with
        TableInfo<
          $MorphologicalRuleExceptionsTable,
          MorphologicalRuleException
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MorphologicalRuleExceptionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _lexemeIdMeta = const VerificationMeta(
    'lexemeId',
  );
  @override
  late final GeneratedColumn<int> lexemeId = GeneratedColumn<int>(
    'lexeme_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ruleIdMeta = const VerificationMeta('ruleId');
  @override
  late final GeneratedColumn<int> ruleId = GeneratedColumn<int>(
    'rule_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _overrideFormMeta = const VerificationMeta(
    'overrideForm',
  );
  @override
  late final GeneratedColumn<String> overrideForm = GeneratedColumn<String>(
    'override_form',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ruleSourceSnapshotMeta =
      const VerificationMeta('ruleSourceSnapshot');
  @override
  late final GeneratedColumn<String> ruleSourceSnapshot =
      GeneratedColumn<String>(
        'rule_source_snapshot',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    lexemeId,
    ruleId,
    overrideForm,
    ruleSourceSnapshot,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'morphological_rule_exceptions';
  @override
  VerificationContext validateIntegrity(
    Insertable<MorphologicalRuleException> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('lexeme_id')) {
      context.handle(
        _lexemeIdMeta,
        lexemeId.isAcceptableOrUnknown(data['lexeme_id']!, _lexemeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_lexemeIdMeta);
    }
    if (data.containsKey('rule_id')) {
      context.handle(
        _ruleIdMeta,
        ruleId.isAcceptableOrUnknown(data['rule_id']!, _ruleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ruleIdMeta);
    }
    if (data.containsKey('override_form')) {
      context.handle(
        _overrideFormMeta,
        overrideForm.isAcceptableOrUnknown(
          data['override_form']!,
          _overrideFormMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_overrideFormMeta);
    }
    if (data.containsKey('rule_source_snapshot')) {
      context.handle(
        _ruleSourceSnapshotMeta,
        ruleSourceSnapshot.isAcceptableOrUnknown(
          data['rule_source_snapshot']!,
          _ruleSourceSnapshotMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ruleSourceSnapshotMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MorphologicalRuleException map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MorphologicalRuleException(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      lexemeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lexeme_id'],
      )!,
      ruleId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rule_id'],
      )!,
      overrideForm: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}override_form'],
      )!,
      ruleSourceSnapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rule_source_snapshot'],
      )!,
    );
  }

  @override
  $MorphologicalRuleExceptionsTable createAlias(String alias) {
    return $MorphologicalRuleExceptionsTable(attachedDatabase, alias);
  }
}

class MorphologicalRuleException extends DataClass
    implements Insertable<MorphologicalRuleException> {
  final int id;
  final int lexemeId;
  final int ruleId;
  final String overrideForm;
  final String ruleSourceSnapshot;
  const MorphologicalRuleException({
    required this.id,
    required this.lexemeId,
    required this.ruleId,
    required this.overrideForm,
    required this.ruleSourceSnapshot,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['lexeme_id'] = Variable<int>(lexemeId);
    map['rule_id'] = Variable<int>(ruleId);
    map['override_form'] = Variable<String>(overrideForm);
    map['rule_source_snapshot'] = Variable<String>(ruleSourceSnapshot);
    return map;
  }

  MorphologicalRuleExceptionsCompanion toCompanion(bool nullToAbsent) {
    return MorphologicalRuleExceptionsCompanion(
      id: Value(id),
      lexemeId: Value(lexemeId),
      ruleId: Value(ruleId),
      overrideForm: Value(overrideForm),
      ruleSourceSnapshot: Value(ruleSourceSnapshot),
    );
  }

  factory MorphologicalRuleException.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MorphologicalRuleException(
      id: serializer.fromJson<int>(json['id']),
      lexemeId: serializer.fromJson<int>(json['lexemeId']),
      ruleId: serializer.fromJson<int>(json['ruleId']),
      overrideForm: serializer.fromJson<String>(json['overrideForm']),
      ruleSourceSnapshot: serializer.fromJson<String>(
        json['ruleSourceSnapshot'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'lexemeId': serializer.toJson<int>(lexemeId),
      'ruleId': serializer.toJson<int>(ruleId),
      'overrideForm': serializer.toJson<String>(overrideForm),
      'ruleSourceSnapshot': serializer.toJson<String>(ruleSourceSnapshot),
    };
  }

  MorphologicalRuleException copyWith({
    int? id,
    int? lexemeId,
    int? ruleId,
    String? overrideForm,
    String? ruleSourceSnapshot,
  }) => MorphologicalRuleException(
    id: id ?? this.id,
    lexemeId: lexemeId ?? this.lexemeId,
    ruleId: ruleId ?? this.ruleId,
    overrideForm: overrideForm ?? this.overrideForm,
    ruleSourceSnapshot: ruleSourceSnapshot ?? this.ruleSourceSnapshot,
  );
  MorphologicalRuleException copyWithCompanion(
    MorphologicalRuleExceptionsCompanion data,
  ) {
    return MorphologicalRuleException(
      id: data.id.present ? data.id.value : this.id,
      lexemeId: data.lexemeId.present ? data.lexemeId.value : this.lexemeId,
      ruleId: data.ruleId.present ? data.ruleId.value : this.ruleId,
      overrideForm: data.overrideForm.present
          ? data.overrideForm.value
          : this.overrideForm,
      ruleSourceSnapshot: data.ruleSourceSnapshot.present
          ? data.ruleSourceSnapshot.value
          : this.ruleSourceSnapshot,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MorphologicalRuleException(')
          ..write('id: $id, ')
          ..write('lexemeId: $lexemeId, ')
          ..write('ruleId: $ruleId, ')
          ..write('overrideForm: $overrideForm, ')
          ..write('ruleSourceSnapshot: $ruleSourceSnapshot')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, lexemeId, ruleId, overrideForm, ruleSourceSnapshot);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MorphologicalRuleException &&
          other.id == this.id &&
          other.lexemeId == this.lexemeId &&
          other.ruleId == this.ruleId &&
          other.overrideForm == this.overrideForm &&
          other.ruleSourceSnapshot == this.ruleSourceSnapshot);
}

class MorphologicalRuleExceptionsCompanion
    extends UpdateCompanion<MorphologicalRuleException> {
  final Value<int> id;
  final Value<int> lexemeId;
  final Value<int> ruleId;
  final Value<String> overrideForm;
  final Value<String> ruleSourceSnapshot;
  const MorphologicalRuleExceptionsCompanion({
    this.id = const Value.absent(),
    this.lexemeId = const Value.absent(),
    this.ruleId = const Value.absent(),
    this.overrideForm = const Value.absent(),
    this.ruleSourceSnapshot = const Value.absent(),
  });
  MorphologicalRuleExceptionsCompanion.insert({
    this.id = const Value.absent(),
    required int lexemeId,
    required int ruleId,
    required String overrideForm,
    required String ruleSourceSnapshot,
  }) : lexemeId = Value(lexemeId),
       ruleId = Value(ruleId),
       overrideForm = Value(overrideForm),
       ruleSourceSnapshot = Value(ruleSourceSnapshot);
  static Insertable<MorphologicalRuleException> custom({
    Expression<int>? id,
    Expression<int>? lexemeId,
    Expression<int>? ruleId,
    Expression<String>? overrideForm,
    Expression<String>? ruleSourceSnapshot,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (lexemeId != null) 'lexeme_id': lexemeId,
      if (ruleId != null) 'rule_id': ruleId,
      if (overrideForm != null) 'override_form': overrideForm,
      if (ruleSourceSnapshot != null)
        'rule_source_snapshot': ruleSourceSnapshot,
    });
  }

  MorphologicalRuleExceptionsCompanion copyWith({
    Value<int>? id,
    Value<int>? lexemeId,
    Value<int>? ruleId,
    Value<String>? overrideForm,
    Value<String>? ruleSourceSnapshot,
  }) {
    return MorphologicalRuleExceptionsCompanion(
      id: id ?? this.id,
      lexemeId: lexemeId ?? this.lexemeId,
      ruleId: ruleId ?? this.ruleId,
      overrideForm: overrideForm ?? this.overrideForm,
      ruleSourceSnapshot: ruleSourceSnapshot ?? this.ruleSourceSnapshot,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (lexemeId.present) {
      map['lexeme_id'] = Variable<int>(lexemeId.value);
    }
    if (ruleId.present) {
      map['rule_id'] = Variable<int>(ruleId.value);
    }
    if (overrideForm.present) {
      map['override_form'] = Variable<String>(overrideForm.value);
    }
    if (ruleSourceSnapshot.present) {
      map['rule_source_snapshot'] = Variable<String>(ruleSourceSnapshot.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MorphologicalRuleExceptionsCompanion(')
          ..write('id: $id, ')
          ..write('lexemeId: $lexemeId, ')
          ..write('ruleId: $ruleId, ')
          ..write('overrideForm: $overrideForm, ')
          ..write('ruleSourceSnapshot: $ruleSourceSnapshot')
          ..write(')'))
        .toString();
  }
}

class $DimensionsTable extends Dimensions
    with TableInfo<$DimensionsTable, Dimension> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DimensionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _posIdMeta = const VerificationMeta('posId');
  @override
  late final GeneratedColumn<int> posId = GeneratedColumn<int>(
    'pos_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES parts_of_speech (id) ON DELETE CASCADE',
    ),
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
  static const VerificationMeta _orderingMeta = const VerificationMeta(
    'ordering',
  );
  @override
  late final GeneratedColumn<int> ordering = GeneratedColumn<int>(
    'ordering',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _levelsJsonMeta = const VerificationMeta(
    'levelsJson',
  );
  @override
  late final GeneratedColumn<String> levelsJson = GeneratedColumn<String>(
    'levels_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _templateIdMeta = const VerificationMeta(
    'templateId',
  );
  @override
  late final GeneratedColumn<String> templateId = GeneratedColumn<String>(
    'template_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    posId,
    name,
    ordering,
    levelsJson,
    templateId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dimensions';
  @override
  VerificationContext validateIntegrity(
    Insertable<Dimension> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('pos_id')) {
      context.handle(
        _posIdMeta,
        posId.isAcceptableOrUnknown(data['pos_id']!, _posIdMeta),
      );
    } else if (isInserting) {
      context.missing(_posIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('ordering')) {
      context.handle(
        _orderingMeta,
        ordering.isAcceptableOrUnknown(data['ordering']!, _orderingMeta),
      );
    }
    if (data.containsKey('levels_json')) {
      context.handle(
        _levelsJsonMeta,
        levelsJson.isAcceptableOrUnknown(data['levels_json']!, _levelsJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_levelsJsonMeta);
    }
    if (data.containsKey('template_id')) {
      context.handle(
        _templateIdMeta,
        templateId.isAcceptableOrUnknown(data['template_id']!, _templateIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Dimension map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Dimension(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      posId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pos_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      ordering: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ordering'],
      )!,
      levelsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}levels_json'],
      )!,
      templateId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}template_id'],
      ),
    );
  }

  @override
  $DimensionsTable createAlias(String alias) {
    return $DimensionsTable(attachedDatabase, alias);
  }
}

class Dimension extends DataClass implements Insertable<Dimension> {
  final int id;
  final int posId;
  final String name;
  final int ordering;
  final String levelsJson;
  final String? templateId;
  const Dimension({
    required this.id,
    required this.posId,
    required this.name,
    required this.ordering,
    required this.levelsJson,
    this.templateId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['pos_id'] = Variable<int>(posId);
    map['name'] = Variable<String>(name);
    map['ordering'] = Variable<int>(ordering);
    map['levels_json'] = Variable<String>(levelsJson);
    if (!nullToAbsent || templateId != null) {
      map['template_id'] = Variable<String>(templateId);
    }
    return map;
  }

  DimensionsCompanion toCompanion(bool nullToAbsent) {
    return DimensionsCompanion(
      id: Value(id),
      posId: Value(posId),
      name: Value(name),
      ordering: Value(ordering),
      levelsJson: Value(levelsJson),
      templateId: templateId == null && nullToAbsent
          ? const Value.absent()
          : Value(templateId),
    );
  }

  factory Dimension.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Dimension(
      id: serializer.fromJson<int>(json['id']),
      posId: serializer.fromJson<int>(json['posId']),
      name: serializer.fromJson<String>(json['name']),
      ordering: serializer.fromJson<int>(json['ordering']),
      levelsJson: serializer.fromJson<String>(json['levelsJson']),
      templateId: serializer.fromJson<String?>(json['templateId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'posId': serializer.toJson<int>(posId),
      'name': serializer.toJson<String>(name),
      'ordering': serializer.toJson<int>(ordering),
      'levelsJson': serializer.toJson<String>(levelsJson),
      'templateId': serializer.toJson<String?>(templateId),
    };
  }

  Dimension copyWith({
    int? id,
    int? posId,
    String? name,
    int? ordering,
    String? levelsJson,
    Value<String?> templateId = const Value.absent(),
  }) => Dimension(
    id: id ?? this.id,
    posId: posId ?? this.posId,
    name: name ?? this.name,
    ordering: ordering ?? this.ordering,
    levelsJson: levelsJson ?? this.levelsJson,
    templateId: templateId.present ? templateId.value : this.templateId,
  );
  Dimension copyWithCompanion(DimensionsCompanion data) {
    return Dimension(
      id: data.id.present ? data.id.value : this.id,
      posId: data.posId.present ? data.posId.value : this.posId,
      name: data.name.present ? data.name.value : this.name,
      ordering: data.ordering.present ? data.ordering.value : this.ordering,
      levelsJson: data.levelsJson.present
          ? data.levelsJson.value
          : this.levelsJson,
      templateId: data.templateId.present
          ? data.templateId.value
          : this.templateId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Dimension(')
          ..write('id: $id, ')
          ..write('posId: $posId, ')
          ..write('name: $name, ')
          ..write('ordering: $ordering, ')
          ..write('levelsJson: $levelsJson, ')
          ..write('templateId: $templateId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, posId, name, ordering, levelsJson, templateId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Dimension &&
          other.id == this.id &&
          other.posId == this.posId &&
          other.name == this.name &&
          other.ordering == this.ordering &&
          other.levelsJson == this.levelsJson &&
          other.templateId == this.templateId);
}

class DimensionsCompanion extends UpdateCompanion<Dimension> {
  final Value<int> id;
  final Value<int> posId;
  final Value<String> name;
  final Value<int> ordering;
  final Value<String> levelsJson;
  final Value<String?> templateId;
  const DimensionsCompanion({
    this.id = const Value.absent(),
    this.posId = const Value.absent(),
    this.name = const Value.absent(),
    this.ordering = const Value.absent(),
    this.levelsJson = const Value.absent(),
    this.templateId = const Value.absent(),
  });
  DimensionsCompanion.insert({
    this.id = const Value.absent(),
    required int posId,
    required String name,
    this.ordering = const Value.absent(),
    required String levelsJson,
    this.templateId = const Value.absent(),
  }) : posId = Value(posId),
       name = Value(name),
       levelsJson = Value(levelsJson);
  static Insertable<Dimension> custom({
    Expression<int>? id,
    Expression<int>? posId,
    Expression<String>? name,
    Expression<int>? ordering,
    Expression<String>? levelsJson,
    Expression<String>? templateId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (posId != null) 'pos_id': posId,
      if (name != null) 'name': name,
      if (ordering != null) 'ordering': ordering,
      if (levelsJson != null) 'levels_json': levelsJson,
      if (templateId != null) 'template_id': templateId,
    });
  }

  DimensionsCompanion copyWith({
    Value<int>? id,
    Value<int>? posId,
    Value<String>? name,
    Value<int>? ordering,
    Value<String>? levelsJson,
    Value<String?>? templateId,
  }) {
    return DimensionsCompanion(
      id: id ?? this.id,
      posId: posId ?? this.posId,
      name: name ?? this.name,
      ordering: ordering ?? this.ordering,
      levelsJson: levelsJson ?? this.levelsJson,
      templateId: templateId ?? this.templateId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (posId.present) {
      map['pos_id'] = Variable<int>(posId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (ordering.present) {
      map['ordering'] = Variable<int>(ordering.value);
    }
    if (levelsJson.present) {
      map['levels_json'] = Variable<String>(levelsJson.value);
    }
    if (templateId.present) {
      map['template_id'] = Variable<String>(templateId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DimensionsCompanion(')
          ..write('id: $id, ')
          ..write('posId: $posId, ')
          ..write('name: $name, ')
          ..write('ordering: $ordering, ')
          ..write('levelsJson: $levelsJson, ')
          ..write('templateId: $templateId')
          ..write(')'))
        .toString();
  }
}

class $ParadigmCellOverridesTable extends ParadigmCellOverrides
    with TableInfo<$ParadigmCellOverridesTable, ParadigmCellOverride> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ParadigmCellOverridesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _lexemeIdMeta = const VerificationMeta(
    'lexemeId',
  );
  @override
  late final GeneratedColumn<int> lexemeId = GeneratedColumn<int>(
    'lexeme_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES lexemes (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _featureSetJsonMeta = const VerificationMeta(
    'featureSetJson',
  );
  @override
  late final GeneratedColumn<String> featureSetJson = GeneratedColumn<String>(
    'feature_set_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _overrideIpaMeta = const VerificationMeta(
    'overrideIpa',
  );
  @override
  late final GeneratedColumn<String> overrideIpa = GeneratedColumn<String>(
    'override_ipa',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _overrideRomanizationMeta =
      const VerificationMeta('overrideRomanization');
  @override
  late final GeneratedColumn<String> overrideRomanization =
      GeneratedColumn<String>(
        'override_romanization',
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    lexemeId,
    featureSetJson,
    overrideIpa,
    overrideRomanization,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'paradigm_cell_overrides';
  @override
  VerificationContext validateIntegrity(
    Insertable<ParadigmCellOverride> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('lexeme_id')) {
      context.handle(
        _lexemeIdMeta,
        lexemeId.isAcceptableOrUnknown(data['lexeme_id']!, _lexemeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_lexemeIdMeta);
    }
    if (data.containsKey('feature_set_json')) {
      context.handle(
        _featureSetJsonMeta,
        featureSetJson.isAcceptableOrUnknown(
          data['feature_set_json']!,
          _featureSetJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_featureSetJsonMeta);
    }
    if (data.containsKey('override_ipa')) {
      context.handle(
        _overrideIpaMeta,
        overrideIpa.isAcceptableOrUnknown(
          data['override_ipa']!,
          _overrideIpaMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_overrideIpaMeta);
    }
    if (data.containsKey('override_romanization')) {
      context.handle(
        _overrideRomanizationMeta,
        overrideRomanization.isAcceptableOrUnknown(
          data['override_romanization']!,
          _overrideRomanizationMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ParadigmCellOverride map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ParadigmCellOverride(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      lexemeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lexeme_id'],
      )!,
      featureSetJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}feature_set_json'],
      )!,
      overrideIpa: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}override_ipa'],
      )!,
      overrideRomanization: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}override_romanization'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $ParadigmCellOverridesTable createAlias(String alias) {
    return $ParadigmCellOverridesTable(attachedDatabase, alias);
  }
}

class ParadigmCellOverride extends DataClass
    implements Insertable<ParadigmCellOverride> {
  final int id;
  final int lexemeId;
  final String featureSetJson;
  final String overrideIpa;
  final String? overrideRomanization;
  final String? notes;
  const ParadigmCellOverride({
    required this.id,
    required this.lexemeId,
    required this.featureSetJson,
    required this.overrideIpa,
    this.overrideRomanization,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['lexeme_id'] = Variable<int>(lexemeId);
    map['feature_set_json'] = Variable<String>(featureSetJson);
    map['override_ipa'] = Variable<String>(overrideIpa);
    if (!nullToAbsent || overrideRomanization != null) {
      map['override_romanization'] = Variable<String>(overrideRomanization);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  ParadigmCellOverridesCompanion toCompanion(bool nullToAbsent) {
    return ParadigmCellOverridesCompanion(
      id: Value(id),
      lexemeId: Value(lexemeId),
      featureSetJson: Value(featureSetJson),
      overrideIpa: Value(overrideIpa),
      overrideRomanization: overrideRomanization == null && nullToAbsent
          ? const Value.absent()
          : Value(overrideRomanization),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory ParadigmCellOverride.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ParadigmCellOverride(
      id: serializer.fromJson<int>(json['id']),
      lexemeId: serializer.fromJson<int>(json['lexemeId']),
      featureSetJson: serializer.fromJson<String>(json['featureSetJson']),
      overrideIpa: serializer.fromJson<String>(json['overrideIpa']),
      overrideRomanization: serializer.fromJson<String?>(
        json['overrideRomanization'],
      ),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'lexemeId': serializer.toJson<int>(lexemeId),
      'featureSetJson': serializer.toJson<String>(featureSetJson),
      'overrideIpa': serializer.toJson<String>(overrideIpa),
      'overrideRomanization': serializer.toJson<String?>(overrideRomanization),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  ParadigmCellOverride copyWith({
    int? id,
    int? lexemeId,
    String? featureSetJson,
    String? overrideIpa,
    Value<String?> overrideRomanization = const Value.absent(),
    Value<String?> notes = const Value.absent(),
  }) => ParadigmCellOverride(
    id: id ?? this.id,
    lexemeId: lexemeId ?? this.lexemeId,
    featureSetJson: featureSetJson ?? this.featureSetJson,
    overrideIpa: overrideIpa ?? this.overrideIpa,
    overrideRomanization: overrideRomanization.present
        ? overrideRomanization.value
        : this.overrideRomanization,
    notes: notes.present ? notes.value : this.notes,
  );
  ParadigmCellOverride copyWithCompanion(ParadigmCellOverridesCompanion data) {
    return ParadigmCellOverride(
      id: data.id.present ? data.id.value : this.id,
      lexemeId: data.lexemeId.present ? data.lexemeId.value : this.lexemeId,
      featureSetJson: data.featureSetJson.present
          ? data.featureSetJson.value
          : this.featureSetJson,
      overrideIpa: data.overrideIpa.present
          ? data.overrideIpa.value
          : this.overrideIpa,
      overrideRomanization: data.overrideRomanization.present
          ? data.overrideRomanization.value
          : this.overrideRomanization,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ParadigmCellOverride(')
          ..write('id: $id, ')
          ..write('lexemeId: $lexemeId, ')
          ..write('featureSetJson: $featureSetJson, ')
          ..write('overrideIpa: $overrideIpa, ')
          ..write('overrideRomanization: $overrideRomanization, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    lexemeId,
    featureSetJson,
    overrideIpa,
    overrideRomanization,
    notes,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ParadigmCellOverride &&
          other.id == this.id &&
          other.lexemeId == this.lexemeId &&
          other.featureSetJson == this.featureSetJson &&
          other.overrideIpa == this.overrideIpa &&
          other.overrideRomanization == this.overrideRomanization &&
          other.notes == this.notes);
}

class ParadigmCellOverridesCompanion
    extends UpdateCompanion<ParadigmCellOverride> {
  final Value<int> id;
  final Value<int> lexemeId;
  final Value<String> featureSetJson;
  final Value<String> overrideIpa;
  final Value<String?> overrideRomanization;
  final Value<String?> notes;
  const ParadigmCellOverridesCompanion({
    this.id = const Value.absent(),
    this.lexemeId = const Value.absent(),
    this.featureSetJson = const Value.absent(),
    this.overrideIpa = const Value.absent(),
    this.overrideRomanization = const Value.absent(),
    this.notes = const Value.absent(),
  });
  ParadigmCellOverridesCompanion.insert({
    this.id = const Value.absent(),
    required int lexemeId,
    required String featureSetJson,
    required String overrideIpa,
    this.overrideRomanization = const Value.absent(),
    this.notes = const Value.absent(),
  }) : lexemeId = Value(lexemeId),
       featureSetJson = Value(featureSetJson),
       overrideIpa = Value(overrideIpa);
  static Insertable<ParadigmCellOverride> custom({
    Expression<int>? id,
    Expression<int>? lexemeId,
    Expression<String>? featureSetJson,
    Expression<String>? overrideIpa,
    Expression<String>? overrideRomanization,
    Expression<String>? notes,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (lexemeId != null) 'lexeme_id': lexemeId,
      if (featureSetJson != null) 'feature_set_json': featureSetJson,
      if (overrideIpa != null) 'override_ipa': overrideIpa,
      if (overrideRomanization != null)
        'override_romanization': overrideRomanization,
      if (notes != null) 'notes': notes,
    });
  }

  ParadigmCellOverridesCompanion copyWith({
    Value<int>? id,
    Value<int>? lexemeId,
    Value<String>? featureSetJson,
    Value<String>? overrideIpa,
    Value<String?>? overrideRomanization,
    Value<String?>? notes,
  }) {
    return ParadigmCellOverridesCompanion(
      id: id ?? this.id,
      lexemeId: lexemeId ?? this.lexemeId,
      featureSetJson: featureSetJson ?? this.featureSetJson,
      overrideIpa: overrideIpa ?? this.overrideIpa,
      overrideRomanization: overrideRomanization ?? this.overrideRomanization,
      notes: notes ?? this.notes,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (lexemeId.present) {
      map['lexeme_id'] = Variable<int>(lexemeId.value);
    }
    if (featureSetJson.present) {
      map['feature_set_json'] = Variable<String>(featureSetJson.value);
    }
    if (overrideIpa.present) {
      map['override_ipa'] = Variable<String>(overrideIpa.value);
    }
    if (overrideRomanization.present) {
      map['override_romanization'] = Variable<String>(
        overrideRomanization.value,
      );
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ParadigmCellOverridesCompanion(')
          ..write('id: $id, ')
          ..write('lexemeId: $lexemeId, ')
          ..write('featureSetJson: $featureSetJson, ')
          ..write('overrideIpa: $overrideIpa, ')
          ..write('overrideRomanization: $overrideRomanization, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PhonemesTable phonemes = $PhonemesTable(this);
  late final $NaturalClassesTable naturalClasses = $NaturalClassesTable(this);
  late final $PhonotacticTemplatesTable phonotacticTemplates =
      $PhonotacticTemplatesTable(this);
  late final $PhonotacticConstraintsTable phonotacticConstraints =
      $PhonotacticConstraintsTable(this);
  late final $RomanizationMappingsTable romanizationMappings =
      $RomanizationMappingsTable(this);
  late final $LexemesTable lexemes = $LexemesTable(this);
  late final $RewriteRulesTable rewriteRules = $RewriteRulesTable(this);
  late final $ProjectSettingsTable projectSettings = $ProjectSettingsTable(
    this,
  );
  late final $PartsOfSpeechTable partsOfSpeech = $PartsOfSpeechTable(this);
  late final $MorphologicalRulesTable morphologicalRules =
      $MorphologicalRulesTable(this);
  late final $MorphologicalRuleExceptionsTable morphologicalRuleExceptions =
      $MorphologicalRuleExceptionsTable(this);
  late final $DimensionsTable dimensions = $DimensionsTable(this);
  late final $ParadigmCellOverridesTable paradigmCellOverrides =
      $ParadigmCellOverridesTable(this);
  late final PhonemeDao phonemeDao = PhonemeDao(this as AppDatabase);
  late final NaturalClassDao naturalClassDao = NaturalClassDao(
    this as AppDatabase,
  );
  late final RomanizationDao romanizationDao = RomanizationDao(
    this as AppDatabase,
  );
  late final PhonotacticDao phonotacticDao = PhonotacticDao(
    this as AppDatabase,
  );
  late final RewriteRuleDao rewriteRuleDao = RewriteRuleDao(
    this as AppDatabase,
  );
  late final MorphologyDao morphologyDao = MorphologyDao(this as AppDatabase);
  late final LexemeDao lexemeDao = LexemeDao(this as AppDatabase);
  late final GrammarDao grammarDao = GrammarDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    phonemes,
    naturalClasses,
    phonotacticTemplates,
    phonotacticConstraints,
    romanizationMappings,
    lexemes,
    rewriteRules,
    projectSettings,
    partsOfSpeech,
    morphologicalRules,
    morphologicalRuleExceptions,
    dimensions,
    paradigmCellOverrides,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'parts_of_speech',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('dimensions', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'lexemes',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('paradigm_cell_overrides', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$PhonemesTableCreateCompanionBuilder =
    PhonemesCompanion Function({
      Value<int> id,
      required String symbol,
      required String type,
      Value<String?> manner,
      Value<String?> place,
      Value<String?> voicing,
      Value<String?> height,
      Value<String?> backness,
      Value<bool?> rounded,
      Value<String?> customProperties,
    });
typedef $$PhonemesTableUpdateCompanionBuilder =
    PhonemesCompanion Function({
      Value<int> id,
      Value<String> symbol,
      Value<String> type,
      Value<String?> manner,
      Value<String?> place,
      Value<String?> voicing,
      Value<String?> height,
      Value<String?> backness,
      Value<bool?> rounded,
      Value<String?> customProperties,
    });

class $$PhonemesTableFilterComposer
    extends Composer<_$AppDatabase, $PhonemesTable> {
  $$PhonemesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get symbol => $composableBuilder(
    column: $table.symbol,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get manner => $composableBuilder(
    column: $table.manner,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get place => $composableBuilder(
    column: $table.place,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get voicing => $composableBuilder(
    column: $table.voicing,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get backness => $composableBuilder(
    column: $table.backness,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get rounded => $composableBuilder(
    column: $table.rounded,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customProperties => $composableBuilder(
    column: $table.customProperties,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PhonemesTableOrderingComposer
    extends Composer<_$AppDatabase, $PhonemesTable> {
  $$PhonemesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get symbol => $composableBuilder(
    column: $table.symbol,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get manner => $composableBuilder(
    column: $table.manner,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get place => $composableBuilder(
    column: $table.place,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get voicing => $composableBuilder(
    column: $table.voicing,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get backness => $composableBuilder(
    column: $table.backness,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get rounded => $composableBuilder(
    column: $table.rounded,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customProperties => $composableBuilder(
    column: $table.customProperties,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PhonemesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PhonemesTable> {
  $$PhonemesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get symbol =>
      $composableBuilder(column: $table.symbol, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get manner =>
      $composableBuilder(column: $table.manner, builder: (column) => column);

  GeneratedColumn<String> get place =>
      $composableBuilder(column: $table.place, builder: (column) => column);

  GeneratedColumn<String> get voicing =>
      $composableBuilder(column: $table.voicing, builder: (column) => column);

  GeneratedColumn<String> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<String> get backness =>
      $composableBuilder(column: $table.backness, builder: (column) => column);

  GeneratedColumn<bool> get rounded =>
      $composableBuilder(column: $table.rounded, builder: (column) => column);

  GeneratedColumn<String> get customProperties => $composableBuilder(
    column: $table.customProperties,
    builder: (column) => column,
  );
}

class $$PhonemesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PhonemesTable,
          Phoneme,
          $$PhonemesTableFilterComposer,
          $$PhonemesTableOrderingComposer,
          $$PhonemesTableAnnotationComposer,
          $$PhonemesTableCreateCompanionBuilder,
          $$PhonemesTableUpdateCompanionBuilder,
          (Phoneme, BaseReferences<_$AppDatabase, $PhonemesTable, Phoneme>),
          Phoneme,
          PrefetchHooks Function()
        > {
  $$PhonemesTableTableManager(_$AppDatabase db, $PhonemesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PhonemesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PhonemesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PhonemesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> symbol = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> manner = const Value.absent(),
                Value<String?> place = const Value.absent(),
                Value<String?> voicing = const Value.absent(),
                Value<String?> height = const Value.absent(),
                Value<String?> backness = const Value.absent(),
                Value<bool?> rounded = const Value.absent(),
                Value<String?> customProperties = const Value.absent(),
              }) => PhonemesCompanion(
                id: id,
                symbol: symbol,
                type: type,
                manner: manner,
                place: place,
                voicing: voicing,
                height: height,
                backness: backness,
                rounded: rounded,
                customProperties: customProperties,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String symbol,
                required String type,
                Value<String?> manner = const Value.absent(),
                Value<String?> place = const Value.absent(),
                Value<String?> voicing = const Value.absent(),
                Value<String?> height = const Value.absent(),
                Value<String?> backness = const Value.absent(),
                Value<bool?> rounded = const Value.absent(),
                Value<String?> customProperties = const Value.absent(),
              }) => PhonemesCompanion.insert(
                id: id,
                symbol: symbol,
                type: type,
                manner: manner,
                place: place,
                voicing: voicing,
                height: height,
                backness: backness,
                rounded: rounded,
                customProperties: customProperties,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PhonemesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PhonemesTable,
      Phoneme,
      $$PhonemesTableFilterComposer,
      $$PhonemesTableOrderingComposer,
      $$PhonemesTableAnnotationComposer,
      $$PhonemesTableCreateCompanionBuilder,
      $$PhonemesTableUpdateCompanionBuilder,
      (Phoneme, BaseReferences<_$AppDatabase, $PhonemesTable, Phoneme>),
      Phoneme,
      PrefetchHooks Function()
    >;
typedef $$NaturalClassesTableCreateCompanionBuilder =
    NaturalClassesCompanion Function({
      Value<int> id,
      required String name,
      required String phonemeIds,
    });
typedef $$NaturalClassesTableUpdateCompanionBuilder =
    NaturalClassesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> phonemeIds,
    });

class $$NaturalClassesTableFilterComposer
    extends Composer<_$AppDatabase, $NaturalClassesTable> {
  $$NaturalClassesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phonemeIds => $composableBuilder(
    column: $table.phonemeIds,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NaturalClassesTableOrderingComposer
    extends Composer<_$AppDatabase, $NaturalClassesTable> {
  $$NaturalClassesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phonemeIds => $composableBuilder(
    column: $table.phonemeIds,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NaturalClassesTableAnnotationComposer
    extends Composer<_$AppDatabase, $NaturalClassesTable> {
  $$NaturalClassesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get phonemeIds => $composableBuilder(
    column: $table.phonemeIds,
    builder: (column) => column,
  );
}

class $$NaturalClassesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NaturalClassesTable,
          NaturalClassesData,
          $$NaturalClassesTableFilterComposer,
          $$NaturalClassesTableOrderingComposer,
          $$NaturalClassesTableAnnotationComposer,
          $$NaturalClassesTableCreateCompanionBuilder,
          $$NaturalClassesTableUpdateCompanionBuilder,
          (
            NaturalClassesData,
            BaseReferences<
              _$AppDatabase,
              $NaturalClassesTable,
              NaturalClassesData
            >,
          ),
          NaturalClassesData,
          PrefetchHooks Function()
        > {
  $$NaturalClassesTableTableManager(
    _$AppDatabase db,
    $NaturalClassesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NaturalClassesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NaturalClassesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NaturalClassesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> phonemeIds = const Value.absent(),
              }) => NaturalClassesCompanion(
                id: id,
                name: name,
                phonemeIds: phonemeIds,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String phonemeIds,
              }) => NaturalClassesCompanion.insert(
                id: id,
                name: name,
                phonemeIds: phonemeIds,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NaturalClassesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NaturalClassesTable,
      NaturalClassesData,
      $$NaturalClassesTableFilterComposer,
      $$NaturalClassesTableOrderingComposer,
      $$NaturalClassesTableAnnotationComposer,
      $$NaturalClassesTableCreateCompanionBuilder,
      $$NaturalClassesTableUpdateCompanionBuilder,
      (
        NaturalClassesData,
        BaseReferences<_$AppDatabase, $NaturalClassesTable, NaturalClassesData>,
      ),
      NaturalClassesData,
      PrefetchHooks Function()
    >;
typedef $$PhonotacticTemplatesTableCreateCompanionBuilder =
    PhonotacticTemplatesCompanion Function({
      Value<int> id,
      required String pattern,
      Value<String?> description,
      Value<bool> isActive,
    });
typedef $$PhonotacticTemplatesTableUpdateCompanionBuilder =
    PhonotacticTemplatesCompanion Function({
      Value<int> id,
      Value<String> pattern,
      Value<String?> description,
      Value<bool> isActive,
    });

class $$PhonotacticTemplatesTableFilterComposer
    extends Composer<_$AppDatabase, $PhonotacticTemplatesTable> {
  $$PhonotacticTemplatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pattern => $composableBuilder(
    column: $table.pattern,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PhonotacticTemplatesTableOrderingComposer
    extends Composer<_$AppDatabase, $PhonotacticTemplatesTable> {
  $$PhonotacticTemplatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pattern => $composableBuilder(
    column: $table.pattern,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PhonotacticTemplatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PhonotacticTemplatesTable> {
  $$PhonotacticTemplatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get pattern =>
      $composableBuilder(column: $table.pattern, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);
}

class $$PhonotacticTemplatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PhonotacticTemplatesTable,
          PhonotacticTemplate,
          $$PhonotacticTemplatesTableFilterComposer,
          $$PhonotacticTemplatesTableOrderingComposer,
          $$PhonotacticTemplatesTableAnnotationComposer,
          $$PhonotacticTemplatesTableCreateCompanionBuilder,
          $$PhonotacticTemplatesTableUpdateCompanionBuilder,
          (
            PhonotacticTemplate,
            BaseReferences<
              _$AppDatabase,
              $PhonotacticTemplatesTable,
              PhonotacticTemplate
            >,
          ),
          PhonotacticTemplate,
          PrefetchHooks Function()
        > {
  $$PhonotacticTemplatesTableTableManager(
    _$AppDatabase db,
    $PhonotacticTemplatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PhonotacticTemplatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PhonotacticTemplatesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PhonotacticTemplatesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> pattern = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
              }) => PhonotacticTemplatesCompanion(
                id: id,
                pattern: pattern,
                description: description,
                isActive: isActive,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String pattern,
                Value<String?> description = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
              }) => PhonotacticTemplatesCompanion.insert(
                id: id,
                pattern: pattern,
                description: description,
                isActive: isActive,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PhonotacticTemplatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PhonotacticTemplatesTable,
      PhonotacticTemplate,
      $$PhonotacticTemplatesTableFilterComposer,
      $$PhonotacticTemplatesTableOrderingComposer,
      $$PhonotacticTemplatesTableAnnotationComposer,
      $$PhonotacticTemplatesTableCreateCompanionBuilder,
      $$PhonotacticTemplatesTableUpdateCompanionBuilder,
      (
        PhonotacticTemplate,
        BaseReferences<
          _$AppDatabase,
          $PhonotacticTemplatesTable,
          PhonotacticTemplate
        >,
      ),
      PhonotacticTemplate,
      PrefetchHooks Function()
    >;
typedef $$PhonotacticConstraintsTableCreateCompanionBuilder =
    PhonotacticConstraintsCompanion Function({
      Value<int> id,
      required String pattern,
      Value<String?> description,
      Value<bool> isActive,
      Value<String> position,
    });
typedef $$PhonotacticConstraintsTableUpdateCompanionBuilder =
    PhonotacticConstraintsCompanion Function({
      Value<int> id,
      Value<String> pattern,
      Value<String?> description,
      Value<bool> isActive,
      Value<String> position,
    });

class $$PhonotacticConstraintsTableFilterComposer
    extends Composer<_$AppDatabase, $PhonotacticConstraintsTable> {
  $$PhonotacticConstraintsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pattern => $composableBuilder(
    column: $table.pattern,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PhonotacticConstraintsTableOrderingComposer
    extends Composer<_$AppDatabase, $PhonotacticConstraintsTable> {
  $$PhonotacticConstraintsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pattern => $composableBuilder(
    column: $table.pattern,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PhonotacticConstraintsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PhonotacticConstraintsTable> {
  $$PhonotacticConstraintsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get pattern =>
      $composableBuilder(column: $table.pattern, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<String> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);
}

class $$PhonotacticConstraintsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PhonotacticConstraintsTable,
          PhonotacticConstraint,
          $$PhonotacticConstraintsTableFilterComposer,
          $$PhonotacticConstraintsTableOrderingComposer,
          $$PhonotacticConstraintsTableAnnotationComposer,
          $$PhonotacticConstraintsTableCreateCompanionBuilder,
          $$PhonotacticConstraintsTableUpdateCompanionBuilder,
          (
            PhonotacticConstraint,
            BaseReferences<
              _$AppDatabase,
              $PhonotacticConstraintsTable,
              PhonotacticConstraint
            >,
          ),
          PhonotacticConstraint,
          PrefetchHooks Function()
        > {
  $$PhonotacticConstraintsTableTableManager(
    _$AppDatabase db,
    $PhonotacticConstraintsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PhonotacticConstraintsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$PhonotacticConstraintsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PhonotacticConstraintsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> pattern = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<String> position = const Value.absent(),
              }) => PhonotacticConstraintsCompanion(
                id: id,
                pattern: pattern,
                description: description,
                isActive: isActive,
                position: position,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String pattern,
                Value<String?> description = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<String> position = const Value.absent(),
              }) => PhonotacticConstraintsCompanion.insert(
                id: id,
                pattern: pattern,
                description: description,
                isActive: isActive,
                position: position,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PhonotacticConstraintsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PhonotacticConstraintsTable,
      PhonotacticConstraint,
      $$PhonotacticConstraintsTableFilterComposer,
      $$PhonotacticConstraintsTableOrderingComposer,
      $$PhonotacticConstraintsTableAnnotationComposer,
      $$PhonotacticConstraintsTableCreateCompanionBuilder,
      $$PhonotacticConstraintsTableUpdateCompanionBuilder,
      (
        PhonotacticConstraint,
        BaseReferences<
          _$AppDatabase,
          $PhonotacticConstraintsTable,
          PhonotacticConstraint
        >,
      ),
      PhonotacticConstraint,
      PrefetchHooks Function()
    >;
typedef $$RomanizationMappingsTableCreateCompanionBuilder =
    RomanizationMappingsCompanion Function({
      Value<int> id,
      required String ipaSymbol,
      required String latinMapping,
    });
typedef $$RomanizationMappingsTableUpdateCompanionBuilder =
    RomanizationMappingsCompanion Function({
      Value<int> id,
      Value<String> ipaSymbol,
      Value<String> latinMapping,
    });

class $$RomanizationMappingsTableFilterComposer
    extends Composer<_$AppDatabase, $RomanizationMappingsTable> {
  $$RomanizationMappingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ipaSymbol => $composableBuilder(
    column: $table.ipaSymbol,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get latinMapping => $composableBuilder(
    column: $table.latinMapping,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RomanizationMappingsTableOrderingComposer
    extends Composer<_$AppDatabase, $RomanizationMappingsTable> {
  $$RomanizationMappingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ipaSymbol => $composableBuilder(
    column: $table.ipaSymbol,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get latinMapping => $composableBuilder(
    column: $table.latinMapping,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RomanizationMappingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RomanizationMappingsTable> {
  $$RomanizationMappingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ipaSymbol =>
      $composableBuilder(column: $table.ipaSymbol, builder: (column) => column);

  GeneratedColumn<String> get latinMapping => $composableBuilder(
    column: $table.latinMapping,
    builder: (column) => column,
  );
}

class $$RomanizationMappingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RomanizationMappingsTable,
          RomanizationMapping,
          $$RomanizationMappingsTableFilterComposer,
          $$RomanizationMappingsTableOrderingComposer,
          $$RomanizationMappingsTableAnnotationComposer,
          $$RomanizationMappingsTableCreateCompanionBuilder,
          $$RomanizationMappingsTableUpdateCompanionBuilder,
          (
            RomanizationMapping,
            BaseReferences<
              _$AppDatabase,
              $RomanizationMappingsTable,
              RomanizationMapping
            >,
          ),
          RomanizationMapping,
          PrefetchHooks Function()
        > {
  $$RomanizationMappingsTableTableManager(
    _$AppDatabase db,
    $RomanizationMappingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RomanizationMappingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RomanizationMappingsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$RomanizationMappingsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> ipaSymbol = const Value.absent(),
                Value<String> latinMapping = const Value.absent(),
              }) => RomanizationMappingsCompanion(
                id: id,
                ipaSymbol: ipaSymbol,
                latinMapping: latinMapping,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String ipaSymbol,
                required String latinMapping,
              }) => RomanizationMappingsCompanion.insert(
                id: id,
                ipaSymbol: ipaSymbol,
                latinMapping: latinMapping,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RomanizationMappingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RomanizationMappingsTable,
      RomanizationMapping,
      $$RomanizationMappingsTableFilterComposer,
      $$RomanizationMappingsTableOrderingComposer,
      $$RomanizationMappingsTableAnnotationComposer,
      $$RomanizationMappingsTableCreateCompanionBuilder,
      $$RomanizationMappingsTableUpdateCompanionBuilder,
      (
        RomanizationMapping,
        BaseReferences<
          _$AppDatabase,
          $RomanizationMappingsTable,
          RomanizationMapping
        >,
      ),
      RomanizationMapping,
      PrefetchHooks Function()
    >;
typedef $$LexemesTableCreateCompanionBuilder =
    LexemesCompanion Function({
      Value<int> id,
      required String ipa,
      Value<String?> rootId,
      Value<String?> ruleIds,
      Value<String?> computedForm,
      Value<String?> romanization,
      Value<String?> meaning,
      Value<String?> partOfSpeech,
      Value<bool> isPhonologicalException,
      Value<String?> skippedDimensionsJson,
    });
typedef $$LexemesTableUpdateCompanionBuilder =
    LexemesCompanion Function({
      Value<int> id,
      Value<String> ipa,
      Value<String?> rootId,
      Value<String?> ruleIds,
      Value<String?> computedForm,
      Value<String?> romanization,
      Value<String?> meaning,
      Value<String?> partOfSpeech,
      Value<bool> isPhonologicalException,
      Value<String?> skippedDimensionsJson,
    });

final class $$LexemesTableReferences
    extends BaseReferences<_$AppDatabase, $LexemesTable, Lexeme> {
  $$LexemesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<
    $ParadigmCellOverridesTable,
    List<ParadigmCellOverride>
  >
  _paradigmCellOverridesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.paradigmCellOverrides,
        aliasName: $_aliasNameGenerator(
          db.lexemes.id,
          db.paradigmCellOverrides.lexemeId,
        ),
      );

  $$ParadigmCellOverridesTableProcessedTableManager
  get paradigmCellOverridesRefs {
    final manager = $$ParadigmCellOverridesTableTableManager(
      $_db,
      $_db.paradigmCellOverrides,
    ).filter((f) => f.lexemeId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _paradigmCellOverridesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LexemesTableFilterComposer
    extends Composer<_$AppDatabase, $LexemesTable> {
  $$LexemesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ipa => $composableBuilder(
    column: $table.ipa,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rootId => $composableBuilder(
    column: $table.rootId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ruleIds => $composableBuilder(
    column: $table.ruleIds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get computedForm => $composableBuilder(
    column: $table.computedForm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get romanization => $composableBuilder(
    column: $table.romanization,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get meaning => $composableBuilder(
    column: $table.meaning,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get partOfSpeech => $composableBuilder(
    column: $table.partOfSpeech,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPhonologicalException => $composableBuilder(
    column: $table.isPhonologicalException,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get skippedDimensionsJson => $composableBuilder(
    column: $table.skippedDimensionsJson,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> paradigmCellOverridesRefs(
    Expression<bool> Function($$ParadigmCellOverridesTableFilterComposer f) f,
  ) {
    final $$ParadigmCellOverridesTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.paradigmCellOverrides,
          getReferencedColumn: (t) => t.lexemeId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ParadigmCellOverridesTableFilterComposer(
                $db: $db,
                $table: $db.paradigmCellOverrides,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$LexemesTableOrderingComposer
    extends Composer<_$AppDatabase, $LexemesTable> {
  $$LexemesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ipa => $composableBuilder(
    column: $table.ipa,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rootId => $composableBuilder(
    column: $table.rootId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ruleIds => $composableBuilder(
    column: $table.ruleIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get computedForm => $composableBuilder(
    column: $table.computedForm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get romanization => $composableBuilder(
    column: $table.romanization,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get meaning => $composableBuilder(
    column: $table.meaning,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get partOfSpeech => $composableBuilder(
    column: $table.partOfSpeech,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPhonologicalException => $composableBuilder(
    column: $table.isPhonologicalException,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get skippedDimensionsJson => $composableBuilder(
    column: $table.skippedDimensionsJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LexemesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LexemesTable> {
  $$LexemesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ipa =>
      $composableBuilder(column: $table.ipa, builder: (column) => column);

  GeneratedColumn<String> get rootId =>
      $composableBuilder(column: $table.rootId, builder: (column) => column);

  GeneratedColumn<String> get ruleIds =>
      $composableBuilder(column: $table.ruleIds, builder: (column) => column);

  GeneratedColumn<String> get computedForm => $composableBuilder(
    column: $table.computedForm,
    builder: (column) => column,
  );

  GeneratedColumn<String> get romanization => $composableBuilder(
    column: $table.romanization,
    builder: (column) => column,
  );

  GeneratedColumn<String> get meaning =>
      $composableBuilder(column: $table.meaning, builder: (column) => column);

  GeneratedColumn<String> get partOfSpeech => $composableBuilder(
    column: $table.partOfSpeech,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isPhonologicalException => $composableBuilder(
    column: $table.isPhonologicalException,
    builder: (column) => column,
  );

  GeneratedColumn<String> get skippedDimensionsJson => $composableBuilder(
    column: $table.skippedDimensionsJson,
    builder: (column) => column,
  );

  Expression<T> paradigmCellOverridesRefs<T extends Object>(
    Expression<T> Function($$ParadigmCellOverridesTableAnnotationComposer a) f,
  ) {
    final $$ParadigmCellOverridesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.paradigmCellOverrides,
          getReferencedColumn: (t) => t.lexemeId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ParadigmCellOverridesTableAnnotationComposer(
                $db: $db,
                $table: $db.paradigmCellOverrides,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$LexemesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LexemesTable,
          Lexeme,
          $$LexemesTableFilterComposer,
          $$LexemesTableOrderingComposer,
          $$LexemesTableAnnotationComposer,
          $$LexemesTableCreateCompanionBuilder,
          $$LexemesTableUpdateCompanionBuilder,
          (Lexeme, $$LexemesTableReferences),
          Lexeme,
          PrefetchHooks Function({bool paradigmCellOverridesRefs})
        > {
  $$LexemesTableTableManager(_$AppDatabase db, $LexemesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LexemesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LexemesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LexemesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> ipa = const Value.absent(),
                Value<String?> rootId = const Value.absent(),
                Value<String?> ruleIds = const Value.absent(),
                Value<String?> computedForm = const Value.absent(),
                Value<String?> romanization = const Value.absent(),
                Value<String?> meaning = const Value.absent(),
                Value<String?> partOfSpeech = const Value.absent(),
                Value<bool> isPhonologicalException = const Value.absent(),
                Value<String?> skippedDimensionsJson = const Value.absent(),
              }) => LexemesCompanion(
                id: id,
                ipa: ipa,
                rootId: rootId,
                ruleIds: ruleIds,
                computedForm: computedForm,
                romanization: romanization,
                meaning: meaning,
                partOfSpeech: partOfSpeech,
                isPhonologicalException: isPhonologicalException,
                skippedDimensionsJson: skippedDimensionsJson,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String ipa,
                Value<String?> rootId = const Value.absent(),
                Value<String?> ruleIds = const Value.absent(),
                Value<String?> computedForm = const Value.absent(),
                Value<String?> romanization = const Value.absent(),
                Value<String?> meaning = const Value.absent(),
                Value<String?> partOfSpeech = const Value.absent(),
                Value<bool> isPhonologicalException = const Value.absent(),
                Value<String?> skippedDimensionsJson = const Value.absent(),
              }) => LexemesCompanion.insert(
                id: id,
                ipa: ipa,
                rootId: rootId,
                ruleIds: ruleIds,
                computedForm: computedForm,
                romanization: romanization,
                meaning: meaning,
                partOfSpeech: partOfSpeech,
                isPhonologicalException: isPhonologicalException,
                skippedDimensionsJson: skippedDimensionsJson,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LexemesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({paradigmCellOverridesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (paradigmCellOverridesRefs) db.paradigmCellOverrides,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (paradigmCellOverridesRefs)
                    await $_getPrefetchedData<
                      Lexeme,
                      $LexemesTable,
                      ParadigmCellOverride
                    >(
                      currentTable: table,
                      referencedTable: $$LexemesTableReferences
                          ._paradigmCellOverridesRefsTable(db),
                      managerFromTypedResult: (p0) => $$LexemesTableReferences(
                        db,
                        table,
                        p0,
                      ).paradigmCellOverridesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.lexemeId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$LexemesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LexemesTable,
      Lexeme,
      $$LexemesTableFilterComposer,
      $$LexemesTableOrderingComposer,
      $$LexemesTableAnnotationComposer,
      $$LexemesTableCreateCompanionBuilder,
      $$LexemesTableUpdateCompanionBuilder,
      (Lexeme, $$LexemesTableReferences),
      Lexeme,
      PrefetchHooks Function({bool paradigmCellOverridesRefs})
    >;
typedef $$RewriteRulesTableCreateCompanionBuilder =
    RewriteRulesCompanion Function({
      Value<int> id,
      required String source,
      Value<int> ordering,
    });
typedef $$RewriteRulesTableUpdateCompanionBuilder =
    RewriteRulesCompanion Function({
      Value<int> id,
      Value<String> source,
      Value<int> ordering,
    });

class $$RewriteRulesTableFilterComposer
    extends Composer<_$AppDatabase, $RewriteRulesTable> {
  $$RewriteRulesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ordering => $composableBuilder(
    column: $table.ordering,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RewriteRulesTableOrderingComposer
    extends Composer<_$AppDatabase, $RewriteRulesTable> {
  $$RewriteRulesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ordering => $composableBuilder(
    column: $table.ordering,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RewriteRulesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RewriteRulesTable> {
  $$RewriteRulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<int> get ordering =>
      $composableBuilder(column: $table.ordering, builder: (column) => column);
}

class $$RewriteRulesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RewriteRulesTable,
          RewriteRule,
          $$RewriteRulesTableFilterComposer,
          $$RewriteRulesTableOrderingComposer,
          $$RewriteRulesTableAnnotationComposer,
          $$RewriteRulesTableCreateCompanionBuilder,
          $$RewriteRulesTableUpdateCompanionBuilder,
          (
            RewriteRule,
            BaseReferences<_$AppDatabase, $RewriteRulesTable, RewriteRule>,
          ),
          RewriteRule,
          PrefetchHooks Function()
        > {
  $$RewriteRulesTableTableManager(_$AppDatabase db, $RewriteRulesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RewriteRulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RewriteRulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RewriteRulesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<int> ordering = const Value.absent(),
              }) => RewriteRulesCompanion(
                id: id,
                source: source,
                ordering: ordering,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String source,
                Value<int> ordering = const Value.absent(),
              }) => RewriteRulesCompanion.insert(
                id: id,
                source: source,
                ordering: ordering,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RewriteRulesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RewriteRulesTable,
      RewriteRule,
      $$RewriteRulesTableFilterComposer,
      $$RewriteRulesTableOrderingComposer,
      $$RewriteRulesTableAnnotationComposer,
      $$RewriteRulesTableCreateCompanionBuilder,
      $$RewriteRulesTableUpdateCompanionBuilder,
      (
        RewriteRule,
        BaseReferences<_$AppDatabase, $RewriteRulesTable, RewriteRule>,
      ),
      RewriteRule,
      PrefetchHooks Function()
    >;
typedef $$ProjectSettingsTableCreateCompanionBuilder =
    ProjectSettingsCompanion Function({
      Value<int> id,
      required String key,
      required String value,
    });
typedef $$ProjectSettingsTableUpdateCompanionBuilder =
    ProjectSettingsCompanion Function({
      Value<int> id,
      Value<String> key,
      Value<String> value,
    });

class $$ProjectSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $ProjectSettingsTable> {
  $$ProjectSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProjectSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProjectSettingsTable> {
  $$ProjectSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProjectSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProjectSettingsTable> {
  $$ProjectSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$ProjectSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProjectSettingsTable,
          ProjectSetting,
          $$ProjectSettingsTableFilterComposer,
          $$ProjectSettingsTableOrderingComposer,
          $$ProjectSettingsTableAnnotationComposer,
          $$ProjectSettingsTableCreateCompanionBuilder,
          $$ProjectSettingsTableUpdateCompanionBuilder,
          (
            ProjectSetting,
            BaseReferences<
              _$AppDatabase,
              $ProjectSettingsTable,
              ProjectSetting
            >,
          ),
          ProjectSetting,
          PrefetchHooks Function()
        > {
  $$ProjectSettingsTableTableManager(
    _$AppDatabase db,
    $ProjectSettingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProjectSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProjectSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProjectSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
              }) => ProjectSettingsCompanion(id: id, key: key, value: value),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String key,
                required String value,
              }) => ProjectSettingsCompanion.insert(
                id: id,
                key: key,
                value: value,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProjectSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProjectSettingsTable,
      ProjectSetting,
      $$ProjectSettingsTableFilterComposer,
      $$ProjectSettingsTableOrderingComposer,
      $$ProjectSettingsTableAnnotationComposer,
      $$ProjectSettingsTableCreateCompanionBuilder,
      $$ProjectSettingsTableUpdateCompanionBuilder,
      (
        ProjectSetting,
        BaseReferences<_$AppDatabase, $ProjectSettingsTable, ProjectSetting>,
      ),
      ProjectSetting,
      PrefetchHooks Function()
    >;
typedef $$PartsOfSpeechTableCreateCompanionBuilder =
    PartsOfSpeechCompanion Function({
      Value<int> id,
      required String name,
      required String abbreviation,
    });
typedef $$PartsOfSpeechTableUpdateCompanionBuilder =
    PartsOfSpeechCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> abbreviation,
    });

final class $$PartsOfSpeechTableReferences
    extends
        BaseReferences<_$AppDatabase, $PartsOfSpeechTable, PartsOfSpeechData> {
  $$PartsOfSpeechTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$DimensionsTable, List<Dimension>>
  _dimensionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.dimensions,
    aliasName: $_aliasNameGenerator(db.partsOfSpeech.id, db.dimensions.posId),
  );

  $$DimensionsTableProcessedTableManager get dimensionsRefs {
    final manager = $$DimensionsTableTableManager(
      $_db,
      $_db.dimensions,
    ).filter((f) => f.posId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_dimensionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PartsOfSpeechTableFilterComposer
    extends Composer<_$AppDatabase, $PartsOfSpeechTable> {
  $$PartsOfSpeechTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get abbreviation => $composableBuilder(
    column: $table.abbreviation,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> dimensionsRefs(
    Expression<bool> Function($$DimensionsTableFilterComposer f) f,
  ) {
    final $$DimensionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.dimensions,
      getReferencedColumn: (t) => t.posId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DimensionsTableFilterComposer(
            $db: $db,
            $table: $db.dimensions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PartsOfSpeechTableOrderingComposer
    extends Composer<_$AppDatabase, $PartsOfSpeechTable> {
  $$PartsOfSpeechTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get abbreviation => $composableBuilder(
    column: $table.abbreviation,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PartsOfSpeechTableAnnotationComposer
    extends Composer<_$AppDatabase, $PartsOfSpeechTable> {
  $$PartsOfSpeechTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get abbreviation => $composableBuilder(
    column: $table.abbreviation,
    builder: (column) => column,
  );

  Expression<T> dimensionsRefs<T extends Object>(
    Expression<T> Function($$DimensionsTableAnnotationComposer a) f,
  ) {
    final $$DimensionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.dimensions,
      getReferencedColumn: (t) => t.posId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DimensionsTableAnnotationComposer(
            $db: $db,
            $table: $db.dimensions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PartsOfSpeechTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PartsOfSpeechTable,
          PartsOfSpeechData,
          $$PartsOfSpeechTableFilterComposer,
          $$PartsOfSpeechTableOrderingComposer,
          $$PartsOfSpeechTableAnnotationComposer,
          $$PartsOfSpeechTableCreateCompanionBuilder,
          $$PartsOfSpeechTableUpdateCompanionBuilder,
          (PartsOfSpeechData, $$PartsOfSpeechTableReferences),
          PartsOfSpeechData,
          PrefetchHooks Function({bool dimensionsRefs})
        > {
  $$PartsOfSpeechTableTableManager(_$AppDatabase db, $PartsOfSpeechTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PartsOfSpeechTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PartsOfSpeechTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PartsOfSpeechTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> abbreviation = const Value.absent(),
              }) => PartsOfSpeechCompanion(
                id: id,
                name: name,
                abbreviation: abbreviation,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String abbreviation,
              }) => PartsOfSpeechCompanion.insert(
                id: id,
                name: name,
                abbreviation: abbreviation,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PartsOfSpeechTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({dimensionsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (dimensionsRefs) db.dimensions],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (dimensionsRefs)
                    await $_getPrefetchedData<
                      PartsOfSpeechData,
                      $PartsOfSpeechTable,
                      Dimension
                    >(
                      currentTable: table,
                      referencedTable: $$PartsOfSpeechTableReferences
                          ._dimensionsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$PartsOfSpeechTableReferences(
                            db,
                            table,
                            p0,
                          ).dimensionsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.posId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$PartsOfSpeechTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PartsOfSpeechTable,
      PartsOfSpeechData,
      $$PartsOfSpeechTableFilterComposer,
      $$PartsOfSpeechTableOrderingComposer,
      $$PartsOfSpeechTableAnnotationComposer,
      $$PartsOfSpeechTableCreateCompanionBuilder,
      $$PartsOfSpeechTableUpdateCompanionBuilder,
      (PartsOfSpeechData, $$PartsOfSpeechTableReferences),
      PartsOfSpeechData,
      PrefetchHooks Function({bool dimensionsRefs})
    >;
typedef $$MorphologicalRulesTableCreateCompanionBuilder =
    MorphologicalRulesCompanion Function({
      Value<int> id,
      required String name,
      required String source,
      Value<int> ordering,
      Value<bool> isActive,
      Value<int?> posId,
      Value<String> posIds,
      Value<String> kind,
      Value<FeatureBindings> featureBindings,
      Value<int?> inputPosId,
      Value<int?> outputPosId,
    });
typedef $$MorphologicalRulesTableUpdateCompanionBuilder =
    MorphologicalRulesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> source,
      Value<int> ordering,
      Value<bool> isActive,
      Value<int?> posId,
      Value<String> posIds,
      Value<String> kind,
      Value<FeatureBindings> featureBindings,
      Value<int?> inputPosId,
      Value<int?> outputPosId,
    });

final class $$MorphologicalRulesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $MorphologicalRulesTable,
          MorphologicalRule
        > {
  $$MorphologicalRulesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PartsOfSpeechTable _posIdTable(_$AppDatabase db) =>
      db.partsOfSpeech.createAlias(
        $_aliasNameGenerator(db.morphologicalRules.posId, db.partsOfSpeech.id),
      );

  $$PartsOfSpeechTableProcessedTableManager? get posId {
    final $_column = $_itemColumn<int>('pos_id');
    if ($_column == null) return null;
    final manager = $$PartsOfSpeechTableTableManager(
      $_db,
      $_db.partsOfSpeech,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_posIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $PartsOfSpeechTable _inputPosIdTable(_$AppDatabase db) =>
      db.partsOfSpeech.createAlias(
        $_aliasNameGenerator(
          db.morphologicalRules.inputPosId,
          db.partsOfSpeech.id,
        ),
      );

  $$PartsOfSpeechTableProcessedTableManager? get inputPosId {
    final $_column = $_itemColumn<int>('input_pos_id');
    if ($_column == null) return null;
    final manager = $$PartsOfSpeechTableTableManager(
      $_db,
      $_db.partsOfSpeech,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_inputPosIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $PartsOfSpeechTable _outputPosIdTable(_$AppDatabase db) =>
      db.partsOfSpeech.createAlias(
        $_aliasNameGenerator(
          db.morphologicalRules.outputPosId,
          db.partsOfSpeech.id,
        ),
      );

  $$PartsOfSpeechTableProcessedTableManager? get outputPosId {
    final $_column = $_itemColumn<int>('output_pos_id');
    if ($_column == null) return null;
    final manager = $$PartsOfSpeechTableTableManager(
      $_db,
      $_db.partsOfSpeech,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_outputPosIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MorphologicalRulesTableFilterComposer
    extends Composer<_$AppDatabase, $MorphologicalRulesTable> {
  $$MorphologicalRulesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ordering => $composableBuilder(
    column: $table.ordering,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get posIds => $composableBuilder(
    column: $table.posIds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<FeatureBindings, FeatureBindings, String>
  get featureBindings => $composableBuilder(
    column: $table.featureBindings,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  $$PartsOfSpeechTableFilterComposer get posId {
    final $$PartsOfSpeechTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.posId,
      referencedTable: $db.partsOfSpeech,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PartsOfSpeechTableFilterComposer(
            $db: $db,
            $table: $db.partsOfSpeech,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PartsOfSpeechTableFilterComposer get inputPosId {
    final $$PartsOfSpeechTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.inputPosId,
      referencedTable: $db.partsOfSpeech,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PartsOfSpeechTableFilterComposer(
            $db: $db,
            $table: $db.partsOfSpeech,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PartsOfSpeechTableFilterComposer get outputPosId {
    final $$PartsOfSpeechTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.outputPosId,
      referencedTable: $db.partsOfSpeech,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PartsOfSpeechTableFilterComposer(
            $db: $db,
            $table: $db.partsOfSpeech,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MorphologicalRulesTableOrderingComposer
    extends Composer<_$AppDatabase, $MorphologicalRulesTable> {
  $$MorphologicalRulesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ordering => $composableBuilder(
    column: $table.ordering,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get posIds => $composableBuilder(
    column: $table.posIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get featureBindings => $composableBuilder(
    column: $table.featureBindings,
    builder: (column) => ColumnOrderings(column),
  );

  $$PartsOfSpeechTableOrderingComposer get posId {
    final $$PartsOfSpeechTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.posId,
      referencedTable: $db.partsOfSpeech,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PartsOfSpeechTableOrderingComposer(
            $db: $db,
            $table: $db.partsOfSpeech,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PartsOfSpeechTableOrderingComposer get inputPosId {
    final $$PartsOfSpeechTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.inputPosId,
      referencedTable: $db.partsOfSpeech,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PartsOfSpeechTableOrderingComposer(
            $db: $db,
            $table: $db.partsOfSpeech,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PartsOfSpeechTableOrderingComposer get outputPosId {
    final $$PartsOfSpeechTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.outputPosId,
      referencedTable: $db.partsOfSpeech,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PartsOfSpeechTableOrderingComposer(
            $db: $db,
            $table: $db.partsOfSpeech,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MorphologicalRulesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MorphologicalRulesTable> {
  $$MorphologicalRulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<int> get ordering =>
      $composableBuilder(column: $table.ordering, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<String> get posIds =>
      $composableBuilder(column: $table.posIds, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumnWithTypeConverter<FeatureBindings, String>
  get featureBindings => $composableBuilder(
    column: $table.featureBindings,
    builder: (column) => column,
  );

  $$PartsOfSpeechTableAnnotationComposer get posId {
    final $$PartsOfSpeechTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.posId,
      referencedTable: $db.partsOfSpeech,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PartsOfSpeechTableAnnotationComposer(
            $db: $db,
            $table: $db.partsOfSpeech,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PartsOfSpeechTableAnnotationComposer get inputPosId {
    final $$PartsOfSpeechTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.inputPosId,
      referencedTable: $db.partsOfSpeech,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PartsOfSpeechTableAnnotationComposer(
            $db: $db,
            $table: $db.partsOfSpeech,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PartsOfSpeechTableAnnotationComposer get outputPosId {
    final $$PartsOfSpeechTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.outputPosId,
      referencedTable: $db.partsOfSpeech,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PartsOfSpeechTableAnnotationComposer(
            $db: $db,
            $table: $db.partsOfSpeech,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MorphologicalRulesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MorphologicalRulesTable,
          MorphologicalRule,
          $$MorphologicalRulesTableFilterComposer,
          $$MorphologicalRulesTableOrderingComposer,
          $$MorphologicalRulesTableAnnotationComposer,
          $$MorphologicalRulesTableCreateCompanionBuilder,
          $$MorphologicalRulesTableUpdateCompanionBuilder,
          (MorphologicalRule, $$MorphologicalRulesTableReferences),
          MorphologicalRule,
          PrefetchHooks Function({
            bool posId,
            bool inputPosId,
            bool outputPosId,
          })
        > {
  $$MorphologicalRulesTableTableManager(
    _$AppDatabase db,
    $MorphologicalRulesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MorphologicalRulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MorphologicalRulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MorphologicalRulesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<int> ordering = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int?> posId = const Value.absent(),
                Value<String> posIds = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<FeatureBindings> featureBindings = const Value.absent(),
                Value<int?> inputPosId = const Value.absent(),
                Value<int?> outputPosId = const Value.absent(),
              }) => MorphologicalRulesCompanion(
                id: id,
                name: name,
                source: source,
                ordering: ordering,
                isActive: isActive,
                posId: posId,
                posIds: posIds,
                kind: kind,
                featureBindings: featureBindings,
                inputPosId: inputPosId,
                outputPosId: outputPosId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String source,
                Value<int> ordering = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int?> posId = const Value.absent(),
                Value<String> posIds = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<FeatureBindings> featureBindings = const Value.absent(),
                Value<int?> inputPosId = const Value.absent(),
                Value<int?> outputPosId = const Value.absent(),
              }) => MorphologicalRulesCompanion.insert(
                id: id,
                name: name,
                source: source,
                ordering: ordering,
                isActive: isActive,
                posId: posId,
                posIds: posIds,
                kind: kind,
                featureBindings: featureBindings,
                inputPosId: inputPosId,
                outputPosId: outputPosId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MorphologicalRulesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({posId = false, inputPosId = false, outputPosId = false}) {
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
                        if (posId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.posId,
                                    referencedTable:
                                        $$MorphologicalRulesTableReferences
                                            ._posIdTable(db),
                                    referencedColumn:
                                        $$MorphologicalRulesTableReferences
                                            ._posIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (inputPosId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.inputPosId,
                                    referencedTable:
                                        $$MorphologicalRulesTableReferences
                                            ._inputPosIdTable(db),
                                    referencedColumn:
                                        $$MorphologicalRulesTableReferences
                                            ._inputPosIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (outputPosId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.outputPosId,
                                    referencedTable:
                                        $$MorphologicalRulesTableReferences
                                            ._outputPosIdTable(db),
                                    referencedColumn:
                                        $$MorphologicalRulesTableReferences
                                            ._outputPosIdTable(db)
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

typedef $$MorphologicalRulesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MorphologicalRulesTable,
      MorphologicalRule,
      $$MorphologicalRulesTableFilterComposer,
      $$MorphologicalRulesTableOrderingComposer,
      $$MorphologicalRulesTableAnnotationComposer,
      $$MorphologicalRulesTableCreateCompanionBuilder,
      $$MorphologicalRulesTableUpdateCompanionBuilder,
      (MorphologicalRule, $$MorphologicalRulesTableReferences),
      MorphologicalRule,
      PrefetchHooks Function({bool posId, bool inputPosId, bool outputPosId})
    >;
typedef $$MorphologicalRuleExceptionsTableCreateCompanionBuilder =
    MorphologicalRuleExceptionsCompanion Function({
      Value<int> id,
      required int lexemeId,
      required int ruleId,
      required String overrideForm,
      required String ruleSourceSnapshot,
    });
typedef $$MorphologicalRuleExceptionsTableUpdateCompanionBuilder =
    MorphologicalRuleExceptionsCompanion Function({
      Value<int> id,
      Value<int> lexemeId,
      Value<int> ruleId,
      Value<String> overrideForm,
      Value<String> ruleSourceSnapshot,
    });

class $$MorphologicalRuleExceptionsTableFilterComposer
    extends Composer<_$AppDatabase, $MorphologicalRuleExceptionsTable> {
  $$MorphologicalRuleExceptionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lexemeId => $composableBuilder(
    column: $table.lexemeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ruleId => $composableBuilder(
    column: $table.ruleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get overrideForm => $composableBuilder(
    column: $table.overrideForm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ruleSourceSnapshot => $composableBuilder(
    column: $table.ruleSourceSnapshot,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MorphologicalRuleExceptionsTableOrderingComposer
    extends Composer<_$AppDatabase, $MorphologicalRuleExceptionsTable> {
  $$MorphologicalRuleExceptionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lexemeId => $composableBuilder(
    column: $table.lexemeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ruleId => $composableBuilder(
    column: $table.ruleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get overrideForm => $composableBuilder(
    column: $table.overrideForm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ruleSourceSnapshot => $composableBuilder(
    column: $table.ruleSourceSnapshot,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MorphologicalRuleExceptionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MorphologicalRuleExceptionsTable> {
  $$MorphologicalRuleExceptionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get lexemeId =>
      $composableBuilder(column: $table.lexemeId, builder: (column) => column);

  GeneratedColumn<int> get ruleId =>
      $composableBuilder(column: $table.ruleId, builder: (column) => column);

  GeneratedColumn<String> get overrideForm => $composableBuilder(
    column: $table.overrideForm,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ruleSourceSnapshot => $composableBuilder(
    column: $table.ruleSourceSnapshot,
    builder: (column) => column,
  );
}

class $$MorphologicalRuleExceptionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MorphologicalRuleExceptionsTable,
          MorphologicalRuleException,
          $$MorphologicalRuleExceptionsTableFilterComposer,
          $$MorphologicalRuleExceptionsTableOrderingComposer,
          $$MorphologicalRuleExceptionsTableAnnotationComposer,
          $$MorphologicalRuleExceptionsTableCreateCompanionBuilder,
          $$MorphologicalRuleExceptionsTableUpdateCompanionBuilder,
          (
            MorphologicalRuleException,
            BaseReferences<
              _$AppDatabase,
              $MorphologicalRuleExceptionsTable,
              MorphologicalRuleException
            >,
          ),
          MorphologicalRuleException,
          PrefetchHooks Function()
        > {
  $$MorphologicalRuleExceptionsTableTableManager(
    _$AppDatabase db,
    $MorphologicalRuleExceptionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MorphologicalRuleExceptionsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$MorphologicalRuleExceptionsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$MorphologicalRuleExceptionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> lexemeId = const Value.absent(),
                Value<int> ruleId = const Value.absent(),
                Value<String> overrideForm = const Value.absent(),
                Value<String> ruleSourceSnapshot = const Value.absent(),
              }) => MorphologicalRuleExceptionsCompanion(
                id: id,
                lexemeId: lexemeId,
                ruleId: ruleId,
                overrideForm: overrideForm,
                ruleSourceSnapshot: ruleSourceSnapshot,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int lexemeId,
                required int ruleId,
                required String overrideForm,
                required String ruleSourceSnapshot,
              }) => MorphologicalRuleExceptionsCompanion.insert(
                id: id,
                lexemeId: lexemeId,
                ruleId: ruleId,
                overrideForm: overrideForm,
                ruleSourceSnapshot: ruleSourceSnapshot,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MorphologicalRuleExceptionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MorphologicalRuleExceptionsTable,
      MorphologicalRuleException,
      $$MorphologicalRuleExceptionsTableFilterComposer,
      $$MorphologicalRuleExceptionsTableOrderingComposer,
      $$MorphologicalRuleExceptionsTableAnnotationComposer,
      $$MorphologicalRuleExceptionsTableCreateCompanionBuilder,
      $$MorphologicalRuleExceptionsTableUpdateCompanionBuilder,
      (
        MorphologicalRuleException,
        BaseReferences<
          _$AppDatabase,
          $MorphologicalRuleExceptionsTable,
          MorphologicalRuleException
        >,
      ),
      MorphologicalRuleException,
      PrefetchHooks Function()
    >;
typedef $$DimensionsTableCreateCompanionBuilder =
    DimensionsCompanion Function({
      Value<int> id,
      required int posId,
      required String name,
      Value<int> ordering,
      required String levelsJson,
      Value<String?> templateId,
    });
typedef $$DimensionsTableUpdateCompanionBuilder =
    DimensionsCompanion Function({
      Value<int> id,
      Value<int> posId,
      Value<String> name,
      Value<int> ordering,
      Value<String> levelsJson,
      Value<String?> templateId,
    });

final class $$DimensionsTableReferences
    extends BaseReferences<_$AppDatabase, $DimensionsTable, Dimension> {
  $$DimensionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PartsOfSpeechTable _posIdTable(_$AppDatabase db) =>
      db.partsOfSpeech.createAlias(
        $_aliasNameGenerator(db.dimensions.posId, db.partsOfSpeech.id),
      );

  $$PartsOfSpeechTableProcessedTableManager get posId {
    final $_column = $_itemColumn<int>('pos_id')!;

    final manager = $$PartsOfSpeechTableTableManager(
      $_db,
      $_db.partsOfSpeech,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_posIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DimensionsTableFilterComposer
    extends Composer<_$AppDatabase, $DimensionsTable> {
  $$DimensionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ordering => $composableBuilder(
    column: $table.ordering,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get levelsJson => $composableBuilder(
    column: $table.levelsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get templateId => $composableBuilder(
    column: $table.templateId,
    builder: (column) => ColumnFilters(column),
  );

  $$PartsOfSpeechTableFilterComposer get posId {
    final $$PartsOfSpeechTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.posId,
      referencedTable: $db.partsOfSpeech,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PartsOfSpeechTableFilterComposer(
            $db: $db,
            $table: $db.partsOfSpeech,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DimensionsTableOrderingComposer
    extends Composer<_$AppDatabase, $DimensionsTable> {
  $$DimensionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ordering => $composableBuilder(
    column: $table.ordering,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get levelsJson => $composableBuilder(
    column: $table.levelsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get templateId => $composableBuilder(
    column: $table.templateId,
    builder: (column) => ColumnOrderings(column),
  );

  $$PartsOfSpeechTableOrderingComposer get posId {
    final $$PartsOfSpeechTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.posId,
      referencedTable: $db.partsOfSpeech,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PartsOfSpeechTableOrderingComposer(
            $db: $db,
            $table: $db.partsOfSpeech,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DimensionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DimensionsTable> {
  $$DimensionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get ordering =>
      $composableBuilder(column: $table.ordering, builder: (column) => column);

  GeneratedColumn<String> get levelsJson => $composableBuilder(
    column: $table.levelsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get templateId => $composableBuilder(
    column: $table.templateId,
    builder: (column) => column,
  );

  $$PartsOfSpeechTableAnnotationComposer get posId {
    final $$PartsOfSpeechTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.posId,
      referencedTable: $db.partsOfSpeech,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PartsOfSpeechTableAnnotationComposer(
            $db: $db,
            $table: $db.partsOfSpeech,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DimensionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DimensionsTable,
          Dimension,
          $$DimensionsTableFilterComposer,
          $$DimensionsTableOrderingComposer,
          $$DimensionsTableAnnotationComposer,
          $$DimensionsTableCreateCompanionBuilder,
          $$DimensionsTableUpdateCompanionBuilder,
          (Dimension, $$DimensionsTableReferences),
          Dimension,
          PrefetchHooks Function({bool posId})
        > {
  $$DimensionsTableTableManager(_$AppDatabase db, $DimensionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DimensionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DimensionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DimensionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> posId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> ordering = const Value.absent(),
                Value<String> levelsJson = const Value.absent(),
                Value<String?> templateId = const Value.absent(),
              }) => DimensionsCompanion(
                id: id,
                posId: posId,
                name: name,
                ordering: ordering,
                levelsJson: levelsJson,
                templateId: templateId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int posId,
                required String name,
                Value<int> ordering = const Value.absent(),
                required String levelsJson,
                Value<String?> templateId = const Value.absent(),
              }) => DimensionsCompanion.insert(
                id: id,
                posId: posId,
                name: name,
                ordering: ordering,
                levelsJson: levelsJson,
                templateId: templateId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DimensionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({posId = false}) {
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
                    if (posId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.posId,
                                referencedTable: $$DimensionsTableReferences
                                    ._posIdTable(db),
                                referencedColumn: $$DimensionsTableReferences
                                    ._posIdTable(db)
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

typedef $$DimensionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DimensionsTable,
      Dimension,
      $$DimensionsTableFilterComposer,
      $$DimensionsTableOrderingComposer,
      $$DimensionsTableAnnotationComposer,
      $$DimensionsTableCreateCompanionBuilder,
      $$DimensionsTableUpdateCompanionBuilder,
      (Dimension, $$DimensionsTableReferences),
      Dimension,
      PrefetchHooks Function({bool posId})
    >;
typedef $$ParadigmCellOverridesTableCreateCompanionBuilder =
    ParadigmCellOverridesCompanion Function({
      Value<int> id,
      required int lexemeId,
      required String featureSetJson,
      required String overrideIpa,
      Value<String?> overrideRomanization,
      Value<String?> notes,
    });
typedef $$ParadigmCellOverridesTableUpdateCompanionBuilder =
    ParadigmCellOverridesCompanion Function({
      Value<int> id,
      Value<int> lexemeId,
      Value<String> featureSetJson,
      Value<String> overrideIpa,
      Value<String?> overrideRomanization,
      Value<String?> notes,
    });

final class $$ParadigmCellOverridesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ParadigmCellOverridesTable,
          ParadigmCellOverride
        > {
  $$ParadigmCellOverridesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LexemesTable _lexemeIdTable(_$AppDatabase db) =>
      db.lexemes.createAlias(
        $_aliasNameGenerator(db.paradigmCellOverrides.lexemeId, db.lexemes.id),
      );

  $$LexemesTableProcessedTableManager get lexemeId {
    final $_column = $_itemColumn<int>('lexeme_id')!;

    final manager = $$LexemesTableTableManager(
      $_db,
      $_db.lexemes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_lexemeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ParadigmCellOverridesTableFilterComposer
    extends Composer<_$AppDatabase, $ParadigmCellOverridesTable> {
  $$ParadigmCellOverridesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get featureSetJson => $composableBuilder(
    column: $table.featureSetJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get overrideIpa => $composableBuilder(
    column: $table.overrideIpa,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get overrideRomanization => $composableBuilder(
    column: $table.overrideRomanization,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  $$LexemesTableFilterComposer get lexemeId {
    final $$LexemesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.lexemeId,
      referencedTable: $db.lexemes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LexemesTableFilterComposer(
            $db: $db,
            $table: $db.lexemes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ParadigmCellOverridesTableOrderingComposer
    extends Composer<_$AppDatabase, $ParadigmCellOverridesTable> {
  $$ParadigmCellOverridesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get featureSetJson => $composableBuilder(
    column: $table.featureSetJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get overrideIpa => $composableBuilder(
    column: $table.overrideIpa,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get overrideRomanization => $composableBuilder(
    column: $table.overrideRomanization,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  $$LexemesTableOrderingComposer get lexemeId {
    final $$LexemesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.lexemeId,
      referencedTable: $db.lexemes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LexemesTableOrderingComposer(
            $db: $db,
            $table: $db.lexemes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ParadigmCellOverridesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ParadigmCellOverridesTable> {
  $$ParadigmCellOverridesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get featureSetJson => $composableBuilder(
    column: $table.featureSetJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get overrideIpa => $composableBuilder(
    column: $table.overrideIpa,
    builder: (column) => column,
  );

  GeneratedColumn<String> get overrideRomanization => $composableBuilder(
    column: $table.overrideRomanization,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  $$LexemesTableAnnotationComposer get lexemeId {
    final $$LexemesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.lexemeId,
      referencedTable: $db.lexemes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LexemesTableAnnotationComposer(
            $db: $db,
            $table: $db.lexemes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ParadigmCellOverridesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ParadigmCellOverridesTable,
          ParadigmCellOverride,
          $$ParadigmCellOverridesTableFilterComposer,
          $$ParadigmCellOverridesTableOrderingComposer,
          $$ParadigmCellOverridesTableAnnotationComposer,
          $$ParadigmCellOverridesTableCreateCompanionBuilder,
          $$ParadigmCellOverridesTableUpdateCompanionBuilder,
          (ParadigmCellOverride, $$ParadigmCellOverridesTableReferences),
          ParadigmCellOverride,
          PrefetchHooks Function({bool lexemeId})
        > {
  $$ParadigmCellOverridesTableTableManager(
    _$AppDatabase db,
    $ParadigmCellOverridesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ParadigmCellOverridesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$ParadigmCellOverridesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ParadigmCellOverridesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> lexemeId = const Value.absent(),
                Value<String> featureSetJson = const Value.absent(),
                Value<String> overrideIpa = const Value.absent(),
                Value<String?> overrideRomanization = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => ParadigmCellOverridesCompanion(
                id: id,
                lexemeId: lexemeId,
                featureSetJson: featureSetJson,
                overrideIpa: overrideIpa,
                overrideRomanization: overrideRomanization,
                notes: notes,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int lexemeId,
                required String featureSetJson,
                required String overrideIpa,
                Value<String?> overrideRomanization = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => ParadigmCellOverridesCompanion.insert(
                id: id,
                lexemeId: lexemeId,
                featureSetJson: featureSetJson,
                overrideIpa: overrideIpa,
                overrideRomanization: overrideRomanization,
                notes: notes,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ParadigmCellOverridesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({lexemeId = false}) {
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
                    if (lexemeId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.lexemeId,
                                referencedTable:
                                    $$ParadigmCellOverridesTableReferences
                                        ._lexemeIdTable(db),
                                referencedColumn:
                                    $$ParadigmCellOverridesTableReferences
                                        ._lexemeIdTable(db)
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

typedef $$ParadigmCellOverridesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ParadigmCellOverridesTable,
      ParadigmCellOverride,
      $$ParadigmCellOverridesTableFilterComposer,
      $$ParadigmCellOverridesTableOrderingComposer,
      $$ParadigmCellOverridesTableAnnotationComposer,
      $$ParadigmCellOverridesTableCreateCompanionBuilder,
      $$ParadigmCellOverridesTableUpdateCompanionBuilder,
      (ParadigmCellOverride, $$ParadigmCellOverridesTableReferences),
      ParadigmCellOverride,
      PrefetchHooks Function({bool lexemeId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PhonemesTableTableManager get phonemes =>
      $$PhonemesTableTableManager(_db, _db.phonemes);
  $$NaturalClassesTableTableManager get naturalClasses =>
      $$NaturalClassesTableTableManager(_db, _db.naturalClasses);
  $$PhonotacticTemplatesTableTableManager get phonotacticTemplates =>
      $$PhonotacticTemplatesTableTableManager(_db, _db.phonotacticTemplates);
  $$PhonotacticConstraintsTableTableManager get phonotacticConstraints =>
      $$PhonotacticConstraintsTableTableManager(
        _db,
        _db.phonotacticConstraints,
      );
  $$RomanizationMappingsTableTableManager get romanizationMappings =>
      $$RomanizationMappingsTableTableManager(_db, _db.romanizationMappings);
  $$LexemesTableTableManager get lexemes =>
      $$LexemesTableTableManager(_db, _db.lexemes);
  $$RewriteRulesTableTableManager get rewriteRules =>
      $$RewriteRulesTableTableManager(_db, _db.rewriteRules);
  $$ProjectSettingsTableTableManager get projectSettings =>
      $$ProjectSettingsTableTableManager(_db, _db.projectSettings);
  $$PartsOfSpeechTableTableManager get partsOfSpeech =>
      $$PartsOfSpeechTableTableManager(_db, _db.partsOfSpeech);
  $$MorphologicalRulesTableTableManager get morphologicalRules =>
      $$MorphologicalRulesTableTableManager(_db, _db.morphologicalRules);
  $$MorphologicalRuleExceptionsTableTableManager
  get morphologicalRuleExceptions =>
      $$MorphologicalRuleExceptionsTableTableManager(
        _db,
        _db.morphologicalRuleExceptions,
      );
  $$DimensionsTableTableManager get dimensions =>
      $$DimensionsTableTableManager(_db, _db.dimensions);
  $$ParadigmCellOverridesTableTableManager get paradigmCellOverrides =>
      $$ParadigmCellOverridesTableTableManager(_db, _db.paradigmCellOverrides);
}
