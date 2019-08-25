#!/bin/bash

URL="$(git config --get remote.origin.url)"

git init config
cd config
git submodule add "$URL" gen

ln -s gen/{Makefile,example.org,letsencrypt.http} .

