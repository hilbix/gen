#!/bin/bash

set -x

URL="$(git config --get remote.origin.url)"

git init config
cd config
git submodule add "$URL" gen

ln -vs gen/{Makefile,example.org,letsencrypt.http} .

