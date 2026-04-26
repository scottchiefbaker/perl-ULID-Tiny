## Name

ULID::Tiny - A lightweight ULID (Universally Unique Lexicographically Sortable Identifier) generator

## Synopsis

```perl
use ULID::Tiny qw(ulid ulid_date);

# Generate a new ULID
my $id = ulid(); # e.g. "01ARZ3NDEKTSV4RRFFQ69G5FAV"

# Generate a ULID with a specific timestamp (milliseconds since epoch)
my $id = ulid(time => 1234567890000);

# Extract the timestamp from a ULID (returns milliseconds since epoch)
my $ms = ulid_date($id);

# Generate a ULID in raw 16-byte binary form
my $bytes = ulid(binary => 1);
```

## Description

ULID::Tiny is a minimal, dependency-light Perl module for generating ULIDs
as defined by [https://github.com/ulid/spec](https://github.com/ulid/spec).

A ULID is a 128-bit identifier consisting of:

- 48-bit millisecond timestamp (first 10 characters)
- 80-bit cryptographic randomness (last 16 characters)

Key properties:

- Lexicographically sortable
- Canonically encoded as a 26-character Crockford Base32 string
- Monotonically increasing within the same millisecond
- 1.21e+24 unique ULIDs per millisecond

## Functions

### Ulid(%Opts)

Generate a new ULID string. Options:

- `time` - Epoch timestamp in milliseconds. Defaults to current time.
- `unique` - If true, generates a completely random ULID (no monotonic incrementing) even within the same millisecond.
- `binary` - If true, returns the raw 16-byte binary ULID instead of a string.

ULIDs generated within the same millisecond are monotonically incremented
(per the ULID spec) to guarantee sort order and uniqueness within a process.

### Ulid\_Date($Ulid\_String)

Extract the timestamp from a ULID string. Returns the number of milliseconds
since the Unix epoch.

## Randomness

The module attempts to use the best available entropy source:

- 1. `getrandom(2)` syscall (Linux)
- 2. `/dev/urandom`
- 3. Perl's `rand()` as a last resort

## Version

1.0.0

## License

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
