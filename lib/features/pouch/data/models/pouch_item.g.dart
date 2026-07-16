// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pouch_item.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetPouchItemCollection on Isar {
  IsarCollection<PouchItem> get pouchItems => this.collection();
}

const PouchItemSchema = CollectionSchema(
  name: r'PouchItem',
  id: -2758443333161176027,
  properties: {
    r'brand': PropertySchema(
      id: 0,
      name: r'brand',
      type: IsarType.string,
    ),
    r'category': PropertySchema(
      id: 1,
      name: r'category',
      type: IsarType.string,
    ),
    r'feedbackScore': PropertySchema(
      id: 2,
      name: r'feedbackScore',
      type: IsarType.long,
    ),
    r'hexCode': PropertySchema(
      id: 3,
      name: r'hexCode',
      type: IsarType.string,
    ),
    r'isReviewSynced': PropertySchema(
      id: 4,
      name: r'isReviewSynced',
      type: IsarType.bool,
    ),
    r'openedDate': PropertySchema(
      id: 5,
      name: r'openedDate',
      type: IsarType.dateTime,
    ),
    r'paoMonths': PropertySchema(
      id: 6,
      name: r'paoMonths',
      type: IsarType.long,
    ),
    r'productName': PropertySchema(
      id: 7,
      name: r'productName',
      type: IsarType.string,
    ),
    r'shadeName': PropertySchema(
      id: 8,
      name: r'shadeName',
      type: IsarType.string,
    )
  },
  estimateSize: _pouchItemEstimateSize,
  serialize: _pouchItemSerialize,
  deserialize: _pouchItemDeserialize,
  deserializeProp: _pouchItemDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _pouchItemGetId,
  getLinks: _pouchItemGetLinks,
  attach: _pouchItemAttach,
  version: '3.1.0+1',
);

int _pouchItemEstimateSize(
  PouchItem object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.brand.length * 3;
  bytesCount += 3 + object.category.length * 3;
  bytesCount += 3 + object.hexCode.length * 3;
  bytesCount += 3 + object.productName.length * 3;
  bytesCount += 3 + object.shadeName.length * 3;
  return bytesCount;
}

void _pouchItemSerialize(
  PouchItem object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.brand);
  writer.writeString(offsets[1], object.category);
  writer.writeLong(offsets[2], object.feedbackScore);
  writer.writeString(offsets[3], object.hexCode);
  writer.writeBool(offsets[4], object.isReviewSynced);
  writer.writeDateTime(offsets[5], object.openedDate);
  writer.writeLong(offsets[6], object.paoMonths);
  writer.writeString(offsets[7], object.productName);
  writer.writeString(offsets[8], object.shadeName);
}

PouchItem _pouchItemDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = PouchItem();
  object.brand = reader.readString(offsets[0]);
  object.category = reader.readString(offsets[1]);
  object.feedbackScore = reader.readLongOrNull(offsets[2]);
  object.hexCode = reader.readString(offsets[3]);
  object.id = id;
  object.isReviewSynced = reader.readBool(offsets[4]);
  object.openedDate = reader.readDateTime(offsets[5]);
  object.paoMonths = reader.readLong(offsets[6]);
  object.productName = reader.readString(offsets[7]);
  object.shadeName = reader.readString(offsets[8]);
  return object;
}

