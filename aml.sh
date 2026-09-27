libfile=$libdir/lib/soundfx/libdiraceffect.so

patch_cfgs dirac_gef 3799d6d1-22c5-43c3-b3ec-d664cf8d2f0d dirac $libfile
patch_cfgs -e dirac_afm 743539f8-1076-451f-8395-84acfab0fac7 dirac
patch_cfgs -e dirac_controller 128b9ba2-d0c9-47c6-aff3-9f761cd0e228 dirac
