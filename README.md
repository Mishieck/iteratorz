# Iteratorz

A Zig library of iterators.

## Features

<dl>
  <dt>Bidirectional</dt>
  <dd>Iterators are capable of going forward and backward.</dd>
  <dt>Random Access</dt>
  <dd>Values of iterators can be accessed randomly.</dd>
  <dt>Read/Write</dt>
  <dd>Iterators can be readable or writable.</dd>
</dl>

## Usage

### Fetch

```sh
zig fetch --save git+https://github.com/mishieck/iteratorz
```

### Add Dependency

In `build.zig`, add the following:

```zig
const iteratorz = b.dependency("iteratorz", .{
    .target = target,
    .optimize = optimize,
});

exe.root_module.addImport("iteratorz", iteratorz.module("iteratorz"));
```

### Examples

Look at [uppercase_vowels](./examples/uppercase_vowels.zig).

## Architecture

```
Collection -> Iterable -> Iterator -> Higher-order Iterator
```

### Collection

A collection is a value that is capable of producing and consuming other values.
A readable collection produces values. A writable collection consumes values.

A collection may be concrete or abstract. 

<dl>
  <dt>Concrete Collection</dt>
  <dd>
    All its values are available before they are read or after they have been
    written. An array is an example of a concrete collection. 
  </dd>
  <dt>Abstract Collection</dt>
  <dd>
    Not all its values are available before they are read or after they have
    been written. A fibonacci sequence and IO ports are examples of abstract
    collections. All abstract collections depend on concrete values.
  </dd>
</dl>

### Iterable

An iterable is a collection with a state that can be mapped to its values. The
state has valid and invalid values. Valid states can be used to read and write
values. Invalid states can not be mapped to any value of the collection. Invalid
states can arise if an attempt to change the state results in a value that is
not a valid state.

### Iterator

An iterator is an abstract collection that reads from and writes to an iterable
while modifying the state of the iterable. Iterators have the following key
methods:

<dl>
  <dt>current</dt>
  <dd>Reads or writes a value then sets the state to the next state.</dd>
  <dt>next</dt>
  <dd>Sets the state to the next state then reads or writes a value.</dd>
  <dt>previous</dt>
  <dd>Sets the state to the previous state then reads or writes a value.</dd>
  <dt>at</dt>
  <dd>
    Reads or writes a value at a given state then sets the state to the next
    state.
  </dd>
</dl>

### Higher-order Iterator

Higher-order iterators depend on other iterators. Iterators for mapping and
filtering values are some of the examples. Higher-order iterators are derived
from other iterators using piping. For example, if you would like to get all
even numbers up to 100, you could take the following steps:

1. Create an iterator of whole numbers (counter).
2. Pipe the counter to a map that doubles a number.
3. Pipe the map to a filter that limits values to 100.
4. Iterate over the final iterator.

In mathematical terms, it is:

$$
\text{let } \text{Even} = \{2x| x \in \mathbb{W}\} \\
\text{let } \text{UpTo100} = \{x| x \in \text{Even} \land x \le 100\}
$$
