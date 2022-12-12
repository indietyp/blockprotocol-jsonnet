local ref(base, user, type, id, version=1, bare=false) = base + '/@' + user + '/' + (if bare then "" else "types/") + type + '/' + id + (if version == null then '/' else '/v/' + version);
local propRef(base, user, id, version=1, bare=false) = ref(base, user, 'property-type', id, version);
local entityRef(base, user, id, version=1, bare=false) = ref(base, user, 'entity-type', id, version);
local dataRef(base, user, id, version=1, bare=false) = ref(base, user, 'data-type', id, version);

local intoRef(properties) = std.map(
  function(prop)
    if std.isObject(prop) && std.objectHasAll(prop, 'magic') then
      prop['$id']
    else
      prop,
  properties
);

local intoRequiredRef(properties) = std.map(
  function(prop)
    if std.isObject(prop) && std.objectHasAll(prop, 'magic') then
      std.get(prop, "key", inc_hidden=true)
    else
      prop,
  properties
);

// properties are a bit special, they need a trailing slash and are without version
local intoPropertyRef(properties) = std.map(
  function(prop)
    if std.isObject(prop) && std.objectHasAll(prop, 'magic') then
      [std.get(prop, "key", inc_hidden=true), {'$ref': prop['$id']}]
    else
      prop,
  properties
);

local makeProperties(properties) = std.foldr(
  function(prop, acc) acc + (
    if std.isString(prop) then
      { [prop]: { '$ref': prop } }
    else
      { [prop[0]]: prop[1] }
  ),
  intoPropertyRef(properties),
  {}
);

local makeOneOf(properties) = std.map(
  function(prop) (
    if std.isString(prop) then
      { '$ref': prop }
    else if std.isObject(prop) && std.objectHasAll(prop, 'internal') then
      prop
    else
      { [prop[0]]: prop[1] }
  ),
  intoRef(properties)
);

local makeRefArray(refArray) = std.map(
  function(prop) (
    if std.isString(prop) then
      { '$ref': prop }
    else
      { [prop[0]]: prop[1] }
  ),
  intoRef(refArray)
);

local makeType(base, user) = {
  entityType: function(id, title, properties, required=[], description=null, version=1, links=[], requiredLinks=[], inheritsFrom=null) {
    kind: 'entityType',
    type: 'object',
    '$id': entityRef(base, user, id, version),
    title: title,
    description: description,
    properties: makeProperties(properties),
    allOf: if inheritsFrom == null then [] else makeRefArray(inheritsFrom),
    required: intoRequiredRef(required),
    links: std.foldr(function(acc, prop) acc + prop, links, {}),
    requiredLinks: intoRef(requiredLinks),
    magic:: true
  },
  propertyType: function(id, title, oneOf, description=null, version=1) {
    kind: 'propertyType',
    '$id': propRef(base, user, id, version),
    title: title,
    description: description,
    oneOf: makeOneOf(oneOf),
    magic:: true,
    key:: propRef(base, user, id, version=null)
  },
  linkType: function(id, title, properties, required=[], description=null, version=1, links=[], requiredLinks=[])
    self.entityType(
      id,
      title,
      properties,
      required,
      description,
      version,
      links,
      requiredLinks,
      ['https://blockprotocol.org/@blockprotocol/types/entity-type/link/v/1']
    ),
  dataType: function(id, title, description, version=1, inheritsFrom=[], schema={}) schema {
    kind: 'dataType',
    '$id': dataRef(base, user, id, version),
    title: title,
    description: description,
    inheritsFrom: {
      allOf: intoRef(inheritsFrom),
    },
    magic:: true,
  },
};

local propertyTypeObject(properties, required) = {
  type: 'object',
  properties: makeProperties(properties),
  required: intoRequiredRef(required),
  internal:: true,
};

local propertyTypeArray(items, count={ min: null, max: null }) = {
  type: 'array',
  items: {
    oneOf: items,
  },
  minItems: if std.objectHas(count, 'min') then count.min,
  maxItems: if std.objectHas(count, 'max') then count.max,
  internal:: true,
};

local entityTypeLink(ref, oneOf=null, count={ min: null, max: null }, ordered=false) = {
  [intoRef([ref])[0]]: {
    type: 'array',
    items: if oneOf == null then null else { oneOf: intoRef(oneOf) },
    minItems: if std.objectHas(count, 'min') then count.min,
    maxItems: if std.objectHas(count, 'max') then count.max,
    ordered: ordered,
  },
};

local bindRegistry(base, bare=false) = function(user) {
  property: function(id, version=1) propRef(base, user, id, version, bare),
  entity: function(id, version=1) entityRef(base, user, id, version, bare),
  data: function(id, version=1) dataRef(base, user, id, version, bare),
  make: makeType(base, user),
};

{
  makeRegistry: bindRegistry,
  makeModule: function(base, user, bare=false) bindRegistry(base, bare)(user),
  propertyType: {
    object: propertyTypeObject,
    array: propertyTypeArray,
  },
  entityType: {
    link: entityTypeLink,
  },
}
