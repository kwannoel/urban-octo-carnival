(export #t)

(import
  <expander-runtime>
  ../common.ss
  ./symbolnat)

;; Manage the generation of fresh symbols when alpha-converting some code
;; and/or further expanding macros or introducing new temporary bindings in further compiler passes

;; An UnusedTable is a [Hashof Symbol UnusedList]
;; Keys are symbols that do not end in numbers.
;; Values are lists where unused nats can be appended with
;; the key to make an unused symbol.
;; make-unused-table : -> UnusedTable
(def (make-unused-table) (make-hash-table-eq))

;; current-unused-table : [Parameterof UnusedTable]
(def current-unused-table (make-parameter (make-unused-table)))

;; copy-current-unused-table : -> UnusedTable
(define (copy-current-unused-table) (hash-copy (current-unused-table)))

;; symbol-fresh : Symbol -> Symbol
;; finds an symbol not used so far, marks it used, and returns it
(def (symbol-fresh sym)
  (unless (symbol? sym)
    (error 'symbol-fresh "expected symbol"))
  (let-values (((s n) (symbol-split sym)))
    (def ut (current-unused-table))
    (def ul (hash-ref ut s []))
    (cond ((unusedlist-unused? ul n)
           (hash-put! ut s (unusedlist-remove ul n))
           (symbolnat s n))
          (else
           (hash-put! ut s (unusedlist-rest ul))
           (symbolnat s (unusedlist-first ul))))))

;; identifier-fresh : Identifer -> Identifier
;; wraps the freshened symbol in the same marks and source location
(def (identifier-fresh id)
  (unless (identifier? id)
    (error 'identifier-fresh "expected identifier"))
  (restx id (symbol-fresh (stx-e id))))
