#!/usr/bin/env perl
use strict;
use warnings;
use v5.16;
use ULID::Tiny qw(ulid ulid_date);
use Time::HiRes qw(time);

my %opts = (
	unique => 1,
);

# Generate a ULID and inspect it
for (1 .. 5) {
	my $id = ulid(%opts);
	say "Generated: $id";
	#say "Length   : " . length($id);
}
