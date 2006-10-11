all:
	@echo "Try 'make install'"

install:
	@for i in *.cgi ; do \
		echo "Uploading $$i" ; \
		ncftpput -d $$i.log -u usene001 -p $$(cat password) -X "SITE CHMOD 755 $$i" ftp.usenetnews.us /www $$i ; \
	done


