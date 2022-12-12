# BlockProtocol Type Definitions

This repo provides a template for defining different types in the block-protocol system using various functions.

This is all based on `jsonnet`, a lazily evaluated templating language that outputs `JSON`.

## Getting Started

1. Clone or fork this repo
2. Your entities go in `entities/`, your links in `links/`, your properties in `properties/` your data types (currently unsupported) in `data/`
3. Install `jq` and `jsonnet` (macOS: `brew install jq go-jsonnet`)
4. Define your types
5. Upload your types via `sh scripts/create.sh`

## Defining Types
