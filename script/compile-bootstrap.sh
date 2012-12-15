#!/bin/sh

./vendor/less.js/bin/lessc --include-path="assets/less:vendor/bootstrap/less:vendor/font-awesome/less" assets/less/custom-bootstrap.less > public/css/wirc.css
cp -r vendor/font-awesome/font public/
