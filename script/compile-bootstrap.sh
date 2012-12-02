#!/bin/sh

lessc --include-path="vendor/bootstrap/less:vendor/font-awesome/less:templates/less" templates/less/wirc.less > public/css/wirc.css
cp -r vendor/font-awesome/font public/
