(export #t)

(import
  :gerbil/gambit/bytes :gerbil/gambit/ports
  :std/format :std/iter :std/srfi/1 :std/sugar
  :std/misc/list :std/misc/number :std/misc/ports
  :clan/persist/content-addressing :clan/persist/db
  :clan/poo/io :clan/poo/poo (only-in :clan/poo/mop display-poo sexp<- Type new)
  :clan/json :clan/path-config :clan/syntax :clan/base :clan/ports
  :mukn/ethereum/assembly :mukn/ethereum/hex :mukn/ethereum/types
  :mukn/ethereum/ethereum :mukn/ethereum/network-config
  :mukn/ethereum/transaction :mukn/ethereum/tx-tracker :mukn/ethereum/json-rpc
  :mukn/ethereum/contract-runtime :mukn/ethereum/signing :mukn/ethereum/assets
  :mukn/ethereum/known-addresses :mukn/ethereum/contract-config :mukn/ethereum/hex)

; INTERPRETER
(defclass Interpreter (program participants arguments variable-offsets params-end)
  transparent: #t)

(defmethod {create-frame-variables Interpreter}
  (λ (self initial-block)
    (defvalues (_ contract-runtime-labels)
      {generate-consensus-runtime self})
    (def checkpoint-location
      (hash-get contract-runtime-labels {make-checkpoint-label self}))
    (flatten1
       [[[checkpoint-location UInt16]]
        [[initial-block Block]]
        (map (λ (participant) [participant Address]) (hash-values (@ self participants)))
        (hash-values (@ self arguments))])))

(def (sexp<-frame-variables frame-variables)
  `(list ,@(map (match <> ([v t] `(list ,(sexp<- t v) ,(sexp<- Type t)))) frame-variables)))

(defmethod {create-contract-pretransaction Interpreter}
  (λ (self initial-block sender-address)
    (defvalues (contract-runtime-bytes contract-runtime-labels)
      {generate-consensus-runtime self})
    (def initial-state
      {create-frame-variables self initial-block})
    (def initial-state-digest
      (digest-product initial-state))
    (def contract-bytes
      (stateful-contract-init initial-state-digest contract-runtime-bytes))
    (create-contract sender-address contract-bytes)))

(define-type ContractHandshake
  (Record
   initial-block: [Block]
   contract-config: [ContractConfig]))

(defmethod {execute-buyer Interpreter}
  (λ (self Buyer)
    (def timeoutInBlocks (.@ (current-ethereum-network) timeoutInBlocks))
    (def initial-block (+ (eth_blockNumber) timeoutInBlocks))
    (def pretx {create-contract-pretransaction self initial-block Buyer})
    (display-poo ["Deploying contract... " "timeoutInBlocks: " timeoutInBlocks
                  "initial-block: " initial-block "\n"])
    (def receipt (post-transaction pretx))
    (def contract-config (contract-config<-creation-receipt receipt))
    (display-poo ["Contract config: " ContractConfig contract-config "\n"])
    (verify-contract-config contract-config pretx)
    (def handshake (new ContractHandshake initial-block contract-config))
    (display-poo ["Handshake: " ContractHandshake handshake "\n"])
    (displayln "Handing off to seller ...\nPlease send this handshake to the other participant:\n```\n"
               (string<-json [ContractHandshake: (json<- ContractHandshake handshake)])
               "\n```\n")
    handshake))

(def (read-value name)
  (printf "~a: " name)
  (read-line))

