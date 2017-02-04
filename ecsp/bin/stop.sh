#!/bin/bash

cd ../
nginx -p `pwd` -c conf/nginx.conf -s quit
