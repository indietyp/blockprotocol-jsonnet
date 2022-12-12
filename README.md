# BlockProtocol Type Definitions

This repo provides a template for defining different types in the block-protocol system using various functions.

This is all based on `jsonnet`, a lazily evaluated templating language that outputs `JSON`.

## Getting Started

1. Clone or fork this repo
2. Your entities go in `entities/`, your links in `links/`, your properties in `properties/` your data types (currently
   unsupported) in `data/`
3. Install `jq` and `jsonnet` (macOS: `brew install jq go-jsonnet`)
4. Define library entrypoint
5. Define your types
6. Upload your types via `sh scripts/create.sh`

## Defining the Library Entrypoint

This library is not immediately usage, first you must create a new library under `lib/` with a name of your choosing. It
should roughly contain:

```jsonnet
local blockprotocol = import 'blockprotocol.libsonnet';

local org1 = blockprotocol.makeModule('<HOST>', '<ORG>');
local bp = blockprotocol.makeModule('https://blockprotocol.org', 'blockprotocol', bare=true);

blockprotocol {
  org1: org1,
  bp: bp {
    builtin: {
      text: bp.data('text', version=1),
      number: bp.data('number', version=1),
      boolean: bp.data('boolean', version=1),
      'null': bp.data('null', version=1),
      object: bp.data('object', version=1),
      emptyList: bp.data('empty-list', version=1),
    },
  },
}
```

You can create as many organisations as you want and name them whatever you want, this makes defining types later a lot
easier. The block protocol defines some common built-in types, it is not required, but advised to also create
shortcuts (as seen via `builtin`) for later use in property types.

## Defining Types

Types are defined once per file, this enables easier dependency resolution. The convention is that the file is called
like the id of the type it represents, e.g. property type `abbreviation` would be located
in `properties/abbreviation.jsonnet`. (_Note: technically the name can be anything, this just makes finding types
easier_)

In the following code snippets `org1` would be the name you
chose [in the previous section](#defining-the-library-entrypoint).

### Defining Entity Types

Entity types are defined through `lib.org1.make.entityType(...)`, with the following signature:

```typescript
type PropRef = PropertyType | string;
type LinkRef = LinkType | string;

type Link = ReturnType<LinkRefHelper>;
type Properties = PropRef[];

interface Arguments {
    id: string,
    title: string,
    properties: Properties,
    required?: PropRef[],     // default = []
    description?: string,     // default = null
    version?: number,         // default = 1
    links?: Link[],           // default = []
    requiredLinks?: LinkRef[] // default = []
}
```

Arguments can be supplied as arguments or keyword arguments, although keyword arguments are preferred.

To make it easier to reference links (and their constraints) a helper function can be used (`lib.entityType.link(...)`),
with the following signature:

```typescript
// Definition for `LinkRefHelper`

type LinkRef = LinkType | string;
type EntityRef = EntityType | string;

interface Arguments {
    ref: LinkRef | null,
    oneOf?: EntityRef[],                   // default: null
    count?: { min?: number, max?: number } // default: {count: {min: null, max: null}},
    ordered?: boolean                      // default: false
}
```

#### Example

```jsonnet
local lib = import '../lib/prelude.libsonnet';

local person = import '../entities/person.jsonnet';

local name = import '../properties/name.jsonnet';
local description = import '../properties/description.jsonnet';

local contains = import '../links/contains.jsonnet';

lib.org1.make.entityType(
  id='category',
  title='Category',
  properties=[
    name,
    description
  ],
  required=[name],
  links=[
    lib.entityType.link(ref=contains, oneOf=[person], count={max: 3}, ordered=true)
  ],
  requiredLinks=[contains]
)
```

### Defining Property Types

Properties types are defined through `lib.org1.make.propertyType(...)`, which has the following signature:

```typescript
type OneOf = ReturnType<PropertyTypeObjectHelper>
    | ReturnType<PropertyTypeArrayHelper>
    | DataType
    | string;

interface Arguments {
    id: string,
    title: string,
    oneOf: OneOf[],
    description?: string,     // default = null
    version?: number,         // default = 1
}
```

To make it easier to create objects the `lib.propertyType.object(...)` helper can be used, which has the following
signature:

```typescript
interface Arguments {
    properties: Properties // same as `.entityType()` properties
    required?: PropRef[]   // default: []
}
```

To make it easier to create arrays the `lib.propertyType.array(...)` helper can be used, which has the following
signature:

```typescript
interface Arguments {
    items: OneOf[],
    count?: { min?: number, max?: number } // default: {count: {min: null, max: null}},
}
```

#### Example

```jsonnet
local lib = import '../lib/mpicbg.libsonnet';

local firstName = import 'firstName.jsonnet';
local lastName = import 'lastName.jsonnet';
local middleName = import 'middleName.jsonnet';

lib.mpi.make.propertyType(
  id='fullName',
  title='Full Name',
  oneOf=[
    lib.propertyType.object(
      properties=[firstName, middleName, lastName],
      required=[firstName, lastName]
    ),
    lib.bp.builtin.text,
    lib.propertyType.array(items=[lib.bp.builtin.text], count={min: 1})
  ]
)
```

### Defining Link Types

Defining links is done over `lib.org1.make.linkType()` the arguments are the same
as [entity types](#defining-entity-types).

## Reference Types

All functions take the object created through the `make` functions as arguments, but sometimes one might want to
reference types outside of the ones defined locally. This can be done through the `.data`, `.property`, `.entity`
function on every created module. They take the id of the type as the first argument and then as a second argument
optional argument for the version selected, this argument defaults to `1`.

## Upload Types

The `create.sh` script creates all types by calling the `REST` endpoints of the graph API, this script supports two
modes: user input and no user input, to completely remove user input one must call the script with the following
environment variables set:

```
GRAPH_URL
API_URL
BACKEND_URL
SESSION_TOKEN (optional if USERNAME and PASSWORD given)
if SESSION_TOKEN not given:
   USERNAME
   PASSWORD
```

This script will first sort all files by their imports, then login the user to HASH and then create all types

> Updating types is currently not supported.

To only list the order of files required execute the `find-deps.sh` script instead.

<sup>You made it to the end, good job! <3</sup>
