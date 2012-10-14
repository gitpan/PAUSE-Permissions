package PAUSE::Permissions;
use strict;
use warnings;

use Moose;
use PAUSE::Permissions::Module;
use File::Spec::Functions qw(tmpdir catfile);
use HTTP::Tiny;

has 'uri' =>
    (
     is         => 'rw',
     isa        => 'Str',
     default    => 'http://www.cpan.org/modules/06perms.txt',
    );

has 'cachedir' =>
    (
     is         => 'rw',
     isa        => 'Str',
     default    => sub {
                       my $dirpath = tmpdir() || die "can't get temp directory: $!\n";
                       my $dirname = __PACKAGE__;
                       $dirname =~ s/::/-/g;
                       my $dir = catfile($dirpath, $dirname);
                       if (! -d $dir) {
                           mkdir($dir, 0755)
                           || die "can't create cache directory $dir: $!\n";
                       }
                       return $dir;
                   },
    );

has 'filename' =>
    (
     is         => 'rw',
     isa        => 'Str',
    );

has '_path' =>
    (
     is         => 'rw',
     isa        => 'Str',
     init_arg   => undef,
    );

sub BUILD
{
    my $self = shift;

    if ($self->filename) {
        if (!-f $self->filename) {
            die "specified file (", $self->filename, ") not found\n";
        }
        $self->_path($self->filename);
    } else {
        $self->_get_uri();
    }
}

sub _get_uri
{
    my $self = shift;
    my $ua   = HTTP::Tiny->new() || die "failed to create HTTP::Tiny: $!\n";

    $self->_path(catfile($self->cachedir, '06perms.txt'));
    if (not $ua->mirror($self->uri, $self->_path)) {
        die "failed to mirror permissions file\n";
    }
    print STDERR "path = ", $self->_path, "\n";
}

sub module_permissions
{
    my $self   = shift;
    my $module = shift;
    my $fh;
    local $_;
    my $inheader = 1;
    my $seen_module = 0;
    my %perms;
    my ($m, $u, $p);

    open($fh, '<', $self->_path)
        || die "can't read local file ", $self->_path, ": $!\n";
    while (<$fh>) {
        chomp;
        if ($inheader && /^\s*$/) {
            $inheader = 0;
            next;
        }
        next if $inheader;
        ($m, $u, $p) = split(/,/, $_);
        if ($m eq $module) {
            push(@{ $perms{$p} }, $u);
            $seen_module = 1;
        }
        last if $seen_module && $m ne $module;
    }
    close($fh);

    if ($seen_module) {
        my @args;
        push(@args, m => $perms{m}->[0]) if exists $perms{m};
        push(@args, f => $perms{f}->[0]) if exists $perms{f};
        push(@args, c => $perms{c})      if exists $perms{c};
        return PAUSE::Permissions::Module->new(@args);
    }

    return undef;
}

1;

=head1 NAME

PAUSE::Permissions - interface to PAUSE's module permissions file (06perms.txt)

=head1 SYNOPSIS

  use PAUSE::Permissions;
  
  my $pp = PAUSE::Permissions->new;
  my $mp = $pp->module_permissions('HTTP::Client');
  
  my $owner    = $mp->owner;
  my @comaints = $mp->co_maintainers;

=head1 DESCRIPTION

PAUSE::Permissions provides an interface to the C<06perms.txt> file produced by
the Perl Authors Upload Server (PAUSE).
The file records who has what permissions for every module on CPAN.
The format and interpretation of this file
are covered in L</"The 06perms.txt file"> below.

By default, the module will mirror C<06perms.txt> from CPAN,
using L<HTTP::Tiny> to request it and store it locally.
By default it will get the file from L<http://www.cpan.org>, but you can
pass an alternate URI to the constructor:

  $perms_uri = "http://$CPAN_MIRROR/modules/06perms.txt";
  $pp = PAUSE::Permissions->new(uri => $perms_uri);

If you've already got a copy lying around, you can tell the module to use that:

  $pp = PAUSE::Permissions->new( filename => '/tmp/06perms.txt' );

Having created an instance of C<PAUSE::Permissions>,
you can then call the C<module_permissions> method
to get the permissions for a particular module.
The SYNOPSIS gives the basic usage.


=head1 METHODS

There are only two methods you need to know: the constructor (C<new>)
and C<module_permissions()>.

=head2 new

The constructor takes a hash of options:

=over 4

=item *

B<filename>: the path to a local copy of 06perms.txt.
The constructor will C<die()> if the file doesn't exist, or isn't readable.
If you don't provide this parameter, then we'll try and get 06perms.txt
from the C<uri> parameter.

=item *

B<uri>: the URI for 06perms.txt;
defaults to L<http://www.cpan.org/modules/06perms.txt>

=item *

B<cachedir>: if we're getting 06perms.txt from CPAN,
then this is the directory where we'll cache the file locally.
By default we call C<tmpdir()> from L<File::Spec>,
and append C<PAUSE-Permissions>.

=back

So you might use the following,
to get C<06perms.txt> from your 'local' CPAN mirror and store it somewhere
of your choosing:

  $pp = PAUSE::Permissions->new(
                uri     => 'http://cpan.inode.at/modules/06perms.txt',
                cachdir => '/tmp/pause',
            );

=head2 module_permissions

The C<module_permissions> method takes a single module name,
and returns an instance of L<PAUSE::Permissions::Module>:

  $mp = $pp->module_permissions( $module_name );

Refer to the documentation for L<PAUSE::Permissions::Module>,
but the key methods are:

=over 4

=item *

