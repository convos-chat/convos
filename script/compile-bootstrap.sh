#!/bin/sh

  lessc --compress templates/less/wirc.less > public/css/wirc.css
cp -r vendor/font-awesome/font public/
