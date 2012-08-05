#!/bin/sh
cd public/bootstrap/less
(
  lessc bootstrap.less;
  lessc responsive.less
) > ../../css/bootstrap.css
