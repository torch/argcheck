argcheck benchmark
==================

We show here an example of `argcheck` in a real-life case: wrapping a call
to the numerical library [TH](https://github.com/torch/TH), used in
[torch7](https://github.com/torch/torch7).

The code does a simple loop over this particular function call. In torch7,
this looks like:
```lua
   for i=1,N do
      torch.add(y, x, 5)
      torch.add(y, x, scale, y)
   end
```

The add function of torch7 is non-trivial, because it has to handle cases
where one wants to add a tensor to a tensor or a value to a tensor. There
is also an optional scale argument. The function is also overloaded for 7
different types of tensors (double, float, int...), which makes things even
more uneasy. We define the double overloading last, to study the worst case
performance.

In the following, we compare:
  - `torch7` (here ran with luajit). Torch7 uses the regular lua/C API.
  - `torch9`, a FFI interface for [`luajit`](http://luajit.org), to the TH library achieved with `argcheck`.
  - `torch9lua`, running [`lua`](http://www.lua.org) with [`libffi`](https://github.com/jmckaskill/luaffi) and `argcheck`.
  - `C`, plain C calls to `TH` library. Contrary to other versions, _it does not include the overhead of multiple tensor types_.

What we call `torch9` here is only a thin interface to `TH` with FFI,
limited to the purpose of this benchmark. The only thing it has to do with
the upcoming `torch9` is the way we use `argcheck` with FFI.

We avoid garbage-collection side-effects by not allocating objects.

## Call to argcheck

We create a function `add()`, which is overloaded to handle various possible argument situations.

```lua
add = argcheck{
   overload = add,
   {name="res", type="torch.DoubleTensor", opt=true},
   {name="src", type="torch.DoubleTensor"},
   {name="value", type="number"},
   call =
      function(res, src, value)
         res = res or DoubleTensor()
         C.THDoubleTensor_add(res, src, value)
         return res
      end
}

add = argcheck{
   overload = add,
   {name="res", type="torch.DoubleTensor", opt=true},
   {name="src1", type="torch.DoubleTensor"},
   {name="value", type="number", default=1},
   {name="src2", type="torch.DoubleTensor"},
   call =
      function(res, src1, value, src2)
         res = res or torch.DoubleTensor()
         C.THDoubleTensor_cadd(res, src1, value, src2)
         return res
      end
}
```

As you can see, there are many variations to handle. The generated code is
201 lines of `lua` code, only for the case of DoubleTensor. With all the 7
types of tensor, it is 5250 lines of code! This code handles both ordered
arguments (as in `torch7`) and named arguments calls. Arguments calls is
just for syntactic sugar, but is slower (it implies creating argument
tables, and looping over them, which is not JIT in the current
`luajit` 2.1).

The tree generated in the case of DoubleTensor is alone, is the following:
![](doc/tree1.png)
When it includes all the 7 types of tensors:
![](doc/tree7.png)

## Running it

We now compare our different setups with matrix sizes of size 2, 10, 100,
and 300 over 100,000,000, 10,000,000, 1,000,000 and 100,000 iterations
respectively. Running time is given is seconds. Experiments were performed
on a MacBook Pro 2.6GHz Quad-core i7, using one core. Overhead per call is
reported, in nano-seconds, computed with the first two columns (w.r.t C
performance).

|                                 |    2     |    10    |    100   |    300   |  overhead  |
|:--------------------------------|---------:|---------:|---------:|---------:|-----------:|
| C                               |   3.82s  |   1.16s  |   8.74s  |  10.34s  |     0ns    |
| torch7 (luajit+C API) (jit=on)  |  73.45s  |   8.22s  |   9.47s  |  10.47s  |   701ns    |
| torch7 (luajit+C API) (jit=off) |  72.22s  |   8.21s  |   9.49s  |  10.59s  |   694ns    |
| torch9 (luajit+ffi)   (jit=on)  |   3.80s  |   1.14s  |   8.82s  |  10.30s  |    -1ns    |
| torch9 (luajit+ffi)   (jit=off) | 167.62s  |  17.35s  |  10.75s  |  10.83s  |  1619ns    |
| torch9 (lua+luaffi)             | 256.20s  |  26.93s  |  11.30s  |  10.66s  |  2550ns    |

### Comments

Not suprisingly, the old lua/C API has quite some overheads when calling
short duration C code.

`luajit` does an impressive job in calling C functions through FFI. It
stays on par with C performance, even when C operations are limited (small
matrix size). `argcheck` is viable even in interpreted mode with luajit,
with only a x2 overhead compared to the lua/C API.

Lua interpreter (with luaffi library) has clearly more
overheads. `argcheck` might be still very usable (here 2.5ms per call, in a
pretty complicated setup), depending on your use-case.

## Named arguments

As mention earlier, named argument calls are expected to be slower. Here is
a comparison against ordered arguments calls, using the same benchmark. In
our case, the overhead is about 1ms per call with luajit (note that with
jit off, the performance is similar, meaning luajit relies mainly on the
interpreter in that case). Our test case is pretty complicated, your
mileage might vary...

|                                          |    2     |    10    |    100   |    300   |  overhead  |
|:-----------------------------------------|---------:|---------:|---------:|---------:|-----------:|
| torch9 (luajit+ffi) (jit=on)  (ordered)  |   3.80s  |   1.14s  |   8.82s  |  10.30s  |     -1ns   |
| torch9 (luajit+ffi) (jit=off) (ordered)  | 167.62s  |  17.35s  |  10.75s  |  10.83s  |   1628ns   |
| torch9 (lua+luaffi)           (ordered)  | 256.20s  |  26.93s  |  11.30s  |  10.66s  |   2550ns   |
| torch9 (luajit+ffi) (jit=on)  (named)    | 110.24s  |  11.81s  |   9.85s  |  10.29s  |   1064ns   |
| torch9 (luajit+ffi) (jit=off) (named)    | 205.99s  |  21.92s  |  11.08s  |  10.72s  |   2049ns   |
| torch9 (lua+luaffi)           (named)    | 486.19s  |  49.48s  |  13.87s  |  10.66s  |   4828ns   |
