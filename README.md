argcheck
========

A powerful argument checker for your lua functions.

Argcheck produces specific code for each function. This code is compiled
once, which implies the checks will not add much overheads to your original
function.

Installation
------------

The easiest is to use [luarocks](http://www.luarocks.org).

```sh
luarocks build https://raw.github.com/andresy/argcheck/master/rocks/argcheck-scm-1.rockspec
```

