#	@(#) $Header$
#	Copyright (C) 2002, Nick Andrew <nick@nick-andrew.net>
#	Distributed under the terms of the GNU Public License
#	See http://www.gnu.org/licenses/gpl.html
#
#  Makefile for ausadmin software

PACKAGE=	ausadmin-software
VERSION=	YYYYMMDD

MISC=		Makefile README.html TODO UPGRADE.html
DIRS=		bin doc samples

all:
	@echo Try \"make VERSION=yyyymmdd package\"

package:	$(HOME)/$(PACKAGE)-$(VERSION).tar.gz
	@echo "Package build complete."

$(HOME)/$(PACKAGE)-$(VERSION).tar.gz:
	tar -z -c -v \
		-f $(HOME)/$(PACKAGE)-$(VERSION).tar.gz \
		--exclude='CVS' \
		--exclude='data' \
		$(MISC) $(DIRS)

# End of Makefile
