all:
	@echo Try make install or make install-web
	@echo for install-web you must be in the root/ directory.

install:
	rsync $(RSYNC_FLAGS) -C -v -a -e ssh . ausadmin@slim.tull.net:~ausadmin/bin/

install-web:
	rsync $(RSYNC_FLAGS) -C -v -a -e ssh . ausadmin@slim.tull.net:/var/www/aus.news-admin.org/
