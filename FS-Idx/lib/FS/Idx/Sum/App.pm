
#
# FS::Idx::Sum application class - logic for a simple index creator utility.
#
# $Id$
#

package FS::Idx::Sum::App;

use warnings;
use strict;

use Fcntl;
use Getopt::Std;

use FS::Idx::Sum;

# sub predecls

sub new;
sub run;

sub _usage_exit;
sub _parse_opts;
sub _process;

# subs

sub new {
	my $class = shift;
	my $self = {};
	$self->{opts} = {};
	bless $self,$class;
	return $self;
}

sub run {
	my $self = shift;
	$self->_usage_exit if scalar @ARGV < 1;
	$self->_parse_opts;

	return $self->_process;
}

sub _usage_exit {
	my $app;
	( $app = $0 ) =~ s:.*/::;
	print "usage: $app [ -s sum.db ] idx.db [matchrx] [filtrx]\n";
	exit 0; 
}

sub _parse_opts { # XXX: not threadsafe ARGV modified

	my $self = shift;
	my $opts = $self->{opts};

	my ($sump,$idxp,$matchrx,$filtrx) = undef;

	my $OLDV = [ @ARGV ];
	getopts('s:', $opts ); # -s sum.db (default: sum.db)

	$sump = 'sum.db';
	$sump = $opts->{s} if $opts->{s};

	die "error: $sump already exists.\n" if -f $sump;

	$idxp = shift @ARGV;
	$matchrx = shift @ARGV;
	$filtrx = shift @ARGV;

	_usage_exit unless $idxp;

	@ARGV = $OLDV;

	$self->{sumpath} = $sump;
	$self->{idxpath} = $idxp;
	$self->{matchrx} = $matchrx;
	$self->{filtrx} = $filtrx;

}

sub _process {
	my $self = shift;
	my $sumpath = $self->{sumpath};
	my $idxpath = $self->{idxpath};
	my $matchrx = $self->{matchrx};
	my $filtrx = $self->{filtrx};

	$self->{sum} = FS::Idx::Sum->new(
		$sumpath, O_CREAT|O_EXCL, $matchrx, $filtrx
	) 
	or die "error creating summary db ($sumpath): $!\n";

	if(!$self->{sum}->process($idxpath)) {
		return -1;
	}
	return 0;
}

1;
