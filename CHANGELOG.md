# Changelog

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
