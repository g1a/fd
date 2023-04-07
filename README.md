## FD

`fd`, for "find directory", is a variant on the "cd" command that will seach for directory names in a "directory path". This works very similar to the `$PATH` environment variable that is searched whenever a program is executed from the shell.

## Usage

- `fd dirname`
Changes the current working directory to the specified directory found somewhere in the list of directory paths stored in the `$FDPATH` environment variable.

- `fd dirn<TAB>`
Autocompletion is supported for all directories in the `$FDPATH`.

- `pd`
Return to the previous directory (wherever you were prior to running `fd`).

- `rd`
Redo directory -- reverses a `pd`.

- `@`
Run a command from another directory, and immediately restore the current working directory as soon as the command is finished. For example, `@ mysite drush status` will run `drush status` on the Drupal site located in the directory `mysite`. Equivalent to `fd dir; <command>; cd -`. **PRELIMINARY**; autocomplete works for the `dir` argument, but not for the command or command arguments.

- `fd-cache-rebuild` (or `fdcr`)
Directories added inside of directories in the `$FDPATH` are invisible to autocomplete until the fd cache is rebuilt (although `fd` will still find them if their full name is provided). Rebuild the cache to allow autocomplete to find them.

- `..`
Go up to the parent directory. If the [cdd](https://github.com/scriptworld/cdd) project is installed and sourced before `fd`, then `..` becomes an alias for `cdd`.

- `title mylabel`
Sets the title of the current directory and adds it to the `pd`/`rd` stack.

- `fd-suggest`
Prints out a recommended `$FDPATH` variable, with a pre-populated list of search locations. The suggested `$FDPATH` is built by finding local working copies of Git repositores cloned in your home directory. It is not a requirement that search locations only include projects backed by Git repositories; this is merely a common use case, and therefore serves as a good starting point. You may hand-edit the `$FDPATH` to suit your needs.

See [Installation](#installation) for more details. Note that `fd-suggest` only outputs the suggestion to the terminal; you must manually alter the `$FDPATH` in your `fdrc` file to persist it.

## Passive Behavior

When `fd.sh` is sourced during shell startup, it will change the current working directory back to the location it was previously at the last time the window was open (as identified by the tty). This is useful in conjunction with the [history-recall](https://github.com/g1a/history-recall) project, especially after a system restart on MacOS, when multiple terminal windows are restored.

## Installation

```
$ cd $HOME/persistent/install/location
$ git clone https://github.com/g1a/fd.git
$ cd fd
$ source fd-install.sh --with-cdd
```

The `fd-install.sh` script will create a `$HOME/.fdrc` file that sources `fd.sh` in the location it was installed to. The initial rc file will include an export of `$FDPATH` with locations provided by the `fd-suggest` function. Edit `$FDPATH` to suit your preferences.

The `--with-cdd` option will cause the installer to also install the [cdd](https://github.com/scriptworld/cdd) project, which provides a more robust implementation of the `..` function.

## About

The `fd` command was added to the [Utiliscripts project in 2015](https://github.com/greg-1-anderson/utiliscripts/commit/e2c02f5). The goal was to allow for projects to be organized hierarchically in the filesystem without requiring that the installation paths be memorized. It now exists in its own project to make it easier to install without taking on everything provided by Utiliscripts.
