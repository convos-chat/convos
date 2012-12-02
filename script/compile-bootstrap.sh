#!/bin/sh

lessc --strict-imports --include-path="vendor/bootstrap/less:vendor/font-awesome/less:templates/less" templates/less/custom-bootstrap.less > public/css/wirc.css
cp -r vendor/font-awesome/font public/
