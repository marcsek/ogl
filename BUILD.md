### Linux

##### Building depencdencies

```shell
cd vendor/cglm
mkdir build && cd build
cmake .. -DCGLM_STATIC=ON -DCMAKE_C_FLAGS='-DCGLM_ALL_UNALIGNED=1'
make
```
