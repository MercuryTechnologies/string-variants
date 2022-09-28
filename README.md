# String Variants

This library provides newtypes of Text for use in application code:

- `NonEmptyText`: a not-empty not-completely-whitespace, length limited newtype
  over Text
- `NullableNonEmptyText`: a NonEmptyText that may be empty or absent. This is
  used for JSON parsing as `Maybe NullableNonEmptyText`.
- `Prose`: a whitespace-stripped newtype over Text

This library is not API stable or fully documented yet, however it is
used in production code. Breaking changes may be introduced with major version
updates.
