
# FS::Idx Makefile.PL
# $Id$

use ExtUtils::MakeMaker;

WriteMakefile(
	NAME => 'FS::Idx',
	VERSION_FROM => 'lib/FS/Idx.pm',
	EXE_FILES => [
		"bin/idxsum2sql",
		"bin/idxrpt",
		"bin/idxsum",
		"bin/fsidx",
		"bin/filetimes"
	],
	PREREQ_PM => {
		'MLDBM' => 0, # tested against 2.05
		'YAML' => 0, # tested against 0.84
		'User::PassDB' => 1
	}
);

