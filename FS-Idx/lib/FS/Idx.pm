
#
# FS::Idx - filesystem index database object
#
# $Id$
#

package FS::Idx;

$VERSION = 1.00;

use warnings;
use strict;
use Carp;

use File::Find;
use File::stat;

use MLDBM qw(DB_File Storable);
use YAML; # XXX debug

use Fcntl;
use Errno qw(:POSIX);

sub new;
sub index;
sub eachcb;

sub _dumpguts;

sub _find_cb;

sub _tie_db; 
sub _check_db;
sub _untie_db; 

sub new { # new(filename, <flags> )

	my $class = shift;
	my $dbpath = shift;

	my $flags = shift; 
	$flags = 0 unless $flags;

	my $self = {};
	my $dbhash = {};

	if (!$dbpath){
		carp "warning: " . $class . "->new(): no file given\n";
		$! = &Errno::ENOENT;
		return $dbpath;
	}
	if (!($flags & O_CREAT) && (! -f $dbpath) ) {
		$! = &Errno::ENOENT;
		return undef;
	}
	if (($flags & O_EXCL) && (-f $dbpath) ) {
		$! = &Errno::EEXIST;		
		return undef;
	}

	tie %{$dbhash}, 'MLDBM', $dbpath;

	$self->{dbpath} = $dbpath;
	$self->{dbhash} = $dbhash;

	bless $self, $class;
	return $self;

}

# index the path, 
# calling preref before storing and postref afterwords
# uses File::Find with follow=0, no_chdir=1.
# todo: control flow via pre/post return status?

sub index { # index($path, [ $preref, $postref ] )

	my ($self, $path, $pre, $post ) = @_;

	$pre = sub {} unless $pre;
	$post = sub {} unless $post;

	my $wanted = sub {
		$pre->();

		my $fp = $File::Find::name;
		
		my $sb = lstat($fp);
		$self->{dbhash}->{$fp} = $sb;

		$post->();
	};

	find({
		wanted => $wanted,
		follow => 0,
		no_chdir => 1 },
		$path
	);
}

sub eachcb { # call 'cb(k,v)' on each of the dbhash key/value pairs
	my $self = shift;
	my $cb = shift;
	while ( my ($k,$v) = each %{$self->{dbhash}} ) {
		$cb->($k,$v);
	}
}

sub _dumpguts {

	my $self = shift;
	my $filtsub = shift;

	$filtsub = sub {return 1;} unless $filtsub;

	$self->eachcb(sub {
		my ($key,$val) = @_;
		if($filtsub->($key)) {
			print YAML::Dump {
				key => $key,
				data => $val
			};
		}
	});

}

1;
__DATA__

# public api:

my $idx = FS::Idx->new(dbpath [, optional Fcntl flags]);
$idx->index($path, [$preref,$postref] ); 
$idx->_dumpguts( $matcher ) ;
foreach(keys $idx->{dbhash}) { ... }

# misc:

 for refs (linux):

  struct stat {
      dev_t     st_dev;     /* ID of device containing file */
      ino_t     st_ino;     /* inode number */
      mode_t    st_mode;    /* protection */
      nlink_t   st_nlink;   /* number of hard links */
      uid_t     st_uid;     /* user ID of owner */
      gid_t     st_gid;     /* group ID of owner */
      dev_t     st_rdev;    /* device ID (if special file) */
      off_t     st_size;    /* total size, in bytes */
      blksize_t st_blksize; /* blocksize for file system I/O */
      blkcnt_t  st_blocks;  /* number of 512B blocks allocated */
      time_t    st_atime;   /* time of last access */
      time_t    st_mtime;   /* time of last modification */
      time_t    st_ctime;   /* time of last status change */
  };

