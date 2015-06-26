
#
# Fs::Idx::Report::App: application class for 'fsidx' per-user report tool
#
# $Id$
#
# TODO: rework/modularize so the data can be computed 1x w/r/t a given DB..
#
# output:
#   - per user:
#     - file count
#     - byte count (also blocks? herm)
#     - oldest atime
#     - oldest mtime
#     - oldest ctime
#     - newest atime
#     - newest mtime
#     - newest ctime
#
# possibly eventually:
#
#   - per-group summaries
#   - file selection regexps
#

package FS::Idx::Report::App;

use strict;
use warnings;

use Carp;
use Getopt::Std;

use Fcntl;
use User::pwent;
use YAML;

use FS::Idx::Sum;
use User::PassDB;

sub _usage_exit;
sub _parse_opts;
sub _dateconv;
sub _process;
sub _readify;
sub _uidify;

sub dump;
sub new;
sub run;

sub _usage_exit {
	my $app;
	( $app = $0 ) =~ s:.*/::;
	print "usage: $app [-h] [-u userdb] [-E expr ] fssum.db [ user ... ]\n";
	exit 0;
}

sub _parse_opts { # XXX: not threadsafe - ARGV modified

	my $self = shift;
	my $opts = $self->{opts};
	my $uids = $self->{uids};

	my $sumdb = $self->{sumdb};
	my $uiddb = $self->{uiddb};

	my ($sdp,$udp) = undef;

	my $OLDV = [ @ARGV ];
	getopts( 'hu:E:', $opts ); # -(h)uman readable -(u)ser PassDB database

	# summary database

	$sdp = shift @ARGV;
	$sumdb = FS::Idx::Sum->new($sdp) 
		or die "error opening summary database $sdp: $!\n";
	$self->{sumdb} = $sumdb;

	# user name translation database

	$udp = $opts->{u} if $opts->{u};
	if($udp) {
		$uiddb = User::PassDB->new($opts->{u})
			or die "error opening user db $udp\n";
		$self->{uiddb} = $uiddb;
	}

	# user filter / uid lookup logic

	$opts->{users} = [];
	foreach my $useropt (@ARGV) {

		# fixme: should do uid lookup if non-numeric
		# as is, will only filter users by uid in report..
		push @{$opts->{users}}, $useropt;

		if($useropt =~m :^\d+$:) {
			$uids->{$useropt} = 1;
		}
		else {
			if($uiddb) {
				my $pwent = $uiddb->getpwnam($useropt);
				if($pwent) {
					$uids->{$pwent->uid} = 1;
				}
				else {
					carp "$useropt not found in uiddb";
				}
			}
			else {
				carp "non-digit user $useropt given w/o uiddb";
			}
		}

	}

	@ARGV = $OLDV;

}

sub _dateconv {
	my $timet = shift;
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
		localtime($timet);

	return sprintf "%04d-%02d-%02d %02d:%02d:%02d",
		(${year}+1900),(${mon}+1),${mday},${hour},${min},${sec};
}

#
# dump - dump data according to default 'raw dump' logic or user 
# provided expression.
# 
# User provide expression to be documented better - basically:
# -E should be a string containing a function which returns
# a hash of 3 functions - precb,cbsub,postcb
# e.g:
#
# sub { 
#	my $ret = {}; 
#	$ret->{precb} = sub { print "precb\n"; }; 
#	$ret->{cbsub} = sub { print "cbsub\n"; }; 
#	$ret->{postcb} = sub { print "postcb\n"; }; 
#	return $ret; 
# }
#
# This should probably actually be pushed down into the sumdb better,
# so we can just pass some default struct down..
#
# but this also implies standardizing the evaluation environment, yadda..
# which is a lot of mess.. so, for now, its good - make driver scripts.
#
# herm..
#

sub _readify {

	my $v = shift;

	# nbyte -> kb
	# natime -> time (YYYY-MM-DD HH:MM:SS)
	# nctime -> time (YYYY-MM-DD HH:MM:SS)
	# nmtime -> time (YYYY-MM-DD HH:MM:SS)
	# oatime -> time (YYYY-MM-DD HH:MM:SS)
	# octime -> time (YYYY-MM-DD HH:MM:SS)
	# omtime -> time (YYYY-MM-DD HH:MM:SS)
	
	my $new_v = {};
	
	$new_v->{nbyte} = int($v->{nbyte} / 1024);
	$new_v->{nfile} = $v->{nfile};
	
	$new_v->{natime} = _dateconv($v->{natime});
	
	$new_v->{nmtime} = _dateconv($v->{nmtime});
	$new_v->{nctime} = _dateconv($v->{nctime});
	
	$new_v->{oatime} = _dateconv($v->{oatime});
	$new_v->{omtime} = _dateconv($v->{omtime});
	$new_v->{octime} = _dateconv($v->{octime});

	return $new_v;
}

sub _uidify { # lookup a uid to a name if possible, else return uid
	my $pwkey = shift;
	my $uiddb = shift;

	if($uiddb) {
		my $pw = $uiddb->getpwuid($pwkey);
		$pwkey = $pw->name if $pw;
	}
	return $pwkey;
}

sub dump {

	my $self = shift;

	my $rpdat = $self->{rpdat};
	my $uiddb = $self->{uiddb};
	my $sumdb = $self->{sumdb};
	my $readable = $self->{opts}->{h};

	my $precb;	# function to call before database iteration 
	my $cbsub;	# function to call on each database item
	my $postcb;	# function to call after database iteration

	my $uids = $self->{uids};
	my $nuids = scalar keys %{$uids};

	my $uexpr = $self->{opts}->{E};

	if($uexpr) {
		my $ueval = (eval $uexpr)->();
		$precb = $ueval->{precb} if $ueval->{precb};
		$cbsub = $ueval->{cbsub} if $ueval->{cbsub};
		$postcb = $ueval->{postcb} if $ueval->{postcb};
	}

	$precb = sub {} unless $precb;

	$cbsub = sub { # unless $cbsub;

		my ($k,$v) = @_;

		return if ($nuids && !$uids->{$k});

		my $pwkey = $k;
		$pwkey = _uidify($k,$uiddb) if $uiddb;
		$v = _readify($v) if $readable;

		print YAML::Dump { $pwkey => $v };

	} unless $cbsub;

	$postcb = sub {} unless $postcb;

	$precb->();
	$sumdb->eachcb($cbsub);
	$postcb->();

	return 0;
}

sub new {
	my $class = shift;
	my $self = {};

	$self->{opts} = {};		# getopt options
	$self->{rpdat} = {};		# reporting data
	$self->{uids} = {};		# uid's of interest

	$self->{sumdb} = undef;		# FS::Idx::Sum ref
	$self->{uiddb} = undef; 	# User::PassDB ref

	bless $self, $class;
	return $self;
}

sub run {
	my $self = shift;
	$self->_usage_exit if scalar @ARGV < 1;
	$self->_parse_opts;

	# for status updates
	$SIG{USR1} = sub { # XXX : threadsafe stdout, modifies signal handler
		my $oldflush = $|; $|=1;
		$self->dump;
		$| = $oldflush;
	}; 

	return $self->dump;
}

1;

