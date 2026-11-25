#!/bin/sh
set -e
chmod +x layout/DEBIAN/postinst layout/DEBIAN/postrm
make package FINALPACKAGE=1
