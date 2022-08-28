ZigNpy
======

**Work In Progress**

[Zig][Zig] library to load [npy][npy] files.

TODO:
----

- [ ] Proper N-D Support 
  - Use [zig-strided-arrays](https://github.com/dweiller/zig-strided-arrays)
- [ ] Support more datatypes
- [ ] Npz support
  - They are just zipped npy files basically where the filenames act as keys
  - Use either [zarc](SuperAuguste/zarc) or [this zip library][https://github.com/kuba--/zip]
    - Speed is important, [zarc might be slow?](https://github.com/SuperAuguste/zarc/issues/7)

[Zig]: https://ziglang.org/
[npy]: https://numpy.org/devdocs/reference/generated/numpy.lib.format.html
