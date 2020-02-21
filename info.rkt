#lang info

;; pkg info

(define version "1.0")
(define collection "whereis")
(define deps '("base"))
(define build-deps '("racket-doc" "scribble-lib"))
(define pkg-authors '(ryanc))

;; collection info

(define name "whereis")
(define scribblings '(("whereis.scrbl" ())))

(define raco-commands
  '(("whereis" (submod whereis/private/raco main) "find Racket local paths" #f)))