P _pouchItemDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readLongOrNull(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readBool(offset)) as P;
    case 5:
      return (reader.readDateTime(offset)) as P;
    case 6:
      return (reader.readLong(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    case 8:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _pouchItemGetId(PouchItem object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _pouchItemGetLinks(PouchItem object) {
  return [];
}

void _pouchItemAttach(IsarCollection<dynamic> col, Id id, PouchItem object) {
  object.id = id;
}

extension PouchItemQueryWhereSort
    on QueryBuilder<PouchItem, PouchItem, QWhere> {
  QueryBuilder<PouchItem, PouchItem, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension PouchItemQueryWhere
    on QueryBuilder<PouchItem, PouchItem, QWhereClause> {
  QueryBuilder<PouchItem, PouchItem, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterWhereClause> idNotEqualTo(Id id) {
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

  QueryBuilder<PouchItem, PouchItem, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterWhereClause> idBetween(
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

extension PouchItemQueryFilter
    on QueryBuilder<PouchItem, PouchItem, QFilterCondition> {
  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition> brandEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'brand',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition> brandGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'brand',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition> brandLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'brand',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition> brandBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'brand',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition> brandStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'brand',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition> brandEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'brand',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition> brandContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'brand',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition> brandMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'brand',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition> brandIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'brand',
        value: '',
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition> brandIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'brand',
        value: '',
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition> categoryEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'category',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition> categoryGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'category',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition> categoryLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'category',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition> categoryBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'category',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition> categoryStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'category',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition> categoryEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'category',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition> categoryContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'category',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition> categoryMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'category',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition> categoryIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'category',
        value: '',
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition>
      categoryIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'category',
        value: '',
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition>
      feedbackScoreIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'feedbackScore',
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition>
      feedbackScoreIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'feedbackScore',
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition>
      feedbackScoreEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'feedbackScore',
        value: value,
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition>
      feedbackScoreGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'feedbackScore',
        value: value,
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition>
      feedbackScoreLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'feedbackScore',
        value: value,
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition>
      feedbackScoreBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'feedbackScore',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition> hexCodeEqualTo(
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

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition> hexCodeGreaterThan(
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

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition> hexCodeLessThan(
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

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition> hexCodeBetween(
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

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition> hexCodeStartsWith(
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

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition> hexCodeEndsWith(
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

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition> hexCodeContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'hexCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition> hexCodeMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'hexCode',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition> hexCodeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'hexCode',
        value: '',
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition>
      hexCodeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'hexCode',
        value: '',
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition> idBetween(
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

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition>
      isReviewSyncedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isReviewSynced',
        value: value,
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition> openedDateEqualTo(
      DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'openedDate',
        value: value,
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition>
      openedDateGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'openedDate',
        value: value,
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition> openedDateLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'openedDate',
        value: value,
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition> openedDateBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'openedDate',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition> paoMonthsEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'paoMonths',
        value: value,
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition>
      paoMonthsGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'paoMonths',
        value: value,
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition> paoMonthsLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'paoMonths',
        value: value,
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition> paoMonthsBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'paoMonths',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition> productNameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'productName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition>
      productNameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'productName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition> productNameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'productName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition> productNameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'productName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition>
      productNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'productName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition> productNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'productName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition> productNameContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'productName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition> productNameMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'productName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition>
      productNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'productName',
        value: '',
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition>
      productNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'productName',
        value: '',
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition> shadeNameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'shadeName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition>
      shadeNameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'shadeName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition> shadeNameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'shadeName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition> shadeNameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'shadeName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition> shadeNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'shadeName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition> shadeNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'shadeName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition> shadeNameContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'shadeName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition> shadeNameMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'shadeName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition> shadeNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'shadeName',
        value: '',
      ));
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterFilterCondition>
      shadeNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'shadeName',
        value: '',
      ));
    });
  }
}

extension PouchItemQueryObject
    on QueryBuilder<PouchItem, PouchItem, QFilterCondition> {}

extension PouchItemQueryLinks
    on QueryBuilder<PouchItem, PouchItem, QFilterCondition> {}

extension PouchItemQuerySortBy on QueryBuilder<PouchItem, PouchItem, QSortBy> {
  QueryBuilder<PouchItem, PouchItem, QAfterSortBy> sortByBrand() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'brand', Sort.asc);
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterSortBy> sortByBrandDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'brand', Sort.desc);
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterSortBy> sortByCategory() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'category', Sort.asc);
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterSortBy> sortByCategoryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'category', Sort.desc);
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterSortBy> sortByFeedbackScore() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'feedbackScore', Sort.asc);
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterSortBy> sortByFeedbackScoreDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'feedbackScore', Sort.desc);
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterSortBy> sortByHexCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hexCode', Sort.asc);
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterSortBy> sortByHexCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hexCode', Sort.desc);
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterSortBy> sortByIsReviewSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isReviewSynced', Sort.asc);
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterSortBy> sortByIsReviewSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isReviewSynced', Sort.desc);
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterSortBy> sortByOpenedDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'openedDate', Sort.asc);
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterSortBy> sortByOpenedDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'openedDate', Sort.desc);
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterSortBy> sortByPaoMonths() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'paoMonths', Sort.asc);
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterSortBy> sortByPaoMonthsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'paoMonths', Sort.desc);
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterSortBy> sortByProductName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'productName', Sort.asc);
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterSortBy> sortByProductNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'productName', Sort.desc);
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterSortBy> sortByShadeName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'shadeName', Sort.asc);
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterSortBy> sortByShadeNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'shadeName', Sort.desc);
    });
  }
}

