# [null]

> [!WARNING]
> This project is very immature, so expect any functionality to be broken. Please don't hesitate to open an [issue](https://github.com/cattokomo/null/issues).

A dependency manager for Nelua.

## Usage

Null requires these dependencies to work:
 - `curl` command
 - `tar` command
 - `sha256sum` command

Once you have those dependencies, clone this repository or download `init.lua` as `null.lua` and then require it in your project's `.neluacfg.lua`
```lua
return require("null") {
    name = "project",
    version = "0.0.0",
    dependencies = {},
}
```

### `{string:any}`

You can pass anything that's a valid Nelua configuration, e.g `add_path` or `{c,ld}flags`.

### `name -> string`

> [!WARNING]
> This field is used to create a directory, and it isn't sanitized on retrieving the field. This will be fixed in the next release.

The project name, can be anything.

### `version -> string`

> [!WARNING]
> This field is used to create a directory, and it isn't sanitized on retrieving the field. This will be fixed in the next release.

The version of the project, must be a [SemVer](https://semver.org) format.

### `dependencies -> {string:NullDependency}`

Dependencies required for the project, the key is a string represents the identifier of the dependency, and the value is a specification of the required dependency. (See below)

#### `url -> string`

URL to where the tarball resides.

#### `hash -> string`

A checksum of the tarball, currently only support SHA-256.

#### `path -> string`

> [!NOTE]
> This functionality might changed in the next release.

Local path to dependency directory, if none found then fallback to fetching tarball source.
