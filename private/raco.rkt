#lang racket/base
(require racket/cmdline
         raco/command-name
         "../main.rkt"
         (only-in "whereis.rkt"
                  whereis-system-base-keys
                  whereis-system-procs))

;; Scriptability:
;; - Prints path(s) found to stdout, errors/warnings to stderr.
;; - TODO: Add option to set separator for multiple results?
;; - Exit code:
;;   - 1 if exn raised
;;   - 2 if any request returned #f (but not empty list)
;;   - 0 otherwise

(define (report v [prefix ""])
  (define (print-path p)
    (printf "~a~a\n" prefix (path->string (simplify-path p))))
  (cond [(list? v) (for-each print-path v)]
        [(path? v) (print-path v)]
        [(string? v) (printf "~a~a\n" v)]))

(define (string->datum what s)
  (define in (open-input-string s))
  (begin0 (read in)
    (unless (eof-object? (peek-char in))
      (raise-user-error '|raco whereis|
                        "expected one S-expression for ~a, given: ~s"
                        what s))))

(define (raco-whereis-command args)

  ;; The code below is written to allow list of requests, but
  ;; currently limited to one (or zero) by #:once-any.

  (define todo null) ;; (Listof (-> (U Path (Listof Path))))
  (define (push! proc [fail void])
    (set! todo (cons proc todo)))

  (command-line
   #:program (short-program+command-name)
   #:argv args

   #:once-any

   [("-a" "--auto")
    module-or-collection-or-pkg
    ["" "Print the most relevant associated *directory* (not file) path"]
    (push! (lambda () (whereis-auto module-or-collection-or-pkg)))]

   [("-m" "--module")
    module-path
    "Print the path of the given module"
    (let ([modpath (string->datum "module path" module-path)])
      (push! (lambda () (whereis-module modpath))))]

   [("-l" "--library-module")
    lib-module-path
    ["" "Print the path of `(lib ,lib-module-path)"]
    (push! (lambda () (whereis-module `(lib ,lib-module-path))))]

   [("-p" "--pkg")
    package
    "Print the package's directory"
    (push! (lambda () (whereis-pkg package)))]

   [("-c" "--collect")
    collection
    "Print the collection's directories"
    (push! (lambda () (whereis-collection collection)))]

   [("-s" "--system")
    location
    "Print the location's path or paths"
    (let ([location (string->symbol location)])
      (push! (lambda () (whereis-system location))))]

   [("-r" "--raco")
    command
    "Print the path of the raco command's implementation"
    (push! (lambda () (whereis-raco command)))]

   [("-b" "--binding")
    providing-module name
    ["" "Print the path where the given name was defined"]
    (let ([providing-module (string->datum "module path" providing-module)]
          [name (string->symbol name)])
      (push! (lambda () (whereis-binding/symbol providing-module name))))]

   [("--all-system-paths")
    "Show all supported --system keys and their values"
    (let ()
      (define (show-keys keys)
        (for ([sym (in-list keys)])
          (define value
            (with-handlers ([exn:fail? (lambda (e) null)])
              (whereis-system sym)))
          (printf "~s:\n" sym)
          (report value "  ")))
      (show-keys whereis-system-base-keys)
      (show-keys (map car whereis-system-procs)))]

   #:args ()
   (let ([any-failed? #f])
     (for ([proc (in-list (reverse todo))])
       (with-handlers ([exn:fail?
                        (lambda (e)
                          (set! any-failed? #t)
                          (define msg (exn-message e))
                          (eprintf "~a\n" (exn-message e)))])
         (report (proc))))
     (exit (if any-failed? 2 0)))))

;; ============================================================

(module* main #f
  (raco-whereis-command (current-command-line-arguments)))
