#!/bin/bash

package="http://aus.news-admin.org/"
dest="ausadmin@ultraman:/virt/web/ausadmin/"

echo Updating $package to $dest
rsync -C -v -a -e ssh --delete * $dest
