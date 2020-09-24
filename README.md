# `Switch-AtomProfile.ps1`

## Introduction

This powershell script used to set needed packages for specific profile in [atom editor](http://atom.io/).

## Usage

1. Set location at folder `switch-atom-profile`
2. Run following command. It will enable all packages in `profile\necessary` and `profile\<profile>` file. The rest packages will be disabled.

* Running on script:

``` shell
PS> .\Switch-AtomProfile.psm1 <profile>
```

* Running on module:

```shell
PS> Switch-AtomProfile -ProfileName <profile>
```

## Customization

You can create a file in `profile` folder containing packages separated by lines (blank lines are allowed) and then run command with its name.

## Example

- In file `profile\python`:

``` text
autocomplete-python
kite

linter
linter-flake8
linter-ui-default

python-black
```

- Command will be:

``` shell
PS> .\Switch-AtomProfile.psm1 python
```

## To-do list

- [x] Reduce running time by checking before execution.
- [x] Tab completion profile name.
- [ ] Warning if wrong packages received from profile.
- [ ] Allow to mix multiple profile in one run.
- [ ] Check current profile (maybe you want to start with single profile first).
- [ ] Finish this README.
