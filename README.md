# README

## How to install toolchain

### Alire

Visit the link below to install Alire

- <https://github.com/alire-project/alire/releases>

### Toolchain

```bash
$ alr toolchain --select
> 1 (gnat_native)
> 1 (gprbuild)

$ alr install gnatformat_bin
# Then add "$HOME/.alire/bin" to PATH.
```

## How to create a project

```bash
$ alr init --bin <project_name>
$ cd <project_name>
$ alr build
$ alr run
```

## References

- <https://ada-lang.io/>
