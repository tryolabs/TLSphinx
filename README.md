# TLSphinx

TLSphinx is a Swift wrapper around [Pocketsphinx], a portable library based on [CMU Sphinx], that allow an application to perform speech recognition **in the devices withouth any server side interaction**

This repository has two main parts. First is syntetized version of the [pocketsphinx](http://sourceforge.net/projects/cmusphinx/files/pocketsphinx/5prealpha/) and [sphinx base] repositories with a module map to access the library as a [Clang module]. The second part is TLSphinx, a Swift framework that use Sphinx Clang module and expose a Swift-like API to use sphinx

[CMU Sphinx]: http://cmusphinx.sourceforge.net/
[Pocketsphinx]: http://cmusphinx.sourceforge.net/wiki/tutorialpocketsphinx
[sphinx base]: http://sourceforge.net/projects/cmusphinx/files/sphinxbase/5prealpha/
[Clang module]: http://clang.llvm.org/docs/Modules.html
