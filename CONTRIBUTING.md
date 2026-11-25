# Contributing to autoslip-noter

Thank you for considering a contribution to **autoslip-noter**!
The following guidelines help keep the process smooth for everyone.

## Reporting bugs

If you find a bug, please open an issue using the
[bug report template](https://github.com/MooersLab/autoslip-noter/issues/new?template=bug_report.md).

Include:

- A clear, descriptive title.
- Steps to reproduce the problem.
- Expected and actual behavior.
- Your environment (OS, Emacs version, package version).
- The versions of org-roam, org-noter, and autoslip-roam.

## Suggesting features

Feature ideas are welcome. Please open an issue using the
[feature request template](https://github.com/MooersLab/autoslip-noter/issues/new?template=feature_request.md).

Describe the problem you want to solve, your proposed solution,
and any alternatives you considered.

## Development setup

1. Fork and clone the repository, and clone autoslip-roam beside it:

   ```bash
   git clone https://github.com/<your-fork>/autoslip-noter.git
   git clone https://github.com/MooersLab/autoslip-roam.git
   cd autoslip-noter
   ```

2. Install the dependencies. The package needs org-roam and org-noter.
   Install them in Emacs with your package manager, then check that the
   Makefile can find them:

   ```bash
   make check-deps
   ```

   The Makefile looks in a straight.el build directory first and in the
   package.el directories second. Set `STRAIGHT_BUILD_DIR` and
   `AUTOSLIP_ROAM_DIR` when your locations differ.

3. Run the tests:

   ```bash
   make test
   ```

## Pull request process

1. Create a feature branch from `main`:

   ```bash
   git checkout -b feature/your-feature-name
   ```

2. Make your changes in small, focused commits.

3. Write or update tests to cover your changes.

4. Run the full test suite and confirm it passes.

5. Push your branch and open a pull request against `main`.

6. Fill in the pull request template completely.

7. Wait for a maintainer review. Address any feedback promptly.

## Commit message conventions

Use the following format:

```
<type>: <short summary>

<optional body explaining the "why">
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`.

## Code style

- Follow the existing code style in the repository.
- Use only the public hooks and functions of org-noter. Do not call
  functions whose names contain two hyphens after `org-noter`.
- Keep the package free of byte-compiler warnings:

  ```bash
  make compile
  ```

- Run the linter before submitting:

  ```bash
  make lint
  ```

## Code of conduct

This project follows the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md).
By participating, you agree to uphold this code. Please report
unacceptable behavior to blaine-mooers@ou.edu.
