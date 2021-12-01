# Changelog

`hslua-module-text` uses [PVP Versioning][1].

## 1.0.1

Release pending.

-   Relaxed upper bound of hslua-core, allowing version 2.1.

-   Relaxed upper bound of hslua-packaging allowing version 2.1.

## 1.0.0

Released 2021-10-22.

-   Use hslua 2.0.

## 0.3.0.1

Released 2020-10-16.

-   Relaxed upper bound for hslua, allow `hslua-1.3.*`.

## 0.3.0

Released 2020-08-15.

-   Use self-documenting module. This allows to include documentation
    with the module definition, and to auto-generate documentation from
    that. Requires hslua-1.2.0 or newer.

-   Run CI tests with all GHC 8 versions, test stack builds.

## 0.2.1

Released 2019-05-04.

-   Require at least HsLua v1.0.3: that version has better support for
    modules.

-   Rename `pushModuleText` to `pushModule`. The old name is keeped as
    an alias for now.

## 0.2.0

Released 2018-09-24.

-   Use hslua 1.0.

## 0.1.2.2

Released 2018-03-09.

-   Relax upper bound for base.

## 0.1.2.1

Released 2017-11-24.

-   Add missing test file in the sources archive. This oversight had
    caused some stackage test failures.

## 0.1.2

Released 2017-11-17.

-   Run tests with Travis CI.
-   Fix problems with GHC 7.8

## 0.1.1

Released 2017-11-16.

-   Lift restriction on base to allow GHC 7.8.

## 0.1

Released 2017-11-15.

-   First version. Released on an unsuspecting world.