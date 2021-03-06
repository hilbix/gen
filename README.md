> Currently this can be used to create configuration for NginX websites
> with best practice (I hope).
>
> Probably this will be extended in future to other things.

[![branch: cirrus](https://api.cirrus-ci.com/github/hilbix/gen.svg?branch=cirrus)](https://cirrus-ci.com/github/hilbix/gen)


# Config generator

This is a generator for complex configuration files.

- Easy to use
- Easy to extend
- mostly pure `bash` (plus a few standard utilities)

All you need is to `make love`.


## Usage

	git init conf
	cd conf

	git fetch https://github.com/hilbix/empty.git
	git reset FETCH_HEAD
	git tag empty

	git submodule add https://github.com/hilbix/gen.git
	git submodule update --init
	ln -s gen/Makefile .

	git add -A .
	git commit -m .

Example:

	ln -s gen/example.org gen/letsencrypt.http .
	make

- It transforms all `*.*` files into `out/` according to `gen/std/`.
- You can adapt/override everything in the directory `gen/`

## HowTo

- Please read the introductory comment in [`gen.sh`](gen.sh)
- For an example see [`letsencrypt.http`](./letsencrypt.http) or [`example.org`](https://raw.githubusercontent.com/hilbix/gen/master/example.org)
- The configuration snippets are in [`std/` directory](std/)
- `make debug` when something breaks


## FAQ

Hints?

- [observatory.mozilla.org](https://observatory.mozilla.org/)

WTF why?

- Because keeping a fleet of sites with all those changing standards is a PITA.
- Hence I needed something to bundle it.
- The problem is with NginX not offering configuration macros, so you need some script to create the site include.

Why Makefiles?

- Because I'm just too lazy.  So I expect `make` to just do it for me.
- Also `Makefile`s are excellent documentation of what is possible where

Bugs? Contact?

- Issue on GitHub, eventually I listen.

Changes? Contrib?

- PR on GitHub, eventually I listen.

License?

- Are you kidding?  This is an absolutely trivial basic open knowledge no-brainer!
- In this universe there are some basic rules, and one is that things like this here cannot be copyrighted.
- So this is Public Domain.  Open speech.  Rants.  Whatever you like.
- **INTELLECTUAL PROPRIETARY RIGHTS ARE SLAVERY!**  Slavery must be abolished.

But ..

- No!  Definitively no.  No buts, no objections, no nothing.  No not no!
- The scripting I did was done in a hurry.  And there is absolutely nothing to it.  Plain straight forward.
- There was something needed to reduce the NginX config complexity.  This is, what came out.
- This all is a no-brainer.  This text here is even more difficult to understand than the Makefile!
- Please see this all here as just some mini-dump of a region of my brain, openly performed to an open audience.