C<owner()>
returns the PAUSE id of the owner (see L</"The 06perms.txt file"> below),
or C<undef> if there isn't a defined owner.

=item *

C<co_maintainers()>
returns a list of PAUSE ids, or an empty list if the module has no co-maintainers.

=back

It returns C<undef> if the module wasn't found in the permissions list.

=head1 The 06perms.txt file

You can find the file on CPAN:

=over 4

L<http://www.cpan.org/modules/06perms.txt>

=back

As of October 2012 this file is 8.4M in size.

The file starts with a header, followed by one blank line, then the body.
The body contains one line per module per user:

  Config::Properties,CMANLEY,c
  Config::Properties,RANDY,f
  Config::Properties,SALVA,m

Each line has three values, separated by commas:

=over 4

=item *

The name of a module.

=item *

A PAUSE user id, which by convention is always given in upper case.

=item *

A single character that specifies what permissions the user has with
respect to the module. See below.

=back

Note that this file lists I<modules>, not distributions.
Every module in a CPAN distribution will be listed in this file.
Modules are listed in alphabetical order, and for a given module,
the PAUSE ids are listed in alphabetical order.

There are three characters that can appear in the permissions column:

=over 4

=item *

B<C<'m'>> identifies the user as the registered I<maintainer> of the module.
A module can only ever have zero or one user listed with the 'm' permission.
For more details on registering a module,
see L<04pause.html|http://www.cpan.org/modules/04pause.html#namespace>.

=item *

B<C<'f'>> identifies the user as the I<first> person to upload the module to CPAN.
You don't have to register a module before uploading it, and ownership
in this case is first-come-first-served.
A module can only ever have zero or one user listed with the 'f' permission.

=item *

B<C<'c'>> identifies the user as a I<co-maintainer> of the module.
A module can have any number of co-maintainers.

=back

If you first upload a module, you'll get an 'f' against you in the file.
If you subsequently register the module, you'll get an 'm' against you.
Internally PAUSE will have you recorded with both an 'm' and an 'f',
but C<06perms.txt> only lists the highest precedence permission for each user.

=head2 What do the permissions mean?

=over 4

=item *

Various places refer to the 'owner' of the module.
This will be either the 'm' or 'f' permission, with 'm' taking precedence.
If a module has both an 'm' and an 'f' user listed, then the 'm' user
is considered the owner, and the 'f' user isn't.
If a module has a user with 'f' listed, but no 'm', then the 'f' user is
considered the owner.

=item *

If a module is listed in 06perms.txt, then only the people listed (m, f, or c)
are allowed to upload (new) versions of the module.
If anyone else uploads a version of the module, then the offending I<distribution> will not be indexed:
it will appear in the uploader's directory on CPAN, but won't be indexed under the module.

=item *

Only the owner for a module can grant co-maintainer status for a module.
I.e. if you have the 'm' permission, you can always do it.
If you have the 'f' permission, you can only do it if no-one else has
the 'm' permission.
You can grant co-maintainer status using the PAUSE web interface.

=item *

Regardless of your permissions, you can only remove things from CPAN that
you uploaded. If you're the owner, you can't delete a version uploaded
by a co-maintainer. If you weren't happy with it, you could revoke their
co-maintainer status and then upload a superseding version. But we'd
recommend you talk to them (first).

=item *

If you upload a distribution containing a number of previously unseen modules,
and haven't pre-registered them,
then you'll get an 'f' permission for all of the modules.
Let's say you upload a second release of the distribution,
which doesn't include one of the modules,
and then delete the first release from CPAN (via the PAUSE web interface).
After some time the module will no longer be on CPAN,
but you'll still have the 'f' permission in 06perms.txt.
You can free up the namespace using the PAUSE interface ("Change Permissions").

=item *

If your first upload of a module is a
L<Developer Release|http://www.cpan.org/modules/04pause.html#developerreleases>,
then you won't get permissions for the module.
You don't get permissions for a module until you've uploaded a non-developer
release containing the module,
that was accepted for indexing.

=item *

If you L<take over|http://www.cpan.org/modules/04pause.html#takeover> maintenance
of a module, then you'll generally be given the permissions of the previous maintainer.
So if the previous maintainer had 'm', then you'll get 'm', and (s)he will be
downgraded to 'c'.
If the previous maintainer had 'f', then you'll get 'f', and the previous owner
will be downgraded to 'c'.

=back

=head1 SEE ALSO

C<tmpdir()> in L<File::Spec::Functions> is used to get a local directory for
caching 06perms.txt.

L<HTTP::Tiny> is used to mirror 06perms.txt from CPAN.

=head1 TODO

=over 4

=item *

Request the file gzip'd, if we've got an appropriate module that can be used
to gunzip it.

=item *

At construct time we currently mirror the file;
should do this lazily, triggering it the first time you want a module's perms.

=item *

Every time you ask for a module, I scan the file from the start, then close it
once I've got the details for the requested module. Would be a lot more efficient
to keep the file open and start the search from there, as the file is sorted.
A binary chop on the file would be much more efficient as well.

=item *

The 06perms.txt file is currently mirrored with an If-Modified-Since request.
We should probably also support a mechanism for saying things like "only get it if
my copy is more than N days old". And consider using rsync as well.

=item *

A command-line script.

=back

=head1 REPOSITORY

L<https://github.com/neilbowers/PAUSE-Permissions>

=head1 AUTHOR

Neil Bowers E<lt>neilb@cpan.orgE<gt>

Thanks to Andreas König, for patiently answering many questions
on how this stuff all works.

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Neil Bowers <neilb@cpan.org>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

