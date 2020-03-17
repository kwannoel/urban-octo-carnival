#!/usr/bin/env gxi

;; Runs the typchecker on the `.sexp` files in `../../examples`.

(import :gerbil/gambit/exceptions
        :std/iter
        :std/format
        :std/misc/repr
        :clan/pure/dict
        "../alpha-convert/alpha-convert.ss"
        "typecheck.ss")

;; tc-prog/list : [Listof StmtStx] -> [Assqof Symbol EnvEntry]
(def (tc-prog/list path)
  (symdict->list (tc-prog path)))

;; only-sexp-files : [Listof Path] -> [Listof Path]
(def (only-sexp-files ps)
  (filter (lambda (p) (string=? ".sexp" (path-extension p))) ps))

;; print-env : Env -> Void
(def (print-env env)
  (for ((x (symdict-keys env)))
    (def e (symdict-ref env x))
    (match e
      ((entry:type [] b)
       (printf "type ~s = ~y" x (type->sexpr b)))
      ((entry:type as b)
       (printf "type ~s~s = ~y" x as (type->sexpr b)))
      ((entry:unknown)
       (printf "unknown ~s\n" x))
      ((entry:known (typing-scheme me t))
       (unless (symdict-empty? me)
         (printf "constraints ")
         (print-representation me))
       (printf "val ~s : ~y" x (type->sexpr t)))
      ((entry:ctor (typing-scheme me t))
       (unless (symdict-empty? me)
         (printf "constraints ")
         (print-representation me))
       (printf "constructor ~s : ~y" x (type->sexpr t))))))

;; main
(def (main . args)
  (match args
    ([] (main "all"))
    (["all"]
     (def names (only-sexp-files (directory-files "../../examples")))
     (def files (map (lambda (p) (path-expand p "../../examples")) names))
     (if (null? files)
         (displayln "nothing to build")
         (apply main files)))
    ([file]
     (def prog (read-syntax-from-file file))
     (displayln file)
     (print-env (tc-prog prog))
     (newline))
    (files
     (def progs (map read-syntax-from-file files))
     (for ((f files) (p progs))
       (displayln f)
       (with-catch
        (lambda (e) (display-exception e))
        (lambda ()
          (print-env (tc-prog p))
          (newline)))
       (newline)))))
