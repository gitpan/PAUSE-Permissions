package PAUSE::Permissions::ModuleIterator;
$PAUSE::Permissions::ModuleIterator::VERSION = '0.08';
use strict;
use warnings;
use 5.10.0;

use Moo;
use PAUSE::Permissions::Module;
use autodie;
use feature 'state';

has 'permissions' =>
    (
        is      => 'ro',
        # isa     => 'PAUSE::Permissions',
    );

sub next_module
{
    my $self        = shift;
    my $line;
    my $current_module;
    state $fh;
    state $cached_line;

    if (not defined $fh) {
        open($fh, '<', $self->permissions->path);
        my $inheader = 1;

        # Skip the header block at the top of the file
        while (<$fh>) {
            last if /^$/;
        }
    }

    my $perms = {};
    while (1) {
        if (defined $cached_line) {
            $line = $cached_line;
            $cached_line = undef;
        } else {
            $line = <$fh>;
        }

        if (defined($line)) {
            $line =~ s/[\r\n]+$//;
            my ($module, $user, $permission) = split(/,/, $line);
            if (defined($current_module) && $module ne $current_module) {
                $cached_line    = $line;
                my $module_name = $current_module;
                $current_module = undef;
                return $self->_new_module($module_name, $perms);
            }
            $current_module = $module;
            push(@{ $perms->{ $permission } }, $user);
        } elsif (defined $current_module) {
            return $self->_new_module($current_module, $perms);
        } else {
            return undef;
        }
    }

}

sub _new_module
{
    my $self        = shift;
    my $module_name = shift;
    my $perms       = shift;
    my @args        = (name => $module_name);

    push(@args, m => $perms->{m}->[0]) if exists($perms->{m});
    push(@args, f => $perms->{f}->[0]) if exists($perms->{f});
    push(@args, c => $perms->{c})      if exists($perms->{c});

    return PAUSE::Permissions::Module->new(@args);
}

1;
