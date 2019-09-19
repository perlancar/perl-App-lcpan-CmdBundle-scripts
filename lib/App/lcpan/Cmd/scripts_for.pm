package App::lcpan::Cmd::scripts_for;

# DATE
# VERSION

use 5.010;
use strict;
use warnings;

require App::lcpan;
use Clone::Util qw(clone);
use Hash::Subset qw(hash_subset);

our %SPEC;

my %rel_args   = %{ clone \%App::lcpan::rdeps_rel_args };
$rel_args{rel}{default} = 'requires';
my %phase_args = %{ clone \%App::lcpan::rdeps_phase_args };
$phase_args{phase}{default} = 'runtime';
my %level_args = %{ clone \%App::lcpan::rdeps_level_args };
delete $level_args{level}{cmdline_aliases}{l};

$SPEC{'handle_cmd'} = {
    v => 1.1,
    summary => 'Try to find whether there are scripts (CLIs) for a module',
    description => <<'_',

Utilizing distribution metadata information, this subcommand basically just
tries to find distributions that depend on the module and has some scripts as
well. It's not terribly accurate, but it's better than nothing. Another
alternative might be to scan the script's source code finding use/require
statement for the module, but that method has its drawbacks too.

_
    args => {
        %App::lcpan::common_args,
        %App::lcpan::mod_args,
        %App::lcpan::detail_args,
        %rel_args,
        %phase_args,
        %level_args,
    },
};
sub handle_cmd {
    my %args = @_;

    my $state = App::lcpan::_init(\%args, 'ro');
    my $dbh = $state->{dbh};

    my $detail = $args{detail};

    my $res = App::lcpan::rdeps(
        hash_subset(\%args, \%App::lcpan::common_args),
        modules => [$args{module}],
        phase   => $args{phase},
        rel     => $args{rel},
        level   => $args{level},
    );

    return [500, "Can't rdeps: $res->[0] - $res->[1]"]
        unless $res->[0] == 200;

    return [200, "OK", []] unless @{ $res->[2] };

    my $sth = $dbh->prepare("SELECT
  script.name name,
  dist.name dist,
  script.abstract abstract
FROM script
LEFT JOIN file ON script.file_id=file.id
LEFT JOIN dist ON file.id=dist.file_id
WHERE dist.name IN (".join(",", map {$dbh->quote($_->{dist})} @{$res->[2]}).")
ORDER BY name DESC");
    $sth->execute();

    my @res;
    while (my $row = $sth->fetchrow_hashref) {
        push @res, $detail ? $row : $row->{name};
    }
    my $resmeta = {};
    $resmeta->{'table.fields'} = [qw/name dist abstract/]
        if $detail;
    [200, "OK", \@res, $resmeta];
}

1;
# ABSTRACT:
