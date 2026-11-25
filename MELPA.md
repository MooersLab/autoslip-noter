# MELPA submission notes for autoslip-noter

This file records what MELPA expects from the package and what remains
to be done before a pull request to
[melpa/melpa](https://github.com/melpa/melpa) can be accepted.

## Status

| Requirement | Status |
|:------------|:-------|
| Public Git repository | Pending. Push this repository to `MooersLab/autoslip-noter`. |
| GPL-compatible license with a `LICENSE` file | Done. GPL-3.0-or-later. |
| Standard file header (`Author`, `Version`, `Package-Requires`, `Keywords`, `URL`) | Done. |
| `lexical-binding: t` in the first line | Done. |
| `;;; Commentary:` and `;;; Code:` sections and the closing `ends here` line | Done. |
| Keywords from `finder-known-keywords` | Done. `outlines`, `hypermedia`, `docs`, `convenience`. |
| Clean byte-compilation | Done. No warnings with Emacs 29.3. |
| Clean `checkdoc` | Done. |
| Clean `package-lint` | One error remains. See the blocker below. |
| All dependencies installable from MELPA or GNU ELPA | Blocked. See below. |
| A recipe | Drafted below. |

## Blocker: autoslip-roam is not on MELPA

MELPA only accepts a package when every package in its
`Package-Requires` header can be installed from MELPA, GNU ELPA, or
NonGNU ELPA. `org-roam` and `org-noter` are on MELPA. `autoslip-roam`
is not, and `package-lint` reports this as an error:

```
error: Package autoslip-roam is not installable.
```

Submit `autoslip-roam` to MELPA first. Its release must include the
function `autoslip-roam-create-child`, which this package calls. After
that release is on MELPA, set the minimum version in the
`Package-Requires` header of `autoslip-noter.el` to that release and
submit this package.

## Recipe

Save the following as the file `recipes/autoslip-noter` in a fork of
MELPA. The `:files` entry keeps the test file out of the package,
because the default file list would include `test-autoslip-noter.el`.

```elisp
(autoslip-noter :fetcher github
                :repo "MooersLab/autoslip-noter"
                :files ("autoslip-noter.el"))
```

## Checks to run before the pull request

```bash
make compile     # byte-compile without warnings
make lint        # checkdoc, and package-lint when it is installed
make test        # all tests pass
```

Then build and install the package from the recipe inside the MELPA
fork, as the MELPA contributing guide describes:

```bash
make recipes/autoslip-noter
```

Install the built package in a clean Emacs with `M-x package-install-file`
and start a session on a PDF file to confirm that it works.

## Pull request checklist

MELPA asks the submitter to confirm the following in the pull request.

- [ ] The package is released under a GPL-compatible license.
- [ ] I have read the MELPA `CONTRIBUTING.org` document.
- [ ] I have used `package-lint` and fixed what it reported.
- [ ] I have run `M-x checkdoc` and fixed what it reported.
- [ ] The package byte-compiles without warnings.
- [ ] I have built and installed the package from the recipe.
- [ ] The pull request adds one recipe only.
- [ ] The pull request gives a brief summary of what the package does
      and a link to the repository.

## Suggested summary for the pull request

> autoslip-noter connects org-noter to a folgezettel zettelkasten that
> is managed with autoslip-roam. When the user starts org-noter on a
> document, the package finds the folgezettel note for that document or
> creates one as a child of a note that the user chooses, links the two
> notes, and starts the session in that note. It uses one public
> org-noter hook and does not advise org-noter or org-roam.
