#!/bin/sh

lessc --include-path="templates/less:vendor/bootstrap/less:vendor/font-awesome/less" templates/less/custom-bootstrap.less > public/css/wirc.css
cp -r vendor/font-awesome/font public/
