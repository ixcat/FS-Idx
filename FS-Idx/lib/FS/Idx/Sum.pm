
#
# package to create a summary db from a filesystem index
#
# $Id$
#
# FIXME/NOTE:
#
#   - does not currently track inodes of files, so hardlinked files
#     will be counted as many times as they are linked in a given source index.
#

package FS::Idx::Sum;

use warnings; 
use strict;
use Carp;

use Fcntl;
use Errno qw(:POSIX);

use MLDBM qw(DB_File Storable);

use FS::Idx;

# sub predecls

sub new;
sub addfile;
sub process;
sub eachcb;

# subs

sub new { # new(sumdbfile, flags, matchrx, filtrx)

	my $class = shift;
	my $sumpath = shift;
	my $flags = shift;
	my $matchrx = shift;
	my $filtrx = shift;

	my $self = {};
	my $sum = {};

	$flags = 0 unless $flags;
	$matchrx = '.*' unless $matchrx;
	$filtrx = '!.*' unless $filtrx;

	if(!$sumpath) {
		carp "$class->new(): no summary file given\n";
		$! = &Errno::ENOENT;
		return undef;
	}
        if (!($flags & O_CREAT) && (! -f $sumpath) ) {
                $! = &Errno::ENOENT;
                return undef;
        }
        if (($flags & O_EXCL) && (-f $sumpath) ) {
                $! = &Errno::EEXIST;
                return undef;
        }

	tie %{$sum}, 'MLDBM', $sumpath;

	$self->{sumpath} = $sumpath;
	$self->{sum} = $sum;
	$self->{matchrx} = $matchrx;
	$self->{filtrx} = $filtrx;

	bless $self,$class;
	return $self;	

}

# Add a file to the summary data - will update per user:
#
#     - file count
#     - byte count (also blocks? herm)
#     - oldest atime
#     - oldest mtime
#     - oldest ctime
#     - newest atime
#     - newest mtime
#     - newest ctime
#
# according to the file stat(2) metadata.
#

sub addfile { # addfile(fname, finfo)

	my $self = shift;
	my $fname = shift;
	my $finfo = shift;

	my $sum = $self->{sum};
	my $matchrx = $self->{matchrx};
	my $filtrx = $self->{filtrx};

	return unless $fname =~ m:$self->{matchrx}:;
	return if $fname =~ m:$self->{filtrx}:;

	my $uid = $finfo->uid();
	my $size = $finfo->size();
	my $atime = $finfo->atime();
	my $mtime = $finfo->mtime();
	my $ctime = $finfo->ctime();

	my $user = $sum->{$uid};

	if(!$user) {
		$user = {
			nfile => 1,
			nbyte => $size,
			oatime => $atime,
			omtime => $mtime,
			octime => $ctime,
			natime => $atime,
			nmtime => $mtime,
			nctime => $ctime
		};
	}
	else {
		$user->{nfile}++;
		$user->{nbyte} += $size;

		$user->{oatime} = $atime if $user->{oatime} > $atime;
		$user->{omtime} = $mtime if $user->{omtime} > $mtime;
		$user->{octime} = $ctime if $user->{octime} > $ctime;

		$user->{natime} = $atime if $user->{natime} < $atime;
		$user->{nmtime} = $mtime if $user->{nmtime} < $mtime;
		$user->{nctime} = $ctime if $user->{nctime} < $ctime;
	}

	$sum->{$uid} = $user;

}

# compute aggregate per user:
#
#   - file count
#   - byte count (also blocks? herm)
#   - oldest atime
#   - oldest mtime
#   - oldest ctime
#   - newest atime
#   - newest mtime
#   - newest ctime
#
# for a given file path.
#

sub process { # process($idxdbpath)

	my $self = shift;
	my $idxpath = shift;

	my $sum = $self->{sum};
	my $matchrx = $self->{matchrx};
	my $filtrx = $self->{filtrx};
	my $idx = FS::Idx->new($idxpath);

	if(!$idx) {
		carp "FS::Idx::Sum::process(): "
			. "couldn't create FS::Idx($idxpath): $!\n";
		return undef;
	}

	$idx->eachcb( sub {
		my ($k,$v) = @_;
		$self->addfile($k,$v);
	} );

	return 0;

}

sub eachcb { # call 'cb(k,v)' on each of the report key/value pairs
	my ($self,$cb) = @_;
	while ( my ($k,$v) = each %{$self->{sum}} ) {
		$cb->($k,$v);
	}
}

1;
