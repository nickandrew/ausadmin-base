#!/bin/bash

package="http://aus.news-admin.org/"
dest="ausadmin@ultraman:/virt/web/ausadmin/"

# Fix permissions if necessary
for i in `find . \! -perm -4 -print` ; do
	echo Fixing permissions: `ls -ld $i`
	if [ -x $i ] ; then
		chmod go+rx $i
	else
		chmod go+r $i
	fi
done

echo Updating $package to $dest
rsync -C -v -a -e ssh --delete bin cgi-bin root $dest
