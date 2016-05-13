
#
# FS::Idx::App : application class for 'fsidx' FS::Idx tool
#
# $Id$
#

package FS::Idx::App;

use Carp;
use warnings;
use strict;

use Fcntl;
use Getopt::Std;

use FS::Idx;

sub _usage_exit {
	my $app;
	( $app = $0 ) =~ s:.*/::;
	print "Usage: $app [-C db|-R db|-U db] [path[...]]\n";
	exit 0;
}

sub _dump_args {
	my $self = shift;
	my $opts = $self->{opts};
	print "C: " . $opts->{C} . "\n" if defined $opts->{C};
	print "R: " . $opts->{R} . "\n" if defined $opts->{R};
	print "U: " . $opts->{U} . "\n" if defined $opts->{U};
}

sub _dump_opts {
	my $self = shift;
	my $opts = $self->{opts};
	foreach my $key (sort keys %{$opts}) {
		if($key eq 'paths'){
			print "$key\n";
			foreach my $p (@{$opts->{$key}}) {
				print "  path => " . $p . "\n";
			}
		}
		else {
			print "$key => " . $opts->{$key} . "\n";
		}
	}
}

sub _newidx { # _newidx(flags)
	my $self = shift;
	my $flags = shift;
	my $opts = $self->{opts};
	my $dbp = $opts->{dbfile};
	my $dbobj;

	$dbobj = FS::Idx->new($dbp, $flags);
	croak "Error: couldn't create FS::Idx('$dbp'): $!\n" unless $dbobj;

	return $dbobj;
}

sub _doidx { # _doidx()
	my $self = shift;
	my $opts = $self->{opts};
	foreach my $p (@{$opts->{'paths'}}) {
		$self->{dbobj}->index($p);
	}
	return 0;
}

sub _create {
	my $self = shift;
	my $dbobj = $self->_newidx(O_CREAT|O_EXCL);

	$self->{dbobj} = $dbobj;

	return $self->_doidx();
}

sub _read {
	my $self = shift;
	my $opts = $self->{opts};
	
	my $dbobj = $self->_newidx();
	$self->{dbobj} = $dbobj;

	my $rx = '';
	my $fnmatch = sub { return 1; }; # match everything

	if(scalar @{$opts->{'paths'}} > 0){ # unless given matchers
		$rx = "(";
		foreach my $p (@{$opts->{'paths'}}) {
			$rx .= "$p|";
		}
		chop $rx;
		$rx .= ")";

		$fnmatch = sub {
			my $key = shift;
			return $key =~ m:$rx: ? 1 : 0;
		};
	}

	return $dbobj->_dumpguts($fnmatch);
}

sub _update {
	my $self = shift;
	my $dbobj = $self->_newidx();

        $self->{dbobj} = $dbobj;

        return $self->_doidx();
}

sub _process {
	my $self = shift;
	my $opts = $self->{opts};
	my $act;

	($act = $opts->{action}) =~ s:^:_:;
	my $fn = \&$act;

	if($act =~ m:^_(create|read|update)$:) {
		return &$fn($self);
	}
	else {
		confess "unknown action: $act\n";
	}
}

sub _parse_opts { # XXX: not threadsafe - ARGV modified
	
	my $self = shift;
	my $opts = $self->{opts};

	my $OLDV =  [ @ARGV ];
	getopts( 'C:R:U:', $self->{opts} ); # -(C)reate -(R)ead -(U)pdate

	my $crucnt = 0;
        foreach my $opt (('C','R','U')) {
		my $optarg = $opts->{$opt};
                if (defined $optarg) {
			$opts->{'dbfile'} = $optarg;
                        $opts->{action} = {
                                'C' => 'create',
                                'R' => 'read',
                                'U' => 'update'
                        }->{$opt};
                        $crucnt++;
                }
        }

        if($crucnt > 1) {
                print "only 1 of -C -R -U may be specified at a time\n";
                _usage_exit;
        }

        $opts->{paths} = [];
        foreach (@ARGV) {
                push @{$opts->{paths}}, $_;
        }

	@ARGV = $OLDV;
}

sub new {
	my $class = shift;
	my $self = {};
	$self->{opts} = {};
	$self->{dbobj} = undef;
	bless $self, $class;
	return $self;
}

sub run {
	my $self = shift;
	# print "running in " . ref($self) . "\n";
	# $self->_dump_args;

	$self->_usage_exit if scalar @ARGV < 2;

	$self->_parse_opts;

	# $self->_dump_opts;
	exit $self->_process;
}

1;
