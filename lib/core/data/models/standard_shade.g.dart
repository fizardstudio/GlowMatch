// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'standard_shade.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetStandardShadeCollection on Isar {
  IsarCollection<StandardShade> get standardShades => this.collection();
}

const StandardShadeSchema = CollectionSchema(
  name: r'StandardShade',
  id: 2677079150281728578,
  properties: {
    r'a': PropertySchema(
      id: 0,
      name: r'a',
      type: IsarType.double,
    ),
    r'b': PropertySchema(
      id: 1,
      name: r'b',
      type: IsarType.double,
    ),
    r'hexCode': PropertySchema(
      id: 2,
      name: r'hexCode',
      type: IsarType.string,
    ),
    r'l': PropertySchema(
      id: 3,
      name: r'l',
      type: IsarType.double,
    ),
    r'name': PropertySchema(
      id: 4,
      name: r'name',
      type: IsarType.string,
    ),
    r'skinTone': PropertySchema(
      id: 5,
      name: r'skinTone',
      type: IsarType.string,
    ),
    r'undertone': PropertySchema(
      id: 6,
      name: r'undertone',
      type: IsarType.string,
    )
  },
  estimateSize: _standardShadeEstimateSize,
  serialize: _standardShadeSerialize,
  deserialize: _standardShadeDeserialize,
  deserializeProp: _standardShadeDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _standardShadeGetId,
  getLinks: _standardShadeGetLinks,
  attach: _standardShadeAttach,
  version: '3.1.0+1',
);

int _standardShadeEstimateSize(
  StandardShade object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.hexCode.length * 3;
  bytesCount += 3 + object.name.length * 3;
  bytesCount += 3 + object.skinTone.length * 3;
  bytesCount += 3 + object.undertone.length * 3;
  return bytesCount;
}

void _standardShadeSerialize(
  StandardShade object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDouble(offsets[0], object.a);
  writer.writeDouble(offsets[1], object.b);
  writer.writeString(offsets[2], object.hexCode);
  writer.writeDouble(offsets[3], object.l);
  writer.writeString(offsets[4], object.name);
  writer.writeString(offsets[5], object.skinTone);
  writer.writeString(offsets[6], object.undertone);
}

StandardShade _standardShadeDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = StandardShade();
  object.a = reader.readDouble(offsets[0]);
  object.b = reader.readDouble(offsets[1]);
  object.hexCode = reader.readString(offsets[2]);
  object.id = id;
  object.l = reader.readDouble(offsets[3]);
  object.name = reader.readString(offsets[4]);
  object.skinTone = reader.readString(offsets[5]);
  object.undertone = reader.readString(offsets[6]);
  return object;
}

P _standardShadeDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDouble(offset)) as P;
    case 1:
      return (reader.readDouble(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readDouble(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _standardShadeGetId(StandardShade object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _standardShadeGetLinks(StandardShade object) {
  return [];
}

void _standardShadeAttach(
    IsarCollection<dynamic> col, Id id, StandardShade object) {
  object.id = id;
}

extension StandardShadeQueryWhereSort
    on QueryBuilder<StandardShade, StandardShade, QWhere> {
  QueryBuilder<StandardShade, StandardShade, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension StandardShadeQueryWhere
    on QueryBuilder<StandardShade, StandardShade, QWhereClause> {
  QueryBuilder<StandardShade, StandardShade, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterWhereClause> idNotEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterWhereClause> idGreaterThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterWhereClause> idLessThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension StandardShadeQueryFilter
    on QueryBuilder<StandardShade, StandardShade, QFilterCondition> {
  QueryBuilder<StandardShade, StandardShade, QAfterFilterCondition> aEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'a',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterFilterCondition>
      aGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'a',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterFilterCondition> aLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'a',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterFilterCondition> aBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'a',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterFilterCondition> bEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'b',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterFilterCondition>
      bGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'b',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterFilterCondition> bLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'b',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterFilterCondition> bBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'b',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterFilterCondition>
      hexCodeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'hexCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterFilterCondition>
      hexCodeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'hexCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterFilterCondition>
      hexCodeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'hexCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterFilterCondition>
      hexCodeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'hexCode',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterFilterCondition>
      hexCodeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'hexCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterFilterCondition>
      hexCodeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'hexCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterFilterCondition>
      hexCodeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'hexCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterFilterCondition>
      hexCodeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'hexCode',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterFilterCondition>
      hexCodeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'hexCode',
        value: '',
      ));
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterFilterCondition>
      hexCodeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'hexCode',
        value: '',
      ));
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterFilterCondition>
      idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterFilterCondition> lEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'l',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterFilterCondition>
      lGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'l',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterFilterCondition> lLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'l',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterFilterCondition> lBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'l',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterFilterCondition> nameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterFilterCondition>
      nameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterFilterCondition>
      nameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterFilterCondition> nameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'name',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterFilterCondition>
      nameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterFilterCondition>
      nameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterFilterCondition>
      nameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterFilterCondition> nameMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'name',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterFilterCondition>
      nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'name',
        value: '',
      ));
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterFilterCondition>
      nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'name',
        value: '',
      ));
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterFilterCondition>
      skinToneEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'skinTone',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterFilterCondition>
      skinToneGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'skinTone',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterFilterCondition>
      skinToneLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'skinTone',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterFilterCondition>
      skinToneBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'skinTone',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterFilterCondition>
      skinToneStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'skinTone',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterFilterCondition>
      skinToneEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'skinTone',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterFilterCondition>
      skinToneContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'skinTone',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterFilterCondition>
      skinToneMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'skinTone',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterFilterCondition>
      skinToneIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'skinTone',
        value: '',
      ));
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterFilterCondition>
      skinToneIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'skinTone',
        value: '',
      ));
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterFilterCondition>
      undertoneEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'undertone',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterFilterCondition>
      undertoneGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'undertone',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterFilterCondition>
      undertoneLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'undertone',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterFilterCondition>
      undertoneBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'undertone',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterFilterCondition>
      undertoneStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'undertone',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterFilterCondition>
      undertoneEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'undertone',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterFilterCondition>
      undertoneContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'undertone',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterFilterCondition>
      undertoneMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'undertone',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterFilterCondition>
      undertoneIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'undertone',
        value: '',
      ));
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterFilterCondition>
      undertoneIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'undertone',
        value: '',
      ));
    });
  }
}

