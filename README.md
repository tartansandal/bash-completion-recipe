# Anaconda install for the bash-completion library and scripts

This library is provides sophisticated tab completion support for a large number of
command line utilities.  In particular, it is required by the `conda-bash-completion`
package which provides tab completion for the `conda` command.

There a various scenarios we need to account for when patching the upstream to work with
Anaconda.  This is complicated by the conflicting expectations of 'shell integration'
and 'isolated environments'. 

## How do we handle the simple happy path?

Steps in this Scenario:

1. The target system does not have a system-with installation of `bash-completion`. 
2. The user installs `bash-completion` into the `base` environment, which includes
    installing `/etc/profile.d/bash_completion.sh` under that environment's root.
3. The `conda init bash` hook ensures that installed `bash_completion.sh` script is
    sourced for new shells.
4. Tab completion is dynamically loaded for any commands that have scripts in
    `/share/bash-completion/competions/` under the base environment's root.

This raises the following problem:

1. The `/share/bash-completion/completions/` directory under the base environment's
    root is not searched for completion scripts by the upstream library.

Two solutions come to mind:

1. Patch the `__load_completion` function in the `bash_completion` library script
    so the "place-holder prefixed" `/share/bash-completion/completions` dir is
    searched for completions.

2. Patch the `bash_completion.sh` to ensure the "place-holder prefixed" `/share`
    directory is in `$XDG_DATA_DIRS`. 

Note the "place-holder prefix" is `/opt/anaconda1anaconda2anaconda3` and gets replaced
by the root of the environment that it gets installed into, in our case the `base`
environment.

Both of those solutions will work with the above Scenario and solves Problem 1. 

Additional Problem:
    
2. One problem with Solution 2 is it may change the behaviour of other conda
    installed packages -- those that also search `$XDG_DATA_DIRS`. This would help
    Anaconda to better align itself with the [XDG Base Directory Specification][1]
    Although this may be a good thing, its not really the responsibility of this
    package, and packages should not have potentially far reaching side-effects. 

    This raises the question: should conda activate/deactivate add/remove the
    target environments `/share` directory to/from the `$XDG_DATA_DIRS`?

## What about existing bash-completion users?

This case introduces some alternatives to Step 1 in the above scenario:

1.a The target system already has a active system-wide installation of
    `bash-completion` 

1.b The target system has system-wide packages installed that provide
    `bash-completion` scripts for their own commands.

1.c The system installed version of `bash-completion` is different from the version
    installed into the users `base` environment. 

Naturally this introduces some more problems:

3. In scenario 1.a, either the system or user `bashrc` scripts will ensure that
    `/etc/profile.d/bash_completion.sh` is sourced early in the initialization
    process, typically before the hooks provided by `conda init bash`.  The
    `bash_completion.sh` script has a check to prevent it from being loaded multiple
    times, so our conda install library is never loaded and none of its completion
    script directories are searched.

4. In scenario 1.b, we want bash completion to work for commands outside of our
    current conda environment, and completion code installed by pacakges in our
    active environment to supercede those installed system-wide (in the same way
    that a conda installed version of python shadows the system installed version).

5. In scenario 1.c, we the version of the library that is loaded may be different
    from the version specified by the environment. However, our expectation is that
    the environment version is always preferred.   

6. There is a possibility that system installed completion scripts incompatible with
    certain version of the `bash-completion` library.  Hopefully they have
    appropriate version guards.

Solutions:

3. Patch `bash-completion.sh` to remove the double load check.

    This addresses Problem 3, but has the potential to significantly slow down shell
    and sub-shell initialization -- the bash-completion library is over 2000 lines of
    shell script.

4. Patch `bash-completion.sh` to ensure the path to the "place-holder prefixed"
    `/share` directory is in `$XDG_DATA_DIRS`, but before the double loading check.

    This addresses Problem 4, provided we ensure that the path is only added
    once and that the path is added before system paths.

5. The bash_completion library sets a BASH_COMPLETION_VERSION_INFO variable, so we
    can patch `bash-completion.sh` to only load the library if the existing version is
    'different' from the one being loaded.  

    This saves us from an unnessary double load, but still allows for the library to
    be overriden, addressing Problem 5.

## What about users who install `bash-completion` into a non-base environment.

Modified Scenario Steps:

2.a User installs a version of `bash-completion` in a specific environment.
4.a User expects that version of bash completion to be active only that environment.

Solutions 1 and 2 use the "place-holder prefix" so that paths to the library and data
directories are already accounted for in this case.

This introduces some new problems:

6. The appropriate `bash_completion.sh` script is not being sourced.

7. Unloading the completions from the current shell would be very complicated and
    not 100% garanteed to work.  So a deactivate hook can not be expected to work.

Possible Solutions:

6. Add some hook to source the appropriate `bash_completion.sh` on activate.

    The double load protection from Solution 5 will ensure appropriate cooperation
    with this solution and Solution 1. 

7. Leave it up to the user to ensure that the appropriate `bash_completion.sh` is
    sourced for non-base installs.

8. Ensure the user understands these limitations via package documentation.

## What about users who don't activate the base environment by default?

Yes, some people prefer environments to be activated explicitly.

Additional Scenario Steps:

6. The flag `auto_activate_base` is set to `false` in their `.condarc` file.
7. The user installs `conda-bash-completion` into the base environment.
8. The `bash-completion` package is loaded as a dependency.
9. The user expects tab completion for the `conda` command to be dynamically loaded.

In this case we can't depend on environment activation hooks to help us out.

Does the use expect or care that other completion code is being loaded even though the
environment is not active? 

In this situation the user has access to a locally installed `conda` command.
`$CONDA_ROOT/condabin` in their `$PATH` which uses `$CONDA_ROOT/bin/python` which uses
the python libraries installed in the `base` environment.  In this 

## Conclusion

At this point a combination of Solutions 1, 5, 6, and 8 seems to be the best compromise.

## References

[1]: https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html

