#lang racket/base
(require racket/contract/base
         setup/collection-name
         "private/whereis.rkt")
(provide
 (contract-out
  [whereis-module
   (-> (or/c module-path? module-path-index?) path?)]
  [whereis-pkg
   (-> string? path?)]
  [whereis-collection
   (-> collection-name? (listof path?))]
  [whereis-raco
   (-> string? path?)]
  [whereis-system
   (-> symbol? (or/c path? (listof path?)))]
  [whereis-binding
   (->* [identifier?] [(or/c exact-integer? #f)] path?)]
  [whereis-binding/symbol
   (-> module-path? symbol? path?)]
  [whereis-auto
   (-> string? path?)]))
