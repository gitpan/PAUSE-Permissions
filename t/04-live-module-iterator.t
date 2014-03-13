#!perl

use strict;
use warnings;

use Test::More 0.88 tests => 3;
use PAUSE::Permissions;
use File::Slurp;

#-----------------------------------------------------------------------
# construct PAUSE::Permissions
#-----------------------------------------------------------------------

my $pp;

eval { $pp = PAUSE::Permissions->new(); };


SKIP: {
    skip("looks like you're offline", 3) if $@;

    ok(defined($pp), "instantiate PAUSE::Permissions");

    #-----------------------------------------------------------------------
    # construct the iterator
    #-----------------------------------------------------------------------
    my $iterator = $pp->module_iterator();

    ok(defined($iterator), 'create module iterator');

    #-----------------------------------------------------------------------
    #-----------------------------------------------------------------------
    my $string = '';

    while (my $entry = $iterator->next_module) {
        next unless $entry->name =~ /^enum/i;

        $string .= 'module='.($entry->name // 'undef')."\n"
                   ."----\n"
                   ;
    }

    my $expected = <<'END_EXPECTED';
module=enum
----
module=Enum
----
module=enum
----
module=enum::fields
----
module=enum::fields::extending
----
module=enum::hash
----
module=EnumElement
----
module=Enumerable
----
module=Enumeration
----
module=EnumType
----
END_EXPECTED

    is($string, $expected, "rendered permissions");
}

