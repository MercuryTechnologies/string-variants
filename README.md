# String Variants

This library provides newtypes of Text for use in application code:

- `NonEmptyText`: a not-empty not-completely-whitespace, length limited newtype
  over Text
- `NullableNonEmptyText`: a NonEmptyText that may be empty, totally whitespace,
  or even null while still successfully parsing as `NullableNonEmptyText Nothing`.
  As of `aeson-2.2.0.0`, fields of this type are optional for records using a
  `Data.Aeson.Options` with `omitNothingFields == True`.
  If using `aeson <2.2.0.0`, use `Maybe NullableNonEmptyText` if you want the
  field to be optional.
- `Prose`: a whitespace-stripped newtype over Text

This library is not API stable or fully documented yet, however it is
used in production code. Breaking changes may be introduced with major version
updates.