(defmethod {execute-seller Interpreter}
  (λ (self contract-handshake Seller)
    (def initial-block (.@ contract-handshake initial-block))
    (def contract-config (.@ contract-handshake contract-config))
    (display-poo ["Verifying contract... "
                  "initial-block: " initial-block
                  "contract-config: " ContractConfig contract-config "\n"])
    (def create-pretx {create-contract-pretransaction self initial-block Seller})
    (verify-contract-config contract-config create-pretx)
    (def digest0 (car (hash-get (@ self arguments) 'digest0)))
    (display-poo ["Generating signature... " "Seller: " Address Seller "Digest: " Digest digest0 "\n"])
    (def signature (make-message-signature (secret-key<-address Seller) digest0))
    (def valid-signature? (message-signature-valid? Seller signature digest0))
    (display-poo ["Publishing signature... "
                  "signature: " Signature signature "verified valid: " valid-signature? "\n"])
    (def message-pretx
      {create-message-pretransaction self signature Signature initial-block Seller (.@ contract-config contract-address)})
    (display-poo ["Posting pre-tx: " PreTransaction message-pretx "\n"])
    (def receipt (post-transaction message-pretx))
    (display-poo ["receipt: " TransactionReceipt receipt "\n"])
    receipt))

;; See gerbil-ethereum/contract-runtime.ss for spec.
(defmethod {create-message-pretransaction Interpreter}
  (λ (self message type initial-block sender-address contract-address)
    (displayln "Send-message")
    (def frame-variables
      {create-frame-variables self initial-block})
    (displayln "Frame-variables: " (object->string (sexp<-frame-variables frame-variables)))
    (def frame-variable-bytes (marshal-product-f frame-variables))
    (displayln "frame-variable-bytes: " (0x<-bytes frame-variable-bytes))
    (def frame-length (bytes-length frame-variable-bytes))
    (displayln "frame-length: " frame-length)

    (def out (open-output-u8vector))
    (marshal UInt16 frame-length out)
    (marshal-product-to frame-variables out)
    (marshal type message out)
    (marshal UInt8 1 out)
    (def message-bytes (get-output-u8vector out))
    (displayln "sender-address: " (0x<-address sender-address))
    (displayln "contract-address: " (0x<-address contract-address))
    (call-function sender-address contract-address message-bytes)))

(def (marshal-product-f fields)
  (def out (open-output-u8vector))
  (marshal-product-to fields out)
  (get-output-u8vector out))

(def (marshal-product-to fields port)
  (for ((p fields))
    (with (([v t] p)) (marshal t v port))))

(def (digest-product fields)
  (def out (open-output-u8vector))
  (for ((p fields))
    (with (([v t] p)) (marshal t v out)))
  (digest<-bytes (marshal-product-f fields)))

(defmethod {generate-consensus-runtime Interpreter}
  (λ (self)
    {compute-parameter-offsets self}
    (parameterize ((brk-start (box params-start@)))
      (assemble
        (&begin
         &simple-contract-prelude
         &define-simple-logging
         (&define-check-participant-or-timeout)
         (&define-end-contract)
         {generate-consensus-code self}
         [&label 'brk-start@ (unbox (brk-start))])))))

; TODO: increment counter of checkpoints
(defmethod {make-checkpoint-label Interpreter}
  (λ (self)
    (def checkpoint-number 0)
    (string->symbol (string-append
      (symbol->string (@ (@ self program) name))
      (string-append "--cp" (number->string checkpoint-number))))))

(defmethod {compute-parameter-offsets Interpreter}
  (λ (self)
    (def frame-variables (make-hash-table))
    ;; Initial offset computed by global registers, see :mukn/ethereum/contract-runtime
    (def start params-start@)
    (for ((values variable value) (in-hash (@ self participants)))
      (def parameter-length (param-length Address))
      (hash-put! frame-variables
        variable (post-increment! start parameter-length)))
    (for ((values variable [_ type]) (in-hash (@ self arguments)))
      (def argument-length (param-length type))
      (hash-put! frame-variables
        variable (post-increment! start argument-length)))
    (set! (@ self variable-offsets) frame-variables)
    (set! (@ self params-end) start)))

(defmethod {lookup-variable-offset Interpreter}
  (λ (self variable-name)
    (def offset
      (hash-get (@ self variable-offsets) variable-name))
    (if offset
      offset
      (error "no address for variable: " variable-name))))

(defmethod {load-variable Interpreter}
  (λ (self variable-name variable-type)
    (&mloadat
      {lookup-variable-offset self variable-name}
      (param-length variable-type))))

(defmethod {add-local-variable Interpreter}
  (λ (self variable-name)
    ; TODO: look this up in the type table
    (def type
      (if (eq? variable-name 'signature) Signature Bool))
    (def argument-length
      (param-length type))
    (hash-put! (@ self variable-offsets)
      variable-name (post-increment! (@ self params-end) argument-length))))

(defmethod {generate-consensus-code Interpreter}
  (λ (self)
    (def consensus-interaction
      {get-interaction (@ self program) #f})
    (def cp0-statements
      (code-block-statements (hash-get consensus-interaction 'cp0)))
    {compute-parameter-offsets self}
    (&begin*
      (cons
        [&jumpdest {make-checkpoint-label self}]
        (flatten1 (map (λ (statement)
          {interpret-consensus-statement self statement}) cp0-statements))))))

(defmethod {find-other-participant Interpreter}
  (λ (self participant)
    (find
      (λ (p) (not (equal? p participant)))
      (hash-keys (@ self participants)))))

(defmethod {interpret-consensus-statement Interpreter}
  (λ (self statement)
    (match statement
      ; TODO: fix @check-timeout and re-enable the pattern
      (['set-participant-XXX new-participant]
        (let (other-participant {find-other-participant self new-participant})
          ; TODO: support more than two participants
          [(&check-participant-or-timeout!
            must-act: {lookup-variable-offset self new-participant}
            or-end-in-favor-of: {lookup-variable-offset self other-participant})]))
      (['def variable-name expression]
        {add-local-variable self variable-name}
        (match expression
          (['expect-published published-variable-name]
            [{lookup-variable-offset self variable-name} &read-published-data-to-mem])
          (['@app 'isValidSignature participant digest signature]
            [{load-variable self participant Address}
             {load-variable self digest Digest}
             ; signatures are passed by reference, not by value
             {lookup-variable-offset self signature}
             &isValidSignature])))
      (['require! variable-name]
        [{load-variable self variable-name Bool} &require!])
      (['expect-withdrawn participant amount]
        [{load-variable self participant Address}
         {load-variable self amount Ether}
         &withdraw!])
      (['@label 'end0]
        [&end-contract!])
      (else
       ;; TODO: don't ignore anything the compiler throws at us!!!
       (display "") #;(displayln "ignoring: " statement)))))

; PARSER
(def (parse-project-output file-path)
  (def project-output-file (open-file file-path))
  (def project-output (read project-output-file))
  (extract-program project-output))

(defclass Program (name arguments interactions)
  transparent: #t)

(defmethod {:init! Program}
  (λ (self (n "") (as []) (is #f))
    (set! (@ self name) n)
    (set! (@ self arguments) as)
    (set! (@ self interactions) (if is is (make-hash-table)))))

(defmethod {get-interaction Program}
  (λ (self participant)
    (hash-get (@ self interactions) participant)))

(defclass ParseContext (current-participant current-label code)
  constructor: :init!
  transparent: #t)

(defmethod {:init! ParseContext}
  (λ (self (cp #f) (cl 'begin0) (c (make-hash-table)))
    (set! (@ self current-participant) cp)
    (set! (@ self current-label) cl)
    (set! (@ self code) c)))

(defmethod {add-statement ParseContext}
  (λ (self statement)
    (match (hash-get (@ self code) (@ self current-label))
      ((code-block statements exits)
        (let ((x (append statements [statement])))
          (hash-put! (@ self code) (@ self current-label) (make-code-block x exits))
          self))
      (#f
        self))))

(defstruct code-block (statements exit) transparent: #t)

(defmethod {set-participant ParseContext}
  (λ (self new-participant)
    (unless (and (@ self current-participant) (equal? new-participant (@ self current-participant)))
      (let (contract (@ self code))
        (match (hash-get contract (@ self current-label))
          ((code-block statements exits)
            (begin
              (match (last statements)
                (['@label last-label]
                  (def init-statements (take statements (- (length statements) 1)))
                  (hash-put! contract (@ self current-label) (make-code-block init-statements last-label))
                  (hash-put! contract last-label (make-code-block [['set-participant new-participant]] #f))
                  (set! (@ self current-participant) new-participant)
                  (set! (@ self current-label) last-label))
                (else
                  (error "change of participant with no preceding label")))))
          (#f
            (begin
              (set! (@ self current-participant) new-participant)
              (hash-put! contract (@ self current-label) (make-code-block [['set-participant new-participant]] #f))
              self)))))))


(def (extract-program statements)
  (def program (make-Program))
  (def (process-header-statement statement)
    (match statement
      (['def name ['@make-interaction [['@list participants ...]] arguments labels interactions ...]]
        (set! (@ program name) name)
        (set! (@ program arguments) arguments)
        (list->hash-table interactions))
      (else
       ;; TODO: don't ignore anything the compiler throws at us!!!
       (display "") #;(displayln "ignoring: " statement))))
  (def raw-interactions (find hash-table? (map process-header-statement statements)))
  (def interactions-table (make-hash-table))
  (hash-map (λ (name body) (hash-put! interactions-table name (process-program name body))) raw-interactions)
  (set! (@ program interactions) interactions-table))

(def (process-program name body)
  (def parse-context (make-ParseContext))
  (for-each! body (λ (statement)
    (match statement
      (['participant:set-participant new-participant]
        {set-participant parse-context new-participant})
      (['consensus:set-participant new-participant]
        {set-participant parse-context new-participant})
      (else
        {add-statement parse-context statement}))))
  (@ parse-context code))