#!/bin/bash

cd ../

pid=`ps -ef | grep "nginx"|wc -l`
if [ $pid -gt 1 ]
then
echo "is running"
sudo nginx -p `pwd` -c conf/nginx.conf -s reload
else
echo "not running"
sudo nginx -p `pwd` -c conf/nginx.conf
fi
