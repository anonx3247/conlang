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
  @override
  List<GeneratedColumn> get $columns => [id, pattern, description, isActive];
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
  const PhonotacticConstraint({
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

  PhonotacticConstraintsCompanion toCompanion(bool nullToAbsent) {
    return PhonotacticConstraintsCompanion(
      id: Value(id),
      pattern: Value(pattern),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      isActive: Value(isActive),
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

  PhonotacticConstraint copyWith({
    int? id,
    String? pattern,
    Value<String?> description = const Value.absent(),
    bool? isActive,
  }) => PhonotacticConstraint(
    id: id ?? this.id,
    pattern: pattern ?? this.pattern,
    description: description.present ? description.value : this.description,
    isActive: isActive ?? this.isActive,
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
    );
  }

  @override
  String toString() {
    return (StringBuffer('PhonotacticConstraint(')
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
      (other is PhonotacticConstraint &&
          other.id == this.id &&
          other.pattern == this.pattern &&
          other.description == this.description &&
          other.isActive == this.isActive);
}

class PhonotacticConstraintsCompanion
    extends UpdateCompanion<PhonotacticConstraint> {
  final Value<int> id;
  final Value<String> pattern;
  final Value<String?> description;
  final Value<bool> isActive;
  const PhonotacticConstraintsCompanion({
    this.id = const Value.absent(),
    this.pattern = const Value.absent(),
    this.description = const Value.absent(),
    this.isActive = const Value.absent(),
  });
  PhonotacticConstraintsCompanion.insert({
    this.id = const Value.absent(),
    required String pattern,
    this.description = const Value.absent(),
    this.isActive = const Value.absent(),
  }) : pattern = Value(pattern);
  static Insertable<PhonotacticConstraint> custom({
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

  PhonotacticConstraintsCompanion copyWith({
    Value<int>? id,
    Value<String>? pattern,
    Value<String?>? description,
    Value<bool>? isActive,
  }) {
    return PhonotacticConstraintsCompanion(
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
    return (StringBuffer('PhonotacticConstraintsCompanion(')
          ..write('id: $id, ')
          ..write('pattern: $pattern, ')
          ..write('description: $description, ')
          ..write('isActive: $isActive')
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
  const Lexeme({
    required this.id,
    required this.ipa,
    this.rootId,
    this.ruleIds,
    this.computedForm,
    this.romanization,
    this.meaning,
    this.partOfSpeech,
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
  }) => Lexeme(
    id: id ?? this.id,
    ipa: ipa ?? this.ipa,
    rootId: rootId.present ? rootId.value : this.rootId,
    ruleIds: ruleIds.present ? ruleIds.value : this.ruleIds,
    computedForm: computedForm.present ? computedForm.value : this.computedForm,
    romanization: romanization.present ? romanization.value : this.romanization,
    meaning: meaning.present ? meaning.value : this.meaning,
    partOfSpeech: partOfSpeech.present ? partOfSpeech.value : this.partOfSpeech,
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
          ..write('partOfSpeech: $partOfSpeech')
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
          other.partOfSpeech == this.partOfSpeech);
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
  const LexemesCompanion({
    this.id = const Value.absent(),
    this.ipa = const Value.absent(),
    this.rootId = const Value.absent(),
    this.ruleIds = const Value.absent(),
    this.computedForm = const Value.absent(),
    this.romanization = const Value.absent(),
    this.meaning = const Value.absent(),
    this.partOfSpeech = const Value.absent(),
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
          ..write('partOfSpeech: $partOfSpeech')
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
  ];
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
    });
typedef $$PhonotacticConstraintsTableUpdateCompanionBuilder =
    PhonotacticConstraintsCompanion Function({
      Value<int> id,
      Value<String> pattern,
      Value<String?> description,
      Value<bool> isActive,
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
              }) => PhonotacticConstraintsCompanion(
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
              }) => PhonotacticConstraintsCompanion.insert(
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
    });

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
          (Lexeme, BaseReferences<_$AppDatabase, $LexemesTable, Lexeme>),
          Lexeme,
          PrefetchHooks Function()
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
              }) => LexemesCompanion(
                id: id,
                ipa: ipa,
                rootId: rootId,
                ruleIds: ruleIds,
                computedForm: computedForm,
                romanization: romanization,
                meaning: meaning,
                partOfSpeech: partOfSpeech,
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
              }) => LexemesCompanion.insert(
                id: id,
                ipa: ipa,
                rootId: rootId,
                ruleIds: ruleIds,
                computedForm: computedForm,
                romanization: romanization,
                meaning: meaning,
                partOfSpeech: partOfSpeech,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
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
      (Lexeme, BaseReferences<_$AppDatabase, $LexemesTable, Lexeme>),
      Lexeme,
      PrefetchHooks Function()
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
}
