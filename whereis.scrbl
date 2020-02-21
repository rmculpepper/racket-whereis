#lang scribble/manual
@(require racket/list scribble/example scribble/bnf
          (for-label racket/base racket/contract whereis pkg/lib))

@title[#:tag "whereis"]{Finding Racket Paths}

@(define-syntax-rule (symlist e ...)
   (apply elem (add-between (list (racket (quote e)) ...) ", ")))

@(begin
  ;; NOTE: "whereis.rkt" hand-edited to replace path prefixes with /home/me/dev
  (define my-eval (make-log-based-eval "private/whereis.rktd" 'replay))
  (my-eval '(require whereis))
  (define-syntax-rule (my-examples e ...)
    (examples #:eval my-eval e ...)))

@(define (returns-enclosing)
   "the path of the enclosing top-level module is returned")

@(define (prints-enclosing)
   "the path of the enclosing top-level module is printed")

This package provides an API and @exec{raco} command that consolidates
support for finding paths significant to Racket.


@section[#:tag "api"]{@racketmodname[whereis] API}

@defmodule[whereis]

The procedures provided by @racketmodname[whereis] return local
filesystem paths corresponding to Racket modules, collections,
packages, etc.

See also @secref["raco-whereis"].


@defproc[(whereis-module [modpath (or/c module-path? module-path-index?)])
         path?]{

Returns the path containing the declaration of the given module.

@margin-note{The example results are for a development build of racket in
@tt{/home/me/dev}. Your results will differ.}
@my-examples[
(whereis-module 'racket/list)
(whereis-module 'racket/draw)
(code:line (whereis-module '(submod racket reader)) (code:comment "same as racket"))
]

If @racket[modpath] cannot be resolved or resolves to a nonexistant
file, an exception is raised. If @racket[modpath] refers to a
submodule, @(returns-enclosing).
}


@defproc[(whereis-collection [collection collection-name?])
         (listof path?)]{

Returns a list of directory paths corresponding to the given
collection. Note that a collection may have multiple directories,
depending on collection roots and installed packages.

@my-examples[
(whereis-collection "json")
(whereis-collection "racket/gui")
(whereis-collection "drracket")
]

In contrast to @racket[collection-path], this procedure returns
returns @emph{all} directories associated with @racket[collection].

If no directories are found for @racket[collection], an exception is
raised.
}


@defproc[(whereis-pkg [pkg string?])
         path?]{

Returns the directory containing @racket[pkg], which must be installed
in some scope.

Like @racket[(pkg-directory pkg)], but simplifies the result path.

@my-examples[
(whereis-pkg "base")
(whereis-pkg "pict-lib")
]

If @racket[pkg] is not installed, an exception is raised.
}


@defproc[(whereis-raco [command string?])
         path?]{

Returns the path of the module implementing the given @exec{raco}
command.

@my-examples[
(whereis-raco "exe")
(whereis-raco "whereis")
]

An error is reported if the given @exec{raco} command is not registered.
If the command is implemented by a submodule, @(returns-enclosing).
}


@defproc[(whereis-system [name symbol?])
         (or/c path? (listof path?))]{

Prints the path or paths corresponding to the given system location.

The following location names are supported:
@itemlist[

@item{@symlist[home-dir pref-dir pref-file temp-dir init-dir init-file
               addon-dir doc-dir desk-dir sys-dir]
--- Equivalent to @racket[(find-system-path _name)].

Example: @racket[(whereis-system 'temp-dir)].}

@item{@symlist[exec-file config-dir host-config-dir collects-dir host-collects-dir]
--- Like @racket[(find-system-path _name)], but relative paths are
converted into absolute paths by interpreting them with respect to the
path of the @exec{racket} executable.

Example: @racket[(whereis-system 'config-dir)].}

@item{the name of a procedure from @racketmodname[setup/dirs] that
returns a path or list of paths.

Example: @racket[(whereis-system 'get-config-dir)].}

]

If @racket[name] is unknown or if the implementation returns
@racket[#f], an exception is raised.
}


@defproc[(whereis-binding [id identifier?]
                          [phase (or/c exact-integer? #f) (syntax-local-phase-level)])
         path?]{

Returns the path of the module that defines the binding referred to by
@racket[id] (at phase @racket[phase]). Note that the defined name
might be different due to renamings.

@my-examples[
(whereis-binding #'lambda)
(whereis-binding #'in-list)
]

Note that this procedure does not see through @racket[contract-out].
That is, @racket[contract-out] defines and exports an auxiliary macro
to perform contract checking, and this procedure reports the
definition site of the macro (the site where @racket[contract-out] is
used) instead of the definition site of the binding being protected.

If @racket[id] does not refer to a module export at phase
@racket[phase], or if the binding was defined by a built-in module
(such as @racketmodname['#%kernel]), an error is reported.
If @racket[id] is defined in a submodule, @(returns-enclosing).
}


@defproc[(whereis-binding/symbol [providing-mod module-path?]
                                 [name symbol?])
         path?]{

Like @racket[whereis-binding], but the binding is @racket[name]
exported by @racket[providing-mod]. Note that the defined name might
be different due to renamings.

@my-examples[
(whereis-binding/symbol 'racket 'define)
(whereis-binding/symbol 'racket 'in-list)
]

If @racket[providing-mod] does not have an export named @racket[name],
or if the binding was defined by a built-in module (such as
@racketmodname['#%kernel]), an error is reported.
If @racket[id] is defined in a submodule, @(returns-enclosing).
}


@; ============================================================
@section[#:tag "raco-whereis"]{@exec{raco whereis}: Finding Racket Local Paths}

@(define-syntax-rule (ttlist e ...)
   (apply elem (add-between (list (tt (format "~a" 'e)) ...) ", ")))

The @exec{raco whereis} command prints the local filesystem path
corresponding to Racket modules, collections, packages, etc.

Command-line flags:

@itemlist[

@item{@Flag{m} @nonterm{module-path} or @DFlag{module}
@nonterm{module-path} --- Prints the path containing the declaration
of the given module. The @nonterm{module-path} argument must contain
exactly one @racket[read]able S-expression, otherwise an error is
reported.

Examples:
@itemlist[
@item{@exec{raco whereis -m racket/list}}
@item{@exec{raco whereis -m racket/draw}}
@item{@exec{raco whereis -m '(submod racket reader)'} ---
same as @exec{raco whereis -m racket}}
]

An error is reported if @nonterm{module-path} cannot be resolved or if
it ``resolves'' to a nonexistant file.
If @nonterm{module-path} refers to a submodule, @(prints-enclosing).
}

@item{@Flag{c} @nonterm{collection} or @DFlag{collect}
@nonterm{collection} --- Prints the directory paths corresponding to
the given collection. Note that a collection may have multiple
directories, depending on collection roots and installed packages.

Examples:
@itemlist[
@item{@exec{raco whereis -c json}}
@item{@exec{raco whereis -c racket/gui}}
@item{@exec{raco whereis -c drracket}}
]

An error is reported if @nonterm{collection} is invalid (see
@racket[collection-name?]) or if no directories are found.
}

@item{@Flag{p} @nonterm{package} or @DFlag{pkg} @nonterm{package} ---
Prints the path of the directory containing @nonterm{package}, which
must be installed in some scope.

Examples:
@itemlist[
@item{@exec{raco whereis -p base}}
@item{@exec{raco whereis -p pict-lib}}
]

If @nonterm{package} is not installed, an error is reported.
}

@item{@Flag{r} @nonterm{command} or @DFlag{raco} @nonterm{command} ---
Prints the path of the module implementing the given @exec{raco} command.

Examples:
@itemlist[
@item{@exec{raco whereis -r exe}}
@item{@exec{raco whereis -r whereis}}
]

An error is reported if the given @exec{raco} command is not registered.
If @nonterm{command} is implemented by a submodule, @(prints-enclosing).
}

@item{@Flag{s} @nonterm{name} or @DFlag{system} @nonterm{name} ---
Prints the path or paths corresponding to the given system location.

The following location names are supported:
@itemlist[
@item{@ttlist[home-dir pref-dir pref-file temp-dir init-dir init-file
              addon-dir doc-dir desk-dir sys-dir]
--- Same as @racket[(find-system-path _name)].

Example: @exec{raco whereis -s temp-dir}}

@item{@ttlist[exec-file config-dir host-config-dir collects-dir host-collects-dir]
      --- Like @racket[(find-system-path _name)], but relative paths are
converted into absolute paths by interpreting them with respect to the
path of the @exec{racket} executable.

Example: @exec{raco whereis -s config-dir}.}

@item{the name of a procedure from @racketmodname[setup/dirs] that
returns a path or list of paths.

Example: @exec{raco whereis -s find-config-dir}.}

]

If @nonterm{name} is unknown or if the corresponding procedure returns
@racket[#f], an error is reported.
}

@item{@DFlag{all-system-paths} ---
Prints all supported ``system'' locations (that is, valid arguments to
@DFlag{system}) and their values. If a location's corresponding
procedure returns @racket[#f], instead of printing an error message
like @DFlag{system}, the location is printed without any values.
}

@item{@Flag{b} @nonterm{providing-module} @nonterm{name} or
      @DFlag{binding} @nonterm{providing-module} @nonterm{name}
--- Prints the path of the module that defines the binding exported by
@nonterm{providing-module} as @nonterm{name}. Note that the defined name
might be different due to renamings.

Examples:
@itemlist[
@item{@exec{raco whereis -b racket define}}
@item{@exec{raco whereis -b racket in-list}}
]

Note that @exec{whereis} does not see through @racket[contract-out].
That is, @racket[contract-out] defines and exports an auxiliary macro
to perform contract checking, and @exec{whereis} reports the
definition site of the macro (the site where @racket[contract-out] is
used) instead of the definition site of the binding being protected.

If @nonterm{name} is not provided by @nonterm{providing-module}, or if
the binding was defined by a built-in module (such as
@racketmodname['#%kernel]), an error is reported.
If @nonterm{name} is defined in a submodule, @(prints-enclosing).
}

]