extension PouchItemQuerySortThenBy
    on QueryBuilder<PouchItem, PouchItem, QSortThenBy> {
  QueryBuilder<PouchItem, PouchItem, QAfterSortBy> thenByBrand() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'brand', Sort.asc);
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterSortBy> thenByBrandDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'brand', Sort.desc);
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterSortBy> thenByCategory() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'category', Sort.asc);
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterSortBy> thenByCategoryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'category', Sort.desc);
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterSortBy> thenByFeedbackScore() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'feedbackScore', Sort.asc);
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterSortBy> thenByFeedbackScoreDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'feedbackScore', Sort.desc);
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterSortBy> thenByHexCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hexCode', Sort.asc);
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterSortBy> thenByHexCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hexCode', Sort.desc);
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterSortBy> thenByIsReviewSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isReviewSynced', Sort.asc);
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterSortBy> thenByIsReviewSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isReviewSynced', Sort.desc);
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterSortBy> thenByOpenedDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'openedDate', Sort.asc);
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterSortBy> thenByOpenedDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'openedDate', Sort.desc);
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterSortBy> thenByPaoMonths() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'paoMonths', Sort.asc);
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterSortBy> thenByPaoMonthsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'paoMonths', Sort.desc);
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterSortBy> thenByProductName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'productName', Sort.asc);
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterSortBy> thenByProductNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'productName', Sort.desc);
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterSortBy> thenByShadeName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'shadeName', Sort.asc);
    });
  }

  QueryBuilder<PouchItem, PouchItem, QAfterSortBy> thenByShadeNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'shadeName', Sort.desc);
    });
  }
}

extension PouchItemQueryWhereDistinct
    on QueryBuilder<PouchItem, PouchItem, QDistinct> {
  QueryBuilder<PouchItem, PouchItem, QDistinct> distinctByBrand(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'brand', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<PouchItem, PouchItem, QDistinct> distinctByCategory(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'category', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<PouchItem, PouchItem, QDistinct> distinctByFeedbackScore() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'feedbackScore');
    });
  }

  QueryBuilder<PouchItem, PouchItem, QDistinct> distinctByHexCode(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'hexCode', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<PouchItem, PouchItem, QDistinct> distinctByIsReviewSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isReviewSynced');
    });
  }

  QueryBuilder<PouchItem, PouchItem, QDistinct> distinctByOpenedDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'openedDate');
    });
  }

  QueryBuilder<PouchItem, PouchItem, QDistinct> distinctByPaoMonths() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'paoMonths');
    });
  }

  QueryBuilder<PouchItem, PouchItem, QDistinct> distinctByProductName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'productName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<PouchItem, PouchItem, QDistinct> distinctByShadeName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'shadeName', caseSensitive: caseSensitive);
    });
  }
}

extension PouchItemQueryProperty
    on QueryBuilder<PouchItem, PouchItem, QQueryProperty> {
  QueryBuilder<PouchItem, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<PouchItem, String, QQueryOperations> brandProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'brand');
    });
  }

  QueryBuilder<PouchItem, String, QQueryOperations> categoryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'category');
    });
  }

  QueryBuilder<PouchItem, int?, QQueryOperations> feedbackScoreProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'feedbackScore');
    });
  }

  QueryBuilder<PouchItem, String, QQueryOperations> hexCodeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'hexCode');
    });
  }

  QueryBuilder<PouchItem, bool, QQueryOperations> isReviewSyncedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isReviewSynced');
    });
  }

  QueryBuilder<PouchItem, DateTime, QQueryOperations> openedDateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'openedDate');
    });
  }

  QueryBuilder<PouchItem, int, QQueryOperations> paoMonthsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'paoMonths');
    });
  }

  QueryBuilder<PouchItem, String, QQueryOperations> productNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'productName');
    });
  }

  QueryBuilder<PouchItem, String, QQueryOperations> shadeNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'shadeName');
    });
  }
}
