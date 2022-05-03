#lang racket/base
(require racket/cmdline
         racket/list
         raco/command-name
         pkg/path
         setup/main-collects
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

(define (result->paths v)
  (cond [(list? v) (append* (map result->paths v))]
        [(path? v) (list (simplify-path v))]
        [(string? v) (list (simplify-path (string->path v)))]))

(define (report v [prefix ""])
  (define (print-path p)
    (printf "~a~a\n" prefix (path->string (simplify-path p))))
  (for-each print-path (result->paths v)))

;; report-pkg : ... -> Boolean, #f if any path could not be mapped to pkg
(define (report-pkg v)
  (define pkgs
    (for/list ([p (in-list (result->paths v))])
      (or (path->pkg/base p)
          (begin0 #f (eprintf "failed to find pkg for ~e\n" (path->string p))))))
  (for ([pkg (in-list (remove-duplicates (filter string? pkgs)))])
    (printf "~a\n" pkg))
  (andmap values pkgs))

(define (path->pkg/base p)
  (or (path->pkg p)
      (let ([r (path->main-collects-relative p)])
        (if (and (pair? r) (eq? (car r) 'collects)) "base" #f))))

(define (string->datum what s)
  (define in (open-input-string s))
  (begin0 (read in)
    (unless (eof-object? (peek-char in))
      (whereis-error "expected one S-expression for ~a, given: ~s" what s))))

(define (whereis-error fmt . args)
  (apply raise-user-error '|raco whereis| fmt args))

(define (raco-whereis-command args)

  ;; The code below is written to allow list of requests, but
  ;; currently limited to one (or zero) by #:once-any.

  (define show 'path)

  (define (check-show-path mode)
    (unless (eq? show 'path)
      (whereis-error "cannot use ~a mode with --print option" mode)))

  (define todo null) ;; (Listof (-> (U Path (Listof Path))))
  (define (push! proc [fail void])
    (set! todo (cons proc todo)))

  (command-line
   #:program (short-program+command-name)
   #:argv args

   #:once-any

   [("-a" "--auto")
    module-or-collection-or-pkg
    ["Print the most relevant associated *directory* (not file) path"]
    (push! (lambda ()
             (check-show-path "--auto")
             (whereis-auto module-or-collection-or-pkg)))]

   [("-m" "--module")
    module-path
    "Print the location of the given module"
    (let ([modpath (string->datum "module path" module-path)])
      (push! (lambda () (whereis-module modpath))))]

   [("-l" "--library-module")
    lib-module-path
    ["Print the location of `(lib ,lib-module-path)"]
    (push! (lambda () (whereis-module `(lib ,lib-module-path))))]

   [("-p" "--pkg")
    package
    "Print the package's directory"
    (push! (lambda () (begin (check-show-path "--pkg") (whereis-pkg package))))]

   [("-c" "--collect")
    collection
    "Print the collection's locations"
    (push! (lambda () (whereis-collection collection)))]

   [("-s" "--system")
    location
    "Print the named location's path or paths"
    (let ([location (string->symbol location)])
      (push! (lambda () (begin (check-show-path "--system") (whereis-system location)))))]

   [("-r" "--raco")
    command
    "Print the location of the raco command's implementation"
    (push! (lambda () (whereis-raco command)))]

   [("-b" "--binding")
    providing-module name
    ["Print the location where the given name was defined"]
    (let ([providing-module (string->datum "module path" providing-module)]
          [name (string->symbol name)])
      (push! (lambda () (whereis-binding/symbol providing-module name))))]

   [("--all-system-paths")
    "Show all supported --system keys and their values."
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

   #:once-each
   [("--print")
    mode
    ["Determines what kind of location is printed."
     "  If <mode> is path (the default), print location paths."
     "  If <mode> is pkg, print each location's corresponding package instead."]
    (case mode
      [("path") (set! show 'path)]
      [("pkg") (set! show 'pkg)]
      [else (raise-user-error '|raco whereis|
                              "expected expected either `path` or `pkg` for --print option")])]

   #:args ()
   (let ([any-failed? #f])
     (for ([proc (in-list (reverse todo))])
       (with-handlers ([exn:fail?
                        (lambda (e)
                          (set! any-failed? #t)
                          (define msg (exn-message e))
                          (eprintf "~a\n" (exn-message e)))])
         (case show
           [(path) (report (proc))]
           [(pkg) (or (report-pkg (proc)) (set! any-failed? #t))])))
     (exit (if any-failed? 2 0)))))

;; ============================================================

(module* main #f
  (raco-whereis-command (current-command-line-arguments)))
