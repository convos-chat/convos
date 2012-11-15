#!/bin/sh
cd ../bootstrap/less;
(
  lessc bootstrap.less;
  lessc responsive.less
) > ../../wirc/public/css/wirc.css
cp -r ../font ../../wirc/public/
