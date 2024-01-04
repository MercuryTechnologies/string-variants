# Changelog

## [0.3.0.1] - 2024-01-03

- Add support for GHC 9.6

## [0.3.0.0] - 2023-10-24

- Remove incorrect `Semigroup` instance for `NonEmptyText`

## [0.2.2.1] - 2023-06-20

- Add support for `aeson-2.2.0.0`.
- When built with `aeson >=2.2.0.0`, record fields with type `NullableNonEmptyText` will be omittable.

## [0.2.2.0] - 2023-02-10

- Add `proseFromNonEmptyText` to create `Prose` from `NonEmptyText`.

## [0.2.1.0] - 2023-01-23

- Use `NonEmptyList` for `chunksOfNonEmptyText`

## [0.2.0.0] - 2022-12-05

- Add `literalNonEmptyText`, `literalProse`, `literalNullableNonEmptyText` for creation of string variants from the type-level literals.
- Add `concatWithSpace` to concatenate NonEmptyText in a type-safe way.
- Drop support for GHC <9.2.

## [0.1.0.2] - 2022-10-18

- Fix `mkNonEmptyTextWithTruncate` to perform truncation after character stripping.

## [0.1.0.1] - 2022-09-29

- Fix building on GHC 8.10.7, and add it to CI.

## [0.1.0.0] - 2022-09-28

- Initial release
