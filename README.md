![Version](https://img.shields.io/static/v1?label=autoslip-noter&message=0.1.0&color=brightcolor)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Emacs](https://img.shields.io/badge/Emacs-27.1+-purple.svg)](https://www.gnu.org/software/emacs/)
[![org-roam](https://img.shields.io/badge/org--roam-2.0+-green.svg)](https://www.orgroam.com/)
[![org-noter](https://img.shields.io/badge/org--noter-1.5+-green.svg)](https://github.com/org-noter/org-noter)

# autoslip-noter

Autoslip-noter connects [org-noter](https://github.com/org-noter/org-noter)
to a folgezettel zettelkasten that is managed with
[autoslip-roam](https://github.com/MooersLab/autoslip-roam).
It gives every document that you annotate one folgezettel note, files
that note under a parent of your choice, and uses it as the org-noter
notes file. The package is for readers who take notes on PDF files
inside Emacs and want those notes to land in the right place in their
zettelkasten without manual linking.

## Table of contents

- [Features](#features)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Usage](#usage)
- [Configuration](#configuration)
- [How it works](#how-it-works)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [Citation](#citation)
- [License](#license)
- [Acknowledgments](#acknowledgments)
- [Update table](#update-table)
- [Sources of funding](#sources-of-funding)

## Features

- Start an org-noter session from a PDF buffer with `M-x org-noter` and
  land in a folgezettel note.
- Reuse the existing note when a document has been annotated before.
- Choose the parent note from a list that shows only notes with a
  folgezettel address.
- Accept or change the next free child address that autoslip-roam
  suggests.
- Get the links between the parent note and the new note without any
  manual step.
- Keep the capture template of the bridge separate from your own
  org-roam capture templates.
- Rely on one public org-noter hook, so org-noter and org-roam are left
  unchanged.

## Prerequisites

- Emacs 27.1 or later.
- [org-roam](https://www.orgroam.com/) 2.0 or later, with a working
  database.
- [org-noter](https://github.com/org-noter/org-noter) 1.5.0 or later.
- [autoslip-roam](https://github.com/MooersLab/autoslip-roam) 3.0.0 or
  later. The version must provide the function
  `autoslip-roam-create-child`.
- A document viewer that org-noter supports. For PDF files,
  [pdf-tools](https://github.com/vedang/pdf-tools) is recommended.
- At least one root note with a folgezettel address in its title, for
  example `1. Crystallography`.

## Installation

Autoslip-noter is not yet available from MELPA. Install it from GitHub
until it is. See [MELPA.md](MELPA.md) for the status of the submission.

### With straight.el and use-package

```elisp
(use-package autoslip-roam
  :straight (autoslip-roam :type git :host github
                           :repo "MooersLab/autoslip-roam")
  :after org-roam
  :config (autoslip-roam-mode 1))

(use-package autoslip-noter
  :straight (autoslip-noter :type git :host github
                            :repo "MooersLab/autoslip-noter"
                            :files ("autoslip-noter.el"))
  :after (autoslip-roam org-noter)
  :config (autoslip-noter-mode 1))
```

### With package-vc (Emacs 29.1 or later)

```elisp
(package-vc-install "https://github.com/MooersLab/autoslip-roam")
(package-vc-install "https://github.com/MooersLab/autoslip-noter")
```

### Manual installation

```bash
git clone https://github.com/MooersLab/autoslip-roam.git
git clone https://github.com/MooersLab/autoslip-noter.git
```

Then add the following to your init file:

```elisp
(add-to-list 'load-path "/path/to/autoslip-roam")
(add-to-list 'load-path "/path/to/autoslip-noter")
(require 'autoslip-roam)
(require 'autoslip-noter)
(autoslip-roam-mode 1)
(autoslip-noter-mode 1)
```

### From MELPA (after acceptance)

```elisp
(use-package autoslip-noter
  :ensure t
  :after (autoslip-roam org-noter)
  :config (autoslip-noter-mode 1))
```

## Usage

Turn the bridge on once in your init file:

```elisp
;; Load the package
(require 'autoslip-noter)

;; Make org-noter use folgezettel notes
(autoslip-noter-mode 1)

;; Optional key binding in PDF buffers
(with-eval-after-load 'pdf-tools
  (define-key pdf-view-mode-map (kbd "C-c n") #'org-noter))
```

Then open a PDF file and start a session:

```
M-x org-noter
```

The first time that you annotate a document, you answer three prompts:

1. **Parent note.** Choose the note under which the new note belongs.
   Only notes with a folgezettel address are listed.
2. **Address.** Accept the suggested child address, for example `1.2c`,
   or type another valid one.
3. **Title.** Accept the file name of the document or type a title.

The bridge creates the note, links it to its parent, records the
document in the note, and starts the session. The next time that you
run `M-x org-noter` on the same document, the session opens in the same
note without any prompt.

You can also start from the note. Visit the note and run `M-x org-noter`
there. This works because the note carries the `NOTER_DOCUMENT`
property.

## Configuration

Customize via `M-x customize-group RET autoslip-noter RET` or add
to your init file:

```elisp
;; File the notes in a subdirectory of the org-roam directory
(setq autoslip-noter-capture-template
      '("n" "autoslip-noter literature note" plain "%?"
        :target (file+head "literature/%<%Y%m%d%H%M%S>-${slug}.org"
                           "#+title: ${title}\n#+filetags: :literature:\n")
        :unnarrowed t))

;; Use the first suggested address without asking
(setq autoslip-noter-confirm-address nil)
```

| Variable | Description | Default |
|:---------|:------------|:--------|
| `autoslip-noter-capture-template` | The org-roam capture template for new notes. It must create a new file and may only use the `${title}` and `${slug}` placeholders. | A template that writes `TIMESTAMP-slug.org` in the org-roam directory |
| `autoslip-noter-template-key` | Key of a template in `org-roam-capture-templates` to use in place of the template above. | `nil` |
| `autoslip-noter-default-title-function` | Function that proposes a title from the path of the document. | `file-name-base` |
| `autoslip-noter-confirm-address` | Whether to ask you to confirm or change the child address. | `t` |

The directory in the capture template must exist. The bridge does not
depend on your own capture templates, because those templates are often
written for other tools and may need values, such as a citekey, that
the bridge cannot supply.

## How it works

With `autoslip-noter-mode` enabled, the function
`autoslip-noter-create-session` is placed at the front of
`org-noter-create-session-from-document-hook`. When you run
`M-x org-noter` in a document buffer, the function does the following.

1. It searches the org-roam database for a note whose `NOTER_DOCUMENT`
   property points to the document. A note with a folgezettel address
   is preferred when several notes match.
2. When no note is found, it asks for the parent, the address, and the
   title, and it calls `autoslip-roam-create-child`. Autoslip-roam
   validates the address, refuses a duplicate, and inserts the links
   between the parent and the child.
3. It writes `NOTER_DOCUMENT` into the property drawer at the top of
   the note, so that the property belongs to the folgezettel note
   itself.
4. It calls `org-noter` in the note.

The page notes that you take during the session are headings in the
same file. Turning the mode off removes the function from the hook and
restores the standard behavior of org-noter.

## Testing

The test suite uses ERT and a real org-roam database in a temporary
directory. Org-noter is replaced by a stub, because a session needs a
displayed document.

```bash
make test            # check the dependencies, then run all tests
make test-verbose    # run all tests with fuller output
make list-tests      # list the names of the tests
make compile         # byte-compile the package
make lint            # run checkdoc, and package-lint when installed
make help            # list all targets
```

The Makefile looks for the dependencies in a straight.el build
directory first and in the package.el directories second. Override the
locations when yours differ:

```bash
make test STRAIGHT_BUILD_DIR=~/.emacs.d/straight/build \
          AUTOSLIP_ROAM_DIR=../autoslip-roam
```

## Troubleshooting

| Symptom | Likely cause | Remedy |
|:--------|:-------------|:-------|
| `Could not find package autoslip-noter` at startup | straight.el is the default for `use-package` and the form has no recipe. | Add the `:straight` recipe shown above, or use `:straight nil` with `:load-path`. |
| `The capture template "..." failed` | The template cannot be used without extra values, or its directory does not exist. | Check `autoslip-noter-capture-template` and create the directory. |
| `Symbol's function definition is void: autoslip-roam-create-child` | The installed autoslip-roam is too old. | Update autoslip-roam. |
| The parent list is empty | No note has a folgezettel address in its title. | Create a root note, for example `1. Crystallography`. |
| The new note has no link to its parent | `autoslip-roam-mode` is off. | Run `M-x autoslip-roam-mode`. |

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md)
for guidelines on how to submit issues, feature requests, and pull requests.

## Citation

If you use autoslip-noter in your work, please see
[CITATION.md](CITATION.md) for how to cite it.

## License

This project is licensed under the GNU General Public License v3.0 — see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [org-noter](https://github.com/org-noter/org-noter) by Gonçalo Santos
  and its current maintainers, whose org-roam module was the model for
  the hook that this package uses.
- [org-roam](https://www.orgroam.com/) by Jethro Kuan and contributors.
- [pdf-tools](https://github.com/vedang/pdf-tools) by Andreas Politz
  and Vedang Manerikar.

## Update table

| Version | Changes                                                      | Date              |
|:---------|:--------------------------------------------------------------|:-------------------|
| 0.1.0   | Initiate project. Added badges, funding, and this update table. | 2026 November 25 |

## Sources of funding

- NIH: R01 CA242845
- NIH: R01 AI088011
- NIH: P30 CA225520 (PI: R. Mannel)
- NIH: P20 GM103640 and P30 GM145423 (PI: A. West)
