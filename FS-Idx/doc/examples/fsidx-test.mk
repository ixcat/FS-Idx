
TDB=test.db

all: opttest test bigtest

test:
	rm -f $(TDB)
	./fsidx -C $(TDB) /etc
	./fsidx -U $(TDB) /etc
	./fsidx -R $(TDB) ^/e

opttest:
	rm -f $(TDB)
	./fsidx -C $(TDB)
	./fsidx -U $(TDB)
	./fsidx -R $(TDB)
	./fsidx -C $(TDB) -R $(TDB)
	./fsidx -C $(TDB) -U $(TDB)
	./fsidx -R $(TDB) -U $(TDB)
	rm -f $(TDB)

bigtest:
	rm -f $(TDB)
	( time ./fsidx -C $(TDB) / ) 2>&1 |tee fsmk.time
	( time ./fsidx -R $(TDB) ) 2>&1 |tee fsrd.time
	du -sk $(TDB)


clean:
	rm -f $(TDB) fsmk.time fsrd.time

