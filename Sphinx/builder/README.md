
# CMU SphinxBase and PocketSphinx Builder

> **DISCLAIMER**: TLSphinx comes with pre-bundled sphinxbase and pocketsphinx
> libraries and headers, you're **strongly** encouraged to use those instead of 
> building them on your own.

These are the CMU sphinxbase and pocketsphinx building instructions for TLSphinx, follow the guide below to build the required libraries for TLSphinx to build.

In order to build sphinxbase and pocketsphinx both packages need to be downloaded, see: [CMUSphinx Downloads](https://cmusphinx.github.io/wiki/download/).

From there you need to download:

 * [sphinxbase-5prealpha](http://sourceforge.net/projects/cmusphinx/files/sphinxbase/5prealpha)
 * [pocketsphinx-5prealpha](http://sourceforge.net/projects/cmusphinx/files/pocketsphinx/5prealpha)

After downloading both files copy them to `Sphinx/builder/cmusphinx`

## Automatic Compilation
After copying the files to the appropiate directory (*see above*) just run the install.sh script and with some luck you're done.

```
cd Sphinx/builder/
./install.sh
```


---
## Manual Compilation
If possible please try automatic compilation when possible, manual compilation is not for the feint of heart yet it might help in scenarios where you want to build CMU Sphinx Base and Pocket Sphinx from their respective master branches. 

Below are sample instructions on how to manually build the **5prealpha** release, to build against the lastest source just modify each command accordingly.
### Sphinxbase
---
#### To prepare build environment:
```
#From TLSphinx root directory
cd Sphinx/builder/cmusphinx
tar zxvf sphinxbase-5prealpha.tar.gz
cp ../ios-build-sphinxbase.sh sphinxbase-5prealpha/
```
#### To build:
```
SPHINX_VERSION_REQ=5prealpha 
cd sphinxbase-5prealpha
./ios-build-sphinxbase.sh
```
#### Install Libraries:
```
cp bin/arm64/lib/libsphinx*.a ../../../lib/sphinxbase/arm64/
cp bin/armv7/lib/libsphinx*.a ../../../lib/sphinxbase/armv7/
cp bin/armv7s/lib/libsphinx*.a ../../../lib/sphinxbase/armv7s/
cp bin/i386/lib/libsphinx*.a ../../../lib/sphinxbase/i386/
cp bin/x86_64/lib/libsphinx*.a ../../../lib/sphinxbase/x86_64/
cp bin/libsphinxad.a ../../../lib/sphinxbase/
cp bin/libsphinxbase.a ../../../lib/sphinxbase/
```
#### Install Headers
```
cp include/sphinxbase/ ../../../include/sphinxbase/
cp include/sphinx_config.h ../../../include/sphinxbase/
```

### PocketSphinx
---
#### To prepare build environment:
```
#From TLSphinx root directory
cd Sphinx/builder/cmusphinx
tar zxvf pocketsphinx-5prealpha.tar.gz
cp ../ios-build-pocketsphinx.sh pocketsphinx-5prealpha/
```
#### To build:
```
SPHINX_VERSION_REQ=5prealpha 
cd pocketsphinx-5prealpha
./ios-build-pocketsphinx.sh
```
#### Install Libraries:
```
cp bin/arm64/lib/libpocketsphinx.a ../../../lib/pocketsphinx/arm64/
cp bin/armv7/lib/libpocketsphinx.a ../../../lib/pocketsphinx/armv7/
cp bin/armv7s/lib/libpocketsphinx.a ../../../lib/pocketsphinx/armv7s/
cp bin/i386/lib/libpocketsphinx.a ../../../lib/pocketsphinx/i386/
cp bin/x86_64/lib/libpocketsphinx.a ../../../lib/pocketsphinx/x86_64/
cp bin/libpocketsphinx.a ../../../lib/pocketsphinx/
```
#### Install Headers
```
cp -vf include/*.h ../../../include/pocketsphinx/
```