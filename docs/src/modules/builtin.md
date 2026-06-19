# The core builtin module directory

`Accurate as of December 15, 2024`

Here is the full guide to all the modules, which I intend to keep largely perminantely in this arrangement so far as I can muster, and so far as it provides a good experience for everyone.

I will also not be changing the names to any of the modules, switching them around willy-nilly, etc., and especially not changing the name of the project, which is `down.nvim`, after its most recent overhaul.

This is a project in its extremely early days, so perhaps I may be laying this down too soon and without any real consequence, but I believe that the system, naming, etc. has congealed to the point where I can 
safely believe in the foundations it has laid.

> [!Tip]
> 
> On a lighter note, working on this project for this long has been an incredible pleasure, and I hope I can impart some of the wonderful flights of fancy my mind would necessarily take
> when stumbling upon what I believed to be a great (at the moment, perhaps) idea. Building an extensible and dev-friendly environment like this, I hope this is something I can share!


## The primary core modules are

Below, you will find a list of the primary **root** core modules builtin to `down.nvim`. There are a few things beyond the obvious that should be stated first:

1. While I have intended for all modules to be useful in their own right in a context not involving internal use, I do have to note that, like all things, there is a certain variance with regards how accessible a given builtin module is, as well as how much use it may serve to you. 
    To that end, I have tried to begin scaffolding a per-module README.md that should (at some point) provide any others contributing or building on top of `down.nvim` what they may and may not get out of the builtin modules here.

2. The hierarchy of modules presented here is very important to understand, both with regards its structure and its purpose. This becomes especially important when considering the control flow of the setup process, both for the plugin as a whole and indeed to a lesser degree for
    the individual modules themselves. It can be easy to at first get lost in the weeds here, but I don't believe it is something that should hinder those exploring the codebase very long at all.

3. As you can see, nearly allo of the builtin base modules have a number of submodules. A creator of a module which has another module (builtin or external) as its parent may, with the ability to affect the code of the parent, the ability to choose whether the module shouuld be
    loaded in whenever the parent is loaded in, or to be specified by the user (or through other means: e.g. through configurations, dependencies, and other module interdependencies).

| **id** | name        | purpose                                                                                                            | submodules                                                                                                                                                        | status                                                                                                                                                                      |
| ------ | ----------- | ------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1      | `cmd`       | provides the core logic to allow other moduless and users to create their own custom commands.                     | `back`, `mod`, `rename`, `find`                                                                                                                                   | <span style="opacity:60%;font-size: 12px; color:darkgreen">good! no changes anticipated at the moment besides a few possible refactors</span>.                              |
| 2      | `data`      | provides database and file-storage capabilities, through a variety of means and methods.                           | `clipboard`, `code`, `dirs`, `encrypt`, `export`, `log`, `media`, `metadata`, `mod`, `save`, `sync`, `tag`, `template`, `time`, `todo`                            | <span style="opacity:60%;color:darkyellow; font-size: 12px;">essential internally already, but will take time</span>                                                        |
| 3      | `edit`      | provides direct editing capabilities when interacting with files, and performs indirect analysis of files.         | `conceal`, `cursor`, `find`, `fold`, `hl`, `indent`, `rk inline`, `link`, `parse`, `syntax`, `toc`, `todo`                                                        | <span style="opacity:60%;color:orange; font-size: 12px;">essential internally already, but will take time</span>                                                            |
| 4      | `lsp`       | provides as much language-server-protocol-enabled functionality as possible without compromising rapidity.         | `command`, `completion`, `declaration`, `definition`, `document`, `implementation`, `moniker`, `notebook`, `refactor`, `reference`, `type`, `window`, `workspace` | <span style="opacity:60%;color:darkorange; font-size: 12px;">the lsp development process, not a surprise, will be a rather laborous endeavour</span>                        |
| 5      | `note`      | provides a journaling environment where notes can be created and leveraged in various powerful ways.               | `...`                                                                                                                                                             | <span style="opacity:60%;color:darkyellow; font-size: 12px;">while more will always be added, the note functionality is fortunately well under way</span>                   |
| 5      | `integration`      | provides interoperability with external integrationing, enabling emergent possibilities.                                  | `blink`, `cmp`, `coq`, `dcmp`, `fzf`, `lualine`, `pandoc`, `telescope`, `treesitter`, `trouble`                                                                   | <span style="opacity:60%;color:darkorange; font-size: 12px;">whie a few modules are well on their way, there are a few I'd like (blink, telescope, etc.)</span>             |
| 5      | `ui`        | provides internal ui functionality, and may be leveraged by users or devs withing to expand their own environment. | `calendar`, `chat`, `dashboard`, `icon`, `nav`, `popup`, `progress`, `prompt`, `render`, `sidebar`, `status`, `win`                                               | <span style="opacity:60%;color:orangered; font-size: 12px;">ui as a whole has not been an early priority, and it shows.</span>                                              |
| 5      | `workspace` | provides the core workspace or vault logic, keeping spaces compartmentalized appropriately.                        | `...`                                                                                                                                                             | <span style="opacity:60%;color:darkgreen; font-size: 12px;">the workspace module has been without any issue thus far, although I would like to clean it up.</span>          |
| 5      | `config`    | without configuration, will initalize a set of default modules most will use, but may be customized.               | `...`                                                                                                                                                             | <span style="opacity:60%;color:darkgreen; font-size: 12px;">Similarly, no problems with the ultra-simple config module, although I do wish to add meaningful options</span> |

`Accurate as of December 15, 2024`
