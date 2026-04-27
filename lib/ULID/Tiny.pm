package ULID::Tiny;

use strict;
use warnings;
use v5.16;

use Crypt::SysRandom qw(random_bytes);
use Time::HiRes qw(time);

use Exporter 'import';

our $VERSION = '1.0.1';

our @EXPORT    = qw(ulid ulid_date);
our @EXPORT_OK = qw(ulid ulid_date);

my @CROCKFORD_CHARS = split //, '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
my %CROCKFORD_VAL;
@CROCKFORD_VAL{@CROCKFORD_CHARS} = (0 .. $#CROCKFORD_CHARS);

###############################################################################
# Public API
###############################################################################

sub ulid {
	my (%opts) = @_;

	my $time = $opts{time} // (time() * 1000);
	my $ts   = _encode_timestamp($time);
	my $rand = random_bytes(10);

	state $prev_ts   = 0;
	state $prev_ulid = "";

	my $ret = '';
	if (!$opts{unique} && $prev_ts && ($ts eq $prev_ts)) {
		$ret = _crockford_increment($prev_ulid);
	} else {
		# 48 bits of timestamp + 80 bits of randomness
		my $raw = $ts . $rand;

		$ret = _crockford_encode($raw);
	}

	if (!$opts{unique}) {
		$prev_ts   = $ts;
		$prev_ulid = $ret;
	}

	if ($opts{binary}) {
		my $bits = _crockford_decode_bits($ret);
		$bits = substr($bits, 0, 128);
		return pack("B*", $bits);
	}

	return $ret;
}

# Extract the millisecond epoch timestamp from a ULID string
sub ulid_date {
	my ($ulid_str) = @_;

	if (!defined $ulid_str || length($ulid_str) != 26) {
		die "Invalid ULID: must be exactly 26 characters";
	}

	# The first 10 characters of a ULID encode the 48-bit timestamp.
	# 10 Crockford chars = 50 bits, but only the top 48 are the timestamp
	# (the encoder right-pads 2 zero bits to reach a multiple of 5).
	my $time_part = substr($ulid_str, 0, 10);
	my $raw       = _crockford_decode_int($time_part);
	my $ms        = $raw >> 2; # discard the 2 padding bits

	return $ms;
}

###############################################################################
# Internal functions
###############################################################################

sub _crockford_increment {
    my ($str) = @_;

    my @out   = reverse split //, uc($str);
    my $carry = 1;

    for my $i (0 .. $#out) {
        last unless $carry;

        my $v  = $CROCKFORD_VAL{$out[$i]};
        $v    += $carry;

        if ($v >= 32) {
            $out[$i] = $CROCKFORD_CHARS[0];
            $carry   = 1;
        } else {
            $out[$i] = $CROCKFORD_CHARS[$v];
            $carry   = 0;
        }
    }

	if ($carry) {
		die "ULID monotonic overflow: cannot increment beyond the maximum ULID value";
	}

	my $result = join('', reverse @out);

	# Per the ULID spec the maximum valid ULID is 7ZZZZZZZZZZZZZZZZZZZZZZZZZ.
	# 26 Crockford chars encode 130 bits but ULID is only 128 bits, so the
	# first character must not exceed '7' (value 7, binary 00111).
	if (substr($result, 0, 1) > 7) {
		die "ULID monotonic overflow: cannot increment beyond the maximum ULID value";
	}

	return $result;
}

sub _crockford_encode {
    my ($bytes) = @_;
    my $bits    = unpack("B*", $bytes);
    my $result  = '';

    # Pad bits to multiple of 5
    my $pad = (5 - (length($bits) % 5)) % 5;
    $bits .= '0' x $pad;

    for (my $i = 0; $i < length($bits); $i += 5) {
        my $chunk = substr($bits, $i, 5);
        my $index = 0;
        for my $bit (split //, $chunk) {
            $index = ($index << 1) | $bit;
        }

        $result .= $CROCKFORD_CHARS[$index];
    }

    return $result;
}

# Decode a Crockford Base32 string to a decimal integer (for timestamps)
sub _crockford_decode_int {
    my ($str) = @_;

    my $n = 0;
    for my $ch (split //, uc($str)) {
        $n = $n * 32 + ($CROCKFORD_VAL{$ch} // die "Invalid Crockford character: $ch");
    }

    return $n;
}

# Decode a Crockford Base32 string to a binary bit string
sub _crockford_decode_bits {
    my ($str) = @_;

    my $bits = '';
    for my $ch (split //, uc($str)) {
        my $v = $CROCKFORD_VAL{$ch} // die "Invalid Crockford character: $ch";
        $bits .= sprintf("%05b", $v);
    }

    return $bits;
}

sub _encode_timestamp {
    my ($epoch_ms) = @_;

	my $ret = substr(pack("Q>", $epoch_ms), 2, 6);

	return $ret;
}

1;

__END__

=head1 NAME

ULID::Tiny - A lightweight ULID (Universally Unique Lexicographically Sortable
Identifier) generator

=head1 SYNOPSIS

    use ULID::Tiny qw(ulid ulid_date);

    # Generate a new ULID
    my $ulid = ulid(); # e.g. "01ARZ3NDEKTSV4RRFFQ69G5FAV"

    # Generate a ULID using a specific timestamp (milliseconds since epoch)
    my $ulid = ulid(time => 1234567890000);

    # Generate a raw, 16 byte, binary ULID
    my $bytes = ulid(binary => 1);

    # Extract the timestamp from a ULID (returns milliseconds since epoch)
    my $ms = ulid_date($ulid);

=head1 DESCRIPTION

ULID::Tiny is a minimal, pure Perl, dependency-light module for generating
ULIDs.

A ULID is a 128-bit identifier consisting of:

=over 4

=item * 48-bit millisecond timestamp (first 10 characters)

=item * 80-bit cryptographic randomness (last 16 characters)

=back

Key properties:

=over 4

=item * Lexicographically sortable

=item * Canonically encoded as a 26 character string

=item * Monotonically increasing within the same millisecond

=back

https://github.com/ulid/spec

=head1 METHODS

=over 4

=item B<ulid(%opts)>

Generate a new ULID string. Options:

=over 4

=item * C<time> - Specify timestamp in milliseconds. Defaults to current time.

=item * C<binary> - Returns the raw 16-byte binary ULID instead of an
alpha-numeric string.

=back

=item B<ulid_date($ulid_string)>

Extract the timestamp from a ULID string. Returns the number of milliseconds
since the Unix epoch.

=back

=head1 LICENSE

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

# vim: tabstop=4 shiftwidth=4 noexpandtab autoindent softtabstop=4
