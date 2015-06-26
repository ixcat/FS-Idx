
idx=tmp/idxtmp/fs/fsidx-20150406.db
pdb=tmp/idxtmp/passdb-ece.db
sum=tmp/idxtmp/fs/fssum-20150406.db

uexpr=' \
 		sub { \
 			my $$ret = {}; \
 			$$ret->{precb} = sub { print "precb\n"; }; \
 			$$ret->{cbsub} = sub { \
 				my ($$k,$$v) = @_; \
 				print $$k .  "\n"; \
 			}; \
 			$$ret->{postcb} = sub { print "postcb\n"; }; \
 			return $$ret; \
 		}; \
'

all: testdump testeval

testdump:
	pdb=$(pdb); sum=$(sum); \
	./idxrpt -h -u $$pdb $$sum 51509 st19

testdumpraw:
	pdb=$(pdb); sum=$(sum); \
	./idxrpt $$sum 51509

testdumphum:
	pdb=$(pdb); sum=$(sum); \
	./idxrpt -h $$sum 51509
		

testeval:
	pdb=$(pdb); sum=$(sum); \
	./idxrpt -h -u $$pdb \
	-E $(uexpr) $$sum;