extension StandardShadeQueryObject
    on QueryBuilder<StandardShade, StandardShade, QFilterCondition> {}

extension StandardShadeQueryLinks
    on QueryBuilder<StandardShade, StandardShade, QFilterCondition> {}

extension StandardShadeQuerySortBy
    on QueryBuilder<StandardShade, StandardShade, QSortBy> {
  QueryBuilder<StandardShade, StandardShade, QAfterSortBy> sortByA() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'a', Sort.asc);
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterSortBy> sortByADesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'a', Sort.desc);
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterSortBy> sortByB() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'b', Sort.asc);
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterSortBy> sortByBDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'b', Sort.desc);
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterSortBy> sortByHexCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hexCode', Sort.asc);
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterSortBy> sortByHexCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hexCode', Sort.desc);
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterSortBy> sortByL() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'l', Sort.asc);
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterSortBy> sortByLDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'l', Sort.desc);
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterSortBy> sortByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterSortBy> sortByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterSortBy> sortBySkinTone() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'skinTone', Sort.asc);
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterSortBy>
      sortBySkinToneDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'skinTone', Sort.desc);
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterSortBy> sortByUndertone() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'undertone', Sort.asc);
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterSortBy>
      sortByUndertoneDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'undertone', Sort.desc);
    });
  }
}

extension StandardShadeQuerySortThenBy
    on QueryBuilder<StandardShade, StandardShade, QSortThenBy> {
  QueryBuilder<StandardShade, StandardShade, QAfterSortBy> thenByA() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'a', Sort.asc);
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterSortBy> thenByADesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'a', Sort.desc);
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterSortBy> thenByB() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'b', Sort.asc);
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterSortBy> thenByBDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'b', Sort.desc);
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterSortBy> thenByHexCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hexCode', Sort.asc);
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterSortBy> thenByHexCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hexCode', Sort.desc);
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterSortBy> thenByL() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'l', Sort.asc);
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterSortBy> thenByLDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'l', Sort.desc);
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterSortBy> thenByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterSortBy> thenByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterSortBy> thenBySkinTone() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'skinTone', Sort.asc);
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterSortBy>
      thenBySkinToneDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'skinTone', Sort.desc);
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterSortBy> thenByUndertone() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'undertone', Sort.asc);
    });
  }

  QueryBuilder<StandardShade, StandardShade, QAfterSortBy>
      thenByUndertoneDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'undertone', Sort.desc);
    });
  }
}

extension StandardShadeQueryWhereDistinct
    on QueryBuilder<StandardShade, StandardShade, QDistinct> {
  QueryBuilder<StandardShade, StandardShade, QDistinct> distinctByA() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'a');
    });
  }

  QueryBuilder<StandardShade, StandardShade, QDistinct> distinctByB() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'b');
    });
  }

  QueryBuilder<StandardShade, StandardShade, QDistinct> distinctByHexCode(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'hexCode', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<StandardShade, StandardShade, QDistinct> distinctByL() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'l');
    });
  }

  QueryBuilder<StandardShade, StandardShade, QDistinct> distinctByName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<StandardShade, StandardShade, QDistinct> distinctBySkinTone(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'skinTone', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<StandardShade, StandardShade, QDistinct> distinctByUndertone(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'undertone', caseSensitive: caseSensitive);
    });
  }
}

extension StandardShadeQueryProperty
    on QueryBuilder<StandardShade, StandardShade, QQueryProperty> {
  QueryBuilder<StandardShade, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<StandardShade, double, QQueryOperations> aProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'a');
    });
  }

  QueryBuilder<StandardShade, double, QQueryOperations> bProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'b');
    });
  }

  QueryBuilder<StandardShade, String, QQueryOperations> hexCodeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'hexCode');
    });
  }

  QueryBuilder<StandardShade, double, QQueryOperations> lProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'l');
    });
  }

  QueryBuilder<StandardShade, String, QQueryOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'name');
    });
  }

  QueryBuilder<StandardShade, String, QQueryOperations> skinToneProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'skinTone');
    });
  }

  QueryBuilder<StandardShade, String, QQueryOperations> undertoneProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'undertone');
    });
  }
}
